open Graphics
open Sys
open Unix

open Ppm
open Math2d
open Mlgrope
open Backend

let tick_rate = 1. /. 60.

let bubble_color = Graphics.red
let rope_color = Graphics.green
let elastic_color = Graphics.blue

let rope_inner_radius = 5.
let goal_size = {x = 75.; y = 40.}
let star_size = {x = 40.; y = 40.}

let mix a b t =
	t *. a +. (1. -. t) *. b

let mix_vec v1 v2 t =
	{ x = mix v1.x v2.x t; y = mix v1.y v2.y t }

let mix_int i1 i2 t =
	int_of_float (mix (float_of_int i1) (float_of_int i2) t)

let rgb_of_color c =
	((c lsr 16) land 0xFF, (c lsr 8) land 0xFF, c land 0xFF)

let mix_color c1 c2 t =
	let (r1, g1, b1) = rgb_of_color c1 in
	let (r2, g2, b2) = rgb_of_color c2 in
	Graphics.rgb (mix_int r1 r2 t) (mix_int g1 g2 t) (mix_int b1 b2 t)

let mouse_of_status s =
	{x = float_of_int s.mouse_x; y = float_of_int s.mouse_y}


let load_image path =
	Ppm.input (open_in path)

let get_image path =
	let cache = ref None in
	fun () ->
		match !cache with
		| Some(img) -> img
		| None ->
			let img = load_image path in
			cache := Some(img);
			img

let ball_img = get_image "img/ball.ppm"
let goal_img = get_image "img/goal.ppm"
let star_img = get_image "img/star.ppm"


let draw_bubble (b : bubble) =
	let (x, y) = ints_of_vec b.position in
	Graphics.set_color bubble_color;
	Graphics.draw_circle x y (int_of_float b.radius)

let draw_rope (r : rope) =
	let (x, y) = ints_of_vec r.position in
	Graphics.set_color rope_color;
	Graphics.fill_circle x y (int_of_float rope_inner_radius);
	Graphics.draw_circle x y (int_of_float r.radius)

let draw_elastic (e : elastic) =
	let (x, y) = ints_of_vec e.position in
	Graphics.set_color elastic_color;
	Graphics.fill_circle x y (int_of_float rope_inner_radius);
	Graphics.draw_circle x y (int_of_float e.radius)

let draw_goal (g : goal) =
	let (corner, _) = ends_of_box g.position goal_size in
	let (x, y) = ints_of_vec corner in
	Graphics.draw_image (goal_img ()) x y

let draw_star (s : star) =
	let (corner, _) = ends_of_box s.position star_size in
	let (x, y) = ints_of_vec corner in
	Graphics.draw_image (star_img ()) x y

let draw_block (b : block) =
	let l = List.map ints_of_vec b.vertices in
	Graphics.set_color b.color;
	Graphics.fill_poly (Array.of_list l)

let rainbow_colors = Array.of_list [Graphics.magenta; Graphics.blue; Graphics.cyan; Graphics.green; Graphics.yellow; Graphics.red]

let rainbow t =
	let n = Array.length rainbow_colors in
	let a = t *. (float_of_int n) in
	let i = int_of_float a in
	let j = (i+1) mod n in
	mix_color rainbow_colors.(j) rainbow_colors.(i) (a -. (float_of_int i))

let draw_fan (f : fan) =
	let a = f.position -: {x = 0.; y = f.size.y /. 2.} in
	let (x, y) = ints_of_vec a in
	let (w, h) = ints_of_vec f.size in
	for i = x to x+w do
		Graphics.set_color (rainbow (mod_float (abs_float ((float_of_int i -. 300.*.f.strength*.(Unix.gettimeofday ())) /. 500.)) 1.));
		Graphics.moveto i y;
		Graphics.lineto i (y+h)
	done

