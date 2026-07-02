extends Node
# Singleton: tracks current zone, coordinate units, and ring grid parameters.
# Zone transitions are animated by main.gd; this singleton holds the state.

signal zone_changed(new_zone: int)
signal body_changed(body_name: String)
signal local_focus_changed(body_name: String)

# 1-indexed. unit is the display label; rings are zone-appropriate distance markers.
const ZONES := [
	{},  # 0: unused
	{"name": "Earth System",  "unit": "km",  "anchor": "Earth",   "rings": [50000.0, 100000.0, 200000.0, 400000.0]},
	{"name": "Cis-lunar",     "unit": "km",  "anchor": "Earth",   "rings": [200000.0, 500000.0, 1000000.0, 2000000.0]},
	{"name": "Inner Solar",   "unit": "AU",  "anchor": "Sun",     "rings": [0.25, 0.5, 1.0, 2.0, 3.5]},
	{"name": "Mid Solar",     "unit": "AU",  "anchor": "Sun",     "rings": [3.0, 5.0, 8.0, 12.0]},
	{"name": "Outer Solar",   "unit": "AU",  "anchor": "Sun",     "rings": [15.0, 25.0, 40.0, 55.0]},
	{"name": "Near Stars",    "unit": "pc",  "anchor": "Sol",     "rings": [1.0, 2.0, 5.0, 10.0]},
	{"name": "Local Bubble",  "unit": "pc",  "anchor": "Sol",     "rings": [25.0, 50.0, 100.0, 200.0]},
	{"name": "Orion Arm",     "unit": "kpc", "anchor": "Sol",     "rings": [0.5, 1.0, 2.0, 5.0]},
	{"name": "Galactic Disc", "unit": "kpc", "anchor": "GalCore", "rings": [5.0, 10.0, 15.0, 20.0]},
	{"name": "Full Galaxy",   "unit": "kpc", "anchor": "GalCore", "rings": [10.0, 25.0, 50.0, 100.0]},
]

var current_zone: int = 1
var current_body: String = "Earth"   # which body zone-1 local view shows
var local_focus:  String = ""        # focused sub-body within current local view (no rebuild)
var _max_unlocked: int = 10  # All zones unlocked for development


func zone_data() -> Dictionary:
	return ZONES[current_zone]


func transition_to(zone: int) -> void:
	zone = clampi(zone, 1, 10)
	if zone == current_zone or zone > _max_unlocked:
		return
	local_focus  = ""
	current_zone = zone
	zone_changed.emit(zone)


func select_body(name: String) -> void:
	local_focus  = ""
	current_body = name
	body_changed.emit(name)


func focus_local(name: String) -> void:
	local_focus = name
	local_focus_changed.emit(name)


func unlock_up_to(zone: int) -> void:
	_max_unlocked = maxi(_max_unlocked, clampi(zone, 1, 10))
