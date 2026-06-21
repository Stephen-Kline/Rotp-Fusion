class_name GameLoop
extends Node

signal tick_processed(state: SimulationState)

var compression: int = Constants.CompressionLevel.SLOW
var state: SimulationState
var _governor: Governor
var _accumulator: float = 0.0  # fractional years accumulated
var _pending_actions: Array = []  # Array[PlayerAction]


func _ready() -> void:
	state = SimulationState.new()
	_governor = Governor.new()


func queue_action(action: PlayerAction) -> void:
	_pending_actions.append(action)


func _process(delta: float) -> void:
	var years_per_second: float = Constants.YEARS_PER_SECOND[compression]
	if years_per_second == 0.0:
		# Still apply pending actions immediately so UI reflects changes even when paused
		if not _pending_actions.is_empty():
			state = _governor.apply_actions(state, _pending_actions)
			_pending_actions.clear()
			tick_processed.emit(state)
		return

	_accumulator += delta * years_per_second

	while _accumulator >= 1.0:
		_accumulator -= 1.0
		_run_tick(1.0)


func _run_tick(delta_years: float) -> void:
	# Apply player actions before computing the tick
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
			event["year"]
		)

	tick_processed.emit(state)


func set_compression(level: int) -> void:
	compression = level


func pause() -> void:
	compression = Constants.CompressionLevel.PAUSED


func is_paused() -> bool:
	return compression == Constants.CompressionLevel.PAUSED
