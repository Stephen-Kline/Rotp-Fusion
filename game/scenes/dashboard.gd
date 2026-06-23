extends PanelContainer

@onready var _power_label:    Label = $MarginContainer/VBox/PowerRow/Value
@onready var _pop_label:      Label = $MarginContainer/VBox/PopRow/Value
@onready var _research_label: Label = $MarginContainer/VBox/ResearchRow/Value
@onready var _build_label:    Label = $MarginContainer/VBox/BuildRow/Value
@onready var _power_warning:  Label = $MarginContainer/VBox/PowerWarning


func refresh(state: SimulationState) -> void:
	_power_label.text = "%d%%" % roundi(state.energy_capacity * 100.0)
	_pop_label.text   = "%.0f M" % state.population_units
	_research_label.text = "%.1f pts/yr" % state.research_rate
	_build_label.text = "%d%%" % roundi(state.construction_speed * 100.0)

	var low_power := state.energy_capacity < 0.3
	_power_warning.visible = low_power
	_power_label.modulate = Color(1.0, 0.35, 0.35) if low_power else Color(1.0, 1.0, 1.0)
