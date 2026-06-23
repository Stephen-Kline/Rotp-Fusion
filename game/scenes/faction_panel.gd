extends PanelContainer

signal spend_capital_requested(faction_id: String, amount: float)

@onready var _capital_label: Label = $MarginContainer/VBox/CapitalRow/Value
@onready var _faction_list:  VBoxContainer = $MarginContainer/VBox/FactionList
@onready var _spend_panel:   PanelContainer = $MarginContainer/VBox/SpendPanel
@onready var _spend_faction_label: Label = $MarginContainer/VBox/SpendPanel/VBox/FactionName
@onready var _spend_btn_10:  Button = $MarginContainer/VBox/SpendPanel/VBox/Amounts/Btn10
@onready var _spend_btn_20:  Button = $MarginContainer/VBox/SpendPanel/VBox/Amounts/Btn20
@onready var _spend_btn_50:  Button = $MarginContainer/VBox/SpendPanel/VBox/Amounts/Btn50
@onready var _spend_cancel:  Button = $MarginContainer/VBox/SpendPanel/VBox/CancelBtn

# faction_id -> {face: FactionFace, trend: Label}
var _faction_rows: Dictionary = {}
var _active_faction_id: String = ""

const FactionFace = preload("res://scenes/faction_face.gd")


func _ready() -> void:
	_spend_panel.hide()
	_spend_btn_10.pressed.connect(_on_spend.bind(10.0))
	_spend_btn_20.pressed.connect(_on_spend.bind(20.0))
	_spend_btn_50.pressed.connect(_on_spend.bind(50.0))
	_spend_cancel.pressed.connect(func(): _spend_panel.hide())


func refresh(state: SimulationState) -> void:
	_capital_label.text = "%.0f / 500" % state.political_capital

	if _faction_rows.is_empty() and state.factions.size() > 0:
		_build_faction_rows(state.factions)

	for f: Faction in state.factions:
		if not _faction_rows.has(f.id):
			continue
		var row: Dictionary = _faction_rows[f.id]
		(row["face"] as Control).set_satisfaction(f.satisfaction)

		var trend_lbl: Label = row["trend"]
		match f.trend():
			1:  trend_lbl.text = "↑"; trend_lbl.modulate = Color(0.3, 0.9, 0.3)
			-1: trend_lbl.text = "↓"; trend_lbl.modulate = Color(0.9, 0.3, 0.3)
			_:  trend_lbl.text = "→"; trend_lbl.modulate = Color(0.7, 0.7, 0.7)


func _build_faction_rows(factions: Array) -> void:
	for child in _faction_list.get_children():
		child.queue_free()

	for f: Faction in factions:
		# One row: [face] [name / badge] [trend] [spend btn]
		var row := HBoxContainer.new()
		row.name = "Row_" + f.id
		_faction_list.add_child(row)

		var face := FactionFace.new()
		face.set_satisfaction(f.satisfaction)
		row.add_child(face)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var name_lbl := Label.new()
		name_lbl.text = f.display_name
		name_lbl.add_theme_font_size_override("font_size", 12)
		info.add_child(name_lbl)

		var badge := Label.new()
		badge.text = f.ideological_type
		badge.add_theme_font_size_override("font_size", 10)
		badge.modulate = Color(0.65, 0.80, 1.0)
		info.add_child(badge)

		var trend_lbl := Label.new()
		trend_lbl.text = "→"
		trend_lbl.add_theme_font_size_override("font_size", 13)
		trend_lbl.custom_minimum_size = Vector2(18, 0)
		row.add_child(trend_lbl)

		var spend_btn := Button.new()
		spend_btn.text = "+"
		spend_btn.add_theme_font_size_override("font_size", 13)
		spend_btn.custom_minimum_size = Vector2(28, 0)
		spend_btn.pressed.connect(_on_spend_btn_pressed.bind(f.id, f.display_name))
		row.add_child(spend_btn)

		_faction_list.add_child(HSeparator.new())

		_faction_rows[f.id] = {"face": face, "trend": trend_lbl}


func _on_spend_btn_pressed(faction_id: String, display_name: String) -> void:
	_active_faction_id = faction_id
	_spend_faction_label.text = display_name
	_spend_panel.show()


func _on_spend(amount: float) -> void:
	if _active_faction_id.is_empty():
		return
	spend_capital_requested.emit(_active_faction_id, amount)
	_spend_panel.hide()
