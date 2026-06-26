structure Tests = struct open Harness structure L = LineEdit
fun run () = let
  val st0 = Readline.init { prompt = "> ", history = [] }

  (* ---- stepChar / stepKey (back-compat + single key) ---- *)
  val () = section "stepChar / stepKey"
  val (st1, _) = L.stepChar st0 #"a"
  val () = checkString "stepChar insert a" ("a", Readline.buffer st1)
  val (st2, _) = L.stepKey st1 Readline.Backspace
  val () = checkString "stepKey backspace" ("", Readline.buffer st2)

  (* ---- feedString builds a whole line ---- *)
  val () = section "feedString"
  val (sHi, acts) = L.feedString st0 "hi"
  val () = checkString "feedString buffer" ("hi", Readline.buffer sHi)
  val () = checkInt "feedString action count" (2, List.length acts)
  val () = checkInt "feedString cursor at end" (2, Readline.cursor sHi)

  (* ---- run a batch of keys (insert, motion, delete) ---- *)
  val () = section "run batch of keys"
  open Readline
  val (sR, actsR) =
    L.run st0 [Char #"a", Char #"b", Char #"c", Left, Backspace]
  (* abc -> cursor 3 -> Left (cursor 2) -> Backspace removes 'b' -> "ac" *)
  val () = checkString "run buffer" ("ac", Readline.buffer sR)
  val () = checkInt "run action count" (5, List.length actsR)

  (* ---- motion: CtrlA / CtrlE ---- *)
  val () = section "CtrlA / CtrlE motion"
  val (sM, _) = L.feedString st0 "hello"
  val (sM, _) = L.stepKey sM CtrlA
  val () = checkInt "CtrlA to start" (0, Readline.cursor sM)
  val (sM, _) = L.stepKey sM CtrlE
  val () = checkInt "CtrlE to end" (5, Readline.cursor sM)

  (* ---- kill (CtrlK) + yank (CtrlY) ---- *)
  val () = section "kill and yank"
  val (sK, _) = L.feedString st0 "hello world"
  val (sK, _) = L.stepKey sK CtrlA               (* cursor at 0 *)
  val (sK, _) = L.run sK [Right, Right, Right, Right, Right] (* cursor 5, before space *)
  val (sK, _) = L.stepKey sK CtrlK               (* kill " world" *)
  val () = checkString "after kill" ("hello", Readline.buffer sK)
  val () = checkString "kill ring holds text" (" world", Readline.killRing sK)
  val (sK, _) = L.stepKey sK CtrlE
  val (sK, _) = L.stepKey sK CtrlY               (* yank it back at end *)
  val () = checkString "after yank" ("hello world", Readline.buffer sK)

  (* ---- CtrlU kills to start ---- *)
  val () = section "CtrlU kill-to-start"
  val (sU, _) = L.feedString st0 "abcdef"
  val (sU, _) = L.run sU [Left, Left, Left]       (* cursor at 3 *)
  val (sU, _) = L.stepKey sU CtrlU                (* kill "abc" *)
  val () = checkString "CtrlU buffer" ("def", Readline.buffer sU)
  val () = checkString "CtrlU kill ring" ("abc", Readline.killRing sU)

  (* ---- history: Up / Down ---- *)
  val () = section "history navigation"
  val stH = Readline.init { prompt = "> ", history = ["one", "two", "three"] }
  val (sUp, _) = L.stepKey stH Up
  val () = checkString "Up recalls latest" ("three", Readline.buffer sUp)
  val (sUp, _) = L.stepKey sUp Up
  val () = checkString "Up again older" ("two", Readline.buffer sUp)
  val (sUp, _) = L.stepKey sUp Down
  val () = checkString "Down newer" ("three", Readline.buffer sUp)

  (* ---- feedBytes decodes an arrow-key escape ---- *)
  val () = section "feedBytes decodes escapes"
  val esc = Char.chr 27
  (* type "ab", then ESC [ D (Left), then Backspace -> removes 'a' -> "b" *)
  val bytes = "ab" ^ String.str esc ^ "[D" ^ String.str (Char.chr 127)
  val {state = sB, actions = actsB, pending = pendB} = L.feedBytes st0 bytes
  val () = checkString "feedBytes buffer" ("b", Readline.buffer sB)
  val () = checkString "feedBytes no pending" ("", pendB)
  val () = check "feedBytes produced actions" (List.length actsB >= 3)

  (* ---- feedBytes buffers an incomplete escape sequence ---- *)
  val () = section "feedBytes incomplete escape"
  val {state = sP, pending = pend2, ...} = L.feedBytes st0 ("x" ^ String.str esc ^ "[")
  val () = checkString "incomplete escape buffered" (String.str esc ^ "[", pend2)
  val () = checkString "buffer has only x" ("x", Readline.buffer sP)

  (* ---- preview ---- *)
  val () = section "preview"
  val (sPv, _) = L.feedString st0 "hi"
  val () = checkString "previewLine" ("> hi", L.previewLine sPv)
  val () = checkInt "previewCursor" (4, L.previewCursor sPv)

  (* ---- action classifiers ---- *)
  val () = section "action classifiers"
  val () = checkBool "isSubmit true" (true, L.isSubmit (Submit "x"))
  val () = checkBool "isSubmit false" (false, L.isSubmit Redraw)
  val () = checkBool "isCancel" (true, L.isCancel Cancel)
  val () = checkBool "isEof" (true, L.isEof Eof)
  val () = checkString "submitOf extracts"
             ("done", case L.submitOf (Submit "done") of SOME s => s | NONE => "?")
  val () = checkBool "submitOf NONE on Redraw"
             (true, case L.submitOf Redraw of NONE => true | _ => false)

  (* ---- runUntilSubmit ---- *)
  val () = section "runUntilSubmit"
  val (line, sS) =
    L.runUntilSubmit st0 [Char #"h", Char #"i", Enter, Char #"x"]
  val () = checkString "submitted line"
             ("hi", case line of SOME s => s | NONE => "?")
  (* after submit, buffer is reset and 'x' (after Enter) is ignored *)
  val () = checkString "buffer reset after submit" ("", Readline.buffer sS)

  val () = section "runUntilSubmit no submit"
  val (line2, _) = L.runUntilSubmit st0 [Char #"a", Char #"b"]
  val () = checkBool "no submit yields NONE"
             (true, case line2 of NONE => true | _ => false)

in Harness.run () end end
