class_name ColonySystem
extends RefCounted

# Manages per-colony state. Currently thin (Earth only); will expand in Milestone 2
# to handle per-colony resource production, population dynamics, and infrastructure.

var _struct_db: StructureDB


func _init() -> void:
	_struct_db = StructureDB.new()


func tick(_s: SimulationState, _delta_years: float, _result: TickResult) -> void:
	pass  # per-colony tick logic added in Milestone 2


func apply(s: SimulationState, action: PlayerAction) -> bool:
	if action.type != PlayerAction.Type.BUILD_STRUCTURE:
		return false
	var p := action.payload
	var body: String = p.get("body", "earth")
	var struct_type: String = p.get("structure_type", "")
	if struct_type.is_empty() or struct_type not in s.available_build_options:
		return true
	var cost := _struct_db.get_cost(struct_type)
	var mat_cost: float = cost["materials"]
	var energy_cost: float = cost["energy"]
	if s.materials_stockpile < mat_cost or s.energy_stockpile < energy_cost:
		return true
	s.materials_stockpile -= mat_cost
	s.energy_stockpile -= energy_cost
	var col := s.colony_for(body)
	if col and struct_type not in col.structures:
		col.structures.append(struct_type)
	s.available_build_options.erase(struct_type)
	return true
