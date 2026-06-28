extends PanelContainer

signal speed_change_requested(speed_index: int)
signal tech_tree_toggled
signal event_log_toggled
signal budget_toggled
signal fleet_toggled

const _NAVY   := Color(0.06, 0.10, 0.22)
const _ORANGE := Color(0.92, 0.48, 0.12)
const _CREAM  := Color(0.94, 0.90, 0.80)
const _CYAN   := Color(0.20, 0.82, 0.90)
const _DIM    := Color(0.38, 0.45, 0.58)
const _WARN   := Color(1.00, 0.28, 0.10)

var _current_speed: int = Constants.SPEED_PAUSE

var _energy_rate:  Label
var _energy_stock: Label
var _cons_rate:    Label
var _cons_stock:   Label
var _know_rate:    Label
var _know_stock:   Label
var _matl_rate:    Label
var _matl_stock:   Label

var _time_label:   Label
var _kard_label:   Label
var _pause_btn:    Button
var _play_btn:     Button
var _fast_btn:     Button   # cycles: 1× → 10× → 100× → 1000× → 1×
var _faction_faces: Array[Control] = []
var _faction_abbrs: Array[Label]   = []

# Index within the fast-forward cycle: 1=1× 2=10× 3=100× 4=1000×
var _ff_index: int = Constants.SPEED_1X

const FactionFace = preload("res://scenes/faction_face.gd")
const _RH         = preload("res://scripts/resource_helpers.gd")


func _ready() -> void:
	custom_minimum_size = Vector2(0, 42)

	var bg := StyleBoxFlat.new()
	bg.bg_color = _NAVY
	add_theme_stylebox_override("panel", bg)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(root)

	# ── LEFT: economy indicators ──────────────────────────────────────────────
	var lpad := Control.new(); lpad.custom_minimum_size = Vector2(10, 0)
	root.add_child(lpad)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_theme_constant_override("separation", 16)
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	left.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	left.tooltip_text = "Click to adjust budget allocation"
	left.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and ev.button_index == MOUSE_BUTTON_LEFT:
			budget_toggled.emit()
	)
	root.add_child(left)

	var ep := _stat(left, "Energy"); _energy_rate = ep[0]; _energy_stock = ep[1]
	var cp := _stat(left, "Cons");   _cons_rate   = cp[0]; _cons_stock   = cp[1]
	var kp := _stat(left, "Know");   _know_rate   = kp[0]; _know_stock   = kp[1]
	var mp := _stat(left, "Matl");   _matl_rate   = mp[0]; _matl_stock   = mp[1]

	var caret := Label.new()
	caret.text = " ▾"
	caret.add_theme_font_size_override("font_size", 10)
	caret.add_theme_color_override("font_color", Color(_CREAM.r, _CREAM.g, _CREAM.b, 0.5))
	caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	left.add_child(caret)

	root.add_child(_vsep())

	# ── CENTER: time + K on top, speed controls below ─────────────────────────
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 1)
	root.add_child(mid)

	var kpi_row := HBoxContainer.new()
	kpi_row.alignment = BoxContainer.ALIGNMENT_CENTER
	kpi_row.add_theme_constant_override("separation", 10)
	mid.add_child(kpi_row)

	_time_label = Label.new()
	_time_label.text = "Day 1"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 16)
	_time_label.add_theme_color_override("font_color", _ORANGE)
	kpi_row.add_child(_time_label)

	_kard_label = Label.new()
	_kard_label.text = "K 0.70"
	_kard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kard_label.add_theme_font_size_override("font_size", 12)
	_kard_label.add_theme_color_override("font_color", _CYAN)
	kpi_row.add_child(_kard_label)

	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 4)
	mid.add_child(speed_row)

	_pause_btn = _make_speed_btn("⏸")
	_pause_btn.pressed.connect(_on_pause)
	speed_row.add_child(_pause_btn)

	_play_btn = _make_speed_btn("▶")
	_play_btn.pressed.connect(_on_play)
	speed_row.add_child(_play_btn)

	_fast_btn = _make_speed_btn("⏩ 1×")
	_fast_btn.pressed.connect(_on_fast_forward)
	speed_row.add_child(_fast_btn)

	_update_speed_buttons()

	root.add_child(_vsep())

	# ── RIGHT: faction faces + nav buttons ────────────────────────────────────
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)

	for i in 5:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right.add_child(box)

		var face := FactionFace.new()
		face.custom_minimum_size = Vector2(24, 24)
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(face)
		_faction_faces.append(face)

		var lbl := Label.new()
		lbl.text = "···"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", _CREAM)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(lbl)
		_faction_abbrs.append(lbl)

	right.add_child(_vsep())

	var tech_btn := Button.new()
	tech_btn.text = "Tech Tree"
	tech_btn.flat = true
	tech_btn.add_theme_color_override("font_color", _CREAM)
	tech_btn.pressed.connect(func(): tech_tree_toggled.emit())
	right.add_child(tech_btn)

	var log_btn := Button.new()
	log_btn.text = "Event Log"
	log_btn.flat = true
	log_btn.add_theme_color_override("font_color", _CREAM)
	log_btn.pressed.connect(func(): event_log_toggled.emit())
	right.add_child(log_btn)

	var fleet_btn := Button.new()
	fleet_btn.text = "Fleet"
	fleet_btn.flat = true
	fleet_btn.add_theme_color_override("font_color", _CREAM)
	fleet_btn.pressed.connect(func(): fleet_toggled.emit())
	right.add_child(fleet_btn)

	var rpad := Control.new(); rpad.custom_minimum_size = Vector2(10, 0)
	root.add_child(rpad)


