open Graphics
open Util
open Math2d
open Mlgrope
open Frontend

exception Play of game_state

type entity_property =
  | Position of vec
  | Radius
  | Size
  | Length
  | Angle
  | Strength
  | Vertex of vec

(* TODO *)

type editor =
  { size : vec
  ; state : game_state
  ; selected : entity option
  ; selected_property : entity_property
  }

let panel_width = 200.

let panel_color = Graphics.rgb 127 127 127

let grid_size = 10.

let grid_color = Graphics.rgb 230 230 230

let handle_size = 10.

let handle_color = Graphics.black

let strength_per_division = 50.

let stick_to_grid pt =
  Math2d.map (fun k -> grid_size *. round_float (k /. grid_size)) pt

let update_position entity position =
  match entity with
  | Ball b -> Ball { b with position }
  | Bubble b -> Bubble { b with position }
  | Magnet m -> Magnet { m with position }
  | Rope b -> Rope { b with position }
  | Elastic b -> Elastic { b with position }
  | Goal _ -> Goal { position }
  | Star _ -> Star { position }
  | Block b ->
    let center = average b.vertices in
    let delta = position -: center in
    let vertices = List.map (fun v -> v +: delta) b.vertices in
    Block { b with vertices }
  | Fan f -> Fan { f with position }
  | Spike s -> Spike { s with position }

let draw_grid size =
  let grid_size = int_of_float grid_size in
  let w, h = ints_of_vec size in
  Graphics.set_color grid_color;
  for i = 0 to w / grid_size do
    Graphics.moveto (i * grid_size) 0;
    Graphics.lineto (i * grid_size) h
  done;
  for i = 0 to h / grid_size do
    Graphics.moveto 0 (i * grid_size);
    Graphics.lineto w (i * grid_size)
  done

let panel_block_vertices pos =
  let block_size = 10. in
  [ pos +: { x = block_size; y = block_size }
  ; pos +: { x = -.block_size; y = block_size }
  ; pos +: { x = -.block_size; y = -.block_size }
  ; pos +: { x = block_size; y = -.block_size }
  ]

let panel_entities size =
  let position = { x = size.x +. (panel_width /. 2.); y = 0. } in
  let radius = 20. in
  let l =
    [ Ball { position; speed = vec0; links = []; previous_links = [] }
    ; Bubble { position; radius }
    ; Magnet { position; radius; strength = 1. }
    ; Rope { position; radius; length = radius }
    ; Elastic { position; radius; length = radius; strength = 1. }
    ; Goal { position }
    ; Star { position }
    ; Block { color = 0xFF69B4; vertices = panel_block_vertices position }
    ; Fan { position; size = { x = 30.; y = 20. }; angle = 0.; strength = 1. }
    ; Spike { position; angle = 0.5 *. pi }
    ]
  in
  let n = List.length l in
  let h = round_float (size.y /. float_of_int (n + 1)) in
  List.mapi
    (fun i e ->
      update_position e { position with y = float_of_int (i + 1) *. h })
    l

let draw_panel size =
  let w, h = ints_of_vec size in
  Graphics.set_color panel_color;
  Graphics.fill_rect w 0 (w + int_of_float panel_width) h;
  let l = panel_entities size in
  List.iter Frontend.draw_entity l

let radius_handle_position e =
  match e with
  | Bubble { position; radius; _ }
   |Magnet { position; radius; _ }
   |Rope { position; radius; _ }
   |Elastic { position; radius; _ } ->
    position +: { x = radius; y = 0. } (* TODO: draw handle in a corner *)
  | _ -> raise Not_found

let size_handle_position e =
  match e with
  | Fan { position; size; angle; _ } ->
    position
    +: (size.x *: vec_of_angle angle)
    +: (0.5 *. size.y *: vec_of_angle (angle -. (0.5 *. pi)))
  | _ -> raise Not_found

let length_handle_position e =
  match e with
  | Rope { position; length; _ }
   |Elastic { position; length; _ } ->
    position +: { x = length; y = 0. } (* TODO: draw handle in a corner *)
  | _ -> raise Not_found

let angle_handle_position e =
  match e with
  | Fan { position; size; angle; _ } ->
    let r = 0.5 *. size.y in
    let angle = angle -. (0.5 *. pi) in
    position +: (r *: vec_of_angle angle)
  | Spike { position; angle } ->
    position +: (spike_edge_size *: vec_of_angle angle)
  | _ -> raise Not_found

