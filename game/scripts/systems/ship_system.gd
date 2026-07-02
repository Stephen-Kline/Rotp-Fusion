class_name ShipSystem
extends RefCounted

var _ship_db: ShipDB


func _init() -> void:
	_ship_db = ShipDB.new()


func tick(s: SimulationState, _delta_years: float, result: TickResult) -> void:
	var db := BodyDB.new()   # one instance per tick, shared across all ships
	for ship: Ship in s.ships:
		match ship.ship_state:
			Ship.ShipState.BUILDING:
				if s.elapsed_days >= ship.build_complete_day:
					ship.ship_state = Ship.ShipState.AWAITING_WINDOW
					result.add_event(
						"ship_built_%s" % ship.id,
						"%s is ready for launch." % ship.label,
						EventSystem.Priority.MEDIUM, "ships",
						{"ship_id": ship.id}
					)

			Ship.ShipState.AWAITING_WINDOW:
				# mission_authorized_day > 0 means the player issued a launch order.
				# When the window arrives, transition to physically in flight.
				if ship.mission_authorized_day > 0.0 \
						and s.elapsed_days >= ship.departure_day:
					ship.ship_state = Ship.ShipState.IN_TRANSIT

			Ship.ShipState.IN_TRANSIT:
				if s.elapsed_days >= ship.arrival_day:
					_handle_arrival(s, ship, result, db)


func apply(s: SimulationState, action: PlayerAction) -> bool:
	match action.type:
		PlayerAction.Type.BUILD_SHIP:
			_do_build_ship(s, action.payload)
			return true
		PlayerAction.Type.LAUNCH_SHIP:
			_do_launch_ship(s, action.payload)
			return true
		PlayerAction.Type.LAUNCH_MOON_MISSION:
			return true   # deprecated no-op
	return false


# ── Arrival ───────────────────────────────────────────────────────────────────

func _handle_arrival(s: SimulationState, ship: Ship,
		result: TickResult, db: BodyDB) -> void:
	ship.origin_body = ship.destination_body
	_on_ship_arrived(s, ship, result)

	# Check for a queued waypoint
	if ship.waypoints.size() > 0:
		var wp: Dictionary = ship.waypoints[0]
		ship.waypoints.remove_at(0)
		if bool(wp.get("auto_proceed", false)):
			_launch_leg(s, ship, str(wp.get("body", "")), db, result)
			return
		# Pause requested — fall through to ORBITING

	ship.ship_state = Ship.ShipState.ARRIVED if ship.is_terminal_on_arrival() \
			else Ship.ShipState.ORBITING


func _on_ship_arrived(s: SimulationState, ship: Ship, result: TickResult) -> void:
	var dest := ship.destination_body
	match dest:
		"Moon":
			match ship.role:
				Ship.Role.MISSION_SPECIFIC:
					if not s.milestone_flags.get("moon_landing", false):
						s.milestone_flags["moon_landing"] = true
						result.add_event(
							"moon_landing",
							"Humanity has landed on the Moon. A new era begins.",
							EventSystem.Priority.CRITICAL, "MILESTONE",
							{"body": "Moon"}
						)
				Ship.Role.PROBE:
					if not s.milestone_flags.get("lunar_probe_complete", false):
						s.milestone_flags["lunar_probe_complete"] = true
						result.add_event(
							"lunar_probe_complete",
							"The lunar probe reaches the Moon. Survey data received.",
							EventSystem.Priority.HIGH, "science",
							{"body": "Moon"}
						)
		_:
			result.add_event(
				"ship_arrived_%s" % ship.id,
				"%s has arrived at %s." % [ship.label, dest],
				EventSystem.Priority.MEDIUM, "ships",
				{"ship_id": ship.id, "body": dest}
			)


# ── Build ─────────────────────────────────────────────────────────────────────

