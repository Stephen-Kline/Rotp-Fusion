extends PanelContainer

# Six vital signs dashboard — reads SimulationState only, never writes.

@onready var _energy_label: Label = $MarginContainer/VBox/EnergyRow/Value
@onready var _population_label: Label = $MarginContainer/VBox/PopulationRow/Value
@onready var _research_label: Label = $MarginContainer/VBox/ResearchRow/Value
@onready var _satisfaction_label: Label = $MarginContainer/VBox/SatisfactionRow/Value
@onready var _military_label: Label = $MarginContainer/VBox/MilitaryRow/Value
@onready var _frontier_label: Label = $MarginContainer/VBox/FrontierRow/Value
@onready var _energy_warning: Label = $MarginContainer/VBox/EnergyWarning


func refresh(state: SimulationState) -> void:
	_energy_label.text = "%.0f%%" % (state.energy_capacity * 100.0)
	_population_label.text = "%.1f" % state.population_units
	_research_label.text = "%.2f edu-yr/yr" % state.research_rate
	_satisfaction_label.text = "%.1f" % state.faction_satisfaction
	_military_label.text = "%.2f" % state.military_readiness
	_frontier_label.text = str(state.expansion_frontier)

	# Energy debuff warning
	var debuffed := state.energy_capacity < 0.3
	_energy_warning.visible = debuffed
	if debuffed:
		_energy_label.modulate = Color(1.0, 0.4, 0.4)
	else:
		_energy_label.modulate = Color(1.0, 1.0, 1.0)
