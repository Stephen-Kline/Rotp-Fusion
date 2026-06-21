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
		PlayerAction.Type.SPEND_POLITICAL_CAPITAL:
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


func tick(state: SimulationState, delta_years: float) -> TickResult:
	var next := state.duplicate_state()
	var result := TickResult.new(next)

	next.year = state.year + int(delta_years)

	_compute_energy(next)
	_compute_research_rate(next)
	_compute_construction_speed(next)
	_compute_population(next, delta_years)
	_tick_research(next, delta_years, result)
	_compute_factions(next, delta_years, result)
	_check_gsa_preconditions(next, result)

	return result


func _compute_energy(s: SimulationState) -> void:
	s.energy_capacity = clamp(s.pillar_energy / 50.0, 0.0, 1.0)


func _compute_research_rate(s: SimulationState) -> void:
	var base := s.pillar_education / 100.0
	var energy_multiplier := 1.0 if s.energy_capacity >= ENERGY_LOW_THRESHOLD else 0.5
	s.research_rate = base * energy_multiplier * 10.0


func _compute_construction_speed(s: SimulationState) -> void:
	var base := s.pillar_industry / 100.0
	var energy_multiplier := 1.0 if s.energy_capacity >= ENERGY_LOW_THRESHOLD else 0.5
	s.construction_speed = base * energy_multiplier


func _compute_population(s: SimulationState, delta_years: float) -> void:
	var food_factor := s.pillar_food / 25.0
	var growth_rate := 0.01 * food_factor
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
		s.milestone_flags["energy_bonus_" + node.id] = true
	if modifiers.has("research_rate_bonus"):
		s.research_rate_bonus += float(modifiers["research_rate_bonus"])


func _compute_factions(s: SimulationState, delta_years: float, result: TickResult) -> void:
	const CRISIS_THRESHOLD := 20.0
	const CRISIS_YEARS := 3

	var pillar_map: Dictionary = {
		"food": s.pillar_food,
		"education": s.pillar_education,
		"industry": s.pillar_industry,
		"energy": s.pillar_energy,
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
			f.dissatisfied_years += int(delta_years)
		else:
			f.dissatisfied_years = 0

		if f.dissatisfied_years >= CRISIS_YEARS:
			result.add_event(
				"faction_crisis_" + f.id,
				"Faction crisis: %s is on the verge of revolt." % f.display_name,
				EventSystem.Priority.HIGH
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
	# Count factions with satisfaction >= 50
	var satisfied_count: int = 0
	for f: Faction in s.factions:
		if f.satisfaction >= 50.0:
			satisfied_count += 1

	# If 3+ satisfied factions AND expanded_station researched, set faction_threshold_met
	if not s.milestone_flags.get("gsa_founded", false):
		if satisfied_count >= 3 and "expanded_station" in s.completed_research:
			s.milestone_flags["faction_threshold_met"] = true

	# Emit the founding CRITICAL event exactly once.
	# gsa_founded is set by _apply_unlock_payload (in _tick_research) in the same tick the
	# research completes. The research_rate_bonus (+0.3) is already applied by _apply_unlock_payload
	# via stat_modifiers. We use gsa_event_fired as a one-shot guard for the event only.
	if s.milestone_flags.get("gsa_founded", false) and not s.milestone_flags.get("gsa_event_fired", false):
		s.milestone_flags["gsa_event_fired"] = true
		result.events.append({
			"id": "gsa_founded",
			"message": "The Global Space Agency is founded. Humanity speaks with one voice.",
			"priority": EventSystem.Priority.CRITICAL,
			"year": s.year,
			"category": "GSA",
		})
