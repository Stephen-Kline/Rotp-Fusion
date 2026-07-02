class_name SimulationState
extends Resource

# Pure data — no logic. Governor reads this and returns a new instance each tick.
# Duplicate via state.duplicate(true) — Resource deep-copies all @export fields.

# Time (game-days elapsed since T=0)
@export var elapsed_days: float = 0.0

# Derived Kardashev level (recomputed each tick from energy + knowledge rates).
@export var kardashev_level: float = 0.70

# Economic pillars (allocation as percentages, must sum to 100)
@export var pillar_food: float = 25.0
@export var pillar_education: float = 25.0
@export var pillar_industry: float = 25.0
@export var pillar_energy: float = 25.0

# ── Colony hierarchy ──────────────────────────────────────────────────────────
# colonies[0] = Earth always; Moon added when landed; further bodies added on colonization.
@export var colonies: Array[ColonyState] = []

# ── Global research multipliers (civilization-wide from tech tree) ─────────────
@export var mult_energy:      float = 1.0
@export var mult_consumables: float = 1.0
@export var mult_knowledge:   float = 1.0
@export var mult_materials:   float = 1.0

# ── Civilisation-wide knowledge (global, not per-colony) ──────────────────────
@export var knowledge_stockpile: float = 0.0
@export var knowledge_rate:      float = 0.0

# ── Faction passive effect bonuses (recomputed by FactionSystem each tick) ────
@export var faction_research_rate_bonus:       float = 0.0
@export var faction_construction_speed_bonus:  float = 0.0
@export var faction_env_bonus:                 float = 0.0

# ── Aggregated display fields (derived each tick from colony data) ─────────────
@export var energy_capacity: float = 1.0
@export var research_rate: float = 0.0
@export var construction_speed: float = 1.0

# Faction data
@export var factions: Array[Faction] = []
@export var political_capital: float = 0.0
@export var faction_satisfaction: float = 50.0

# Military readiness (placeholder)
@export var military_readiness: float = 0.5

# Expansion frontier (0 = Earth only)
@export var expansion_frontier: int = 0

# Tech tree
@export var completed_research: Array[String] = []
@export var active_research: String = ""
@export var research_progress: float = 0.0
@export var research_queue: Array[String] = []

# Milestone flags
@export var milestone_flags: Dictionary = {}

var milestone_moon_landing: bool:
	get: return milestone_flags.get("moon_landing", false)
var milestone_gsa_founded: bool:
	get: return milestone_flags.get("gsa_founded", false)

@export var available_build_options: Array[String] = []

# Legacy bonus fields — kept until tech tree payloads are migrated to multipliers
@export var research_rate_bonus: float = 0.0
@export var construction_speed_bonus: float = 0.0
# Global env recovery bonus granted by reforestation tech (stub for per-colony system)
@export var env_rate_bonus: float = 0.0

@export var founding_principles: Array[String] = []

@export var ships: Array[Ship] = []
@export var orbital_units: Array[OrbitalUnit] = []

# Active events (Array of Dictionary: event_id, triggered_day, expiry_day, choice_made)
@export var active_events: Array = []

# Transport multiplier — base 1.0, doubled by transport_capacity_upgrade tech
@export var transport_capacity_mult: float = 1.0

# ── Aggregate read-only getters (sum across all colonies) ─────────────────────
# EconomySystem writes to col.* fields directly; these aggregate for UI display.
# ShipSystem and ColonySystem MUST use col.* for deductions (no write path here).

var energy_stockpile: float:
	get:
		var t := 0.0
		for c: ColonyState in colonies: t += c.energy_stockpile
		return t

var consumables_stockpile: float:
	get:
		var t := 0.0
		for c: ColonyState in colonies: t += c.consumables_stockpile
		return t

var materials_stockpile: float:
	get:
		var t := 0.0
		for c: ColonyState in colonies: t += c.materials_stockpile
		return t

var energy_rate: float:
	get:
		var t := 0.0
		for c: ColonyState in colonies: t += c.energy_rate
		return t

var consumables_rate: float:
	get:
		var t := 0.0
		for c: ColonyState in colonies: t += c.consumables_rate
		return t

var materials_rate: float:
	get:
		var t := 0.0
		for c: ColonyState in colonies: t += c.materials_rate
		return t

# Earth-display read (planet_view_3d, toolbar population label)
var population_units: float:
	get: return colonies[0].population_units if not colonies.is_empty() else 0.0

# Read-only compat for fleet_panel and other UI reading state.structures.get("body", [])
var structures: Dictionary:
	get:
		var d: Dictionary = {}
		for c: ColonyState in colonies:
			d[c.body_id.to_lower()] = c.structures
		return d

# ── Derived properties (computed from ships) ──────────────────────────────────

var moon_mission_active: bool:
	get:
		for ship in ships:
			if ship.destination_body == "moon" \
					and ship.role == Ship.Role.MISSION_SPECIFIC \
					and ship.ship_state in [Ship.ShipState.IN_TRANSIT,
					Ship.ShipState.AWAITING_WINDOW]:
				return true
		return false

var moon_mission_progress: float:
	get:
		for ship in ships:
			if ship.destination_body == "moon" \
					and ship.role == Ship.Role.MISSION_SPECIFIC \
					and ship.ship_state == Ship.ShipState.IN_TRANSIT:
				return maxf(0.0, elapsed_days - ship.mission_authorized_day)
		return 0.0

var moon_mission_duration: float:
	get:
		for ship in ships:
			if ship.destination_body == "moon" \
					and ship.role == Ship.Role.MISSION_SPECIFIC \
					and ship.ship_state == Ship.ShipState.IN_TRANSIT:
				return maxf(0.001, ship.arrival_day - ship.mission_authorized_day)
		return 1.0


func _init() -> void:
	colonies = [_make_earth_colony()]
	_init_factions()
	# Basic infrastructure available without research
	available_build_options = ["coal_plant", "industrial_complex", "forest_reserve"]


func _make_earth_colony() -> ColonyState:
	var c := ColonyState.new()
	c.body_id = "Earth"
	c.population_units = 30.0
	c.environment = 85.0
	c.resource_bonus = BodyDB.new().resource_bonus("Earth")
	return c


func _init_factions() -> void:
	factions = FactionDB.new().create_all()


func colony_for(body_id: String) -> ColonyState:
	var key := body_id.to_lower()
	for c: ColonyState in colonies:
		if c.body_id.to_lower() == key:
			return c
	return null


func duplicate_state() -> SimulationState:
	return duplicate(true) as SimulationState
