class_name GameLoop
extends Node

signal tick_processed(state: SimulationState)

var compression: int = Constants.CompressionLevel.PAUSED
var state: SimulationState
var _governor: Governor
var _pending_actions: Array = []
var _last_decade: int = 0
# Highest speed tier the player has unlocked. Base cap = FASTER (10 yr/s).
var _max_unlocked_level: int = Constants.CompressionLevel.FASTER


func _ready() -> void:
	state = SimulationState.new()
	_governor = Governor.new()
	_last_decade = int(state.year) / 10
	EventSystem.update_compression(compression)


func queue_action(action: PlayerAction) -> void:
	_pending_actions.append(action)


func _process(delta: float) -> void:
	var yps: float = Constants.YEARS_PER_SECOND[compression]

	if yps == 0.0:
		# Still apply pending actions while paused so UI stays live.
		if not _pending_actions.is_empty():
			state = _governor.apply_actions(state, _pending_actions)
			_pending_actions.clear()
			tick_processed.emit(state)
		return

	# Cap: advance at most 1/20th of a second worth of game-time per frame.
	# Guards against spiral-of-death on frame drops without affecting normal play.
	var delta_years := minf(delta * yps, yps / 20.0)
	_run_tick(delta_years)


func _run_tick(delta_years: float) -> void:
	if not _pending_actions.is_empty():
		state = _governor.apply_actions(state, _pending_actions)
		_pending_actions.clear()

	var result := _governor.tick(state, delta_years)
	state = result.state

	for event in result.events:
		EventSystem.emit_event(
			event["id"],
			event["message"],
			event["priority"],
			int(state.year),
			event.get("category", "")
		)

	var current_decade: int = int(state.year) / 10
	if current_decade > _last_decade:
		_last_decade = current_decade
		EventSystem.emit_event(
			"decade_passed",
			"Decade passed: %d" % int(state.year),
			EventSystem.Priority.LOW,
			int(state.year),
			"INFO"
		)

	tick_processed.emit(state)


func set_compression(level: int) -> void:
	if level > _max_unlocked_level:
		return
	compression = level
	EventSystem.update_compression(level)


func unlock_speed(level: int) -> void:
	_max_unlocked_level = maxi(_max_unlocked_level, level)


func can_use_speed(level: int) -> bool:
	return level <= _max_unlocked_level


func pause() -> void:
	compression = Constants.CompressionLevel.PAUSED
	EventSystem.update_compression(Constants.CompressionLevel.PAUSED)


func is_paused() -> bool:
	return compression == Constants.CompressionLevel.PAUSED
