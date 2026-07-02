extends Node

# Headless tick harness — run via: godot --headless res://test_tick.tscn
# Verifies: station consumables drain, Earth→Station transport, event resolution.

func _ready() -> void:
	print("=== Tick Harness Start ===")
	var gov := Governor.new()
	var s   := _make_state()

	for i in 40:
		var r := gov.tick(s, 10.0)
		s = r.state
		if i % 10 == 9:
			_print_state(s)

	# Inject an active event and resolve it
	s.active_events.append({
		"event_id":    "supply_disruption",
		"triggered_day": s.elapsed_days,
		"expiry_day":  s.elapsed_days + 7.0,
		"choice_made": ""
	})
	var cons_before: float = s.colonies[0].consumables_stockpile
	s = gov.apply_actions(s, [PlayerAction.resolve_event("supply_disruption", "ration")])
	var resolved: bool = s.active_events[0].get("choice_made", "") != ""
	var satisfaction_changed: bool = s.faction_satisfaction != 50.0
	print("\n--- Event resolution ---")
	print("  resolved: ", resolved)
	print("  faction_satisfaction after ration: %.1f (was 50.0)" % s.faction_satisfaction)
	print("  consumables unchanged (ration has no cost): ", \
		is_equal_approx(s.colonies[0].consumables_stockpile, cons_before))

	print("\n=== Tick Harness Done ===")
	get_tree().quit()


func _make_state() -> SimulationState:
	var s := SimulationState.new()   # creates Earth + factions

	# Station colony with life support drain
	var station := ColonyState.new()
	station.body_id          = "Station"
	station.population_units = 0.05
	station.environment      = 100.0
	station.env_yield_mult   = 1.0
	station.resource_bonus   = {}
	station.structures.append("life_support_module")
	station.online_flags.append(true)
	# stockpiles start at 0 — should go negative via life_support drain
	s.colonies.append(station)

	# Freighter already in orbit
	var ship := Ship.new()
	ship.id          = "freighter_001"
	ship.label       = "Freighter 1"
	ship.role        = Ship.Role.TRANSPORT_CARGO
	ship.capacity    = 1e12
	ship.ship_state  = Ship.ShipState.ORBITING
	s.ships.append(ship)

	return s


func _print_state(s: SimulationState) -> void:
	print("Day %d:" % int(s.elapsed_days))
	for col: ColonyState in s.colonies:
		print("  " + col.body_id + "  cons_stock=" + str(col.consumables_stockpile) \
			+ "  cons_rate=" + str(col.consumables_rate))
