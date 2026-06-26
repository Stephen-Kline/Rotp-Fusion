class_name Governor

# Stateless logic. Takes SimulationState + delta (in game-years), returns a
# new SimulationState and a list of events to emit via EventSystem.
# No side effects, no UI coupling.

# Base production rates at 100% budget allocation, no tech bonuses, no structures.
# budget_factor(25%) ≈ 0.457, so starting rates at equal 25% splits are:
#   Energy:      ~91 EJ/yr   → K_energy  ≈ 0.70
#   Consumables: ~1.8 Pcal/yr
#   Knowledge:   ~914 Mbits/yr → K_knowledge ≈ 0.70
#   Materials:   ~9.1 Gt/yr
const BASE_ENERGY_RATE      := 2e20  # J/yr
const BASE_CONSUMABLES_RATE := 4e15  # kcal/yr
const BASE_KNOWLEDGE_RATE   := 2e9   # bits/yr
const BASE_MATERIALS_RATE   := 2e10  # tonnes/yr

# Interaction thresholds: below 15% of base, a resource is "critically low"
# and penalizes other resource production rates.
const CRITICAL_FLOOR := 0.15

const ENERGY_LOW_THRESHOLD := 0.3  # legacy: below this, display shows warning

const _RH = preload("res://scripts/resource_helpers.gd")

var _tech_db: TechTreeDB

