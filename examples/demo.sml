(* demo.sml - drive the pure Readline state machine through LineEdit's
   higher-level operations: feed a whole string, run a batch of key events
   (including cursor movement and a backspace), feed raw ANSI bytes, and run
   a batch to completion. Deterministic: no terminal, no I/O, no wall-clock. *)

structure R = Readline
structure L = LineEdit

fun actionName a =
  case a of
      R.Redraw   => "Redraw"
    | R.Submit s => "Submit \"" ^ s ^ "\""
    | R.Cancel   => "Cancel"
    | R.Eof      => "Eof"
    | R.Bell     => "Bell"
    | R.Noop     => "Noop"

val () = print "sml-lineedit demo\n"

(* 1. Fresh state with some history, feed a whole string at once. *)
val s0 = R.init {prompt = "> ", history = ["ls -la", "git status"]}
val (s1, acts1) = L.feedString s0 "echo hi"
val () = print "feedString \"echo hi\":\n"
val () = print ("  line    = " ^ L.previewLine s1 ^ "\n")
val () = print ("  cursor  = " ^ Int.toString (L.previewCursor s1) ^ "\n")
val () = print ("  actions = [" ^ String.concatWith "," (List.map actionName acts1) ^ "]\n")

(* 2. Move left twice, then backspace, as a batch of key events. *)
val (s2, acts2) = L.run s1 [R.Left, R.Left, R.Backspace]
val () = print "run [Left, Left, Backspace]:\n"
val () = print ("  line    = " ^ L.previewLine s2 ^ "\n")
val () = print ("  cursor  = " ^ Int.toString (L.previewCursor s2) ^ "\n")
val () = print ("  actions = [" ^ String.concatWith "," (List.map actionName acts2) ^ "]\n")

(* 3. Feed raw bytes containing an ANSI escape sequence (Up arrow). *)
val {state = s3, actions = acts3, pending} = L.feedBytes s2 "\027[A"
val () = print "feedBytes \"ESC [ A\" (Up arrow):\n"
val () = print ("  line    = " ^ L.previewLine s3 ^ "\n")
val () = print ("  actions = [" ^ String.concatWith "," (List.map actionName acts3) ^ "]\n")
val () = print ("  pending = " ^ (if pending = "" then "<empty>" else pending) ^ "\n")

(* 4. Drive a fresh state to submission with runUntilSubmit. *)
val keys = List.map R.Char (String.explode "echo done") @ [R.Enter]
val (submitted, _) = L.runUntilSubmit (R.init {prompt = "> ", history = []}) keys
val () = print "runUntilSubmit \"echo done\" ++ Enter:\n"
val () = print ("  submitted = " ^ (case submitted of SOME line => line | NONE => "<none>") ^ "\n")

(* 5. Action classifiers / extractors. *)
val () = print "classifiers:\n"
val () = print ("  isSubmit (Submit \"x\") = " ^ Bool.toString (L.isSubmit (R.Submit "x")) ^ "\n")
val () = print ("  isCancel Cancel        = " ^ Bool.toString (L.isCancel R.Cancel) ^ "\n")
val () = print ("  isEof Eof              = " ^ Bool.toString (L.isEof R.Eof) ^ "\n")
val () = print ("  submitOf (Submit \"x\") = "
                ^ (case L.submitOf (R.Submit "x") of SOME v => v | NONE => "NONE") ^ "\n")
