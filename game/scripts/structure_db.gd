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


func has(id: String) -> bool:
	return _entries.has(id)
