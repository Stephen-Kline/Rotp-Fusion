class_name TickResult
extends RefCounted

var state: SimulationState
var events: Array[Dictionary]


func _init(s: SimulationState) -> void:
	state = s
	events = []


func add_event(
	id: String,
	message: String,
	priority: int,
	category: String = "",
	payload: Dictionary = {}
) -> void:
	events.append({
		"id": id,
		"message": message,
		"priority": priority,
		"category": category,
		"payload": payload,
	})
