class_name ColonyState
extends Resource

# Per-colony simulation data. SimulationState holds Array[ColonyState]; Earth is index 0.

@export var body_id: String = "Earth"

@export var population_units: float = 30.0

# Local resource stockpiles — energy/consumables/materials are per-colony physical quantities.
# Knowledge is civilisation-wide and lives on SimulationState directly.
@export var energy_stockpile:      float = 0.0
@export var consumables_stockpile: float = 0.0
@export var materials_stockpile:   float = 0.0

# Local production rates (units / game-year), recomputed each tick by EconomySystem.
# Home colony (colonies[0]) gets pillar-driven base + structures; others are structure-driven only.
@export var energy_rate:      float = 0.0
@export var consumables_rate: float = 0.0
@export var materials_rate:   float = 0.0

# Per-body resource multipliers loaded from body_catalog at colony creation.
# e.g. {"materials": 1.5, "energy": 0.8}
@export var resource_bonus: Dictionary = {}

# Structure flat-rate contributions (units/year), summed from built structures
@export var struct_energy:      float = 0.0
@export var struct_consumables: float = 0.0
@export var struct_knowledge:   float = 0.0
@export var struct_materials:   float = 0.0

# Structure type IDs built at this colony
@export var structures: Array[String] = []

# Parallel to structures — true if the structure is currently powered and online
@export var online_flags: Array[bool] = []

# Environment health bar: 0 (collapse) – 100 (pristine)
@export var environment: float = 85.0

# Net environment change per year (natural recovery + structure deltas), display only
@export var env_rate: float = 0.0

# Yield multiplier derived from environment tier, applied by EconomySystem each tick
@export var env_yield_mult: float = 1.0
