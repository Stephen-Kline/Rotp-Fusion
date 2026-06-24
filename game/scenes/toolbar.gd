extends PanelContainer
# Single-row top toolbar. ~40 px tall. Builds its own UI in _ready().

signal speed_change_requested(level: int)
signal tech_tree_toggled
signal event_log_toggled

var _current_level: int = Constants.CompressionLevel.PAUSED
var _pre_pause_level: int = Constants.CompressionLevel.SLOW

var _power_val:    Label
var _pop_val:      Label
var _research_val: Label
var _build_val:    Label
var _year_label:   Label
var _speed_label:  Label
var _pause_btn:    Button
var _kard_label:   Label

const _LEVELS := [
	Constants.CompressionLevel.SLOW,
	Constants.CompressionLevel.NORMAL,
	Constants.CompressionLevel.FAST,
	Constants.CompressionLevel.FASTER,
	Constants.CompressionLevel.MAX,
]
const _SPEED_NAMES: Dictionary = {
	Constants.CompressionLevel.PAUSED:  "Paused",
	Constants.CompressionLevel.SLOW:    "0.2×",
	Constants.CompressionLevel.NORMAL:  "1×",
	Constants.CompressionLevel.FAST:    "5×",
	Constants.CompressionLevel.FASTER:  "20×",
	Constants.CompressionLevel.MAX:     "100×",
}


func _ready() -> void:
	custom_minimum_size = Vector2(0, 42)

	var margin := MarginContainer.new()
	for s in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(s, 5)
	add_child(margin)

	# Three sections, each wrapped in a CenterContainer for vertical centering
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	margin.add_child(root)

	# ── Left status ──────────────────────────────────────────────────────────
	var left_wrap := CenterContainer.new()
	left_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left_wrap)

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left_wrap.add_child(left)

	_power_val    = _stat(left, "Power")
	_pop_val      = _stat(left, "Pop")
	_research_val = _stat(left, "Research")
	_build_val    = _stat(left, "Build")

	root.add_child(_vsep())

	# ── Center: year + speed ─────────────────────────────────────────────────
	var mid_wrap := CenterContainer.new()
	mid_wrap.custom_minimum_size = Vector2(310, 0)
	root.add_child(mid_wrap)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 6)
	mid_wrap.add_child(mid)

	var slow_btn := Button.new()
	slow_btn.text = "◀"
	slow_btn.flat = true
	slow_btn.pressed.connect(_on_slow)
	mid.add_child(slow_btn)

	_year_label = Label.new()
	_year_label.text = "Year 1960"
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_year_label.custom_minimum_size = Vector2(110, 0)
	_year_label.add_theme_font_size_override("font_size", 16)
	mid.add_child(_year_label)

	var fast_btn := Button.new()
	fast_btn.text = "▶"
	fast_btn.flat = true
	fast_btn.pressed.connect(_on_fast)
	mid.add_child(fast_btn)

	mid.add_child(_vsep())

	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Pause"
	_pause_btn.pressed.connect(_on_pause)
	mid.add_child(_pause_btn)

	_speed_label = Label.new()
	_speed_label.text = "Paused"
	_speed_label.add_theme_font_size_override("font_size", 11)
	_speed_label.modulate = Color(0.60, 0.60, 0.68)
	_speed_label.custom_minimum_size = Vector2(40, 0)
	mid.add_child(_speed_label)

	root.add_child(_vsep())

	# ── Right: K-scale + buttons ─────────────────────────────────────────────
	var right_wrap := CenterContainer.new()
	root.add_child(right_wrap)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right_wrap.add_child(right)

	_kard_label = Label.new()
	_kard_label.text = "K 0.70"
	_kard_label.add_theme_font_size_override("font_size", 15)
	_kard_label.modulate = Color(0.75, 0.88, 1.0)
	right.add_child(_kard_label)

	right.add_child(_vsep())

	var tech_btn := Button.new()
	tech_btn.text = "Tech Tree"
	tech_btn.pressed.connect(func(): tech_tree_toggled.emit())
	right.add_child(tech_btn)

	var log_btn := Button.new()
	log_btn.text = "Event Log"
	log_btn.pressed.connect(func(): event_log_toggled.emit())
	right.add_child(log_btn)


func _stat(parent: HBoxContainer, name_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = name_text + ": --"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	return lbl


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.custom_minimum_size = Vector2(1, 0)
	return s


# ── Public API ────────────────────────────────────────────────────────────────

func refresh(state: SimulationState) -> void:
	_year_label.text = "Year %d" % state.year
	var low := state.energy_capacity < 0.3
	_power_val.text    = "Power: %d%%" % roundi(state.energy_capacity * 100.0)
	_power_val.modulate = Color(1.0, 0.35, 0.35) if low else Color.WHITE
	_pop_val.text      = "Pop: %.0fM" % state.population_units
	_research_val.text = "Research: %.1f pts/yr" % state.research_rate
	_build_val.text    = "Build: %d%%" % roundi(state.construction_speed * 100.0)
	_kard_label.text   = "K %.2f" % _kardashev(state)


func apply_compression(level: int) -> void:
	_current_level = level
	var paused := level == Constants.CompressionLevel.PAUSED
	_pause_btn.text = "▶ Resume" if paused else "⏸ Pause"
	_speed_label.text = _SPEED_NAMES.get(level, "")


# ── Speed handlers ────────────────────────────────────────────────────────────

func _on_pause() -> void:
	if _current_level == Constants.CompressionLevel.PAUSED:
		_emit(_pre_pause_level)
	else:
		_pre_pause_level = _current_level
		_emit(Constants.CompressionLevel.PAUSED)


func _on_slow() -> void:
	if _current_level == Constants.CompressionLevel.PAUSED:
		return
	var idx := _LEVELS.find(_current_level)
	if idx > 0:
		_emit(_LEVELS[idx - 1])


func _on_fast() -> void:
	if _current_level == Constants.CompressionLevel.PAUSED:
		_emit(_LEVELS[0])
		return
	var idx := _LEVELS.find(_current_level)
	if idx >= 0 and idx < _LEVELS.size() - 1:
		_emit(_LEVELS[idx + 1])


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
