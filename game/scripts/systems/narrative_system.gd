class_name NarrativeSystem
extends RefCounted

# Probabilistic event engine. Each tick:
#   1. Evaluates conditions and rolls probability for each definition.
#   2. Queues triggered events on SimulationState.active_events.
#   3. Resolves expired events via default consequence.
# Player resolves active events by sending RESOLVE_EVENT actions.

var _defs: Dictionary = {}  # event_id -> definition Dictionary


func _init() -> void:
	_load_defs()


func _load_defs() -> void:
	var file := FileAccess.open("res://data/events.json", FileAccess.READ)
	if not file:
		push_error("EventSystem: could not open events.json")
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("EventSystem: JSON parse error: %s" % json.get_error_message())
		return
	for entry: Dictionary in json.data:
		_defs[str(entry.get("id", ""))] = entry


func tick(s: SimulationState, delta_years: float, result: TickResult) -> void:
	_resolve_expired(s, result)
	_roll_new_events(s, delta_years, result)


func apply(s: SimulationState, action: PlayerAction) -> bool:
	if action.type != PlayerAction.Type.RESOLVE_EVENT:
		return false
	var event_id: String = action.payload.get("event_id", "")
	var choice_id: String = action.payload.get("choice_id", "")
	for i in s.active_events.size():
		var inst: Dictionary = s.active_events[i]
		if inst.get("event_id", "") != event_id:
			continue
		if inst.get("choice_made", "") != "":
			break  # already resolved
		var def: Dictionary = _defs.get(event_id, {})
		var consequence := _find_choice_consequence(def, choice_id)
		_apply_cost(s, def, choice_id)
		_apply_consequence(s, consequence)
		inst["choice_made"] = choice_id
		s.active_events[i] = inst
		break
	return true


# ── Internal ──────────────────────────────────────────────────────────────────

func _resolve_expired(s: SimulationState, result: TickResult) -> void:
	var keep: Array = []
	for inst: Dictionary in s.active_events:
		if inst.get("choice_made", "") != "":
			continue  # already resolved — drop it
		var expiry_day: float = float(inst.get("expiry_day", 0.0))
		if expiry_day > 0.0 and s.elapsed_days >= expiry_day:
			var def: Dictionary = _defs.get(str(inst.get("event_id", "")), {})
			_apply_consequence(s, def.get("default_consequence", {}))
			result.add_event(
				"event_expired_%s" % inst.get("event_id", ""),
				"%s: time expired — default consequence applied." \
						% def.get("display_name", inst.get("event_id", "")),
				EventSystem.Priority.HIGH, "events",
				{"event_id": inst.get("event_id", "")}
			)
		else:
			keep.append(inst)
	s.active_events = keep


func _roll_new_events(s: SimulationState, delta_years: float, result: TickResult) -> void:
	var active_ids: Dictionary = {}
	for inst: Dictionary in s.active_events:
		active_ids[inst.get("event_id", "")] = true

	for event_id: String in _defs:
		if active_ids.has(event_id):
			continue
		var def: Dictionary = _defs[event_id]
		if not _conditions_met(s, def):
			continue
		var base_prob: float = float(def.get("base_probability", 0.0))
		var prob := base_prob * delta_years
		if def.get("probability_scales_with_kardashev", false):
			prob *= s.kardashev_level
		if randf() >= prob:
			continue
		var window: float = float(def.get("detection_window_days", 0.0))
		var inst := {
			"event_id":    event_id,
			"triggered_day": s.elapsed_days,
			"expiry_day":  s.elapsed_days + window if window > 0.0 else 0.0,
			"choice_made": "",
		}
		if window <= 0.0:
			# Immediate — apply default consequence and fire notification
			_apply_consequence(s, def.get("default_consequence", {}))
			result.add_event(
				"event_triggered_%s" % event_id,
				"%s struck without warning." % def.get("display_name", event_id),
				EventSystem.Priority.CRITICAL, "events",
				{"event_id": event_id}
			)
		else:
			s.active_events.append(inst)
			result.add_event(
				"event_detected_%s" % event_id,
				"%s detected. %d days to respond." \
						% [def.get("display_name", event_id), int(window)],
				EventSystem.Priority.HIGH, "events",
				{"event_id": event_id, "expiry_day": inst["expiry_day"]}
			)


func _conditions_met(s: SimulationState, def: Dictionary) -> bool:
	var cond: Dictionary = def.get("conditions", {})
	if cond.has("min_elapsed_days") and s.elapsed_days < float(cond["min_elapsed_days"]):
		return false
	if cond.has("max_elapsed_days") and s.elapsed_days > float(cond["max_elapsed_days"]):
		return false
	if cond.has("min_kardashev") and s.kardashev_level < float(cond["min_kardashev"]):
		return false
	if cond.has("max_kardashev") and s.kardashev_level > float(cond["max_kardashev"]):
		return false
	if cond.has("min_colonies") and s.colonies.size() < int(cond["min_colonies"]):
		return false
	if cond.has("max_faction_satisfaction") \
			and s.faction_satisfaction > float(cond["max_faction_satisfaction"]):
		return false
	return true


func _find_choice_consequence(def: Dictionary, choice_id: String) -> Dictionary:
	for choice: Dictionary in def.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return choice.get("consequence", {}) as Dictionary
	return def.get("default_consequence", {}) as Dictionary


func _apply_cost(s: SimulationState, def: Dictionary, choice_id: String) -> void:
	for choice: Dictionary in def.get("choices", []):
		if str(choice.get("id", "")) != choice_id:
			continue
		var cost: Dictionary = choice.get("cost", {}) as Dictionary
		if cost.has("energy") and not s.colonies.is_empty():
			s.colonies[0].energy_stockpile      -= float(cost["energy"])
		if cost.has("materials") and not s.colonies.is_empty():
			s.colonies[0].materials_stockpile   -= float(cost["materials"])
		if cost.has("consumables") and not s.colonies.is_empty():
			s.colonies[0].consumables_stockpile -= float(cost["consumables"])
		if cost.has("political_capital"):
			s.political_capital -= float(cost["political_capital"])
		break


func _apply_consequence(s: SimulationState, cons: Dictionary) -> void:
	if cons.is_empty() or s.colonies.is_empty():
		return
	var home: ColonyState = s.colonies[0]
	if cons.has("env_delta"):
		home.environment = clampf(home.environment + float(cons["env_delta"]), 0.0, 100.0)
	if cons.has("consumables_loss"):
		home.consumables_stockpile -= float(cons["consumables_loss"])
	if cons.has("materials_loss"):
		home.materials_stockpile   -= float(cons["materials_loss"])
	if cons.has("energy_loss"):
		home.energy_stockpile      -= float(cons["energy_loss"])
	if cons.has("faction_satisfaction"):
		s.faction_satisfaction = clampf(
			s.faction_satisfaction + float(cons["faction_satisfaction"]), 0.0, 100.0)
	if cons.has("structures_lost"):
		var n: int = int(cons["structures_lost"])
		for _i in n:
			if home.structures.is_empty():
				break
			var idx := randi() % home.structures.size()
			home.structures.remove_at(idx)
			if idx < home.online_flags.size():
				home.online_flags.remove_at(idx)
