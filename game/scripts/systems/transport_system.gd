class_name TransportSystem
extends RefCounted

# Handles automatic inter-colony resource transfers.
# Each tick: compute per-colony deficits, source from nearest surplus,
# cap total transfer by (num_transport_ships * capacity_per_ship).
#
# With only one colony this system is a no-op. Real transfers activate at Milestone 1.5
# when Earth → Station routes become the first live test (TODOS.md item 11).


func tick(s: SimulationState, delta_years: float, _result: TickResult) -> void:
	if s.colonies.size() < 2:
		return  # nothing to transport yet

	var total_capacity := _fleet_capacity(s) * delta_years
	if total_capacity <= 0.0:
		return

	# Transfer each resource type: drain from surplus, fill deficits.
	for resource in ["energy", "consumables", "materials"]:
		_transfer_resource(s, resource, total_capacity)


func _fleet_capacity(s: SimulationState) -> float:
	var total := 0.0
	for ship: Ship in s.ships:
		if ship.role == Ship.Role.TRANSPORT_CARGO \
				and ship.ship_state == Ship.ShipState.ORBITING:
			total += ship.capacity
	return total


func _transfer_resource(s: SimulationState, resource: String, capacity: float) -> void:
	var remaining := capacity
	for deficit_col: ColonyState in s.colonies:
		if remaining <= 0.0:
			break
		var deficit := _colony_deficit(deficit_col, resource)
		if deficit <= 0.0:
			continue
		# Source from the colony with most surplus (greedy pick).
		var best_surplus: ColonyState = null
		var best_amount  := 0.0
		for surplus_col: ColonyState in s.colonies:
			if surplus_col == deficit_col:
				continue
			var surplus := _colony_surplus(surplus_col, resource)
			if surplus > best_amount:
				best_amount  = surplus
				best_surplus = surplus_col
		if best_surplus == null:
			continue
		var transfer := minf(minf(deficit, best_amount), remaining)
		_deduct(best_surplus, resource, transfer)
		_add(deficit_col,    resource, transfer)
		remaining -= transfer


func _colony_deficit(col: ColonyState, resource: String) -> float:
	match resource:
		"energy":       return maxf(0.0, -col.energy_stockpile)
		"consumables":  return maxf(0.0, -col.consumables_stockpile)
		"materials":    return maxf(0.0, -col.materials_stockpile)
	return 0.0


func _colony_surplus(col: ColonyState, resource: String) -> float:
	match resource:
		"energy":       return maxf(0.0, col.energy_stockpile)
		"consumables":  return maxf(0.0, col.consumables_stockpile)
		"materials":    return maxf(0.0, col.materials_stockpile)
	return 0.0


func _deduct(col: ColonyState, resource: String, amount: float) -> void:
	match resource:
		"energy":       col.energy_stockpile      -= amount
		"consumables":  col.consumables_stockpile -= amount
		"materials":    col.materials_stockpile   -= amount


func _add(col: ColonyState, resource: String, amount: float) -> void:
	match resource:
		"energy":       col.energy_stockpile      += amount
		"consumables":  col.consumables_stockpile += amount
		"materials":    col.materials_stockpile   += amount