func _stat(parent: HBoxContainer, name: String) -> Array:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	var rate_lbl := Label.new()
	rate_lbl.text = name + ": --"
	rate_lbl.add_theme_font_size_override("font_size", 10)
	rate_lbl.add_theme_color_override("font_color", _DIM)
	col.add_child(rate_lbl)

	var stock_lbl := Label.new()
	stock_lbl.text = "--"
	stock_lbl.add_theme_font_size_override("font_size", 11)
	stock_lbl.add_theme_color_override("font_color", _CREAM)
	col.add_child(stock_lbl)

	return [rate_lbl, stock_lbl]


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(1, 0)
	return s


func _make_speed_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 11)
	return btn


# ── Speed controls ────────────────────────────────────────────────────────────

func _on_pause() -> void:
	_current_speed = Constants.SPEED_PAUSE
	_update_speed_buttons()
	speed_change_requested.emit(Constants.SPEED_PAUSE)


func _on_play() -> void:
	_current_speed = Constants.SPEED_1X
	_ff_index = Constants.SPEED_1X
	_update_speed_buttons()
	speed_change_requested.emit(Constants.SPEED_1X)


func _on_fast_forward() -> void:
	# Cycle: 1× → 10× → 100× → 1000× → wrap to 1×
	if _ff_index >= Constants.SPEED_1000X:
		_ff_index = Constants.SPEED_1X
	else:
		_ff_index += 1
	_current_speed = _ff_index
	_update_speed_buttons()
	speed_change_requested.emit(_current_speed)


func _update_speed_buttons() -> void:
	var paused := _current_speed == Constants.SPEED_PAUSE
	_pause_btn.modulate = _ORANGE if paused else _DIM
	_play_btn.modulate  = _ORANGE if _current_speed == Constants.SPEED_1X else _DIM
	var ff_label := "⏩ %s" % Constants.SPEED_LABELS.get(_ff_index, "1×")
	_fast_btn.text = ff_label
	_fast_btn.modulate = _ORANGE if _current_speed >= Constants.SPEED_10X else _DIM


# ── Public API ────────────────────────────────────────────────────────────────

func refresh(state: SimulationState) -> void:
	_time_label.text = _format_elapsed(state.elapsed_days)
	_kard_label.text = "K %.2f" % state.kardashev_level

	var low_energy := state.energy_capacity < 0.15
	var rate_color := _WARN if low_energy else _DIM

	_energy_rate.text  = "Energy: " + _RH.format_si(state.energy_rate, "J") + "/yr"
	_energy_rate.add_theme_color_override("font_color", rate_color)
	_energy_stock.text = _RH.format_si(state.energy_stockpile, "J")
	_energy_stock.add_theme_color_override("font_color", _WARN if low_energy else _CREAM)

	_cons_rate.text  = "Cons: "   + _RH.format_si(state.consumables_rate,      "cal")  + "/yr"
	_cons_stock.text = _RH.format_si(state.consumables_stockpile, "cal")

	_know_rate.text  = "Know: "   + _RH.format_si(state.knowledge_rate,   "bits") + "/yr"
	_know_stock.text = _RH.format_si(state.knowledge_stockpile, "bits")

	_matl_rate.text  = "Matl: "   + _RH.format_si(state.materials_rate,   "t")    + "/yr"
	_matl_stock.text = _RH.format_si(state.materials_stockpile, "t")

	for i in mini(state.factions.size(), _faction_faces.size()):
		var f: Faction = state.factions[i]
		(_faction_faces[i] as Control).set_satisfaction(f.satisfaction)
		_faction_faces[i].tooltip_text = f.display_name
		_faction_abbrs[i].text = f.display_name.substr(0, 3)


func apply_speed(speed_index: int) -> void:
	_current_speed = speed_index
	if speed_index >= Constants.SPEED_10X:
		_ff_index = speed_index
	_update_speed_buttons()


static func _format_elapsed(days: float) -> String:
	var d := int(days)
	var h := int((days - float(d)) * 24.0)
	if d < 30:
		return "Day %d, %dh" % [d + 1, h]
	if d < 365:
		var month := d / 30 + 1
		return "Month %d" % month
	var year := d / 365
	var m_in_year := (d % 365) / 30 + 1
	return "Year %d, Month %d" % [year, m_in_year]
