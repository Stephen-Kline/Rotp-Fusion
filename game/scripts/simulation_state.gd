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

# Faction satisfaction aggregate (0–100); detailed faction data added in Slice 4
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
	return s