class TickResult:
	var state: SimulationState
	var events: Array[Dictionary]  # [{id, message, priority, year, category}]

	func _init(s: SimulationState) -> void:
		state = s
		events = []

	func add_event(id: String, message: String, priority: int, category: String = "") -> void:
		events.append({
			"id": id,
			"message": message,
			"priority": priority,
			"year": state.year,
			"category": category,
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
			if node_id in s.completed_research or node_id == s.active_research or node_id in s.research_queue:
				pass  # already done or queued
			elif _tech_db.is_available(node_id, s.completed_research, s.milestone_flags):
				if s.active_research.is_empty():
					s.active_research = node_id
					s.research_progress = 0.0
				else:
					s.research_queue.append(node_id)
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
		PlayerAction.Type.LAUNCH_MOON_MISSION:
			var prereqs_met: bool = (
				"crewed_lunar_vehicle" in s.completed_research
				and s.milestone_flags.get("lunar_probe_complete", false)
				and not s.moon_mission_active
				and not s.milestone_flags.get("moon_landing", false)
			)
			if prereqs_met:
				s.moon_mission_active = true
				s.moon_mission_progress = 0.0
				var duration := 2.0 / maxf(s.construction_speed, 0.001)
				s.moon_mission_duration = clampf(duration, 0.5, 9999.0)


func tick(state: SimulationState, delta_years: float) -> TickResult:
	var next := state.duplicate_state()
	var result := TickResult.new(next)

	next.year = state.year + delta_years

	_compute_resources(next, delta_years)
	_tick_research(next, delta_years, result)
	_check_leo_milestones(next, result)
	_tick_moon_mission(next, delta_years, result)
	_compute_factions(next, delta_years, result)
	_check_gsa_preconditions(next, result)

	return result


func _compute_resources(s: SimulationState, delta_years: float) -> void:
	# Budget → base production rates (soft diminishing returns with floor)
	var bf_e := _budget_factor(s.pillar_energy)
	var bf_c := _budget_factor(s.pillar_food)
	var bf_k := _budget_factor(s.pillar_education)
	var bf_m := _budget_factor(s.pillar_industry)

	var base_e := BASE_ENERGY_RATE      * bf_e
	var base_c := BASE_CONSUMABLES_RATE * bf_c
	var base_k := BASE_KNOWLEDGE_RATE   * bf_k
	var base_m := BASE_MATERIALS_RATE   * bf_m

	# Light cross-resource interactions:
	#   Consumables low → all other rates penalized (starving civilization can't function)
	#   Energy low      → Knowledge and Materials rates penalized (no power, no progress)
	var cons_critical := BASE_CONSUMABLES_RATE * CRITICAL_FLOOR
	var energy_critical := BASE_ENERGY_RATE * CRITICAL_FLOOR
	var cons_mult   := clampf(base_c / cons_critical,   0.50, 1.0)
	var energy_mult := clampf(base_e / energy_critical, 0.70, 1.0)

	# Final rates: (budget_rate + structure_rate) × research_mult × interactions
	s.energy_rate      = (base_e + s.struct_energy)      * s.mult_energy      * cons_mult
	s.consumables_rate = (base_c + s.struct_consumables) * s.mult_consumables
	s.knowledge_rate   = (base_k + s.struct_knowledge)   * s.mult_knowledge   * cons_mult * energy_mult
	s.materials_rate   = (base_m + s.struct_materials)   * s.mult_materials   * cons_mult * energy_mult

	# Accumulate stockpiles
	s.energy_stockpile      += s.energy_rate      * delta_years
	s.consumables_stockpile += s.consumables_rate * delta_years
	s.knowledge_stockpile   += s.knowledge_rate   * delta_years
	s.materials_stockpile   += s.materials_rate   * delta_years

	# ── Legacy display fields (kept until UI layer is updated) ─────────────────
	# energy_capacity: normalized 0–1 based on energy rate vs base
	s.energy_capacity = clampf(s.energy_rate / BASE_ENERGY_RATE, 0.0, 1.0)

	# research_rate: scaled knowledge rate used by _tick_research progress system
	# Calibrated so starting value (~4.57) is similar to the old formula output (~2.5)
	s.research_rate = (s.knowledge_rate / BASE_KNOWLEDGE_RATE) * 5.0 + s.research_rate_bonus

	# construction_speed: scaled materials rate used for mission timing
	s.construction_speed = clampf(
		s.materials_rate / BASE_MATERIALS_RATE + s.construction_speed_bonus, 0.1, 5.0)

	# population_units (millions): smoothly tracks consumables rate equilibrium
	# ~1M people need ~7.3e11 kcal/year (2000 kcal/day)
	var pop_target := s.consumables_rate / 7.3e11
	s.population_units = lerpf(s.population_units, pop_target, 0.1 * delta_years)

	# Kardashev level: 60% energy, 40% knowledge blend
	var k_e := _RH.k_from_energy(s.energy_rate)
	var k_k := _RH.k_from_knowledge(s.knowledge_rate)
	s.kardashev_level = clampf(0.60 * k_e + 0.40 * k_k, 0.0, 3.0)


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
			EventSystem.Priority.LOW
		)
		# Auto-start next queued item (skip any that became unavailable or were completed)
		while not s.research_queue.is_empty():
			var next_id: String = s.research_queue.pop_front()
			if next_id not in s.completed_research and _tech_db.is_available(next_id, s.completed_research, s.milestone_flags):
				s.active_research = next_id
				break


const LEO_LADDER := [
	{"id": "suborbital_flight",    "message": "Humanity reaches space for the first time."},
	{"id": "orbital_satellite",    "message": "A satellite circles the Earth."},
	{"id": "crewed_orbit",         "message": "A human being orbits the Earth."},
	{"id": "long_duration_crewed", "message": "Crews live in space for weeks at a time."},
	{"id": "modular_station",      "message": "A permanent outpost now orbits the Earth."},
	{"id": "expanded_station",     "message": "The station grows — a true gateway to the cosmos."},
]


func _check_leo_milestones(s: SimulationState, result: TickResult) -> void:
	for step in LEO_LADDER:
		var node_id: String = step["id"]
		var flag: String = "leo_celebrated_" + node_id
		if node_id in s.completed_research and not s.milestone_flags.get(flag, false):
			result.add_event("leo_milestone_" + node_id, step["message"], EventSystem.Priority.CRITICAL, "LEO")
			s.milestone_flags[flag] = true


func _tick_moon_mission(s: SimulationState, delta_years: float, result: TickResult) -> void:
	if s.moon_mission_active and not s.milestone_flags.get("moon_landing", false):
		s.moon_mission_progress += delta_years
		if s.moon_mission_progress >= s.moon_mission_duration:
			s.moon_mission_active = false
			s.milestone_flags["moon_landing"] = true
			result.add_event("moon_landing", "Humanity has landed on the Moon. A new era begins.", EventSystem.Priority.CRITICAL, "MILESTONE")


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
	# Legacy additive bonuses (existing tech tree payloads)
	if modifiers.has("research_rate_bonus"):
		s.research_rate_bonus += float(modifiers["research_rate_bonus"])
	if modifiers.has("construction_speed_bonus"):
		s.construction_speed_bonus += float(modifiers["construction_speed_bonus"])
	# Resource multipliers — new-style payloads tag a resource and supply a factor > 1.0
	# e.g. "mult_energy": 1.15 increases Energy production rate by 15%
	if modifiers.has("mult_energy"):
		s.mult_energy *= float(modifiers["mult_energy"])
	if modifiers.has("mult_consumables"):
		s.mult_consumables *= float(modifiers["mult_consumables"])
	if modifiers.has("mult_knowledge"):
		s.mult_knowledge *= float(modifiers["mult_knowledge"])
	if modifiers.has("mult_materials"):
		s.mult_materials *= float(modifiers["mult_materials"])


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
			f.dissatisfied_years += delta_years
		else:
			f.dissatisfied_years = 0.0

		if f.dissatisfied_years >= float(CRISIS_YEARS):
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


# ── Resource helpers ──────────────────────────────────────────────────────────

# Budget allocation % → production factor. Soft diminishing returns with floor.
#   0%   → 0.10  (civilization has momentum even with no investment)
#   25%  → ~0.46
#   50%  → ~0.68
#   100% → 1.00
func _budget_factor(pct: float) -> float:
	const FLOOR := 0.10
	const CURVE := 0.65
	return FLOOR + (1.0 - FLOOR) * pow(clampf(pct, 0.0, 100.0) / 100.0, CURVE)


func _check_gsa_preconditions(s: SimulationState, result: TickResult) -> void:
	if s.milestone_flags.get("gsa_founded", false):
		return

	# GSA auto-founds when 3+ factions satisfied AND expanded station is built
	var satisfied_count: int = 0
	for f: Faction in s.factions:
		if f.satisfaction >= 50.0:
			satisfied_count += 1

	if satisfied_count >= 3 and "expanded_station" in s.completed_research:
		s.milestone_flags["gsa_founded"] = true
		s.research_rate_bonus += 0.3   # same bonus previously in unlock_payload
		result.events.append({
			"id": "gsa_founded",
			"message": "The Global Space Agency is founded. Humanity speaks with one voice.",
			"priority": EventSystem.Priority.CRITICAL,
			"year": s.year,
			"category": "GSA",
		})
