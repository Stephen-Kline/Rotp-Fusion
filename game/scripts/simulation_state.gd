class_name SimulationState

# Pure data — no logic. Governor reads this and returns a new instance each tick.

# Time
var year: int = 1960

# Economic pillars (allocation as percentages, must sum to 100)
var pillar_food: float = 25.0
var pillar_education: float = 25.0
var pillar_industry: float = 25.0
var pillar_energy: float = 25.0

# Derived economic values (computed by Governor each tick)
var energy_capacity: float = 1.0       # 0.0–1.0 normalized
var population_units: float = 30.0     # abstracted population
var research_rate: float = 0.0         # education-output-years per game-year
var construction_speed: float = 1.0    # industry multiplier

# Faction data (Slice 4)
var factions: Array = []               # Array[Faction]
var political_capital: float = 0.0    # accumulated political capital, capped at 500

# Faction satisfaction aggregate (0–100); average of all faction satisfactions
var faction_satisfaction: float = 50.0

# Military readiness (placeholder)
var military_readiness: float = 0.5

# Expansion frontier (0 = Earth only)
var expansion_frontier: int = 0

# Tech tree: set of completed node ids
var completed_research: Array[String] = []
var active_research: String = ""
var research_progress: float = 0.0  # in education-output-years

# Milestone flags (unified dict replaces individual booleans)
var milestone_flags: Dictionary = {}

# Convenience accessors for common flags
var milestone_moon_landing: bool:
	get: return milestone_flags.get("moon_landing", false)
var milestone_gsa_founded: bool:
	get: return milestone_flags.get("gsa_founded", false)

# Unlocked build options (from tech tree payloads)
var available_build_options: Array[String] = []

# Research rate bonus from tech unlocks (additive multiplier)
var research_rate_bonus: float = 0.0

# Founding principles (list of string tags)
var founding_principles: Array[String] = []

# Moon mission state
var moon_mission_active: bool = false
var moon_mission_progress: float = 0.0   # years elapsed
var moon_mission_duration: float = 0.0   # total years needed (set at launch)


func _init() -> void:
	_init_factions()


func _init_factions() -> void:
	factions = [
		Faction.new("militarist",     "Military-Industrial", "militarist",     "industry",  45.0, 0.20),
		Faction.new("expansionist",   "Expansionist",        "expansionist",   "industry",  55.0, 0.18),
		Faction.new("technocrat",     "Technocrats",         "technocrat",     "education", 50.0, 0.22),
		Faction.new("cooperativist",  "Cooperativists",      "cooperativist",  "food",      60.0, 0.15),
		Faction.new("traditionalist", "Traditionalists",     "traditionalist", "food",      65.0, 0.12),
		Faction.new("isolationist",   "Isolationists",       "isolationist",   "energy",    40.0, 0.13),
	]


func duplicate_state() -> SimulationState:
	var s := SimulationState.new()
	s.year = year
	s.pillar_food = pillar_food
	s.pillar_education = pillar_education
	s.pillar_industry = pillar_industry
	s.pillar_energy = pillar_energy
	s.energy_capacity = energy_capacity
	s.population_units = population_units
	s.research_rate = research_rate
	s.construction_speed = construction_speed
	# Deep-copy factions
	s.factions = []
	for f in factions:
		s.factions.append(f.duplicate())
	s.political_capital = political_capital
	s.faction_satisfaction = faction_satisfaction
	s.military_readiness = military_readiness
	s.expansion_frontier = expansion_frontier
	s.completed_research = completed_research.duplicate()
	s.active_research = active_research
	s.research_progress = research_progress
	s.milestone_flags = milestone_flags.duplicate()
	s.available_build_options = available_build_options.duplicate()
	s.research_rate_bonus = research_rate_bonus
	s.founding_principles = founding_principles.duplicate()
	s.moon_mission_active = moon_mission_active
	s.moon_mission_progress = moon_mission_progress
	s.moon_mission_duration = moon_mission_duration
	return s
