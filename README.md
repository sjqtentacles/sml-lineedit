# sml-lineedit

[![CI](https://github.com/sjqtentacles/sml-lineedit/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-lineedit/actions/workflows/ci.yml)

A pure, high-level **line-editing driver** for Standard ML, built on top of
`sml-readline`'s editor state machine. `Readline` decides *what* a single key
event does; `sml-lineedit` composes those single steps into the operations a
REPL front-end actually needs: feed a whole string, feed raw bytes (decoding
ANSI escape sequences so arrow keys / Home / End / Delete work), run a batch of
keys, drive the editor until a line is submitted, and inspect the resulting
actions.

Everything here is **pure**: no terminal, no raw mode, no I/O.

## API

```sml
(* single steps *)
val stepChar : Readline.state -> char -> Readline.state * Readline.action
val stepKey  : Readline.state -> Readline.key -> Readline.state * Readline.action

(* batch drivers *)
val feedString : Readline.state -> string -> Readline.state * Readline.action list
val run        : Readline.state -> Readline.key list -> Readline.state * Readline.action list
val feedBytes  : Readline.state -> string
                 -> {state:Readline.state, actions:Readline.action list, pending:string}

(* the "edit one line" entry point *)
val runUntilSubmit : Readline.state -> Readline.key list -> string option * Readline.state

(* view *)
val previewLine   : Readline.state -> string
val previewCursor : Readline.state -> int

(* action classifiers / extractors *)
val submitOf : Readline.action -> string option
val isSubmit : Readline.action -> bool
val isCancel : Readline.action -> bool
val isEof    : Readline.action -> bool
```

## Examples

Build a line one character at a time:

```sml
val st = Readline.init { prompt = "> ", history = [] }
val (st', _actions) = LineEdit.feedString st "hello"
val ()  = print (LineEdit.previewLine st')   (* "> hello" *)
```

Feed raw terminal bytes (an arrow-key escape sequence is decoded):

```sml
val esc = String.str (Char.chr 27)
val {state, pending, ...} = LineEdit.feedBytes st ("ab" ^ esc ^ "[D")  (* Left *)
(* `pending` holds any bytes of an *incomplete* trailing escape sequence;
   prepend it to the next chunk you read. *)
```

Drive keys until a line is submitted:

```sml
val (line, st') =
  LineEdit.runUntilSubmit st [Readline.Char #"h", Readline.Char #"i", Readline.Enter]
(* line = SOME "hi" *)
```

## Scope and limitations

- **Pure** transitions only: this module never touches the terminal, reads
  input, or manages raw mode. You supply the I/O loop; apply the returned
  `Readline.action`s (redraw, accept, EOF, ring the bell) yourself.
- Editing semantics (cursor movement, history, kill/yank, reverse-search, etc.)
  are defined by the `Readline.state`/`Readline.key`/`Readline.action` model in
  `sml-readline`; this module is the batch/stream driver over that model.
- `feedBytes` decodes ANSI escape sequences via `Readline.decode`; bytes forming
  an *incomplete* trailing escape are returned as `pending` for the caller to
  carry forward. Input is byte/char oriented and does not interpret multi-byte
  (UTF-8) encodings.
- `runUntilSubmit` stops at the first `Submit`; keys after it are ignored. It
  returns `NONE` if the batch ends without a submit (e.g. on Cancel/Eof or
  simply running out of keys).

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-lineedit
smlpkg sync
```

Reference from your `.mlb`:

```
lib/github.com/sjqtentacles/sml-lineedit/lineedit.mlb
```

## Building and testing

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make clean
```

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
feeds a whole string and a batch of key events (cursor movement, backspace, an
ANSI escape sequence for the Up arrow) through the `Readline`/`LineEdit` state
machine and drives one line to submission (output is byte-identical under
MLton and Poly/ML):

```
sml-lineedit demo
feedString "echo hi":
  line    = > echo hi
  cursor  = 9
  actions = [Redraw,Redraw,Redraw,Redraw,Redraw,Redraw,Redraw]
run [Left, Left, Backspace]:
  line    = > echohi
  cursor  = 6
  actions = [Redraw,Redraw,Redraw]
feedBytes "ESC [ A" (Up arrow):
  line    = > git status
  actions = [Redraw]
  pending = <empty>
runUntilSubmit "echo done" ++ Enter:
  submitted = echo done
classifiers:
  isSubmit (Submit "x") = true
  isCancel Cancel        = true
  isEof Eof              = true
  submitOf (Submit "x") = x
```

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-lineedit/
  lineedit.sig
  lineedit.sml   high-level driver over the Readline state machine
  lineedit.mlb
test/
  test.sml       single steps, batch drivers, escape decoding, submit driver
```

## License

MIT. See [LICENSE](LICENSE).
