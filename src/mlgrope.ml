open Math2d

type bubble =
  { position : vec
  ; radius : float
  }

type magnet =
  { position : vec
  ; radius : float
  ; strength : float
  }

type rope =
  { position : vec
  ; radius : float
  ; length : float
  }

type elastic =
  { position : vec
  ; radius : float
  ; length : float
  ; strength : float
  }

type goal = { position : vec }

type star = { position : vec }

type block =
  { vertices : vec list
  ; color : Graphics.color
  }

type spike =
  { position : vec
  ; angle : float
  }

let spike_edge_size = 40.0

type fan =
  { position : vec
  ; size : vec
  ; angle : float
  ; strength : float
  }

type ball =
  { position : vec
  ; speed : vec
  ; links : entity list
  ; previous_links : entity list
  }

and entity =
  | Ball of ball
  | Bubble of bubble
  | Magnet of magnet
  | Rope of rope
  | Goal of goal
  | Elastic of elastic
  | Star of star
  | Block of block
  | Fan of fan
  | Spike of spike

type game_state = entity list

let ball_radius = 20.0

let position_of_entity e =
  match e with
  | Ball { position; _ }
   |Bubble { position; _ }
   |Rope { position; _ }
   |Goal { position; _ }
   |Elastic { position; _ }
   |Star { position; _ }
   |Fan { position; _ }
   |Spike { position; _ }
   |Magnet { position; _ } ->
    position
  | Block { vertices; _ } -> average vertices

(* Returns a function that updates a ball, to be used with List.map *)
let swap_ball ball updated e =
  match e with
  | Ball b ->
    if b == ball then
      Ball updated
    else
      e
  | _ -> e

(* Executes List.fold_left only on balls *)
let fold_balls f acc l =
  List.fold_left
    (fun acc e ->
      match e with
      | Ball b -> f acc b
      | _ -> acc)
    acc l
