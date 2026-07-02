class_name OrbitalMechanics
extends RefCounted

# Pure physics math for orbital mechanics.
# All functions are static — no instance state.
# Units: AU and days for solar-scale; km and days for local-system (moon) scale.

# ── Constants ─────────────────────────────────────────────────────────────────

const AU_TO_KM      := 149_597_870.7
const KM_TO_AU      := 1.0 / 149_597_870.7
const DAYS_PER_YEAR := 365.25

# GM_SUN in AU³/day² — derived from Earth's orbit: 4π²·1³/365.25²
const GM_SUN := 2.9591e-4

# GM per planet in km³/day² — derived from innermost reliable moon:
#   GM = 4π²·a³/T²  (a in km, T in days)
const GM_PLANETS: Dictionary = {
	"Earth":   3.008e15,   # Moon:      a=384400 km,  T=27.321 d
	"Mars":    3.200e14,   # Phobos:    a=9376 km,    T=0.319 d
	"Jupiter": 9.471e17,   # Io:        a=421800 km,  T=1.769 d
	"Saturn":  2.841e17,   # Mimas:     a=185520 km,  T=0.942 d
	"Uranus":  4.341e16,   # Miranda:   a=129900 km,  T=1.413 d
	"Neptune": 5.104e16,   # Triton:    a=354800 km,  T=5.877 d
	"Pluto":   7.272e12,   # Charon:    a=19591 km,   T=6.387 d
}

# Planet-to-Sun mass ratios — used for SOI and Lagrange point calculations.
const MASS_RATIOS: Dictionary = {
	"Mercury": 1.660e-7,
	"Venus":   2.448e-6,
	"Earth":   3.003e-6,
	"Mars":    3.227e-7,
	"Ceres":   4.720e-10,
	"Jupiter": 9.548e-4,
	"Saturn":  2.858e-4,
	"Uranus":  4.365e-5,
	"Neptune": 5.149e-5,
	"Pluto":   6.580e-9,
}


# ── Body positions ────────────────────────────────────────────────────────────

# Solar body position in AU (y=0 orbital plane).
# ang0_deg: angle at elapsed_days=0 (J2000-ish epoch offset).
static func solar_pos_at(orbital_au: float, period_years: float,
		ang0_deg: float, elapsed_days: float) -> Vector3:
	if orbital_au == 0.0:
		return Vector3.ZERO
	var angle := deg_to_rad(ang0_deg) + (TAU / (period_years * DAYS_PER_YEAR)) * elapsed_days
	return Vector3(cos(angle) * orbital_au, 0.0, sin(angle) * orbital_au)


# Moon position relative to parent planet in km (y=0 orbital plane).
# ang0_deg: angle at elapsed_days=0.
# Negative period_days = retrograde orbit (e.g. Triton).
static func moon_pos_at(orbital_km: float, period_days: float,
		ang0_deg: float, elapsed_days: float) -> Vector3:
	var angle := deg_to_rad(ang0_deg) + (TAU / period_days) * elapsed_days
	return Vector3(cos(angle) * orbital_km, 0.0, sin(angle) * orbital_km)


# ── Transfer mechanics ────────────────────────────────────────────────────────

# Hohmann transit time in days for a transfer between two circular orbits.
# r1, r2: orbital radii in the same units as gm.
# gm: GM_SUN (AU³/day²) for solar transfers, GM_PLANETS[parent] (km³/day²) for local.
static func hohmann_transit_days(r1: float, r2: float, gm: float) -> float:
	var a := (r1 + r2) * 0.5
	return PI * sqrt(a * a * a / gm)


# Synodic period in days between two bodies with the given orbital periods.
static func synodic_period_days(p1_days: float, p2_days: float) -> float:
	var diff := absf(1.0 / p1_days - 1.0 / p2_days)
	return 1.0 / diff if diff > 1e-12 else 1e12


# Earliest departure day >= from_day for a Hohmann transfer from origin to dest.
# ang0 values must match the coordinate frame used by solar_pos_at.
static func next_window_day(
		origin_au: float, origin_period_years: float, ang0_origin_deg: float,
		dest_au:   float, dest_period_years:   float, ang0_dest_deg:   float,
		from_day: float) -> float:
	if origin_au == 0.0 or dest_au == 0.0:
		return from_day
	var r1 := minf(origin_au, dest_au)
	var r2 := maxf(origin_au, dest_au)
	var transit := hohmann_transit_days(r1, r2, GM_SUN)

	var op_days := origin_period_years * DAYS_PER_YEAR
	var dp_days := dest_period_years   * DAYS_PER_YEAR
	var omega_o := TAU / op_days
	var omega_d := TAU / dp_days
	var d_omega  := omega_d - omega_o

	# Phase angle dest must be ahead of origin at departure.
	# φ = π - ω_dest · transit  (works for both inbound and outbound legs)
	var phi := PI - omega_d * transit

	var theta_o := deg_to_rad(ang0_origin_deg) + omega_o * from_day
	var theta_d := deg_to_rad(ang0_dest_deg)   + omega_d * from_day
	var current_phase := fmod(theta_d - theta_o, TAU)

	if absf(d_omega) < 1e-12:
		return from_day
	var synodic := synodic_period_days(op_days, dp_days)
	var wait    := fmod((phi - current_phase) / d_omega, synodic)
	if wait < 0.0:
		wait += synodic
	return from_day + wait


# ── Sphere of influence & Lagrange points ─────────────────────────────────────

# SOI radius in AU for a planet with the given orbital radius and mass ratio.
static func soi_radius_au(planet_au: float, mass_ratio: float) -> float:
	return planet_au * pow(mass_ratio, 0.4)


