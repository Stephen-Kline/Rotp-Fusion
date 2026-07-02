class_name FlightPlanner

# Computes mission profiles for ship transits using orbital mechanics.
# All times are game-days. Requires a BodyDB for orbital parameter lookups.

const _OM = preload("res://scripts/orbital_mechanics.gd")

const SECS_PER_DAY := 86400.0

# Apollo-class override: real minimum-energy Earth↔Moon Hohmann ≈ 5 days,
# but 3.1 days matches Apollo trajectory feel for early-game pacing.
const EARTH_MOON_DAYS := 3.1


class MissionProfile:
	var window_wait_days: float  = 0.0
	var transit_days:     float  = 0.0
	var departure_day:    float  = 0.0
	var arrival_day:      float  = 0.0
	var arc_type:         int    = Ship.TrajectoryType.HOHMANN
	var n_turns:          int    = 0       # ion spiral only
	var origin_pos:       Vector3 = Vector3.ZERO  # baked at departure_day
	var dest_pos:         Vector3 = Vector3.ZERO  # baked at arrival_day
	var is_local:         bool   = false   # true = km frame, false = AU frame


static func plan(origin: String, destination: String,
		departure_from: float, propulsion_tier: int, db: BodyDB) -> MissionProfile:

	if propulsion_tier == PropulsionData.Tier.FOLDING:
		return _plan_folding(origin, destination, departure_from, db)

	if propulsion_tier >= PropulsionData.Tier.FUSION:
		return _plan_torch(origin, destination, departure_from, propulsion_tier, db)

	return _plan_orbital(origin, destination, departure_from, propulsion_tier, db)


# ── Folding ────────────────────────────────────────────────────────────────────

static func _plan_folding(origin: String, destination: String,
		departure_from: float, db: BodyDB) -> MissionProfile:
	var prof        := MissionProfile.new()
	prof.arc_type    = Ship.TrajectoryType.FOLDING
	prof.departure_day = departure_from
	prof.arrival_day   = departure_from
	prof.origin_pos    = db.body_pos_at(origin, departure_from)
	prof.dest_pos      = prof.origin_pos
	return prof


# ── Torch (fusion+): straight brachistochrone line ─────────────────────────────

static func _plan_torch(origin: String, destination: String,
		departure_from: float, tier: int, db: BodyDB) -> MissionProfile:
	var prof      := MissionProfile.new()
	prof.arc_type  = Ship.TrajectoryType.TORCH
	var speed_kmps := float(PropulsionData.SPEED_KMPS.get(tier, 1000.0))

	# Distance at departure — torch ships don't need a window
	var op      := db.body_pos_at(origin, departure_from)
	var dp      := db.body_pos_at(destination, departure_from)
	var dist_km := op.distance_to(dp) * _OM.AU_TO_KM

	prof.transit_days  = dist_km / speed_kmps / SECS_PER_DAY
	prof.departure_day = departure_from
	prof.arrival_day   = departure_from + prof.transit_days
	prof.origin_pos    = op
	prof.dest_pos      = db.body_pos_at(destination, prof.arrival_day)
	return prof


# ── Hohmann / spiral (chemical / nuclear / ion) ────────────────────────────────

static func _plan_orbital(origin: String, destination: String,
		departure_from: float, tier: int, db: BodyDB) -> MissionProfile:
	var prof      := MissionProfile.new()
	prof.arc_type  = Ship.TrajectoryType.SPIRAL if tier == PropulsionData.Tier.ION \
			else Ship.TrajectoryType.HOHMANN

	# Earth ↔ Moon: Apollo-class override, no window (local transfer)
	if _is_earth_moon_pair(origin, destination):
		prof.transit_days  = EARTH_MOON_DAYS
		prof.departure_day = departure_from
		prof.arrival_day   = departure_from + EARTH_MOON_DAYS
		prof.is_local      = true
		prof.origin_pos    = db.body_pos_at(origin, prof.departure_day)
		prof.dest_pos      = db.body_pos_at(destination, prof.arrival_day)
		return prof

	# Determine if transfer is within one planet's local system
	var local_parent := _local_parent(origin, destination, db)
	if local_parent != "":
		return _plan_local(origin, destination, departure_from, prof, local_parent, db)

	return _plan_solar(origin, destination, departure_from, prof, db)


