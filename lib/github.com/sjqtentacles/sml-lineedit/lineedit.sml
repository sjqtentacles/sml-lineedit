structure LineEdit :> LINEEDIT =
struct
  open Readline

  fun stepChar st c = step st (Char c)
  fun stepKey st k = step st k

  fun run st keys =
    let
      fun loop (st, []) acc = (st, List.rev acc)
        | loop (st, k :: ks) acc =
            let val (st', a) = step st k
            in loop (st', ks) (a :: acc) end
    in loop (st, keys) [] end

  fun feedString st s =
    run st (List.map Char (String.explode s))

  fun feedBytes st bytes =
    let
      val (keys, pending) = decode bytes
      val (st', actions) = run st keys
    in {state = st', actions = actions, pending = pending} end

  fun previewLine st = #text (render st)
  fun previewCursor st = #cursor (render st)

  fun submitOf (Submit s) = SOME s
    | submitOf _ = NONE
  fun isSubmit (Submit _) = true
    | isSubmit _ = false
  fun isCancel Cancel = true
    | isCancel _ = false
  fun isEof Eof = true
    | isEof _ = false

  fun runUntilSubmit st keys =
    let
      fun loop (st, []) = (NONE, st)
        | loop (st, k :: ks) =
            let val (st', a) = step st k
            in case a of
                   Submit line => (SOME line, st')
                 | _ => loop (st', ks)
            end
    in loop (st, keys) end
end
