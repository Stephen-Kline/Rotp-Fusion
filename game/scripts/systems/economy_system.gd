class_name EconomySystem
extends RefCounted

const BASE_ENERGY_RATE      := 2e20  # J/yr
const BASE_CONSUMABLES_RATE := 4e15  # kcal/yr
const BASE_KNOWLEDGE_RATE   := 2e9   # bits/yr
const BASE_MATERIALS_RATE   := 2e10  # tonnes/yr
const CRITICAL_FLOOR        := 0.15
const ENERGY_LOW_THRESHOLD  := 0.3


func tick(s: SimulationState, delta_years: float, _result: TickResult) -> void:
	var bf_e := ResourceHelpers.budget_factor(s.pillar_energy)
	var bf_c := ResourceHelpers.budget_factor(s.pillar_food)
	var bf_k := ResourceHelpers.budget_factor(s.pillar_education)
	var bf_m := ResourceHelpers.budget_factor(s.pillar_industry)

	var base_e := BASE_ENERGY_RATE      * bf_e
	var base_c := BASE_CONSUMABLES_RATE * bf_c
	var base_k := BASE_KNOWLEDGE_RATE   * bf_k
	var base_m := BASE_MATERIALS_RATE   * bf_m

	var cons_critical  := BASE_CONSUMABLES_RATE * CRITICAL_FLOOR
	var energy_critical := BASE_ENERGY_RATE     * CRITICAL_FLOOR
	var cons_mult   := clampf(base_c / cons_critical,   0.50, 1.0)
	var energy_mult := clampf(base_e / energy_critical, 0.70, 1.0)

	# Colony[0] = Earth; global multipliers applied per-colony here until ColonySystem matures
	s.energy_rate      = (base_e + s.struct_energy)      * s.mult_energy      * cons_mult
	s.consumables_rate = (base_c + s.struct_consumables) * s.mult_consumables
	s.knowledge_rate   = (base_k + s.struct_knowledge)   * s.mult_knowledge   * cons_mult * energy_mult
	s.materials_rate   = (base_m + s.struct_materials)   * s.mult_materials   * cons_mult * energy_mult

	s.energy_stockpile      += s.energy_rate      * delta_years
	s.consumables_stockpile += s.consumables_rate * delta_years
	s.knowledge_stockpile   += s.knowledge_rate   * delta_years
	s.materials_stockpile   += s.materials_rate   * delta_years

	s.energy_capacity = clampf(s.energy_rate / BASE_ENERGY_RATE, 0.0, 1.0)
	s.research_rate = (s.knowledge_rate / BASE_KNOWLEDGE_RATE) * 5.0 + s.research_rate_bonus
	s.construction_speed = clampf(
		s.materials_rate / BASE_MATERIALS_RATE + s.construction_speed_bonus, 0.1, 5.0)

	var pop_target := s.consumables_rate / 7.3e11
	s.population_units = lerpf(s.population_units, pop_target, 0.1 * delta_years)

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
