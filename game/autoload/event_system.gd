extends Node

# Routes typed events from the Governor to the notification queue and event log.
# UI nodes connect to these signals on ready — they never write to SimulationState.

enum Priority { LOW, HIGH, CRITICAL }

signal event_logged(entry: EventEntry)
signal notification_requested(entry: EventEntry)
signal time_pause_requested()

var _log: Array[EventEntry] = []
var pause_threshold: int = Priority.HIGH  # events at or above this auto-pause


class EventEntry:
	var id: String
	var message: String
	var priority: int
	var year: int

	func _init(p_id: String, p_message: String, p_priority: int, p_year: int) -> void:
		id = p_id
		message = p_message
		priority = p_priority
		year = p_year


func emit_event(id: String, message: String, priority: int, year: int) -> void:
	var entry := EventEntry.new(id, message, priority, year)
	_log.append(entry)
	event_logged.emit(entry)

	if priority >= pause_threshold:
		notification_requested.emit(entry)
		time_pause_requested.emit()


func get_log() -> Array[EventEntry]:
	return _log
