val is_between : float -> float -> float -> bool

type vec = {
	x : float;
	y : float;
}

val vec0 : vec

val ints_of_vec : vec -> (int * int)
val squared_distance : vec -> vec -> float
val distance : vec -> vec -> float
val (=:) : vec -> vec -> bool
val (+:) : vec -> vec -> vec
val (-:) : vec -> vec -> vec
val ( *:) : float -> vec -> vec
val dot : vec -> vec -> float
val length : vec -> float
val normalize : vec -> vec
