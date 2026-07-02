class_name Ship
extends Resource

const _OM = preload("res://scripts/orbital_mechanics.gd")

enum Role {
	PROBE,
	TRANSPORT_HUMAN,
	TRANSPORT_CARGO,
	MILITARY,
	MISSION_SPECIFIC,
}

enum ShipState {
	BUILDING,
	AWAITING_WINDOW,
	IN_TRANSIT,
	ORBITING,
	ARRIVED,       # terminal — only for MISSION_SPECIFIC / one-shot roles
}

enum TrajectoryType {
	HOHMANN,  # chemical / nuclear — Keplerian semi-ellipse
	SPIRAL,   # ion drive — Archimedean outward spiral
	TORCH,    # fusion+ — straight brachistochrone line
	FOLDING,  # instantaneous
}

# Identity
@export var id:       String = ""
@export var label:    String = ""
@export var role:     int    = Role.PROBE
@export var capacity: float  = 0.0  # cargo capacity in resource units; 0 for non-transport

# Route
@export var origin_body:      String = "Earth"
@export var destination_body: String = ""
@export var waypoints:        Array  = []   # Array of {body: String, auto_proceed: bool}

# Propulsion
@export var propulsion_tier: int = 0
@export var arc_type:        int = TrajectoryType.HOHMANN
@export var n_turns:         int = 3    # ion spiral only

# Baked arc endpoints (set at launch, never change during transit)
# Units: AU for solar transfers, km for local-system (moon) transfers
@export var origin_pos: Vector3 = Vector3.ZERO
@export var dest_pos:   Vector3 = Vector3.ZERO
@export var is_local:   bool    = false   # true = local-system km frame

# State
@export var ship_state: int = ShipState.BUILDING

# Timeline (game-days elapsed since T=0)
@export var build_start_day:      float = 0.0
@export var build_complete_day:   float = 0.0
@export var mission_authorized_day: float = 0.0
@export var departure_day:        float = 0.0
@export var arrival_day:          float = 0.0

@export var payload: Dictionary = {}


# 3D position along the arc at the given elapsed_days.
# Returns a position in the same frame as origin_pos / dest_pos
# (AU for solar transfers, km for local).
func position_at(elapsed_days: float) -> Vector3:
	match ship_state:
		ShipState.BUILDING, ShipState.AWAITING_WINDOW:
			return origin_pos
		ShipState.ORBITING, ShipState.ARRIVED:
			return dest_pos
		ShipState.IN_TRANSIT:
			if arrival_day <= departure_day:
				return origin_pos
			var t := clampf(
				(elapsed_days - departure_day) / (arrival_day - departure_day), 0.0, 1.0)
			match arc_type:
				TrajectoryType.HOHMANN:
					return _OM.hohmann_pos_at(origin_pos, dest_pos, t)
				TrajectoryType.SPIRAL:
					return _OM.spiral_pos_at(origin_pos, dest_pos, n_turns, t)
				TrajectoryType.TORCH:
					return _OM.torch_pos_at(origin_pos, dest_pos, t)
				_:   # FOLDING
					return dest_pos
	return origin_pos


# Orbit altitude radius in km for this role — used by planet_view renderer.
func orbit_radius_km(body_radius_km: float) -> float:
	match role:
		Role.PROBE:            return body_radius_km * 1.8
		Role.TRANSPORT_HUMAN:  return body_radius_km * 3.5
		Role.TRANSPORT_CARGO:  return body_radius_km * 3.5
		Role.MILITARY:         return body_radius_km * 2.5
		_:                     return body_radius_km * 2.0


# Whether this role should enter ARRIVED (terminal) rather than ORBITING on arrival.
func is_terminal_on_arrival() -> bool:
	return role == Role.MISSION_SPECIFIC
