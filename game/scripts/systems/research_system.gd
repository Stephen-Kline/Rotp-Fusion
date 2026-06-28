class_name ResearchSystem
extends RefCounted

const LEO_LADDER := [
	{"id": "suborbital_flight",    "message": "Humanity reaches space for the first time."},
	{"id": "orbital_satellite",    "message": "A satellite circles the Earth."},
	{"id": "crewed_orbit",         "message": "A human being orbits the Earth."},
	{"id": "long_duration_crewed", "message": "Crews live in space for weeks at a time."},
	{"id": "modular_station",      "message": "A permanent outpost now orbits the Earth."},
	{"id": "expanded_station",     "message": "The station grows — a true gateway to the cosmos."},
]

var _tech_db: TechTreeDB


func _init() -> void:
	_tech_db = TechTreeDB.new()


func tick(s: SimulationState, delta_years: float, result: TickResult) -> void:
	_tick_research(s, delta_years, result)
	_check_leo_milestones(s, result)


func apply(s: SimulationState, action: PlayerAction) -> bool:
	if action.type != PlayerAction.Type.SET_ACTIVE_RESEARCH:
		return false
	var node_id: String = action.payload.get("node_id", "")
	if node_id in s.completed_research or node_id == s.active_research or node_id in s.research_queue:
		return true
	if _tech_db.is_available(node_id, s.completed_research, s.milestone_flags):
		if s.active_research.is_empty():
			s.active_research = node_id
			s.research_progress = 0.0
		else:
			s.research_queue.append(node_id)
	return true


func _tick_research(s: SimulationState, delta_years: float, result: TickResult) -> void:
	if s.active_research.is_empty():
		return
	var node: TechNode = _tech_db.get_node(s.active_research)
	if not node:
		s.active_research = ""
		return
	s.research_progress += s.research_rate * delta_years
	if s.research_progress >= node.research_cost:
		s.completed_research.append(s.active_research)
		s.active_research = ""
		s.research_progress = 0.0
		_apply_unlock_payload(s, node)
		result.add_event(
			"research_complete_%s" % node.id,
			"Research complete: %s" % node.display_name,
			EventSystem.Priority.LOW,
			"research",
			{"node_id": node.id}
		)
		while not s.research_queue.is_empty():
			var next_id: String = s.research_queue.pop_front()
			if next_id not in s.completed_research \
					and _tech_db.is_available(next_id, s.completed_research, s.milestone_flags):
				s.active_research = next_id
				break


func _check_leo_milestones(s: SimulationState, result: TickResult) -> void:
	for step: Dictionary in LEO_LADDER:
		var node_id: String = step["id"]
		var flag: String = "leo_celebrated_" + node_id
		if node_id in s.completed_research and not s.milestone_flags.get(flag, false):
			result.add_event(
				"leo_milestone_" + node_id,
				step["message"],
				EventSystem.Priority.CRITICAL,
				"LEO",
				{"node_id": node_id}
			)
			s.milestone_flags[flag] = true


func _apply_unlock_payload(s: SimulationState, node: TechNode) -> void:
	var payload := node.unlock_payload
	for milestone in payload.get("milestones", []):
		s.milestone_flags[milestone] = true
	for build_option in payload.get("build_options", []):
		if not build_option in s.available_build_options:
			s.available_build_options.append(build_option)
	var modifiers: Dictionary = payload.get("stat_modifiers", {})
	if modifiers.has("energy_bonus"):
		s.milestone_flags["energy_bonus_" + node.id] = true
	if modifiers.has("research_rate_bonus"):
		s.research_rate_bonus += float(modifiers["research_rate_bonus"])
	if modifiers.has("construction_speed_bonus"):
		s.construction_speed_bonus += float(modifiers["construction_speed_bonus"])
	if modifiers.has("mult_energy"):
		s.mult_energy *= float(modifiers["mult_energy"])
	if modifiers.has("mult_consumables"):
		s.mult_consumables *= float(modifiers["mult_consumables"])
	if modifiers.has("mult_knowledge"):
		s.mult_knowledge *= float(modifiers["mult_knowledge"])
	if modifiers.has("mult_materials"):
		s.mult_materials *= float(modifiers["mult_materials"])
