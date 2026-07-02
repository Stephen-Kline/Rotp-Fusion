class_name ShipDB
extends RefCounted

var _entries: Dictionary = {}  # id -> Dictionary


func _init() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/ships.json", FileAccess.READ)
	if not file:
		push_error("ShipDB: could not open ships.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ShipDB: JSON parse error: %s" % json.get_error_message())
		return
	for entry: Dictionary in json.data:
		_entries[str(entry.get("id", ""))] = entry


func get_cost(id: String) -> Dictionary:
	var e: Dictionary = _entries.get(id, {})
	return {
		"materials":  float(e.get("materials",  0.0)),
		"energy":     float(e.get("energy",     0.0)),
		"build_days": float(e.get("build_days", 365.0)),
	}


func get_display_name(id: String) -> String:
	return str(_entries.get(id, {}).get("display_name", id.replace("_", " ").capitalize()))


func get_role(id: String) -> int:
	var role_str: String = str(_entries.get(id, {}).get("role", "probe"))
	match role_str:
		"mission_specific":  return Ship.Role.MISSION_SPECIFIC
		"transport":         return Ship.Role.TRANSPORT_CARGO
		"transport_human":   return Ship.Role.TRANSPORT_HUMAN
		"transport_cargo":   return Ship.Role.TRANSPORT_CARGO
		"military":          return Ship.Role.MILITARY
		"colonizer":         return Ship.Role.COLONIZER
		_:                   return Ship.Role.PROBE


func get_capacity(id: String) -> float:
	return float(_entries.get(id, {}).get("capacity", 0.0))


func get_default_payload(id: String) -> Dictionary:
	return _entries.get(id, {}).get("payload", {}) as Dictionary


func get_description(id: String) -> String:
	return str(_entries.get(id, {}).get("description", ""))


func has(id: String) -> bool:
	return _entries.has(id)
