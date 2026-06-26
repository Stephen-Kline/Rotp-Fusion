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

var _current_level: int = Constants.CompressionLevel.PAUSED

var _power_val:      Label
var _pop_val:        Label
var _research_val:   Label
var _build_val:      Label
var _year_label:     Label
var _kard_label:     Label
var _speed_btns:     Array[Button]  = []
var _faction_faces:  Array[Control] = []
var _faction_abbrs:  Array[Label]   = []

const FactionFace = preload("res://scenes/faction_face.gd")

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

	_power_val    = _stat(left, "Power")
	_pop_val      = _stat(left, "Pop")
	_research_val = _stat(left, "R&D")
	_build_val    = _stat(left, "Build")

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


func _stat(parent: HBoxContainer, label: String) -> Label:
	var lbl := Label.new()
	lbl.text = label + ": --"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", _CREAM)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	return lbl


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(1, 0)
	return s


# ── Public API ────────────────────────────────────────────────────────────────

func refresh(state: SimulationState) -> void:
	_year_label.text = "%d" % state.year
	_kard_label.text = "K %.2f" % _kardashev(state)

	var low := state.energy_capacity < 0.3
	_power_val.text = "Power: %d%%" % roundi(state.energy_capacity * 100.0)
	_power_val.add_theme_color_override("font_color",
		Color(1.0, 0.28, 0.10) if low else _CREAM)
	_pop_val.text      = "Pop: %.0fM" % state.population_units
	_research_val.text = "R&D: %.1f/yr" % state.research_rate
	_build_val.text    = "Build: %d%%" % roundi(state.construction_speed * 100.0)

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


# ── Kardashev estimate ────────────────────────────────────────────────────────

func _kardashev(state: SimulationState) -> float:
	var milestones := ["suborbital_flight", "orbital_satellite", "crewed_orbit",
		"long_duration_crewed", "modular_station", "expanded_station",
		"gsa_founded", "lunar_transit", "lunar_probe_complete",
		"crewed_lunar_vehicle", "space_telescope", "seti_array"]
	var done := 0
	for m in milestones:
		if state.milestone_flags.get(m, false):
			done += 1
	return 0.70 + 0.30 * (float(done) / float(milestones.size()))
