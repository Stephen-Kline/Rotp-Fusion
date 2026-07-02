class_name Governor
extends RefCounted

# Stateless coordinator. Delegates all logic to domain subsystems.
# Takes SimulationState + input, returns new SimulationState + events.

var _economy   := EconomySystem.new()
var _research  := ResearchSystem.new()
var _ships     := ShipSystem.new()
var _colony    := ColonySystem.new()
var _factions  := FactionSystem.new()
var _transport := TransportSystem.new()


func apply_actions(state: SimulationState, actions: Array) -> SimulationState:
	if actions.is_empty():
		return state
	var next := state.duplicate(true) as SimulationState
	for action: PlayerAction in actions:
		if _economy.apply(next, action):  continue
		if _research.apply(next, action): continue
		if _ships.apply(next, action):    continue
		if _colony.apply(next, action):   continue
		_factions.apply(next, action)
	return next


func tick(state: SimulationState, delta_days: float) -> TickResult:
	var next := state.duplicate(true) as SimulationState
	next.elapsed_days = state.elapsed_days + delta_days
	var result := TickResult.new(next)
	var delta_years := delta_days / 365.25
	_factions.tick(next, delta_years, result)   # passive bonuses written first
	_economy.tick(next, delta_years, result)    # reads faction bonuses from previous tick
	_research.tick(next, delta_years, result)
	_ships.tick(next, delta_years, result)
	_colony.tick(next, delta_years, result)
	_transport.tick(next, delta_years, result)  # runs after stockpiles are updated
	return result