static func _plan_solar(origin: String, destination: String,
		departure_from: float, prof: MissionProfile, db: BodyDB) -> MissionProfile:
	var r1 := _solar_au_of(origin, db)
	var r2 := _solar_au_of(destination, db)
	if r1 <= 0.0 or r2 <= 0.0:
		prof.transit_days  = 365.0
		prof.departure_day = departure_from
		prof.arrival_day   = departure_from + 365.0
		return prof

	prof.transit_days = _OM.hohmann_transit_days(r1, r2, _OM.GM_SUN)
	if prof.arc_type == Ship.TrajectoryType.SPIRAL:
		prof.n_turns = _OM.spiral_turn_count(r1, r2)

	# Window calc uses the solar-orbiting body (parent if origin/dest is a moon)
	var win_o := _solar_ancestor(origin, db)
	var win_d := _solar_ancestor(destination, db)
	var ob    := db.get_body(win_o)
	var deb   := db.get_body(win_d)

	var dep := _OM.next_window_day(
		float(ob.get("orbital_au", r1)),
		float(ob.get("orbital_period_years", 1.0)),
		float(ob.get("ang0_deg", 0.0)),
		float(deb.get("orbital_au", r2)),
		float(deb.get("orbital_period_years", 1.0)),
		float(deb.get("ang0_deg", 0.0)),
		departure_from
	)
	prof.window_wait_days = dep - departure_from
	prof.departure_day    = dep
	prof.arrival_day      = dep + prof.transit_days
	prof.origin_pos       = db.body_pos_at(origin, prof.departure_day)
	prof.dest_pos         = db.body_pos_at(destination, prof.arrival_day)
	return prof


static func _plan_local(origin: String, destination: String,
		departure_from: float, prof: MissionProfile,
		parent: String, db: BodyDB) -> MissionProfile:
	var r1 := _local_radius_km(origin, parent, db)
	var r2 := _local_radius_km(destination, parent, db)
	var gm := float(_OM.GM_PLANETS.get(parent, _OM.GM_PLANETS["Earth"]))

	prof.transit_days  = _OM.hohmann_transit_days(r1, r2, gm)
	prof.departure_day = departure_from   # local transfers: no window wait
	prof.arrival_day   = departure_from + prof.transit_days
	prof.is_local      = true
	prof.origin_pos    = db.body_pos_at(origin, prof.departure_day)
	prof.dest_pos      = db.body_pos_at(destination, prof.arrival_day)
	if prof.arc_type == Ship.TrajectoryType.SPIRAL:
		prof.n_turns = _OM.spiral_turn_count(r1, r2)
	return prof


# ── Helpers ────────────────────────────────────────────────────────────────────

static func _is_earth_moon_pair(a: String, b: String) -> bool:
	return (a == "Earth" and b == "Moon") or (a == "Moon" and b == "Earth")


# Returns the parent body name if the transfer is within one local system,
# or "" if it is a solar-scale transfer.
static func _local_parent(origin: String, destination: String, db: BodyDB) -> String:
	var ob := db.get_body(origin)
	var db_ := db.get_body(destination)
	var op := str(ob.get("parent", "Sol"))
	var dp := str(db_.get("parent", "Sol"))

	# Both moons of the same planet
	if op == dp and op != "Sol" and op != "" and op != "null":
		return op
	# Planet → its own moon (e.g. Mars → Phobos)
	if op == "Sol" and dp == origin:
		return origin
	# Moon → its parent planet (e.g. Phobos → Mars)
	if dp == "Sol" and op == destination:
		return destination
	return ""


# Orbital radius in km for use in a local-system Hohmann.
# If the body IS the parent planet, use its radius_km (approximates LEO).
static func _local_radius_km(id: String, parent: String, db: BodyDB) -> float:
	if id == parent:
		return float(db.get_body(id).get("radius_km", 6371.0))
	return float(db.get_body(id).get("orbital_km", 384400.0))


# Returns the solar-orbiting ancestor of id (itself if it orbits Sol, else its parent).
static func _solar_ancestor(id: String, db: BodyDB) -> String:
	var b      := db.get_body(id)
	var parent := str(b.get("parent", "Sol"))
	if parent == "Sol" or parent == "" or parent == "null":
		return id
	return parent


# Returns the solar orbital AU of a body, using its parent's AU if it is a moon.
static func _solar_au_of(id: String, db: BodyDB) -> float:
	var b      := db.get_body(id)
	var parent := str(b.get("parent", "Sol"))
	if parent == "Sol" or parent == "" or parent == "null":
		return float(b.get("orbital_au", 0.0))
	return db.orbital_au(parent)
