primitive DuplicateMode
primitive DropMode
primitive GarbleMode
primitive DelayMode
primitive ReorderMode
primitive RandomMode
primitive PassMode

type Mode is
  ( DuplicateMode
  | DropMode
  | GarbleMode
  | DelayMode
  | ReorderMode
  | RandomMode
  | PassMode
  )


primitive ModeMaker
  fun from(mode: String ref, env: Env): Mode ? =>
    match mode
    | "duplicate" => DuplicateMode
    | "drop" => DropMode
    | "garble" => GarbleMode
    | "delay" => DelayMode
    | "reorder" => ReorderMode
    | "random" => RandomMode
    | "pass" => PassMode
    else
      env.out.print("Invalid mode. Valid options: duplicate, drop, garble, delay, reorder, random, pass")
      error
    end

  fun string_for(mode: Mode): String =>
    match mode
      | DuplicateMode => "duplicate mode"
      | DropMode => "drop mode"
      | GarbleMode => "garble mode"
      | DelayMode => "delay mode"
      | ReorderMode => "reorder mode"
      | RandomMode => "random mode"
      | PassMode => "pass mode"
    else
      "unknown mode"
    end