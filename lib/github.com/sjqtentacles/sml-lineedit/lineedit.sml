structure LineEdit :> LINEEDIT =
struct
  fun stepChar st c = Readline.step st (Readline.Char c)
end
