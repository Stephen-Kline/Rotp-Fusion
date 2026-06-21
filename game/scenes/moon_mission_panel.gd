class_name MoonMissionPanel
extends PanelContainer

signal mission_launch_requested

# State labels
@onready var _prereq_label: Label = $VBox/PrereqLabel
@onready var _vehicle_check: RichTextLabel = $VBox/VehicleCheck
@onready var _probe_check: RichTextLabel = $VBox/ProbeCheck
@onready var _gsa_check: RichTextLabel = $VBox/GsaCheck
@onready var _launch_btn: Button = $VBox/LaunchBtn
@onready var _progress_bar: ProgressBar = $VBox/ProgressBar
@onready var _progress_label: Label = $VBox/ProgressLabel
@onready var _complete_label: Label = $VBox/CompleteLabel


func _ready() -> void:
	_launch_btn.pressed.connect(_on_launch_pressed)


func refresh(state: SimulationState) -> void:
	var has_vehicle: bool = "crewed_lunar_vehicle" in state.completed_research
	var has_probe: bool = state.milestone_flags.get("lunar_probe_complete", false)
	var has_gsa: bool = state.milestone_flags.get("gsa_founded", false)
	var is_active: bool = state.moon_mission_active
	var is_complete: bool = state.milestone_flags.get("moon_landing", false)

	_vehicle_check.text = ("[color=green]☑[/color] Crewed Lunar Vehicle researched"
		if has_vehicle else "[color=gray]☐ Crewed Lunar Vehicle researched[/color]")
	_probe_check.text = ("[color=green]☑[/color] Lunar Probe data received"
		if has_probe else "[color=gray]☐ Lunar Probe data received[/color]")
	_gsa_check.text = ("[color=green]☑[/color] GSA Founded"
		if has_gsa else "[color=gray]☐ GSA Founded[/color]")

	if is_complete:
		# State 4: Complete
		_prereq_label.hide()
		_vehicle_check.hide()
		_probe_check.hide()
		_gsa_check.hide()
		_launch_btn.hide()
		_progress_bar.hide()
		_progress_label.hide()
		_complete_label.show()
		_complete_label.text = "Humanity has reached the Moon. ✓ Milestone 1 Complete"
	elif is_active:
		# State 3: Mission in progress
		_prereq_label.hide()
		_vehicle_check.hide()
		_probe_check.hide()
		_gsa_check.hide()
		_launch_btn.hide()
		_progress_bar.show()
		_progress_label.show()
		_complete_label.hide()
		var duration := state.moon_mission_duration
		var progress := state.moon_mission_progress
		_progress_bar.max_value = duration if duration > 0.0 else 1.0
		_progress_bar.value = progress
		var year_of := int(progress) + 1
		var year_total := int(duration) + 1
		_progress_label.text = "Mission in progress — Year %d of %d" % [year_of, year_total]
	elif has_vehicle and has_probe and has_gsa:
		# State 2: Ready to launch
		_prereq_label.show()
		_prereq_label.text = "All prerequisites met:"
		_vehicle_check.show()
		_probe_check.show()
		_gsa_check.show()
		_launch_btn.show()
		_progress_bar.hide()
		_progress_label.hide()
		_complete_label.hide()
	else:
		# State 1: Prerequisites not met
		_prereq_label.show()
		_prereq_label.text = "Moon landing requires: Crewed Lunar Vehicle + Lunar Probe data + GSA"
		_vehicle_check.show()
		_probe_check.show()
		_gsa_check.show()
		_launch_btn.hide()
		_progress_bar.hide()
		_progress_label.hide()
		_complete_label.hide()


func _on_launch_pressed() -> void:
	mission_launch_requested.emit()
