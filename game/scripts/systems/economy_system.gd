class_name EconomySystem
extends RefCounted

const BASE_ENERGY_RATE      := 2e20  # J/yr
const BASE_CONSUMABLES_RATE := 4e15  # kcal/yr
const BASE_KNOWLEDGE_RATE   := 2e9   # bits/yr
const BASE_MATERIALS_RATE   := 2e10  # tonnes/yr
const CRITICAL_FLOOR        := 0.15
const ENERGY_LOW_THRESHOLD  := 0.3


func tick(s: SimulationState, delta_years: float, _result: TickResult) -> void:
	# Pillar-driven base rates — represent Earth's civilisation-wide economic capacity.
	var bf_e := ResourceHelpers.budget_factor(s.pillar_energy)
	var bf_c := ResourceHelpers.budget_factor(s.pillar_food)
	var bf_k := ResourceHelpers.budget_factor(s.pillar_education)
	var bf_m := ResourceHelpers.budget_factor(s.pillar_industry)

	var home_base_e := BASE_ENERGY_RATE      * bf_e
	var home_base_c := BASE_CONSUMABLES_RATE * bf_c
	var home_base_k := BASE_KNOWLEDGE_RATE   * bf_k
	var home_base_m := BASE_MATERIALS_RATE   * bf_m

	# Global sustainability multipliers (derived from home base, applied everywhere).
	var cons_critical   := BASE_CONSUMABLES_RATE * CRITICAL_FLOOR
	var energy_critical := BASE_ENERGY_RATE      * CRITICAL_FLOOR
	var cons_mult   := clampf(home_base_c / cons_critical,   0.50, 1.0)
	var energy_mult := clampf(home_base_e / energy_critical, 0.70, 1.0)

	var total_knowledge_rate := 0.0

	for i in s.colonies.size():
		var col: ColonyState = s.colonies[i]
		var env_m := col.env_yield_mult
		var rb: Dictionary = col.resource_bonus

		# Only home colony (index 0) gets the pillar-driven base.
		# Off-world colonies are structures + body bonus only.
		var base_e := home_base_e if i == 0 else 0.0
		var base_c := home_base_c if i == 0 else 0.0
		var base_k := home_base_k if i == 0 else 0.0
		var base_m := home_base_m if i == 0 else 0.0

		var body_e := float(rb.get("energy",      1.0))
		var body_c := float(rb.get("consumables", 1.0))
		var body_k := float(rb.get("knowledge",   1.0))
		var body_m := float(rb.get("materials",   1.0))

		col.energy_rate      = (base_e + col.struct_energy)      * s.mult_energy      * cons_mult              * env_m * body_e
		col.consumables_rate = (base_c + col.struct_consumables) * s.mult_consumables                          * env_m * body_c
		col.materials_rate   = (base_m + col.struct_materials)   * s.mult_materials   * cons_mult * energy_mult * env_m * body_m
		var col_k_rate       := (base_k + col.struct_knowledge)  * s.mult_knowledge   * cons_mult * energy_mult * env_m * body_k

		col.energy_stockpile      += col.energy_rate      * delta_years
		col.consumables_stockpile += col.consumables_rate * delta_years
		col.materials_stockpile   += col.materials_rate   * delta_years

		total_knowledge_rate += col_k_rate

		var pop_target := col.consumables_rate / 7.3e11
		col.population_units = lerpf(col.population_units, pop_target, 0.1 * delta_years)

	# Knowledge is civilisation-wide.
	s.knowledge_rate      = total_knowledge_rate
	s.knowledge_stockpile += s.knowledge_rate * delta_years

	# Aggregate metrics for toolbar and Kardashev computation.
	s.energy_capacity    = clampf(s.energy_rate / BASE_ENERGY_RATE, 0.0, 1.0)
	s.research_rate      = (s.knowledge_rate / BASE_KNOWLEDGE_RATE) * 5.0 \
	                       + s.research_rate_bonus + s.faction_research_rate_bonus
	s.construction_speed = clampf(
		s.materials_rate / BASE_MATERIALS_RATE \
		+ s.construction_speed_bonus + s.faction_construction_speed_bonus,
		0.1, 5.0)

	var k_e := ResourceHelpers.k_from_energy(s.energy_rate)
	var k_k := ResourceHelpers.k_from_knowledge(s.knowledge_rate)
	s.kardashev_level = clampf(0.60 * k_e + 0.40 * k_k, 0.0, 3.0)


func apply(s: SimulationState, action: PlayerAction) -> bool:
	if action.type != PlayerAction.Type.SET_PILLAR_ALLOCATION:
		return false
	var p := action.payload
	s.pillar_food      = float(p.get("food",      s.pillar_food))
	s.pillar_education = float(p.get("education", s.pillar_education))
	s.pillar_industry  = float(p.get("industry",  s.pillar_industry))
	s.pillar_energy    = float(p.get("energy",    s.pillar_energy))
	return true
