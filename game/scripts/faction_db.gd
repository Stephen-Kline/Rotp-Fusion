class_name FactionDB
extends RefCounted

var _entries: Array[Dictionary] = []


func _init() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/factions.json", FileAccess.READ)
	if not file:
		push_error("FactionDB: could not open factions.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("FactionDB: JSON parse error: %s" % json.get_error_message())
		return
	for entry: Dictionary in json.data:
		_entries.append(entry)


func create_all() -> Array[Faction]:
	var result: Array[Faction] = []
	for e: Dictionary in _entries:
		result.append(Faction.new(
			str(e.get("id", "")),
			str(e.get("display_name", "")),
			str(e.get("ideological_type", "")),
			str(e.get("preferred_pillar", "")),
			float(e.get("starting_satisfaction", 50.0)),
			float(e.get("weight", 0.0))
		))
	return result


func get_description(faction_id: String) -> String:
	for e: Dictionary in _entries:
		if str(e.get("id", "")) == faction_id:
			return str(e.get("description", ""))
	return ""
