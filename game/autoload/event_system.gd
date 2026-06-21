extends Node

# Routes typed events from the Governor to the notification queue and event log.
# UI nodes connect to these signals on ready — they never write to SimulationState.

enum Priority { LOW, HIGH, CRITICAL }

signal event_logged(entry: EventEntry)
signal notification_requested(entry: EventEntry)
signal time_pause_requested()

var _log: Array[EventEntry] = []
var pause_threshold: int = Priority.HIGH          # events at or above this trigger auto-pause
var compression_threshold: int = 2               # above this compression level, NO auto-pause (FAST=2)
var _current_compression: int = 0               # updated by GameLoop each time compression changes


class EventEntry:
	var id: String
	var message: String
	var priority: int
	var year: int
	var category: String

	func _init(p_id: String, p_message: String, p_priority: int, p_year: int, p_category: String = "") -> void:
		id = p_id
		message = p_message
		priority = p_priority
		year = p_year
		category = p_category


func emit_event(id: String, message: String, priority: int, year: int, category: String = "") -> void:
	var entry := EventEntry.new(id, message, priority, year, category)
	_log.append(entry)
	event_logged.emit(entry)

	# Dual threshold: auto-pause ONLY IF priority >= pause_threshold AND
	# current compression level is at or below compression_threshold
	if priority >= pause_threshold:
		notification_requested.emit(entry)
		if _current_compression <= compression_threshold:
			time_pause_requested.emit()


func set_pause_threshold(level: int) -> void:
	pause_threshold = level


func set_compression_threshold(compression_level: int) -> void:
	compression_threshold = compression_level


func update_compression(compression_level: int) -> void:
	_current_compression = compression_level


func get_log() -> Array[EventEntry]:
	return _log
