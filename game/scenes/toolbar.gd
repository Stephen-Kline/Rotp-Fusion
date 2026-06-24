extends PanelContainer
# Full-width top toolbar. Builds its own UI in _ready().

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

const _SPEED_NAMES := {
	Constants.CompressionLevel.PAUSED:  "Paused",
	Constants.CompressionLevel.SLOW:    "0.2×",
	Constants.CompressionLevel.NORMAL:  "1×",
	Constants.CompressionLevel.FAST:    "5×",
	Constants.CompressionLevel.FASTER:  "20×",
	Constants.CompressionLevel.MAX:     "100×",
}


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	# ── Left: status stats ──────────────────────────────────────────────────
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_BEGIN
	left.add_theme_constant_override("separation", 20)
	row.add_child(left)

	_power_val    = _stat(left, "POWER")
	_pop_val      = _stat(left, "POPULATION")
	_research_val = _stat(left, "RESEARCH")
	_build_val    = _stat(left, "BUILD SPEED")

	# ── Center: year + speed controls ───────────────────────────────────────
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(200, 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 2)
	row.add_child(center)

	_year_label = Label.new()
	_year_label.text = "Year 1960"
	_year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_year_label.add_theme_font_size_override("font_size", 18)
	center.add_child(_year_label)

	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 4)
	center.add_child(speed_row)

	var slow_btn := Button.new()
	slow_btn.text = "◀  Slow"
	slow_btn.pressed.connect(_on_slow)
	speed_row.add_child(slow_btn)

	_pause_btn = Button.new()
	_pause_btn.text = "⏸ Pause"
	_pause_btn.pressed.connect(_on_pause)
	speed_row.add_child(_pause_btn)

	var fast_btn := Button.new()
	fast_btn.text = "Fast  ▶"
	fast_btn.pressed.connect(_on_fast)
	speed_row.add_child(fast_btn)

	_speed_label = Label.new()
	_speed_label.text = "Paused"
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_font_size_override("font_size", 10)
	_speed_label.modulate = Color(0.65, 0.65, 0.7)
	center.add_child(_speed_label)

	# ── Right: K-scale + buttons ────────────────────────────────────────────
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)

	var k_vbox := VBoxContainer.new()
	k_vbox.add_theme_constant_override("separation", 0)
	right.add_child(k_vbox)

	var k_hdr := Label.new()
	k_hdr.text = "KARDASHEV"
	k_hdr.add_theme_font_size_override("font_size", 9)
	k_hdr.modulate = Color(0.6, 0.6, 0.7)
	k_vbox.add_child(k_hdr)

	_kard_label = Label.new()
	_kard_label.text = "K 0.70"
	_kard_label.add_theme_font_size_override("font_size", 16)
	_kard_label.modulate = Color(0.75, 0.88, 1.0)
	k_vbox.add_child(_kard_label)

	right.add_child(VSeparator.new())

	var tech_btn := Button.new()
	tech_btn.text = "Tech Tree"
	tech_btn.pressed.connect(func(): tech_tree_toggled.emit())
	right.add_child(tech_btn)

	var log_btn := Button.new()
	log_btn.text = "Event Log"
	log_btn.pressed.connect(func(): event_log_toggled.emit())
	right.add_child(log_btn)


func _stat(parent: HBoxContainer, header: String) -> Label:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	parent.add_child(vbox)

	var hdr := Label.new()
	hdr.text = header
	hdr.add_theme_font_size_override("font_size", 9)
	hdr.modulate = Color(0.58, 0.58, 0.68)
	vbox.add_child(hdr)

	var val := Label.new()
	val.text = "--"
	val.add_theme_font_size_override("font_size", 14)
	vbox.add_child(val)
	return val


# ── Public API ────────────────────────────────────────────────────────────────

func refresh(state: SimulationState) -> void:
	_year_label.text = "Year %d" % state.year
	_power_val.text    = "%d%%" % roundi(state.energy_capacity * 100.0)
	_pop_val.text      = "%.0f M" % state.population_units
	_research_val.text = "%.1f pts/yr" % state.research_rate
	_build_val.text    = "%d%%" % roundi(state.construction_speed * 100.0)
	_power_val.modulate = Color(1.0, 0.35, 0.35) if state.energy_capacity < 0.3 else Color.WHITE
	_kard_label.text = "K %.2f" % _kardashev(state)


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
