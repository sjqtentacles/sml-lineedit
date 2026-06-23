# sml-lineedit

[![CI](https://github.com/sjqtentacles/sml-lineedit/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-lineedit/actions/workflows/ci.yml)

A single-keystroke **line-editing step function** for Standard ML, built on top
of `sml-readline`'s editor state. Given the current editor state and one input
character, it returns the next state and the action to take.

## API

```sml
Lineedit.stepChar : Readline.state -> char -> Readline.state * Readline.action
```

```sml
val (state', action) = Lineedit.stepChar state ch
```

This is the pure transition core you drive from your own input loop: feed it
characters one at a time, apply the returned `Readline.action` (e.g. redraw,
accept the line, signal EOF), and carry the new `Readline.state` forward.

## Scope and limitations

- A **pure** state-transition function — it does not touch the terminal, read
  input, or manage raw mode. You supply the I/O loop.
- Editing semantics (cursor movement, history, kill/yank, etc.) are defined by
  the `Readline.state`/`Readline.action` model in `sml-readline`; this module is
  the per-character driver over that model.

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

## Project layout

```
sml.pkg
Makefile
lib/github.com/sjqtentacles/sml-lineedit/
  lineedit.sig
  lineedit.sml   per-character editor transition
  lineedit.mlb
test/
  test.sml       keystroke -> (state, action) transitions
```

## License

MIT. See [LICENSE](LICENSE).
