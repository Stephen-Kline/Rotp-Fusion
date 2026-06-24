extends PanelContainer
# Single-row top toolbar (~42 px). Builds its own UI in _ready().

signal speed_change_requested(level: int)
signal tech_tree_toggled
signal event_log_toggled

var _current_level: int = Constants.CompressionLevel.PAUSED
var _pre_pause_level: int = Constants.CompressionLevel.SLOW

var _power_val:      Label
var _pop_val:        Label
var _research_val:   Label
var _build_val:      Label
var _year_label:     Label
var _kard_label:     Label
var _pause_btn:      Button
var _speed_btns:    Array[Button]  = []
var _faction_faces: Array[Control] = []
var _faction_abbrs: Array[Label]   = []

const FactionFace = preload("res://scenes/faction_face.gd")

const _LEVELS := [
	Constants.CompressionLevel.SLOW,
	Constants.CompressionLevel.NORMAL,
	Constants.CompressionLevel.FAST,
	Constants.CompressionLevel.FASTER,
	Constants.CompressionLevel.MAX,
]
const _SPEED_LABELS := ["0.2×", "1×", "5×", "20×", "100×"]


func _ready() -> void:
	custom_minimum_size = Vector2(0, 42)

	# [left EXPAND_FILL] | [center natural] | [right EXPAND_FILL]
	# Equal expand on both sides pins center visually in the middle.
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(root)

	# ── LEFT: economy indicators, left-justified ──────────────────────────────
	var lpad := Control.new(); lpad.custom_minimum_size = Vector2(10, 0)
	root.add_child(lpad)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_theme_constant_override("separation", 16)
	root.add_child(left)

	_power_val    = _stat(left, "Power")
	_pop_val      = _stat(left, "Pop")
	_research_val = _stat(left, "R&D")
	_build_val    = _stat(left, "Build")

	root.add_child(_vsep())

	# ── CENTER: Year + K as KPIs, then speed controls ─────────────────────────
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	root.add_child(mid)

	# Year — primary KPI, largest element
	_year_label = Label.new()
	_year_label.text = "1960"
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_year_label.custom_minimum_size  = Vector2(52, 0)
	_year_label.add_theme_font_size_override("font_size", 18)
	mid.add_child(_year_label)

	# Kardashev scale — secondary KPI
	_kard_label = Label.new()
	_kard_label.text = "K 0.70"
	_kard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kard_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_kard_label.custom_minimum_size  = Vector2(52, 0)
	_kard_label.add_theme_font_size_override("font_size", 13)
	_kard_label.modulate = Color(0.70, 0.88, 1.0)
	mid.add_child(_kard_label)

	mid.add_child(_vsep())

	# Pause / Resume toggle
	_pause_btn = Button.new()
	_pause_btn.text = "⏸"
	_pause_btn.flat = true
	_pause_btn.add_theme_font_size_override("font_size", 15)
	_pause_btn.pressed.connect(_on_pause)
	mid.add_child(_pause_btn)

	mid.add_child(_vsep())

	# Discrete speed buttons — active one stays bright, inactive are dimmed
	for i in _SPEED_LABELS.size():
		var btn := Button.new()
		btn.text = _SPEED_LABELS[i]
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 12)
		btn.modulate = Color(0.38, 0.38, 0.42)   # start dimmed; apply_compression lights up active
		var lvl: int = _LEVELS[i]
		btn.pressed.connect(func(): _emit(lvl))
		mid.add_child(btn)
		_speed_btns.append(btn)

	root.add_child(_vsep())

	# ── RIGHT: faction satisfaction + nav buttons, right-justified ────────────
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	root.add_child(right)

	# Per faction: [face][abbrev] side by side
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
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(lbl)
		_faction_abbrs.append(lbl)

	right.add_child(_vsep())

	var tech_btn := Button.new()
	tech_btn.text = "Tech Tree"
	tech_btn.pressed.connect(func(): tech_tree_toggled.emit())
	right.add_child(tech_btn)

	var log_btn := Button.new()
	log_btn.text = "Event Log"
	log_btn.pressed.connect(func(): event_log_toggled.emit())
	right.add_child(log_btn)

	var rpad := Control.new(); rpad.custom_minimum_size = Vector2(10, 0)
	root.add_child(rpad)


func _stat(parent: HBoxContainer, label: String) -> Label:
	var lbl := Label.new()
	lbl.text = label + ": --"
	lbl.add_theme_font_size_override("font_size", 12)
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
	_power_val.text    = "Power: %d%%" % roundi(state.energy_capacity * 100.0)
	_power_val.modulate = Color(1.0, 0.35, 0.35) if low else Color.WHITE
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
	var paused := level == Constants.CompressionLevel.PAUSED
	_pause_btn.text = "▶" if paused else "⏸"
	for i in _speed_btns.size():
		_speed_btns[i].modulate = Color.WHITE if _LEVELS[i] == level else Color(0.38, 0.38, 0.42)


# ── Speed handlers ────────────────────────────────────────────────────────────

func _on_pause() -> void:
	if _current_level == Constants.CompressionLevel.PAUSED:
		_emit(_pre_pause_level)
	else:
		_pre_pause_level = _current_level
		_emit(Constants.CompressionLevel.PAUSED)


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
