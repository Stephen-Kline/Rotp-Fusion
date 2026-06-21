extends PanelContainer

# Faction panel — reads SimulationState; sends PlayerAction for spend capital.
# Never writes to SimulationState directly.

signal spend_capital_requested(faction_id: String, amount: float)

@onready var _capital_label: Label = $MarginContainer/VBox/CapitalRow/Value
@onready var _faction_list: VBoxContainer = $MarginContainer/VBox/FactionList

# Sub-panel for spending capital
@onready var _spend_panel: PanelContainer = $MarginContainer/VBox/SpendPanel
@onready var _spend_faction_label: Label = $MarginContainer/VBox/SpendPanel/VBox/FactionName
@onready var _spend_btn_10: Button = $MarginContainer/VBox/SpendPanel/VBox/Amounts/Btn10
@onready var _spend_btn_20: Button = $MarginContainer/VBox/SpendPanel/VBox/Amounts/Btn20
@onready var _spend_btn_50: Button = $MarginContainer/VBox/SpendPanel/VBox/Amounts/Btn50
@onready var _spend_cancel: Button = $MarginContainer/VBox/SpendPanel/VBox/CancelBtn

# Dynamically created per-faction rows — keyed by faction id
var _faction_rows: Dictionary = {}  # faction_id -> {sat_bar, sat_label, trend_label, btn}
var _active_faction_id: String = ""


func _ready() -> void:
	_spend_panel.hide()
	_spend_btn_10.pressed.connect(_on_spend.bind(10.0))
	_spend_btn_20.pressed.connect(_on_spend.bind(20.0))
	_spend_btn_50.pressed.connect(_on_spend.bind(50.0))
	_spend_cancel.pressed.connect(func(): _spend_panel.hide())


func refresh(state: SimulationState) -> void:
	_capital_label.text = "%.1f / 500" % state.political_capital

	# Build rows on first call
	if _faction_rows.is_empty() and state.factions.size() > 0:
		_build_faction_rows(state.factions)

	# Update each row
	for f: Faction in state.factions:
		if not _faction_rows.has(f.id):
			continue
		var row: Dictionary = _faction_rows[f.id]

		# Satisfaction bar fill (0–100 → 0.0–1.0)
		var bar: ProgressBar = row["sat_bar"]
		bar.value = f.satisfaction

		# Color the bar
		var color: Color
		if f.satisfaction > 60.0:
			color = Color(0.2, 0.8, 0.2)   # green
		elif f.satisfaction >= 30.0:
			color = Color(0.9, 0.8, 0.1)   # yellow
		else:
			color = Color(0.9, 0.2, 0.2)   # red
		bar.modulate = color

		# Satisfaction label
		var sat_lbl: Label = row["sat_label"]
		sat_lbl.text = "%.0f" % f.satisfaction

		# Trend arrow
		var trend_lbl: Label = row["trend_label"]
		match f.trend():
			1:  trend_lbl.text = "↑"
			-1: trend_lbl.text = "↓"
			_:  trend_lbl.text = "→"


func _build_faction_rows(factions: Array) -> void:
	# Clear placeholder children if any
	for child in _faction_list.get_children():
		child.queue_free()

	for f: Faction in factions:
		var row_container := VBoxContainer.new()
		row_container.name = "Row_" + f.id
		_faction_list.add_child(row_container)

		# Top line: name + ideological type badge + trend + sat value
		var top_row := HBoxContainer.new()
		row_container.add_child(top_row)

		var name_lbl := Label.new()
		name_lbl.text = f.display_name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		top_row.add_child(name_lbl)

		var badge := Label.new()
		badge.text = "[%s]" % f.ideological_type
		badge.add_theme_font_size_override("font_size", 10)
		badge.modulate = Color(0.7, 0.85, 1.0)
		top_row.add_child(badge)

		var trend_lbl := Label.new()
		trend_lbl.text = "→"
		trend_lbl.add_theme_font_size_override("font_size", 12)
		trend_lbl.custom_minimum_size = Vector2(18, 0)
		top_row.add_child(trend_lbl)

		var sat_lbl := Label.new()
		sat_lbl.text = "50"
		sat_lbl.add_theme_font_size_override("font_size", 12)
		sat_lbl.custom_minimum_size = Vector2(30, 0)
		top_row.add_child(sat_lbl)

		# Bottom line: progress bar + spend button
		var bottom_row := HBoxContainer.new()
		row_container.add_child(bottom_row)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = f.satisfaction
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		bottom_row.add_child(bar)

		var spend_btn := Button.new()
		spend_btn.text = "Spend"
		spend_btn.add_theme_font_size_override("font_size", 11)
		spend_btn.pressed.connect(_on_spend_btn_pressed.bind(f.id, f.display_name))
		bottom_row.add_child(spend_btn)

		# Separator
		var sep := HSeparator.new()
		row_container.add_child(sep)

		_faction_rows[f.id] = {
			"sat_bar": bar,
			"sat_label": sat_lbl,
			"trend_label": trend_lbl,
		}


func _on_spend_btn_pressed(faction_id: String, display_name: String) -> void:
	_active_faction_id = faction_id
	_spend_faction_label.text = display_name
	_spend_panel.show()


func _on_spend(amount: float) -> void:
	if _active_faction_id.is_empty():
		return
	spend_capital_requested.emit(_active_faction_id, amount)
	_spend_panel.hide()
