open Graphics
open Sys
open Unix

open Mlgrope
open Backend

let tick_rate = 1. /. 60.

let ball_color = Graphics.black
let bubble_color = Graphics.red
let rope_color = Graphics.green
let goal_color = Graphics.blue

let dist a b =
	sqrt ((a.x -. b.x)**2. +. (a.y -. b.y)**2.)

let mix v1 v2 t =
	{ x = t *. v1.x +. (1. -. t) *. v2.x; y = t *. v1.y +. (1. -. t) *. v2.y }

let int_of_position p =
	(int_of_float p.x, int_of_float p.y)

let draw_ball (b : ball) =
	let (x, y) = int_of_position b.position in
	Graphics.set_color ball_color;
	Graphics.fill_circle x y (int_of_float Mlgrope.ball_radius)

let draw_bubble (b : bubble) =
	let (x, y) = int_of_position b.position in
	Graphics.set_color bubble_color;
	Graphics.draw_circle x y (int_of_float b.radius)

let draw_rope (r : rope) =
	let (x, y) = int_of_position r.position in
	Graphics.set_color rope_color;
	Graphics.draw_circle x y (int_of_float r.radius)

let draw_goal (g : goal) =
	let (x, y) = int_of_position g.position in
	Graphics.set_color goal_color;
	Graphics.fill_rect (x - 1) (y - 1) 2 2

let draw_entity e =
	match e with
	| Bubble(b) -> draw_bubble b
	| Rope(r) -> draw_rope r
	| Goal(g) -> draw_goal g

let rec draw_link b l =
	match l with
	| Rope({position}) -> let a = 0.1 in
		let n = 10 in
		let line = Array.init (n+1) (fun i ->
			let t = (float_of_int i) /. (float_of_int n) in
			int_of_position (mix position b.position t)
			(* TODO *)
		) in
		Graphics.set_color Graphics.black;
		Graphics.draw_poly_line line
	| _ -> ()

let draw s =
	draw_ball s.ball;
	List.iter draw_entity s.entities;
	List.iter (draw_link s.ball) s.ball.links

let step g =
	let t = Unix.gettimeofday () in
	let dt = t -. g.time in
	let g = { g with time = t; state = Backend.move g.state dt } in
	Graphics.clear_graph ();
	draw g.state;
	Graphics.synchronize ();
	g

let is_bubble e =
	match e with
	| Bubble(_) -> true
	| _ -> false

let handle_click_on_bubble ba pos =
	try
		let Bubble(bu) = List.find is_bubble ba.links in
		if dist pos ba.position <= bu.radius then
			{ba with links = List.filter (fun e -> e != Bubble(bu)) ba.links}
		else ba
	with _ -> ba

let handle_event gs s =
	match s with
	| {button = true; mouse_x; mouse_y} ->
		let pos = {x = float_of_int mouse_x; y = float_of_int mouse_y} in
		{gs with ball = handle_click_on_bubble gs.ball pos}
	| {keypressed = true; key = '\027'} -> raise Exit
	| _ -> gs

let run g =
	let (w, h) = (int_of_float g.size.x, int_of_float g.size.y) in
	Graphics.open_graph (" "^(string_of_int w)^"x"^(string_of_int h));
	Graphics.auto_synchronize false;

	let g = ref (step g) in
	Sys.set_signal Sys.sigalrm (Sys.Signal_handle (fun _ -> g := step !g));
	let _ = Unix.setitimer Unix.ITIMER_REAL {it_interval = tick_rate; it_value = tick_rate} in
	let events = [Graphics.Button_down; Graphics.Key_pressed] in
	Graphics.loop_at_exit events (fun s -> g := {!g with state = handle_event !g.state s})
