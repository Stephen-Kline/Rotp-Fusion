class_name Ship

# Derived-position transit vehicle. Position at any game-year is computed
# deterministically from trajectory parameters — no per-frame integration needed.

enum Role {
	PROBE,
	TRANSPORT_HUMAN,
	TRANSPORT_CARGO,
	MILITARY,
	MISSION_SPECIFIC,
}

enum ShipState {
	BUILDING,         # under construction at origin_body
	AWAITING_WINDOW,  # built; waiting for player to authorize launch
	IN_TRANSIT,       # flying (window-wait phase: year < departure_year stays at origin)
	ORBITING,         # arrived; in stable orbit at destination
	ARRIVED,          # landed / mission complete (terminal)
}

enum TrajectoryType {
	HOHMANN,  # minimum-energy transfer arc
	DIRECT,   # brute-force burn — requires fusion+ tech gate
	FOLDING,  # instantaneous — requires space folding
}

var id: String = ""
var label: String = ""
var role: int = Role.PROBE
var origin_body: String = "earth"
var destination_body: String = ""
var propulsion_tier: int = 0          # PropulsionData.Tier value
var trajectory_type: int = TrajectoryType.HOHMANN
var ship_state: int = ShipState.BUILDING

# Timeline (all in game-years)
var build_start_year: float = 0.0           # construction started
var build_complete_year: float = 0.0        # construction done → AWAITING_WINDOW
var mission_authorized_year: float = 0.0   # when player confirmed launch
var departure_year: float = 0.0            # actual burn start (after window wait)
var arrival_year: float = 0.0

var payload: Dictionary = {}


# Deterministic position at game-year t.
# Caller provides body positions; SimulationState does not compute screen coords.
func position_at(year: float, origin_pos: Vector2, dest_pos: Vector2) -> Vector2:
	match ship_state:
		ShipState.BUILDING, ShipState.AWAITING_WINDOW:
			return origin_pos
		ShipState.ORBITING, ShipState.ARRIVED:
			return dest_pos
		ShipState.IN_TRANSIT:
			if year < departure_year or arrival_year <= departure_year:
				return origin_pos
			var t := clampf((year - departure_year) / (arrival_year - departure_year), 0.0, 1.0)
			return origin_pos.lerp(dest_pos, t)
	return origin_pos


func duplicate() -> Ship:
	var s := Ship.new()
	s.id = id; s.label = label; s.role = role
	s.origin_body = origin_body; s.destination_body = destination_body
	s.propulsion_tier = propulsion_tier; s.trajectory_type = trajectory_type
	s.ship_state = ship_state
	s.build_start_year = build_start_year
	s.build_complete_year = build_complete_year
	s.mission_authorized_year = mission_authorized_year
	s.departure_year = departure_year; s.arrival_year = arrival_year
	s.payload = payload.duplicate()
	return s
