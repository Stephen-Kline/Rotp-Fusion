class_name BodyDB
extends RefCounted

var _solar: Dictionary = {}   # id -> body Dictionary
var _solar_list: Array = []   # ordered for solar system view
var _stars: Array = []        # nearby stars list


func _init() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/body_catalog.json", FileAccess.READ)
	if not file:
		push_error("BodyDB: could not open body_catalog.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("BodyDB: JSON parse error: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	for body: Dictionary in data.get("solar_bodies", []):
		var id: String = str(body.get("id", ""))
		_solar[id] = body
		_solar_list.append(body)
		for moon: Dictionary in body.get("moons", []):
			var mid: String = str(moon.get("id", ""))
			_solar[mid] = moon.merged({"type": "moon", "parent": id})
	for star: Dictionary in data.get("nearby_stars", []):
		_stars.append(star)


func get_body(id: String) -> Dictionary:
	return _solar.get(id, {})


func has_body(id: String) -> bool:
	return _solar.has(id)


func get_moons(body_id: String) -> Array:
	var body: Dictionary = _solar.get(body_id, {})
	return body.get("moons", [])


func get_solar_bodies() -> Array:
	return _solar_list


func get_planets() -> Array:
	var result: Array = []
	for b: Dictionary in _solar_list:
		var t: String = str(b.get("type", ""))
		if t == "planet" or t == "dwarf_planet":
			result.append(b)
	return result


func get_nearby_stars() -> Array:
	return _stars


func orbital_au(id: String) -> float:
	return float(_solar.get(id, {}).get("orbital_au", 0.0))


func orbital_period_years(id: String) -> float:
	return float(_solar.get(id, {}).get("orbital_period_years", 1.0))


func radius_km(id: String) -> float:
	return float(_solar.get(id, {}).get("radius_km", 0.0))