(* Newton's method *)
let find_zero f x0 =
	let accuracy = 10.**(-4.) in
	let epsilon = 10.**(-10.) in
	let maxiter = 50 in
	let dx = 10.**(-4.) in
	let f' x = ((f x) -. (f (x -. dx))) /. dx in
	let rec find_zero n x =
		if n > maxiter then raise Not_found else
		let (y, y') = (f x, f' x) in
		if abs_float y' < epsilon then raise Not_found else
		let x' = x -. y /. y' in
		if abs_float (x' -. x) <= accuracy *. abs_float x' then
			x'
		else
			find_zero (n+1) x'
	in
	find_zero 0 x0

let build_poly_line f =
	let n = 100 in
	Array.init (n+1) (fun i ->
		let t = (float_of_int i) /. (float_of_int n) in
		ints_of_vec (f t)
	)

let create_line a b =
	fun t -> mix_vec a b t

(* See https://codegolf.stackexchange.com/a/37710 *)
let create_rope_line a b l =
	let (a, b) = if a.x < b.x then (a, b) else (b, a) in
	let (x1, y1) = (a.x, a.y) in
	let (x2, y2) = (b.x, b.y) in
	let f z = ((sqrt (l**2. -. (y2 -. y1)**2.)) /. (x2 -. x1)) -. (sinh z) /. z in
	let z = find_zero f 1. in
	let a = (x2 -. x1) /. 2. /. z in
	let p = (x1 +. x2 -. a *. (log ((l +. y2 -. y1) /. (l -. y2 +. y1)))) /. 2. in
	let q = (y2 +. y1 -. l *. (cosh z) /. (sinh z)) /. 2. in
	let y x = a *. (cosh ((x -. p) /. a)) +. q in
	fun t -> let x = mix x1 x2 t in {x; y = y x}

let draw_link b l =
	match l with
	| Bubble(bubble) -> draw_bubble {bubble with position = b.position}
	| Rope{position; length} | Elastic{position; length} ->
		let line = build_poly_line (
			try create_rope_line position b.position length
			with _ -> create_line position b.position
		) in
		Graphics.set_color Graphics.black;
		Graphics.draw_poly_line line
	| _ -> ()

let draw_ball (b : ball) =
	let corner = b.position -: ball_radius *: vec1 in
	let (x, y) = ints_of_vec corner in
	Graphics.draw_image (ball_img ()) x y;

	List.iter (draw_link b) b.links

let draw_entity e =
	match e with
	| Ball(b) -> draw_ball b
	| Bubble(b) -> draw_bubble b
	| Rope(r) -> draw_rope r
	| Elastic(e) -> draw_elastic e
	| Goal(g) -> draw_goal g
	| Star(s) -> draw_star s
	| Block(b) -> draw_block b
	| Fan(f) -> draw_fan f

let draw gs =
	(* First draw things that aren't a ball *)
	List.iter (fun e ->
		match e with
		| Ball(_) -> ()
		| _ -> draw_entity e
	) gs;
	(* Then only draw balls *)
	List.iter (fun e ->
		match e with
		| Ball(_) -> draw_entity e
		| _ -> ()
	) gs

let deinit () =
	let _ = Unix.setitimer Unix.ITIMER_REAL {it_interval = 0.; it_value = 0.} in
	Sys.set_signal Sys.sigalrm Sys.Signal_default

let close () =
	deinit ();
	Graphics.close_graph ()

let run step handle_event size g =
	let (w, h) = ints_of_vec size in
	Graphics.open_graph (" "^(string_of_int w)^"x"^(string_of_int h));
	Graphics.auto_synchronize false;
	Graphics.set_window_title "Mlgrope";

	let g = ref (step g) in
	Sys.set_signal Sys.sigalrm (Sys.Signal_handle (fun _ ->
		Graphics.clear_graph ();
		g := step !g;
		Graphics.synchronize ()
	));
	let _ = Unix.setitimer Unix.ITIMER_REAL {it_interval = tick_rate; it_value = tick_rate} in
	();

	try
		let events = [Graphics.Button_down; Graphics.Mouse_motion; Graphics.Key_pressed] in
		let rec loop last_status =
			let status = Graphics.wait_next_event events in
			g := handle_event !g last_status status;
			loop status
		in
		loop {mouse_x = 0; mouse_y = 0; button = false; keypressed = false; key = '\000'}
	with e -> deinit (); raise e