# Lagrange point position in the solar AU frame.
# point: 1=L1, 2=L2, 3=L3, 4=L4, 5=L5
# mass_ratio: planet mass / star mass
static func lagrange_pos(orbital_au: float, period_years: float, ang0_deg: float,
		elapsed_days: float, mass_ratio: float, point: int) -> Vector3:
	var planet := solar_pos_at(orbital_au, period_years, ang0_deg, elapsed_days)
	var angle  := deg_to_rad(ang0_deg) + (TAU / (period_years * DAYS_PER_YEAR)) * elapsed_days
	var sun_dir := Vector3(cos(angle), 0.0, sin(angle))   # unit vector away from sun
	# Hill radius ≈ distance to L1/L2
	var r_hill := orbital_au * pow(mass_ratio / 3.0, 1.0 / 3.0)
	match point:
		1:
			return planet - sun_dir * r_hill
		2:
			return planet + sun_dir * r_hill
		3:
			# Opposite side of star, slightly outside planet orbit
			return -sun_dir * orbital_au * (1.0 + 5.0 / 12.0 * mass_ratio)
		4:
			var a4 := angle + PI / 3.0
			return Vector3(cos(a4), 0.0, sin(a4)) * orbital_au
		5:
			var a5 := angle - PI / 3.0
			return Vector3(cos(a5), 0.0, sin(a5)) * orbital_au
	return planet


# ── Ship position along trajectory ───────────────────────────────────────────

# Hohmann arc position at transit fraction t ∈ [0, 1].
# Uses eccentric anomaly (Kepler's second law) for physically correct speed variation.
# origin_pos, dest_pos: baked 3D positions in AU (y=0).
static func hohmann_pos_at(origin_pos: Vector3, dest_pos: Vector3, t: float) -> Vector3:
	var r1 := origin_pos.length()
	var r2 := dest_pos.length()
	if r1 < 1e-6 or r2 < 1e-6:
		return origin_pos.lerp(dest_pos, t)
	var rp    := minf(r1, r2)
	var ra    := maxf(r1, r2)
	var a     := (rp + ra) * 0.5
	var e     := (ra - rp) / (ra + rp)
	var going_out := r2 >= r1

	# Mean anomaly: 0→π for outbound (perihelion→aphelion),
	#               π→2π for inbound (aphelion→perihelion, prograde).
	var M  := PI * t if going_out else PI * (1.0 + t)
	var E  := _solve_kepler(M, e)
	var nu := 2.0 * atan2(sqrt(1.0 + e) * sin(E * 0.5), sqrt(1.0 - e) * cos(E * 0.5))
	var r  := a * (1.0 - e * cos(E))

	# Perihelion direction: toward origin for outbound, away from origin for inbound.
	var theta_orig := atan2(origin_pos.z, origin_pos.x)
	var peri_dir   := theta_orig if going_out else theta_orig + PI
	var angle      := peri_dir + nu
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


# Ion drive Archimedean spiral position at t ∈ [0, 1].
# Radius interpolates linearly; angle advances n_turns full orbits, prograde.
static func spiral_pos_at(origin_pos: Vector3, dest_pos: Vector3,
		n_turns: int, t: float) -> Vector3:
	var r1    := origin_pos.length()
	var r2    := dest_pos.length()
	var r     := lerpf(r1, r2, t)
	var angle := atan2(origin_pos.z, origin_pos.x) + float(n_turns) * TAU * t
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


# Number of spiral turns for an ion drive transfer between two solar orbits.
static func spiral_turn_count(r1_au: float, r2_au: float) -> int:
	var ratio := maxf(r1_au, r2_au) / maxf(minf(r1_au, r2_au), 1e-6)
	return maxi(3, int(floor(ratio * 2.0)))


# Fusion torch brachistochrone position at t ∈ [0, 1].
# Accelerates to midpoint then decelerates: piecewise quadratic in t.
static func torch_pos_at(origin_pos: Vector3, dest_pos: Vector3, t: float) -> Vector3:
	var s := 2.0 * t * t if t < 0.5 else 1.0 - 2.0 * (1.0 - t) * (1.0 - t)
	return origin_pos.lerp(dest_pos, s)


# ── Polyline generation for arc rendering ─────────────────────────────────────

# Returns n+1 points along a Hohmann arc as a PackedVector3Array.
static func hohmann_arc_points(origin_pos: Vector3, dest_pos: Vector3,
		n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	for i in n + 1:
		pts[i] = hohmann_pos_at(origin_pos, dest_pos, float(i) / float(n))
	return pts


# Returns n+1 points along an ion spiral.
static func spiral_arc_points(origin_pos: Vector3, dest_pos: Vector3,
		n_turns: int, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	for i in n + 1:
		pts[i] = spiral_pos_at(origin_pos, dest_pos, n_turns, float(i) / float(n))
	return pts


# Returns n+1 points along a torch trajectory.
static func torch_arc_points(origin_pos: Vector3, dest_pos: Vector3,
		n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.resize(n + 1)
	for i in n + 1:
		pts[i] = torch_pos_at(origin_pos, dest_pos, float(i) / float(n))
	return pts


# ── Private ───────────────────────────────────────────────────────────────────

# Newton-Raphson solver for Kepler's equation: M = E - e·sin(E).
# Converges in ≤5 iterations for e < 0.9.
static func _solve_kepler(M: float, e: float) -> float:
	var E := M
	for _i in 5:
		E -= (E - e * sin(E) - M) / (1.0 - e * cos(E))
	return E
