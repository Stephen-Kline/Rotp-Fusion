extends PanelContainer
# Single-row top toolbar (~42 px). Builds its own UI in _ready().

signal speed_change_requested(level: int)
signal tech_tree_toggled
signal event_log_toggled
signal budget_toggled

const _NAVY   := Color(0.06, 0.10, 0.22)
const _ORANGE := Color(0.92, 0.48, 0.12)
const _CREAM  := Color(0.94, 0.90, 0.80)
const _CYAN   := Color(0.20, 0.82, 0.90)
const _DIM    := Color(0.38, 0.45, 0.58)
const _WARN   := Color(1.00, 0.28, 0.10)

var _current_level: int = Constants.CompressionLevel.PAUSED

# Each resource: [rate_label, stock_label]
var _energy_rate:  Label
var _energy_stock: Label
var _cons_rate:    Label
var _cons_stock:   Label
var _know_rate:    Label
var _know_stock:   Label
var _matl_rate:    Label
var _matl_stock:   Label

var _year_label:    Label
var _kard_label:    Label
var _speed_btns:    Array[Button]  = []
var _faction_faces: Array[Control] = []
var _faction_abbrs: Array[Label]   = []

const FactionFace = preload("res://scenes/faction_face.gd")
const _RH         = preload("res://scripts/resource_helpers.gd")

const _LEVELS := [
	Constants.CompressionLevel.PAUSED,
	Constants.CompressionLevel.SLOW,
	Constants.CompressionLevel.NORMAL,
	Constants.CompressionLevel.FAST,
	Constants.CompressionLevel.FASTER,
	Constants.CompressionLevel.MAX,
]
const _SPEED_LABELS := ["⏸", "0.2×", "1×", "5×", "20×", "100×"]


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

	# ── LEFT: economy indicators — click to open budget dropdown ─────────────
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

	# ── CENTER: Year + K on top, speed buttons below ──────────────────────────
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 1)
	root.add_child(mid)

	var kpi_row := HBoxContainer.new()
	kpi_row.alignment = BoxContainer.ALIGNMENT_CENTER
	kpi_row.add_theme_constant_override("separation", 10)
	mid.add_child(kpi_row)

	_year_label = Label.new()
	_year_label.text = "1960"
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_label.add_theme_font_size_override("font_size", 16)
	_year_label.add_theme_color_override("font_color", _ORANGE)
	kpi_row.add_child(_year_label)

	_kard_label = Label.new()
	_kard_label.text = "K 0.70"
	_kard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kard_label.add_theme_font_size_override("font_size", 12)
	_kard_label.add_theme_color_override("font_color", _CYAN)
	kpi_row.add_child(_kard_label)

	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 2)
	mid.add_child(speed_row)

	for i in _SPEED_LABELS.size():
		var btn := Button.new()
		btn.text = _SPEED_LABELS[i]
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 11)
		btn.modulate = _DIM
		var lvl: int = _LEVELS[i]
		btn.pressed.connect(func(): _emit(lvl))
		speed_row.add_child(btn)
		_speed_btns.append(btn)

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

	var rpad := Control.new(); rpad.custom_minimum_size = Vector2(10, 0)
	root.add_child(rpad)


# Returns [rate_label, stock_label] stacked in a VBoxContainer column.
# Top row: resource name + rate (small, dim).  Bottom row: stockpile (cream).
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


# ── Public API ────────────────────────────────────────────────────────────────

func refresh(state: SimulationState) -> void:
	_year_label.text = "%d" % state.year

	var k_e := _RH.k_from_energy(state.energy_rate)
	var k_k := _RH.k_from_knowledge(state.knowledge_rate)
	_kard_label.text = "K %.2f" % clampf(0.60 * k_e + 0.40 * k_k, 0.0, 2.0)

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


func apply_compression(level: int) -> void:
	_current_level = level
	for i in _speed_btns.size():
		_speed_btns[i].modulate = _ORANGE if _LEVELS[i] == level else _DIM


# ── Speed handler ─────────────────────────────────────────────────────────────

func _emit(level: int) -> void:
	apply_compression(level)
	speed_change_requested.emit(level)
