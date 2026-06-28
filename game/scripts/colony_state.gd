class_name ColonyState
extends Resource

# Per-colony simulation data. SimulationState holds Array[ColonyState]; Earth is index 0.

@export var body_id: String = "Earth"

@export var population_units: float = 30.0

# Resource stockpiles (accumulated over time, spent to unlock milestones)
@export var energy_stockpile:      float = 0.0
@export var consumables_stockpile: float = 0.0
@export var knowledge_stockpile:   float = 0.0
@export var materials_stockpile:   float = 0.0

# Production rates (units / game-year), recomputed each tick by ColonySystem
@export var energy_rate:      float = 0.0
@export var consumables_rate: float = 0.0
@export var knowledge_rate:   float = 0.0
@export var materials_rate:   float = 0.0

# Structure flat-rate contributions (units/year), summed from built structures
@export var struct_energy:      float = 0.0
@export var struct_consumables: float = 0.0
@export var struct_knowledge:   float = 0.0
@export var struct_materials:   float = 0.0

# Structure type IDs built at this colony
@export var structures: Array[String] = []
