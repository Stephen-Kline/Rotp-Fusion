class_name FactionSystem
extends RefCounted

const CRISIS_THRESHOLD := 20.0
const CRISIS_YEARS     := 3


func tick(s: SimulationState, delta_years: float, result: TickResult) -> void:
	_compute_factions(s, delta_years, result)
	_check_gsa_preconditions(s, result)


func apply(s: SimulationState, action: PlayerAction) -> bool:
	if action.type != PlayerAction.Type.SPEND_POLITICAL_CAPITAL:
		return false
	var p := action.payload
	var faction_id: String = p.get("faction_id", "")
	var amount: float = float(p.get("amount", 0.0))
	for f: Faction in s.factions:
		if f.id == faction_id:
			var cost: float = 20.0 * (1.0 + (100.0 - f.satisfaction) / 100.0)
			if s.political_capital >= cost:
				s.political_capital -= cost
				f._prev_satisfaction = f._cur_satisfaction
				f._cur_satisfaction = clampf(f.satisfaction + amount / 10.0, 0.0, 100.0)
				f.satisfaction = f._cur_satisfaction
			break
	return true


func _compute_factions(s: SimulationState, delta_years: float, result: TickResult) -> void:
	var pillar_map: Dictionary = {
		"food":      s.pillar_food,
		"education": s.pillar_education,
		"industry":  s.pillar_industry,
		"energy":    s.pillar_energy,
	}
	var capital_accrual: float = 0.0

	for f: Faction in s.factions:
		var alloc: float = pillar_map.get(f.preferred_pillar, 0.0)
		f._prev_satisfaction = f._cur_satisfaction
		var sat_delta: float = 0.0
		if alloc >= 30.0:
			sat_delta = 2.0 * delta_years
		elif alloc < 20.0:
			sat_delta = -3.0 * delta_years
		f._cur_satisfaction = clampf(f.satisfaction + sat_delta, 0.0, 100.0)
		f.satisfaction = f._cur_satisfaction

		if f.satisfaction < CRISIS_THRESHOLD:
			f.dissatisfied_years += delta_years
		else:
			f.dissatisfied_years = 0.0

		if f.dissatisfied_years >= float(CRISIS_YEARS):
			result.add_event(
				"faction_crisis_" + f.id,
				"Faction crisis: %s is on the verge of revolt." % f.display_name,
				EventSystem.Priority.HIGH,
				"faction",
				{"faction_id": f.id}
			)

		capital_accrual += f.satisfaction * f.weight

	s.political_capital = clampf(
		s.political_capital + (capital_accrual / 100.0) * delta_years,
		0.0,
		500.0
	)
	var total: float = 0.0
	for f: Faction in s.factions:
		total += f.satisfaction
	s.faction_satisfaction = total / float(s.factions.size()) if s.factions.size() > 0 else 50.0


func _check_gsa_preconditions(s: SimulationState, result: TickResult) -> void:
	if s.milestone_flags.get("gsa_founded", false):
		return
	var satisfied_count: int = 0
	for f: Faction in s.factions:
		if f.satisfaction >= 50.0:
			satisfied_count += 1
	if satisfied_count >= 3 and "expanded_station" in s.completed_research:
		s.milestone_flags["gsa_founded"] = true
		s.research_rate_bonus += 0.3
		result.add_event(
			"gsa_founded",
			"The Global Space Agency is founded. Humanity speaks with one voice.",
			EventSystem.Priority.CRITICAL,
			"GSA"
		)
