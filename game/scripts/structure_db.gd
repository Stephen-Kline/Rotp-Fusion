class_name StructureDB
extends RefCounted

var _entries: Dictionary = {}  # id -> Dictionary


func _init() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/structures.json", FileAccess.READ)
	if not file:
		push_error("StructureDB: could not open structures.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("StructureDB: JSON parse error: %s" % json.get_error_message())
		return
	for entry: Dictionary in json.data:
		_entries[str(entry.get("id", ""))] = entry


func get_cost(id: String) -> Dictionary:
	var e: Dictionary = _entries.get(id, {})
	return {
		"materials": float(e.get("materials", 0.0)),
		"energy":    float(e.get("energy",    0.0)),
	}


func get_display_name(id: String) -> String:
	return str(_entries.get(id, {}).get("display_name", id.replace("_", " ").capitalize()))


func get_struct_bonuses(id: String) -> Dictionary:
	return _entries.get(id, {}).get("struct_bonuses", {}) as Dictionary


func get_description(id: String) -> String:
	return str(_entries.get(id, {}).get("description", ""))


# Returns the orbital altitude above the body surface in km (game-scaled for
# visibility, not real-world), or null if the structure is surface-based.
func get_orbit_km(id: String) -> Variant:
	var e: Dictionary = _entries.get(id, {})
	if not e.has("orbit_km"):
		return null
	return float(e["orbit_km"])


func is_repeatable(id: String) -> bool:
	return bool(_entries.get(id, {}).get("repeatable", false))


func get_env_delta(id: String) -> float:
	return float(_entries.get(id, {}).get("env_delta", 0.0))


func get_energy_op(id: String) -> float:
	return float(_entries.get(id, {}).get("energy_op", 0.0))


func has(id: String) -> bool:
	return _entries.has(id)
