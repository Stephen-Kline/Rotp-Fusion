class_name SimulationState

# Pure data — no logic. Governor reads this and returns a new instance each tick.

# Time
var year: int = 1950

# Economic pillars (allocation as percentages, must sum to 100)
var pillar_food: float = 25.0
var pillar_education: float = 25.0
var pillar_industry: float = 25.0
var pillar_energy: float = 25.0

# ── Primary Resources ──────────────────────────────────────────────────────────
# Four resource stockpiles (accumulated over time, spent to unlock milestones).
#   Energy      → joules (J)
#   Consumables → kilocalories (kcal)
#   Knowledge   → bits
#   Materials   → tonnes (t)
var energy_stockpile:      float = 0.0
var consumables_stockpile: float = 0.0
var knowledge_stockpile:   float = 0.0
var materials_stockpile:   float = 0.0

# Production rates (units / game-year).
# Formula: rate = (budget_rate + struct_rate) × research_mult × interaction_factor
var energy_rate:      float = 0.0
var consumables_rate: float = 0.0
var knowledge_rate:   float = 0.0
var materials_rate:   float = 0.0

# Research multipliers — accumulated product of all tech node bonuses per resource.
# Start at 1.0; each relevant tech node multiplies its resource's value.
var mult_energy:      float = 1.0
var mult_consumables: float = 1.0
var mult_knowledge:   float = 1.0
var mult_materials:   float = 1.0

# Structure flat-rate contributions (units/year) — summed from all built structures.
# 0.0 until structures are implemented; slot exists for the engine to use.
var struct_energy:      float = 0.0
var struct_consumables: float = 0.0
var struct_knowledge:   float = 0.0
var struct_materials:   float = 0.0

# ── Legacy display fields (derived from new resource values each tick) ─────────
# Kept for backward compatibility until the UI display layer is updated.
var energy_capacity: float = 1.0       # 0–1 normalized Energy rate
var population_units: float = 30.0     # millions, smoothed from Consumables rate
var research_rate: float = 0.0         # scaled Knowledge rate (for tech progress)
var construction_speed: float = 1.0    # scaled Materials rate (for mission timing)

# Faction data
var factions: Array = []
var political_capital: float = 0.0
var faction_satisfaction: float = 50.0

# Military readiness (placeholder)
var military_readiness: float = 0.5

# Expansion frontier (0 = Earth only)
var expansion_frontier: int = 0

# Tech tree
var completed_research: Array[String] = []
var active_research: String = ""
var research_progress: float = 0.0
var research_queue: Array[String] = []

# Milestone flags
var milestone_flags: Dictionary = {}

var milestone_moon_landing: bool:
	get: return milestone_flags.get("moon_landing", false)
var milestone_gsa_founded: bool:
	get: return milestone_flags.get("gsa_founded", false)

var available_build_options: Array[String] = []

# Legacy bonus fields — kept until tech tree payloads are migrated to multipliers
var research_rate_bonus: float = 0.0
var construction_speed_bonus: float = 0.0

var founding_principles: Array[String] = []

# Moon mission
var moon_mission_active: bool = false
var moon_mission_progress: float = 0.0
var moon_mission_duration: float = 0.0


func _init() -> void:
	_init_factions()


func _init_factions() -> void:
	factions = [
		Faction.new("technocrat",       "Technocrats",       "technocrat",       "education", 55.0, 0.25),
		Faction.new("industrialist",    "Industrialists",    "industrialist",    "industry",  50.0, 0.25),
		Faction.new("environmentalist", "Environmentalists", "environmentalist", "energy",    45.0, 0.20),
		Faction.new("internationalist", "Internationalists", "internationalist", "food",      55.0, 0.15),
		Faction.new("conservative",     "Conservatives",     "conservative",     "food",      62.0, 0.15),
	]


func duplicate_state() -> SimulationState:
	var s := SimulationState.new()
	s.year = year
	s.pillar_food = pillar_food
	s.pillar_education = pillar_education
	s.pillar_industry = pillar_industry
	s.pillar_energy = pillar_energy
	# Resource stockpiles
	s.energy_stockpile      = energy_stockpile
	s.consumables_stockpile = consumables_stockpile
	s.knowledge_stockpile   = knowledge_stockpile
	s.materials_stockpile   = materials_stockpile
	# Rates
	s.energy_rate      = energy_rate
	s.consumables_rate = consumables_rate
	s.knowledge_rate   = knowledge_rate
	s.materials_rate   = materials_rate
	# Multipliers
	s.mult_energy      = mult_energy
	s.mult_consumables = mult_consumables
	s.mult_knowledge   = mult_knowledge
	s.mult_materials   = mult_materials
	# Structure rates
	s.struct_energy      = struct_energy
	s.struct_consumables = struct_consumables
	s.struct_knowledge   = struct_knowledge
	s.struct_materials   = struct_materials
	# Legacy display
	s.energy_capacity     = energy_capacity
	s.population_units    = population_units
	s.research_rate       = research_rate
	s.construction_speed  = construction_speed
	# Factions
	s.factions = []
	for f in factions:
		s.factions.append(f.duplicate())
	s.political_capital      = political_capital
	s.faction_satisfaction   = faction_satisfaction
	s.military_readiness     = military_readiness
	s.expansion_frontier     = expansion_frontier
	s.completed_research     = completed_research.duplicate()
	s.active_research        = active_research
	s.research_progress      = research_progress
	s.research_queue         = research_queue.duplicate()
	s.milestone_flags        = milestone_flags.duplicate()
	s.available_build_options = available_build_options.duplicate()
	s.research_rate_bonus    = research_rate_bonus
	s.construction_speed_bonus = construction_speed_bonus
	s.founding_principles    = founding_principles.duplicate()
	s.moon_mission_active    = moon_mission_active
	s.moon_mission_progress  = moon_mission_progress
	s.moon_mission_duration  = moon_mission_duration
	return s