let strength_handle_position e =
  match e with
  | Magnet { position; strength; _ }
   |Elastic { position; strength; _ } ->
    position +: { x = strength *. strength_per_division; y = 0. }
  | Fan { position; angle; strength; _ } ->
    position +: (strength *. strength_per_division *: vec_of_angle angle)
  | _ -> raise Not_found

let vertex_handle_position v e =
  match e with
  | Block _ -> v
  | _ -> raise Not_found

let handle_position prop e =
  match prop with
  | Radius -> radius_handle_position e
  | Size -> size_handle_position e
  | Length -> length_handle_position e
  | Angle -> angle_handle_position e
  | Strength -> strength_handle_position e
  | Vertex v -> vertex_handle_position v e
  | _ -> raise Not_found

let draw_handle prop e =
  let x, y = ints_of_vec (handle_position prop e) in
  let hs = int_of_float handle_size in
  Graphics.set_color handle_color;
  match prop with
  | Angle -> Graphics.fill_circle x y (hs / 2)
  | Strength ->
    let l =
      Array.of_list
        [ (x, y + (hs / 2))
        ; (x - (hs / 2), y)
        ; (x, y - (hs / 2))
        ; (x + (hs / 2), y)
        ]
    in
    Graphics.fill_poly l
  | _ -> Graphics.fill_rect (x - (hs / 2)) (y - (hs / 2)) hs hs

let handles_of_entity e =
  match e with
  | Ball _ -> []
  | Bubble _ -> [ Radius ]
  | Magnet _ -> [ Radius; Strength ]
  | Rope _ -> [ Radius; Length ]
  | Elastic _ -> [ Radius; Length; Strength ]
  | Block { vertices; _ } ->
    List.fold_left (fun props v -> Vertex v :: props) [] vertices
  | Spike _ -> [ Angle ]
  | Fan _ -> [ Size; Angle; Strength ]
  | Goal _
   |Star _ ->
    []

let draw_handles e =
  List.iter (fun prop -> draw_handle prop e) (handles_of_entity e)

let draw_entity e =
  Frontend.draw_entity e;
  draw_handles e

let step ed =
  draw_grid ed.size;
  draw_panel ed.size;
  List.iter draw_entity ed.state;
  ed

let intersect_entity pt entity =
  match entity with
  | Ball { position; _ } ->
    Collide.circle_point position Mlgrope.ball_radius pt
  | Goal { position; _ } ->
    let a, b = ends_of_box position goal_size in
    Collide.box_point a b pt
  | Star { position; _ } ->
    let a, b = ends_of_box position star_size in
    Collide.box_point a b pt
  | Bubble { position; radius; _ }
   |Rope { position; radius; _ }
   |Elastic { position; radius; _ }
   |Magnet { position; radius; _ } ->
    Collide.circle_point position radius pt
  | Block { vertices; _ } -> Collide.polygon_point vertices pt
  | Fan { position; size; angle; _ } ->
    let pt = pt -: position in
    let pt = rotate angle pt in
    let a = vec0 -: { x = 0.; y = size.y /. 2. } in
    let b = a +: size in
    Collide.box_point a b pt
  | Spike { position; _ } ->
    Collide.circle_point position (spike_edge_size /. 2.) pt

let intersect_handles pt e =
  List.find
    (fun prop ->
      Collide.circle_point (handle_position prop e) (handle_size /. 2.) pt)
    (handles_of_entity e)

let rec intersect_entities pt state =
  match state with
  | e :: state -> (
    try
      let prop = intersect_handles pt e in
      Some (e, prop)
    with Not_found ->
      if intersect_entity pt e then
        Some (e, Position (pt -: position_of_entity e))
      else
        intersect_entities pt state )
  | [] -> None

let swap_entity entity updated e =
  if e == entity then
    updated
  else
    e

let update_radius entity position =
  let radius = distance (position_of_entity entity) position in
  match entity with
  | Bubble b -> Bubble { b with radius }
  | Magnet m -> Magnet { m with radius }
  | Rope r -> Rope { r with radius }
  | Elastic e -> Elastic { e with radius }
  | _ -> entity

let update_length entity position =
  let length = distance (position_of_entity entity) position in
  match entity with
  | Rope r -> Rope { r with length }
  | Elastic e -> Elastic { e with length }
  | _ -> entity

