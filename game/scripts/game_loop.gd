class_name GameLoop
extends Node

signal tick_processed(state: SimulationState)

var speed_index: int = Constants.SPEED_PAUSE
var state: SimulationState
var _governor: Governor
var _pending_actions: Array = []
# Track 30-day milestones for event emission
var _last_month: int = 0


func _ready() -> void:
	state = SimulationState.new()
	_governor = Governor.new()
	EventSystem.update_speed(speed_index)


func queue_action(action: PlayerAction) -> void:
	_pending_actions.append(action)


func _process(delta: float) -> void:
	var dps: float = Constants.DAYS_PER_SECOND[speed_index]

	if dps == 0.0:
		if not _pending_actions.is_empty():
			state = _governor.apply_actions(state, _pending_actions)
			_pending_actions.clear()
			tick_processed.emit(state)
		return

	# Cap at 1/20th of a second of game-time per frame to guard against spiral-of-death.
	var delta_days := minf(delta * dps, dps / 20.0)
	_run_tick(delta_days)


func _run_tick(delta_days: float) -> void:
	if not _pending_actions.is_empty():
		state = _governor.apply_actions(state, _pending_actions)
		_pending_actions.clear()

	var result := _governor.tick(state, delta_days)
	state = result.state

	for event in result.events:
		EventSystem.emit_event(
			event["id"],
			event["message"],
			event["priority"],
			int(state.elapsed_days),
			event.get("category", ""),
			event.get("payload", {})
		)

	tick_processed.emit(state)


func set_speed(index: int) -> void:
	speed_index = clampi(index, Constants.SPEED_PAUSE, Constants.SPEED_1000X)
	EventSystem.update_speed(speed_index)


func pause() -> void:
	set_speed(Constants.SPEED_PAUSE)


func is_paused() -> bool:
	return speed_index == Constants.SPEED_PAUSE
