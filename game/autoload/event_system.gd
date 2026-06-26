extends Node

# Routes typed events from the Governor to the notification queue and event log.
# Auto-pause behavior is speed-aware: faster speeds trip on lower-priority events.

enum Priority { LOW, MEDIUM, HIGH, CRITICAL }

signal event_logged(entry: EventEntry)
signal notification_requested(entry: EventEntry)
signal time_pause_requested()   # CRITICAL events: full stop
signal time_slow_requested()    # HIGH/MEDIUM events: drop to 0.2×, auto-resume

var _log: Array[EventEntry] = []
var _current_compression: int = 0


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

	if priority < _pause_threshold_for(_current_compression):
		return

	notification_requested.emit(entry)

	if priority >= Priority.CRITICAL:
		time_pause_requested.emit()
	else:
		time_slow_requested.emit()


# Returns the minimum event priority that triggers auto-pause at the given speed.
func _pause_threshold_for(compression: int) -> int:
	match compression:
		Constants.CompressionLevel.SLOW, \
		Constants.CompressionLevel.NORMAL:
			return Priority.CRITICAL
		Constants.CompressionLevel.FAST, \
		Constants.CompressionLevel.FASTER:
			return Priority.HIGH
		Constants.CompressionLevel.MAX, \
		Constants.CompressionLevel.KILO:
			return Priority.MEDIUM
		Constants.CompressionLevel.TEN_K, \
		Constants.CompressionLevel.HUNDRED_K:
			return Priority.LOW
		_:  # PAUSED — irrelevant, nothing fires
			return Priority.CRITICAL


func update_compression(compression_level: int) -> void:
	_current_compression = compression_level


func get_log() -> Array[EventEntry]:
	return _log