let update_size entity position =
  (* let delta = position -: (position_of_entity entity) in let size = {x =
    abs_float delta.x; y = abs_float (2. *. delta.y)} in *)
  match entity with
  | Fan f ->
    let delta = position -: f.position in
    let delta = rotate f.angle delta in
    let size = { x = abs_float delta.x; y = abs_float (2. *. delta.y) } in
    Fan { f with size }
  | _ -> entity

let update_angle entity position =
  let delta = position -: position_of_entity entity in
  let angle = angle_of_vec delta in
  match entity with
  | Fan f -> Fan { f with angle = normalize_angle (angle +. (0.5 *. pi)) }
  | Spike s ->
    let angle = 0.5 *. pi *. round_float (angle /. (0.5 *. pi)) in
    Spike { s with angle }
  | _ -> entity

let update_strength entity position =
  let ep = position_of_entity entity in
  let d = distance ep position in
  let strength = copysign (d /. strength_per_division) (position.x -. ep.x) in
  match entity with
  | Magnet m -> Magnet { m with strength }
  | Elastic e -> Elastic { e with strength }
  | Fan f -> Fan { f with strength }
  | _ -> entity

let update_vertex entity vertex position =
  match entity with
  | Block b ->
    let vertices =
      List.map
        (fun v ->
          if v == vertex then
            position
          else
            v)
        b.vertices
    in
    Block { b with vertices }
  | _ -> entity

let update ed entity prop position =
  let ed = { ed with selected_property = prop } in
  let updated, selected_property =
    match prop with
    | Position delta ->
      (update_position entity (position -: stick_to_grid delta), prop)
    | Radius -> (update_radius entity position, prop)
    | Length -> (update_length entity position, prop)
    | Size -> (update_size entity position, prop)
    | Angle -> (update_angle entity position, prop)
    | Strength -> (update_strength entity position, prop)
    | Vertex v -> (update_vertex entity v position, Vertex position)
  in
  let state = List.map (swap_entity entity updated) ed.state in
  { ed with state; selected = Some updated; selected_property }

let remove ed entity =
  let state = List.filter (fun e -> e != entity) ed.state in
  { ed with state; selected = None }

let handle_event path ed s s' =
  let pos = Frontend.mouse_of_status s' in
  let outside = pos.x > ed.size.x in
  let update ed e prop pos =
    let pos =
      if outside then
        pos
      else
        stick_to_grid pos
    in
    update ed e prop pos
  in
  match (s, s') with
  | { button = false; _ }, { button = true; _ } -> (
    match intersect_entities pos ed.state with
    | Some (e, prop) -> update ed e prop pos
    | None -> (
      let l = panel_entities ed.size in
      try
        let e = List.find (intersect_entity pos) l in
        let ed = { ed with state = e :: ed.state } in
        update ed e (Position (pos -: position_of_entity e)) pos
      with Not_found -> ed ) )
  | { button = true; _ }, { button; _ } ->
    if (not button) && outside then
      match ed.selected with
      | Some e -> remove ed e
      | None -> ed
    else
      let ed =
        match ed.selected with
        | Some e -> update ed e ed.selected_property pos
        | None -> ed
      in
      if button then
        ed
      else
        { ed with selected = None }
  | _, { keypressed = true; key = 'q'; _ } -> raise Exit
  | _, { keypressed = true; key = 'w'; _ } ->
    let ch = open_out path in
    Level.output ch ed.state;
    close_out ch;
    Printf.printf "Saved %s\n%!" path;
    ed
  | _, { keypressed = true; key = 'p'; _ } -> raise (Play ed.state)
  | _ -> ed

let run size path =
  let state =
    if Sys.file_exists path then (
      let ch = open_in path in
      let state = Level.input ch in
      close_in ch;
      Printf.printf "Loaded %s\n%!" path;
      state
    ) else
      [ Ball
        { position = 0.5 *: size
        ; speed = vec0
        ; links = []
        ; previous_links = []
        }
      ]
  in
  let rec run state =
    let ed =
      { size; state; selected = None; selected_property = Position vec0 }
    in
    Printf.printf "Press w to save, p to play, q to quit\n%!";
    try
      Frontend.run step (handle_event path)
        (size +: { x = panel_width; y = 0. })
        ed
    with Play state -> ( try Player.run size state with _ -> run state )
  in
  run state
