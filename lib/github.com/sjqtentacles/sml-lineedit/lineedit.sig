signature LINEEDIT =
sig
  val stepChar : Readline.state -> char -> Readline.state * Readline.action
end
