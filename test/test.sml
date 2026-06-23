structure Tests = struct open Harness structure L = LineEdit
fun run () = let
  val st0 = Readline.init { prompt = "> ", history = [] }
  val (st1, _) = L.stepChar st0 #"a"
  val () = section "keystroke"
  val () = checkString "insert a" ("a", Readline.buffer st1)
  val (st2, _) = Readline.step st1 Readline.Backspace
  val () = checkString "backspace" ("", Readline.buffer st2)
in Harness.run () end end
