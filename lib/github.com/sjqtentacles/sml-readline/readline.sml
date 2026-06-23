(* readline.sml

   Pure, deterministic line-editor state machine + ANSI escape decoder.
   No FFI, no termios, no threads, no clock: `step`, `render` and `decode`
   are ordinary total functions over immutable values. *)

structure Readline :> READLINE =
struct

  (* ---- Key & action model -------------------------------------------- *)

  datatype key =
      Char of char
    | Enter
    | Backspace
    | Delete
    | Left
    | Right
    | Up
    | Down
    | Home
    | End
    | Tab
    | CtrlA
    | CtrlE
    | CtrlK
    | CtrlU
    | CtrlW
    | CtrlY
    | CtrlL
    | CtrlC
    | CtrlD
    | CtrlR
    | Alt of char

  datatype action =
      Redraw
    | Submit of string
    | Cancel
    | Eof
    | Bell
    | Noop

  type completer = string * int -> {replacement:string, candidates:string list}

  val noCompleter : completer = fn _ => {replacement = "", candidates = []}

  (* Reverse-incremental-search state: the query typed so far, the line/cursor
     to restore on abort, and the history index of the current match (~1 if no
     match yet). *)
  type search = {query:string, saved:string, savedPos:int, idx:int}

  type state = {
    prompt : string,
    buf    : string,
    pos    : int,
    hist   : string list,    (* most recent last *)
    navIdx : int option,     (* SOME i: viewing hist[i]; NONE: editing buf *)
    saved  : string,         (* editing line stashed while navigating hist *)
    kill   : string,         (* kill ring (single slot) *)
    comp   : completer,
    search : search option
  }

  (* ---- Construction & accessors -------------------------------------- *)

  fun init {prompt, history} =
    {prompt = prompt, buf = "", pos = 0, hist = history, navIdx = NONE,
     saved = "", kill = "", comp = noCompleter, search = NONE}

  fun initWith {prompt, history, completer} =
    {prompt = prompt, buf = "", pos = 0, hist = history, navIdx = NONE,
     saved = "", kill = "", comp = completer, search = NONE}

  fun buffer (s:state)  = #buf s
  fun cursor (s:state)  = #pos s
  fun prompt (s:state)  = #prompt s
  fun history (s:state) = #hist s
  fun killRing (s:state)= #kill s
  fun searching (s:state) = case #search s of SOME _ => true | NONE => false

  (* ---- Functional record updates ------------------------------------- *)

  fun rebuild (s:state) (buf, pos, navIdx, saved, kill, search) : state =
    {prompt = #prompt s, buf = buf, pos = pos, hist = #hist s,
     navIdx = navIdx, saved = saved, kill = kill, comp = #comp s,
     search = search}

  fun setBuf s (buf, pos) =
    rebuild s (buf, pos, #navIdx s, #saved s, #kill s, #search s)
  fun setKill s (buf, pos, kill) =
    rebuild s (buf, pos, #navIdx s, #saved s, kill, #search s)
  fun setSearch s se =
    rebuild s (#buf s, #pos s, #navIdx s, #saved s, #kill s, se)
  fun setSearchBuf s (buf, pos, se) =
    rebuild s (buf, pos, #navIdx s, #saved s, #kill s, se)
  fun navTo s (buf, pos, navIdx, saved) =
    rebuild s (buf, pos, navIdx, saved, #kill s, #search s)

  fun submitState (s:state) line =
    let val hist' = if line = "" then #hist s else (#hist s) @ [line]
    in {prompt = #prompt s, buf = "", pos = 0, hist = hist', navIdx = NONE,
        saved = "", kill = #kill s, comp = #comp s, search = NONE}
    end

  fun cancelState (s:state) =
    {prompt = #prompt s, buf = "", pos = 0, hist = #hist s, navIdx = NONE,
     saved = "", kill = #kill s, comp = #comp s, search = NONE}

  (* ---- String / word helpers ----------------------------------------- *)

  fun takeS (s, n) = String.substring (s, 0, n)
  fun dropS (s, n) = String.substring (s, n, String.size s - n)
  fun midS  (s, i, j) = String.substring (s, i, j - i)

  (* Start of the word immediately before `pos` (whitespace-delimited). *)
  fun prevWordStart (s, pos) =
    let
      fun isWs i = Char.isSpace (String.sub (s, i))
      fun skipWs i   = if i > 0 andalso isWs (i-1) then skipWs (i-1) else i
      fun skipWord i = if i > 0 andalso not (isWs (i-1)) then skipWord (i-1) else i
    in skipWord (skipWs pos) end

  (* End of the word at or after `pos` (whitespace-delimited). *)
  fun nextWordEnd (s, pos) =
    let
      val m = String.size s
      fun isWs i = Char.isSpace (String.sub (s, i))
      fun skipWs i   = if i < m andalso isWs i then skipWs (i+1) else i
      fun skipWord i = if i < m andalso not (isWs i) then skipWord (i+1) else i
    in skipWord (skipWs pos) end

  (* ---- Normal-mode transition ---------------------------------------- *)

  fun stepNormal (s:state) key =
    let
      val buf = #buf s
      val pos = #pos s
      val n   = String.size buf
    in
      case key of
          Char c =>
            (setBuf s (takeS (buf, pos) ^ String.str c ^ dropS (buf, pos),
                       pos + 1), Redraw)
        | Enter => (submitState s buf, Submit buf)
        | Backspace =>
            if pos > 0
            then (setBuf s (takeS (buf, pos-1) ^ dropS (buf, pos), pos-1), Redraw)
            else (s, Bell)
        | Delete =>
            if pos < n
            then (setBuf s (takeS (buf, pos) ^ dropS (buf, pos+1), pos), Redraw)
            else (s, Bell)
        | Left  => if pos > 0 then (setBuf s (buf, pos-1), Redraw) else (s, Bell)
        | Right => if pos < n then (setBuf s (buf, pos+1), Redraw) else (s, Bell)
        | Home  => (setBuf s (buf, 0), Redraw)
        | End   => (setBuf s (buf, n), Redraw)
        | CtrlA => (setBuf s (buf, 0), Redraw)
        | CtrlE => (setBuf s (buf, n), Redraw)
        | CtrlK =>
            if pos < n
            then (setKill s (takeS (buf, pos), pos, dropS (buf, pos)), Redraw)
            else (s, Bell)
        | CtrlU =>
            if pos > 0
            then (setKill s (dropS (buf, pos), 0, takeS (buf, pos)), Redraw)
            else (s, Bell)
        | CtrlW =>
            let val start = prevWordStart (buf, pos) in
              if start < pos
              then (setKill s (takeS (buf, start) ^ dropS (buf, pos), start,
                               midS (buf, start, pos)), Redraw)
              else (s, Bell)
            end
        | CtrlY =>
            if #kill s <> ""
            then (setBuf s (takeS (buf, pos) ^ #kill s ^ dropS (buf, pos),
                            pos + String.size (#kill s)), Redraw)
            else (s, Bell)
        | CtrlL => (s, Redraw)
        | CtrlC => (cancelState s, Cancel)
        | CtrlD =>
            if n = 0 then (s, Eof)
            else if pos < n
            then (setBuf s (takeS (buf, pos) ^ dropS (buf, pos+1), pos), Redraw)
            else (s, Bell)
        | CtrlR =>
            (setSearch s (SOME {query = "", saved = buf, savedPos = pos, idx = ~1}),
             Redraw)
        | Tab =>
            let val {replacement, candidates} = (#comp s) (buf, pos) in
              if null candidates then (s, Bell)
              else
                let val start = prevWordStart (buf, pos) in
                  (setBuf s (takeS (buf, start) ^ replacement ^ dropS (buf, pos),
                             start + String.size replacement), Redraw)
                end
            end
        | Up =>
            let val len = List.length (#hist s) in
              if len = 0 then (s, Bell)
              else
                (case #navIdx s of
                     NONE =>
                       let val i = len - 1
                           val line = List.nth (#hist s, i)
                       in (navTo s (line, String.size line, SOME i, buf), Redraw) end
                   | SOME i =>
                       if i > 0
                       then let val line = List.nth (#hist s, i-1)
                            in (navTo s (line, String.size line, SOME (i-1),
                                         #saved s), Redraw) end
                       else (s, Bell))
            end
        | Down =>
            (case #navIdx s of
                 NONE => (s, Bell)
               | SOME i =>
                   let val len = List.length (#hist s) in
                     if i < len - 1
                     then let val line = List.nth (#hist s, i+1)
                          in (navTo s (line, String.size line, SOME (i+1),
                                       #saved s), Redraw) end
                     else (navTo s (#saved s, String.size (#saved s), NONE, ""),
                           Redraw)
                   end)
        | Alt c =>
            (case c of
                 #"b" => (setBuf s (buf, prevWordStart (buf, pos)), Redraw)
               | #"f" => (setBuf s (buf, nextWordEnd (buf, pos)), Redraw)
               | #"d" =>
                   let val e = nextWordEnd (buf, pos) in
                     if e > pos
                     then (setKill s (takeS (buf, pos) ^ dropS (buf, e), pos,
                                      midS (buf, pos, e)), Redraw)
                     else (s, Bell)
                   end
               | _ => (s, Noop))
    end

  (* ---- Reverse-search-mode transition -------------------------------- *)

  (* Most-recent-first scan for the highest index <= startIdx whose entry
     contains `query` as a substring. *)
  fun findFrom hist query startIdx =
    let
      fun loop i =
        if i < 0 then NONE
        else if String.isSubstring query (List.nth (hist, i)) then SOME i
        else loop (i - 1)
    in loop startIdx end

  fun stepSearch (s:state) (se:search) key =
    let val hist = #hist s in
      case key of
          Char c =>
            let val q = #query se ^ String.str c in
              case findFrom hist q (List.length hist - 1) of
                  SOME i =>
                    let val line = List.nth (hist, i) in
                      (setSearchBuf s (line, String.size line,
                         SOME {query = q, saved = #saved se,
                               savedPos = #savedPos se, idx = i}), Redraw)
                    end
                | NONE =>
                    (setSearch s (SOME {query = q, saved = #saved se,
                                        savedPos = #savedPos se, idx = #idx se}),
                     Bell)
            end
        | Backspace =>
            let val q = if String.size (#query se) > 0
                        then takeS (#query se, String.size (#query se) - 1)
                        else ""
            in
              case findFrom hist q (List.length hist - 1) of
                  SOME i =>
                    let val line = List.nth (hist, i) in
                      (setSearchBuf s (line, String.size line,
                         SOME {query = q, saved = #saved se,
                               savedPos = #savedPos se, idx = i}), Redraw)
                    end
                | NONE =>
                    (setSearch s (SOME {query = q, saved = #saved se,
                                        savedPos = #savedPos se, idx = ~1}),
                     Redraw)
            end
        | CtrlR =>
            (case findFrom hist (#query se) (#idx se - 1) of
                 SOME i =>
                   let val line = List.nth (hist, i) in
                     (setSearchBuf s (line, String.size line,
                        SOME {query = #query se, saved = #saved se,
                              savedPos = #savedPos se, idx = i}), Redraw)
                   end
               | NONE => (s, Bell))
        | Enter => (submitState s (#buf s), Submit (#buf s))
        | CtrlC =>
            (* abort the search, restoring the original line *)
            (setSearch (setBuf s (#saved se, #savedPos se)) NONE, Redraw)
        | _ =>
            (* any other key terminates the search (keeping the match) and is
               then executed in normal mode *)
            stepNormal (setSearch s NONE) key
    end

  fun step (s:state) key =
    case #search s of
        SOME se => stepSearch s se key
      | NONE => stepNormal s key

  (* ---- View model ----------------------------------------------------- *)

  fun render (s:state) =
    case #search s of
        SOME se =>
          let val pfx = "(reverse-i-search)`" ^ #query se ^ "': "
          in {text = pfx ^ #buf s, cursor = String.size pfx + #pos s} end
      | NONE =>
          {text = #prompt s ^ #buf s,
           cursor = String.size (#prompt s) + #pos s}

  (* ---- ANSI / escape decoder ----------------------------------------- *)

  (* Map a single byte (not ESC) to a key, if recognised. *)
  fun single c =
    case Char.ord c of
        127 => SOME Backspace
      | 8   => SOME Backspace
      | 13  => SOME Enter
      | 10  => SOME Enter
      | 9   => SOME Tab
      | 1   => SOME CtrlA
      | 5   => SOME CtrlE
      | 11  => SOME CtrlK
      | 21  => SOME CtrlU
      | 23  => SOME CtrlW
      | 25  => SOME CtrlY
      | 12  => SOME CtrlL
      | 3   => SOME CtrlC
      | 4   => SOME CtrlD
      | 18  => SOME CtrlR
      | k   => if k >= 32 andalso k < 127 then SOME (Char c) else NONE

  fun decode input =
    let
      val n = String.size input
      fun sub i = String.sub (input, i)
      fun leftoverFrom i = (* incomplete escape sequence: hand back the tail *)
        String.extract (input, i, NONE)

      fun go i acc =
        if i >= n then (List.rev acc, "")
        else if sub i = Char.chr 27 then decodeEsc i acc
        else (case single (sub i) of
                  SOME k => go (i+1) (k :: acc)
                | NONE   => go (i+1) acc)

      and decodeEsc i acc =
        if i + 1 >= n then (List.rev acc, leftoverFrom i)
        else
          let val c1 = sub (i+1) in
            if c1 = #"[" orelse c1 = #"O" then decodeCsi i (i+2) acc
            else go (i+2) (Alt c1 :: acc)
          end

      and decodeCsi i j acc =
        if j >= n then (List.rev acc, leftoverFrom i)
        else
          (case sub j of
               #"A" => go (j+1) (Up :: acc)
             | #"B" => go (j+1) (Down :: acc)
             | #"C" => go (j+1) (Right :: acc)
             | #"D" => go (j+1) (Left :: acc)
             | #"H" => go (j+1) (Home :: acc)
             | #"F" => go (j+1) (End :: acc)
             | c => if Char.isDigit c then decodeTilde i j acc
                    else go (j+1) acc)

      and decodeTilde i j acc =
        let
          fun scan k =
            if k >= n then NONE
            else if Char.isDigit (sub k) then scan (k+1)
            else SOME k
        in
          case scan j of
              NONE => (List.rev acc, leftoverFrom i)   (* still incomplete *)
            | SOME k =>
                if sub k = #"~" then
                  let
                    val num = midS (input, j, k)
                    val key = case num of
                                  "1" => SOME Home
                                | "7" => SOME Home
                                | "4" => SOME End
                                | "8" => SOME End
                                | "3" => SOME Delete
                                | _   => NONE
                  in case key of
                         SOME kk => go (k+1) (kk :: acc)
                       | NONE    => go (k+1) acc
                  end
                else go (k+1) acc
        end
    in
      go 0 []
    end

  (* Streaming decoder: the buffered bytes of an in-flight escape sequence. *)
  type decoder = string
  val decoder = ""
  fun feed d c =
    let val (ks, rest) = decode (d ^ String.str c)
    in (rest, ks) end
  fun pending d = d

end
