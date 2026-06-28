class_name Ship
extends Resource

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
	ARRIVED,
}

enum TrajectoryType {
	HOHMANN,
	DIRECT,
	FOLDING,
}

@export var id: String = ""
@export var label: String = ""
@export var role: int = Role.PROBE
@export var origin_body: String = "earth"
@export var destination_body: String = ""
@export var propulsion_tier: int = 0
@export var trajectory_type: int = TrajectoryType.HOHMANN
@export var ship_state: int = ShipState.BUILDING

# Timeline (all in game-days elapsed since T=0)
@export var build_start_day: float = 0.0
@export var build_complete_day: float = 0.0
@export var mission_authorized_day: float = 0.0
@export var departure_day: float = 0.0
@export var arrival_day: float = 0.0

@export var payload: Dictionary = {}


func position_at(elapsed_days: float, origin_pos: Vector2, dest_pos: Vector2) -> Vector2:
	match ship_state:
		ShipState.BUILDING, ShipState.AWAITING_WINDOW:
			return origin_pos
		ShipState.ORBITING, ShipState.ARRIVED:
			return dest_pos
		ShipState.IN_TRANSIT:
			if elapsed_days < departure_day or arrival_day <= departure_day:
				return origin_pos
			var t := clampf((elapsed_days - departure_day) / (arrival_day - departure_day), 0.0, 1.0)
			return origin_pos.lerp(dest_pos, t)
	return origin_pos
