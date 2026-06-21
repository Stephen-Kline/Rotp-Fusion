class_name Governor

# Stateless logic. Takes SimulationState + delta (in game-years), returns a
# new SimulationState and a list of events to emit via EventSystem.
# No side effects, no UI coupling.

const ENERGY_LOW_THRESHOLD := 0.3  # below this, debuffs apply

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

		PlayerAction.Type.SPEND_POLITICAL_CAPITAL:
			var p := action.payload
			var faction_id: String = p.get("faction_id", "")
			var amount: float = float(p.get("amount", 0.0))
			for f: Faction in s.factions:
				if f.id == faction_id:
					# Cost scales: base 20, multiplied by (1 + (100 - satisfaction) / 100)
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

	_compute_factions(next, delta_years, result)

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


func _compute_factions(s: SimulationState, delta_years: float, result: TickResult) -> void:
	const CRISIS_THRESHOLD := 20.0
	const CRISIS_YEARS := 3

	# Map pillar name → current allocation
	var pillar_map: Dictionary = {
		"food": s.pillar_food,
		"education": s.pillar_education,
		"industry": s.pillar_industry,
		"energy": s.pillar_energy,
	}

	var capital_accrual: float = 0.0

	for f: Faction in s.factions:
		var alloc: float = pillar_map.get(f.preferred_pillar, 0.0)

		# Satisfaction update
		f._prev_satisfaction = f._cur_satisfaction
		var sat_delta: float = 0.0
		if alloc >= 30.0:
			sat_delta = 2.0 * delta_years
		elif alloc < 20.0:
			sat_delta = -3.0 * delta_years
		# 20–30%: no change
		f._cur_satisfaction = clampf(f.satisfaction + sat_delta, 0.0, 100.0)
		f.satisfaction = f._cur_satisfaction

		# Dissatisfied years tracking
		if f.satisfaction < CRISIS_THRESHOLD:
			f.dissatisfied_years += int(delta_years)
		else:
			f.dissatisfied_years = 0

		# Crisis event
		if f.dissatisfied_years >= CRISIS_YEARS:
			result.add_event(
				"faction_crisis_" + f.id,
				"Faction crisis: %s is on the verge of revolt." % f.display_name,
				EventSystem.Priority.HIGH
			)

		# Political capital contribution
		capital_accrual += f.satisfaction * f.weight

	# Accrue political capital
	s.political_capital = clampf(
		s.political_capital + (capital_accrual / 100.0) * delta_years,
		0.0,
		500.0
	)

	# Aggregate faction satisfaction
	var total: float = 0.0
	for f: Faction in s.factions:
		total += f.satisfaction
	s.faction_satisfaction = total / float(s.factions.size()) if s.factions.size() > 0 else 50.0
