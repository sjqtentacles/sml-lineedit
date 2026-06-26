(* lineedit.sig

   A high-level driver layer over the pure `Readline` state machine.

   `Readline` decides *what* a single key event does; this module composes those
   single steps into the operations a REPL front-end actually needs: feed a whole
   string of characters, feed raw bytes (decoding ANSI escape sequences so arrow
   keys / Home / End / Delete work), run a batch of keys, drive the editor until a
   line is submitted, and inspect the resulting `action`s.

   Everything here is pure: no terminal, no raw mode, no I/O. *)

signature LINEEDIT =
sig
  (* Apply one printable character (back-compat with the original API). *)
  val stepChar : Readline.state -> char -> Readline.state * Readline.action

  (* Apply one abstract key event. *)
  val stepKey : Readline.state -> Readline.key -> Readline.state * Readline.action

  (* Feed a string one character at a time (each char becomes `Char c`).
     Returns the final state and the list of actions, in order. *)
  val feedString : Readline.state -> string -> Readline.state * Readline.action list

  (* Run a batch of key events, returning the final state and the actions in
     order. *)
  val run : Readline.state -> Readline.key list -> Readline.state * Readline.action list

  (* Feed raw input bytes, decoding ANSI escape sequences via `Readline.decode`.
     Bytes forming an *incomplete* trailing escape sequence are buffered and
     returned as `pending` so the caller can prepend them to the next chunk. *)
  val feedBytes : Readline.state -> string
                  -> {state:Readline.state, actions:Readline.action list, pending:string}

  (* The visible line (prompt + buffer, or the reverse-search prompt) and the
     column at which the cursor belongs, from `Readline.render`. *)
  val previewLine   : Readline.state -> string
  val previewCursor : Readline.state -> int

  (* Action classifiers / extractors. *)
  val submitOf : Readline.action -> string option
  val isSubmit : Readline.action -> bool
  val isCancel : Readline.action -> bool
  val isEof    : Readline.action -> bool

  (* Drive a batch of keys until the editor submits a line (Enter), returning the
     submitted line (NONE if the batch ends without a Submit, e.g. on Cancel/Eof
     or simply running out of keys) together with the resulting state. Keys after
     the first Submit are ignored. *)
  val runUntilSubmit : Readline.state -> Readline.key list -> string option * Readline.state
end
