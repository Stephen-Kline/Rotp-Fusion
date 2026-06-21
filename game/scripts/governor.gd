class_name Governor

# Stateless logic. Takes SimulationState + delta (in game-years), returns a
# new SimulationState and a list of events to emit via EventSystem.
# No side effects, no UI coupling.

const ENERGY_LOW_THRESHOLD := 0.3  # below this, debuffs apply

var _tech_db: TechTreeDB

class TickResult:
	var state: SimulationState
	var events: Array[Dictionary]  # [{id, message, priority, year}]

	func _init(s: SimulationState) -> void:
		state = s
		events = []

	func add_event(id: String, message: String, priority: int) -> void:
		events.append({
			"id": id,
			"message": message,
			"priority": priority,
			"year": state.year,
		})


func _init() -> void:
	_tech_db = TechTreeDB.new()


# Process a batch of player actions against state, returning the updated state.
# Called before tick() so the tick sees current player intent.
func apply_actions(state: SimulationState, actions: Array) -> SimulationState:
	if actions.is_empty():
		return state
	var next := state.duplicate_state()
	for action in actions:
		_apply_action(next, action)
	return next


func _apply_action(s: SimulationState, action: PlayerAction) -> void:
	match action.type:
		PlayerAction.Type.SET_PILLAR_ALLOCATION:
			var p := action.payload
			s.pillar_food = float(p.get("food", s.pillar_food))
			s.pillar_education = float(p.get("education", s.pillar_education))
			s.pillar_industry = float(p.get("industry", s.pillar_industry))
			s.pillar_energy = float(p.get("energy", s.pillar_energy))
		PlayerAction.Type.SET_ACTIVE_RESEARCH:
			var node_id: String = action.payload.get("node_id", "")
			if _tech_db.is_available(node_id, s.completed_research, s.milestone_flags):
				s.active_research = node_id
				s.research_progress = 0.0


func tick(state: SimulationState, delta_years: float) -> TickResult:
	var next := state.duplicate_state()
	var result := TickResult.new(next)

	next.year = state.year + int(delta_years)

	_compute_energy(next)
	_compute_research_rate(next)
	_compute_construction_speed(next)
	_compute_population(next, delta_years)
	_tick_research(next, delta_years, result)

	return result


func _compute_energy(s: SimulationState) -> void:
	# Energy capacity scales with pillar allocation; normalized 0–1
	s.energy_capacity = clamp(s.pillar_energy / 50.0, 0.0, 1.0)


func _compute_research_rate(s: SimulationState) -> void:
	var base := s.pillar_education / 100.0
	var energy_multiplier := 1.0 if s.energy_capacity >= ENERGY_LOW_THRESHOLD else 0.5
	s.research_rate = base * energy_multiplier * 10.0  # in education-output-years per game-year


func _compute_construction_speed(s: SimulationState) -> void:
	var base := s.pillar_industry / 100.0
	var energy_multiplier := 1.0 if s.energy_capacity >= ENERGY_LOW_THRESHOLD else 0.5
	s.construction_speed = base * energy_multiplier


func _compute_population(s: SimulationState, delta_years: float) -> void:
	var food_factor := s.pillar_food / 25.0  # 25% is baseline
	var growth_rate := 0.01 * food_factor    # 1% per year at baseline
	s.population_units += s.population_units * growth_rate * delta_years


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
			EventSystem.Priority.HIGH
		)


func _apply_unlock_payload(s: SimulationState, node: TechNode) -> void:
	var payload := node.unlock_payload
	for milestone in payload.get("milestones", []):
		s.milestone_flags[milestone] = true
	for build_option in payload.get("build_options", []):
		if not build_option in s.available_build_options:
			s.available_build_options.append(build_option)
	var modifiers: Dictionary = payload.get("stat_modifiers", {})
	if modifiers.has("energy_bonus"):
		# Bonus is applied next compute cycle via modified capacity ceiling
		s.milestone_flags["energy_bonus_" + node.id] = true
	if modifiers.has("research_rate_bonus"):
		s.research_rate_bonus += float(modifiers["research_rate_bonus"])
