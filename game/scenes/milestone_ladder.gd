extends PanelContainer

# Compact vertical list of the 6 LEO milestone steps.
# Each row shows: status icon + step name.
# Status: ☐ locked  ▶ in-progress  ☑ complete

const LEO_STEPS := [
	{"id": "suborbital_flight",    "label": "Suborbital Flight"},
	{"id": "orbital_satellite",    "label": "Orbital Satellite"},
	{"id": "crewed_orbit",         "label": "Crewed Orbit"},
	{"id": "long_duration_crewed", "label": "Long-Duration Crewed"},
	{"id": "modular_station",      "label": "Modular Space Station"},
	{"id": "expanded_station",     "label": "Expanded Space Station"},
]

const ICON_LOCKED      := "☐"
const ICON_IN_PROGRESS := "▶"
const ICON_COMPLETE    := "☑"

@onready var _rows: VBoxContainer = $MarginContainer/VBox/Rows


func refresh(state: SimulationState) -> void:
	var children := _rows.get_children()
	for i in LEO_STEPS.size():
		var step: Dictionary = LEO_STEPS[i]
		var node_id: String = step["id"]
		var icon: String
		if node_id in state.completed_research:
			icon = ICON_COMPLETE
		elif state.active_research == node_id:
			icon = ICON_IN_PROGRESS
		else:
			icon = ICON_LOCKED
		var row: Label = children[i]
		row.text = "%s %s" % [icon, step["label"]]
