class_name ShipSystem
extends RefCounted

var _db: ShipDB


func _init() -> void:
	_db = ShipDB.new()


func tick(s: SimulationState, _delta_years: float, result: TickResult) -> void:
	for ship: Ship in s.ships:
		match ship.ship_state:
			Ship.ShipState.BUILDING:
				if s.elapsed_days >= ship.build_complete_day:
					ship.ship_state = Ship.ShipState.AWAITING_WINDOW
					result.add_event(
						"ship_built_%s" % ship.id,
						"%s is ready for launch." % ship.label,
						EventSystem.Priority.MEDIUM,
						"ships",
						{"ship_id": ship.id}
					)
			Ship.ShipState.IN_TRANSIT:
				if s.elapsed_days >= ship.arrival_day:
					ship.ship_state = Ship.ShipState.ARRIVED
					_on_ship_arrived(s, ship, result)


func apply(s: SimulationState, action: PlayerAction) -> bool:
	match action.type:
		PlayerAction.Type.BUILD_SHIP:
			_do_build_ship(s, action.payload)
			return true
		PlayerAction.Type.LAUNCH_SHIP:
			_do_launch_ship(s, action.payload)
			return true
		PlayerAction.Type.LAUNCH_MOON_MISSION:
			return true  # deprecated no-op
	return false


func _do_build_ship(s: SimulationState, p: Dictionary) -> void:
	var build_option: String = p.get("build_option", "")
	var origin: String = p.get("origin", "earth")
	if build_option.is_empty() or build_option not in s.available_build_options:
		return
	var origin_col := s.colony_for(origin)
	var origin_structs: Array = origin_col.structures if origin_col else []
	if "launch_facility" not in origin_structs \
			and "space_launch_facility" not in origin_structs:
		return
	var cost := _db.get_cost(build_option)
	var mat_cost: float = cost["materials"]
	var energy_cost: float = cost["energy"]
	var build_days: float = cost["build_days"]
	if s.materials_stockpile < mat_cost or s.energy_stockpile < energy_cost:
		return
	s.materials_stockpile -= mat_cost
	s.energy_stockpile -= energy_cost
	var ship := Ship.new()
	ship.id = "ship_%s_%05d" % [build_option, int(s.elapsed_days * 10) % 100000]
	ship.label = _db.get_display_name(build_option)
	ship.role = _db.get_role(build_option)
	ship.origin_body = origin
	ship.propulsion_tier = PropulsionData.best_tier(s.completed_research)
	ship.ship_state = Ship.ShipState.BUILDING
	ship.build_start_day = s.elapsed_days
	ship.build_complete_day = s.elapsed_days + build_days / maxf(s.construction_speed, 0.001)
	s.ships.append(ship)


func _do_launch_ship(s: SimulationState, p: Dictionary) -> void:
	var ship_id: String = p.get("ship_id", "")
	var destination: String = p.get("destination", "")
	var use_direct: bool = bool(p.get("use_direct", false))
	for ship: Ship in s.ships:
		if ship.id != ship_id:
			continue
		if ship.ship_state != Ship.ShipState.AWAITING_WINDOW \
				and ship.ship_state != Ship.ShipState.ORBITING:
			break
		if not destination.is_empty():
			ship.destination_body = destination
		if ship.destination_body.is_empty():
			break
		var tier: int = ship.propulsion_tier
		var direct_ok := use_direct and PropulsionData.is_direct_unlocked(s.completed_research)
		var prof := FlightPlanner.plan(
			ship.origin_body, ship.destination_body, s.elapsed_days, tier, direct_ok)
		ship.trajectory_type = (
			Ship.TrajectoryType.FOLDING if tier == PropulsionData.Tier.FOLDING
			else (Ship.TrajectoryType.DIRECT if direct_ok
			else Ship.TrajectoryType.HOHMANN)
		)
		ship.mission_authorized_day = s.elapsed_days
		if direct_ok:
			ship.departure_day = prof.direct_arrival_day - prof.direct_transit_days
			ship.arrival_day = prof.direct_arrival_day
			s.energy_stockpile = maxf(0.0, s.energy_stockpile - Constants.DIRECT_LAUNCH_ENERGY_COST)
		else:
			ship.departure_day = prof.departure_day
			ship.arrival_day = prof.arrival_day
		ship.ship_state = Ship.ShipState.IN_TRANSIT
		break


func _on_ship_arrived(s: SimulationState, ship: Ship, result: TickResult) -> void:
	match ship.destination_body:
		"moon":
			match ship.role:
				Ship.Role.MISSION_SPECIFIC:
					if not s.milestone_flags.get("moon_landing", false):
						s.milestone_flags["moon_landing"] = true
						result.add_event(
							"moon_landing",
							"Humanity has landed on the Moon. A new era begins.",
							EventSystem.Priority.CRITICAL,
							"MILESTONE",
							{"body": "moon"}
						)
				Ship.Role.PROBE:
					if not s.milestone_flags.get("lunar_probe_complete", false):
						s.milestone_flags["lunar_probe_complete"] = true
						result.add_event(
							"lunar_probe_complete",
							"The lunar probe reaches the Moon. Survey data received.",
							EventSystem.Priority.HIGH,
							"science",
							{"body": "moon"}
						)
		_:
			result.add_event(
				"ship_arrived_%s" % ship.id,
				"%s has arrived at %s." % [ship.label, ship.destination_body],
				EventSystem.Priority.MEDIUM,
				"ships",
				{"ship_id": ship.id, "body": ship.destination_body}
			)
