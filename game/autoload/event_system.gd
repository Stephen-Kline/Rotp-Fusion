extends Node

enum Priority { LOW, MEDIUM, HIGH, CRITICAL }

signal event_logged(entry: EventEntry)
signal notification_requested(entry: EventEntry)
signal time_pause_requested()
signal time_slow_requested()

var _log: Array[EventEntry] = []
var _current_speed_index: int = 0


class EventEntry:
	var id: String
	var message: String
	var priority: int
	var elapsed_day: int
	var category: String
	var payload: Dictionary

	func _init(p_id: String, p_message: String, p_priority: int, p_day: int,
			p_category: String = "", p_payload: Dictionary = {}) -> void:
		id = p_id
		message = p_message
		priority = p_priority
		elapsed_day = p_day
		category = p_category
		payload = p_payload


func emit_event(id: String, message: String, priority: int, elapsed_day: int,
		category: String = "", payload: Dictionary = {}) -> void:
	var entry := EventEntry.new(id, message, priority, elapsed_day, category, payload)
	_log.append(entry)
	event_logged.emit(entry)

	if priority < _pause_threshold_for(_current_speed_index):
		return

	notification_requested.emit(entry)

	if priority >= Priority.CRITICAL:
		time_pause_requested.emit()
	else:
		time_slow_requested.emit()


func _pause_threshold_for(speed_index: int) -> int:
	match speed_index:
		Constants.SPEED_PAUSE, Constants.SPEED_1X:
			return Priority.CRITICAL
		Constants.SPEED_10X:
			return Priority.HIGH
		Constants.SPEED_100X:
			return Priority.MEDIUM
		Constants.SPEED_1000X:
			return Priority.LOW
		_:
			return Priority.CRITICAL


func update_speed(speed_index: int) -> void:
	_current_speed_index = speed_index


func get_log() -> Array[EventEntry]:
	return _log
