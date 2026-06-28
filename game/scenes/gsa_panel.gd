extends PanelContainer

# GSA Status Panel — reads SimulationState; emits signal when player wants to establish GSA.
# Never writes to SimulationState directly.

signal gsa_establish_requested

@onready var _status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var _faction_progress_label: Label = $MarginContainer/VBox/FactionProgressLabel
@onready var _establish_btn: Button = $MarginContainer/VBox/EstablishBtn
@onready var _bonus_label: Label = $MarginContainer/VBox/BonusLabel


func _ready() -> void:
	_establish_btn.pressed.connect(_on_establish_pressed)
	_establish_btn.hide()
	_bonus_label.hide()


func refresh(state: SimulationState) -> void:
	var gsa_founded: bool = state.milestone_flags.get("gsa_founded", false)
	var threshold_met: bool = state.milestone_flags.get("faction_threshold_met", false)
	var expanded_done: bool = "expanded_station" in state.completed_research
	var gsa_queued: bool = state.active_research == "global_space_agency"

	# Count factions at >= 50 satisfaction
	var satisfied_count: int = 0
	for f: Faction in state.factions:
		if f.satisfaction >= 50.0:
			satisfied_count += 1

	_faction_progress_label.text = "Factions supporting: %d / 3 needed" % satisfied_count

	if gsa_founded:
		_status_label.text = "GSA Founded"
		_status_label.modulate = UIUtil.COL_SUCCESS
		_establish_btn.hide()
		_bonus_label.text = "Research rate bonus: +30%%"
		_bonus_label.show()
	elif threshold_met and not gsa_queued:
		_status_label.text = "Conditions Met — Establish GSA"
		_status_label.modulate = UIUtil.COL_AMBER
		_establish_btn.show()
		_bonus_label.hide()
	elif threshold_met and gsa_queued:
		_status_label.text = "GSA Founding In Progress..."
		_status_label.modulate = UIUtil.COL_AMBER
		_establish_btn.hide()
		_bonus_label.hide()
	elif expanded_done:
		_status_label.text = "Not Founded (need 3 factions ≥50)"
		_status_label.modulate = UIUtil.COL_MUTED
		_establish_btn.hide()
		_bonus_label.hide()
	else:
		_status_label.text = "Not Founded"
		_status_label.modulate = UIUtil.COL_MUTED
		_establish_btn.hide()
		_bonus_label.hide()


func _on_establish_pressed() -> void:
	gsa_establish_requested.emit()