func _do_build_ship(s: SimulationState, p: Dictionary) -> void:
	var build_option: String = p.get("build_option", "")
	var origin: String       = p.get("origin", "Earth")
	if build_option.is_empty() or build_option not in s.available_build_options:
		return
	var origin_col    := s.colony_for(origin)
	var origin_structs: Array = origin_col.structures if origin_col else []
	if "launch_facility" not in origin_structs \
			and "space_launch_facility" not in origin_structs:
		return
	var cost      := _ship_db.get_cost(build_option)
	var mat_cost: float   = cost["materials"]
	var energy_cost: float = cost["energy"]
	var build_days: float  = cost["build_days"]
	var home_col: ColonyState = s.colonies[0] if not s.colonies.is_empty() else null
	if home_col == null or home_col.materials_stockpile < mat_cost or home_col.energy_stockpile < energy_cost:
		return
	home_col.materials_stockpile -= mat_cost
	home_col.energy_stockpile    -= energy_cost
	var ship := Ship.new()
	ship.id              = "ship_%s_%05d" % [build_option, int(s.elapsed_days * 10) % 100000]
	ship.label           = _ship_db.get_display_name(build_option)
	ship.role            = _ship_db.get_role(build_option)
	ship.capacity        = _ship_db.get_capacity(build_option)
	ship.origin_body     = origin
	ship.propulsion_tier = PropulsionData.best_tier(s.completed_research)
	ship.ship_state      = Ship.ShipState.BUILDING
	ship.build_start_day    = s.elapsed_days
	ship.build_complete_day = s.elapsed_days + build_days / maxf(s.construction_speed, 0.001)
	s.ships.append(ship)


# ── Launch ────────────────────────────────────────────────────────────────────

func _do_launch_ship(s: SimulationState, p: Dictionary) -> void:
	var ship_id:    String = p.get("ship_id", "")
	var destination: String = p.get("destination", "")
	var waypoints:   Array  = p.get("waypoints", [])

	for ship: Ship in s.ships:
		if ship.id != ship_id:
			continue
		if ship.ship_state != Ship.ShipState.AWAITING_WINDOW \
				and ship.ship_state != Ship.ShipState.ORBITING:
			break

		# Store remaining legs (everything after the immediate destination)
		ship.waypoints = waypoints.duplicate(true)

		# If no explicit destination, pop the first waypoint
		var dest := destination
		if dest.is_empty() and not ship.waypoints.is_empty():
			var wp: Dictionary = ship.waypoints[0]
			ship.waypoints.remove_at(0)
			dest = str(wp.get("body", ""))

		if dest.is_empty():
			break

		var db := BodyDB.new()
		_launch_leg(s, ship, dest, db, null)
		break


# Computes and applies the flight plan for the next leg. Validates range and
# departure gravity before committing. Passes result only when called from tick
# (auto-proceed) so error events reach the player; nil is fine for UI-triggered launches.
func _launch_leg(s: SimulationState, ship: Ship, destination: String,
		db: BodyDB, result: TickResult) -> void:
	if destination.is_empty():
		ship.ship_state = Ship.ShipState.ORBITING
		return

	# Range validation (solar AU scale)
	var origin_au := db.orbital_au(ship.origin_body)
	var dest_au   := db.orbital_au(destination)
	if not PropulsionData.range_ok(ship.propulsion_tier, origin_au, dest_au):
		if result:
			result.add_event(
				"ship_range_%s" % ship.id,
				"%s cannot reach %s — out of range for %s propulsion." \
						% [ship.label, destination,
						   PropulsionData.tier_name(ship.propulsion_tier)],
				EventSystem.Priority.HIGH, "ships", {"ship_id": ship.id}
			)
		ship.ship_state = Ship.ShipState.ORBITING
		return

	# Departure gravity validation
	if not PropulsionData.can_depart(ship.propulsion_tier, ship.origin_body):
		if result:
			result.add_event(
				"ship_gravity_%s" % ship.id,
				"%s cannot depart from %s — gravity too strong for %s propulsion." \
						% [ship.label, ship.origin_body,
						   PropulsionData.tier_name(ship.propulsion_tier)],
				EventSystem.Priority.HIGH, "ships", {"ship_id": ship.id}
			)
		ship.ship_state = Ship.ShipState.ORBITING
		return

	ship.destination_body = destination
	var prof := FlightPlanner.plan(
		ship.origin_body, destination, s.elapsed_days, ship.propulsion_tier, db)

	ship.arc_type              = prof.arc_type
	ship.n_turns               = prof.n_turns
	ship.origin_pos            = prof.origin_pos
	ship.dest_pos              = prof.dest_pos
	ship.is_local              = prof.is_local
	ship.mission_authorized_day = s.elapsed_days
	ship.departure_day         = prof.departure_day
	ship.arrival_day           = prof.arrival_day
	ship.ship_state            = Ship.ShipState.AWAITING_WINDOW
