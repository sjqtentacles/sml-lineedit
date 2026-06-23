(* readline.sig

   sml-readline: a pure, deterministic line-editor state machine.

   This is the reusable *core* of an interactive line editor (the heart of a
   future "utop for SML" REPL frontend). It contains NO FFI, NO termios, NO
   threads and NO wall-clock: every function is a pure value transformation,
   so the whole editor can be tested with ordinary unit tests and reused
   under any runtime.

   The intended split:

     - THIS library decides *what* should happen: it maps abstract key events
       to buffer/cursor/history transitions and tells the caller which side
       effect to perform (`action`).
     - A later, impure terminal driver (a Poly/ML-backed tool) is responsible
       for raw mode, reading bytes, and painting the screen. It feeds raw
       bytes through `decode`, hands the resulting keys to `step`, and uses
       `render` to draw. None of that lives here.

   All indices are character offsets into the current line; this library is
   byte/char oriented and does not interpret multi-byte (UTF-8) encodings. *)

signature READLINE =
sig
  (* ---- Key model ------------------------------------------------------ *)

  (* An abstract key event. `Char` carries a self-inserting printable byte;
     the remaining constructors are the editing/control keys understood by
     `step`. `Alt c` is a meta/escape-prefixed key (e.g. Alt #"b"). *)
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
    | CtrlA          (* move to start of line   *)
    | CtrlE          (* move to end of line     *)
    | CtrlK          (* kill to end of line     *)
    | CtrlU          (* kill to start of line   *)
    | CtrlW          (* kill previous word      *)
    | CtrlY          (* yank (paste kill ring)  *)
    | CtrlL          (* clear screen / redraw   *)
    | CtrlC          (* cancel current line     *)
    | CtrlD          (* EOF on empty line       *)
    | CtrlR          (* reverse incremental search *)
    | Alt of char    (* meta-prefixed key       *)

  (* What the impure shell should DO after a `step`. The state machine never
     performs effects itself; it returns one of these for the caller. *)
  datatype action =
      Redraw            (* the visible line changed; repaint it          *)
    | Submit of string  (* the user accepted this line                    *)
    | Cancel            (* the user abandoned the line (Ctrl-C)           *)
    | Eof               (* end of input on an empty line (Ctrl-D)         *)
    | Bell              (* nothing happened; ring the terminal bell       *)
    | Noop              (* nothing to do                                  *)

  (* ---- Completion hook ------------------------------------------------ *)

  (* A pure completion function. Given the current (buffer, cursor) it returns
     a `replacement` for the word immediately before the cursor together with
     the list of `candidates` (for the shell to display). An empty candidate
     list means "no completion" (Tab rings the bell). *)
  type completer = string * int -> {replacement:string, candidates:string list}

  (* A completer that never completes anything. *)
  val noCompleter : completer

  (* ---- Editor state --------------------------------------------------- *)

  type state

  (* Build a fresh editor state with the given prompt and history (most recent
     entry last, as a shell would accumulate it). Uses `noCompleter`. *)
  val init : {prompt:string, history:string list} -> state

  (* Like `init` but installs a completion function. *)
  val initWith : {prompt:string, history:string list, completer:completer} -> state

  (* Accessors (pure views of the state). *)
  val buffer  : state -> string        (* current line contents          *)
  val cursor  : state -> int           (* cursor offset, 0..size buffer  *)
  val prompt  : state -> string        (* the prompt string              *)
  val history : state -> string list   (* history, most recent last      *)
  val killRing: state -> string        (* last killed text               *)
  val searching : state -> bool        (* in reverse-search mode?        *)

  (* The pure transition function: apply one key to the state, yielding the
     next state and the action the shell should perform. *)
  val step : state -> key -> state * action

  (* ---- View model ----------------------------------------------------- *)

  (* A pure view of what should be on screen: `text` is the full visible line
     (prompt + buffer, or the reverse-search prompt while searching) and
     `cursor` is the column at which the terminal cursor belongs. *)
  val render : state -> {text:string, cursor:int}

  (* ---- ANSI / escape decoder ------------------------------------------ *)

  (* Decode a raw byte string into key events. Returns the keys recognised so
     far and any trailing bytes that form an *incomplete* escape sequence; the
     caller should prepend that leftover to the next chunk it reads. This makes
     partial-sequence handling explicit and pure. *)
  val decode : string -> key list * string

  (* Streaming variant: an opaque decoder that consumes one byte at a time. *)
  type decoder
  val decoder : decoder                          (* empty initial decoder    *)
  val feed    : decoder -> char -> decoder * key list
  val pending : decoder -> string                (* buffered partial bytes   *)
end
