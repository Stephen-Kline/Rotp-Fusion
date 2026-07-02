class_name ColonyPanel
extends PanelContainer

signal build_structure_requested(structure_type: String, body: String)
signal demolish_structure_requested(structure_type: String, body: String)
signal research_requested(node_id: String)
signal tab_jumped(tab_index: int)

const _WIDTH     := 320.0
const _TAB_HOME  := 0
const _TAB_ENV   := 1
const _TAB_STRUCT := 2
const _TAB_RES   := 3

# Colony-scoped research techs shown in the Research tab (stub for per-colony system)
const COLONY_RESEARCH: Dictionary = {
	"Environment": ["reforestation_program"],
}

const _COL_HEALTHY  := Color(0.25, 0.85, 0.35)
const _COL_STRESSED := Color(0.95, 0.85, 0.10)
const _COL_CRITICAL := Color(0.95, 0.50, 0.10)
const _COL_COLLAPSE := Color(0.88, 0.15, 0.15)

var _struct_db: StructureDB
var _current_body: String = ""

# Header
var _body_title: Label

# Tabs
var _tabs: TabContainer

# Home tab
var _home_pop:        Label
var _home_env_bar:    ProgressBar
var _home_env_tier:   Label
var _home_struct_sum: Label
var _home_res_name:   Label
var _home_res_bar:    ProgressBar

# Environment tab
var _env_bar:       ProgressBar
var _env_tier_lbl:  Label
var _env_rate_lbl:  Label
var _env_breakdown: VBoxContainer

# Structures tab
var _struct_body: VBoxContainer

# Research tab
var _res_body: VBoxContainer


func _ready() -> void:
	_struct_db = StructureDB.new()

	custom_minimum_size = Vector2(_WIDTH, 0)
	add_theme_stylebox_override("panel",
		UIUtil.panel_style(Color(UIUtil.COL_NAVY.r, UIUtil.COL_NAVY.g, UIUtil.COL_NAVY.b, 0.96),
		Color(UIUtil.COL_CREAM.r, UIUtil.COL_CREAM.g, UIUtil.COL_CREAM.b, 0.12), 1))

	var outer := UIUtil.make_vbox(0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	# ── Header ────────────────────────────────────────────────────────────────
	var header := UIUtil.make_hbox(0)
	outer.add_child(header)

	_body_title = UIUtil.make_label("COLONY", 12, UIUtil.COL_ORANGE)
	_body_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_title.custom_minimum_size   = Vector2(0, 34)
	_body_title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	var lpad := StyleBoxEmpty.new(); lpad.content_margin_left = 8
	_body_title.add_theme_stylebox_override("normal", lpad)
	header.add_child(_body_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", UIUtil.COL_DIM)
	close_btn.custom_minimum_size = Vector2(28, 0)
	close_btn.pressed.connect(hide)
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	# ── Tabs ──────────────────────────────────────────────────────────────────
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 10)
	outer.add_child(_tabs)

	_build_home_tab()
	_build_env_tab()
	_build_struct_tab()
	_build_res_tab()


# ── Tab builders ──────────────────────────────────────────────────────────────

func _build_home_tab() -> void:
	var scroll := _tab_scroll("Home")
	var body   := _padded_vbox(scroll, 8)

	# Population
	var pop_row := UIUtil.make_hbox(0)
	pop_row.add_child(UIUtil.make_label("Population", 10, UIUtil.COL_DIM))
	pop_row.add_child(_spacer())
	_home_pop = UIUtil.make_label("—", 11, UIUtil.COL_CREAM)
	pop_row.add_child(_home_pop)
	body.add_child(pop_row)

	body.add_child(HSeparator.new())

	# Environment card (clickable → env tab)
	var env_card := _card("ENVIRONMENT", func(): _tabs.current_tab = _TAB_ENV)
	body.add_child(env_card)
	_home_env_bar  = _make_progress_bar()
	env_card.add_child(_home_env_bar)
	var tier_row := UIUtil.make_hbox(0)
	_home_env_tier = UIUtil.make_label("—", 10, UIUtil.COL_DIM)
	tier_row.add_child(_home_env_tier)
	env_card.add_child(tier_row)

	body.add_child(HSeparator.new())

	# Structures card
	var struct_card := _card("STRUCTURES", func(): _tabs.current_tab = _TAB_STRUCT)
	body.add_child(struct_card)
	_home_struct_sum = UIUtil.make_label("—", 10, UIUtil.COL_CREAM)
	struct_card.add_child(_home_struct_sum)

	body.add_child(HSeparator.new())

	# Research card
	var res_card := _card("RESEARCH", func(): _tabs.current_tab = _TAB_RES)
	body.add_child(res_card)
	_home_res_name = UIUtil.make_label("—", 10, UIUtil.COL_CREAM)
	res_card.add_child(_home_res_name)
	_home_res_bar  = _make_progress_bar()
	_home_res_bar.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	res_card.add_child(_home_res_bar)


func _build_env_tab() -> void:
	var scroll := _tab_scroll("Environment")
	var body   := _padded_vbox(scroll, 8)

	_env_bar = _make_progress_bar()
	body.add_child(_env_bar)

	var tier_row := UIUtil.make_hbox(0)
	_env_tier_lbl = UIUtil.make_label("—", 11, UIUtil.COL_CREAM)
	tier_row.add_child(_env_tier_lbl)
	tier_row.add_child(_spacer())
	_env_rate_lbl = UIUtil.make_label("—", 10, UIUtil.COL_DIM)
	tier_row.add_child(_env_rate_lbl)
	body.add_child(tier_row)

	body.add_child(HSeparator.new())
	body.add_child(UIUtil.make_label("ENV CONTRIBUTION BY STRUCTURE", 9, UIUtil.COL_DIM))

	_env_breakdown = UIUtil.make_vbox(2)
	body.add_child(_env_breakdown)


func _build_struct_tab() -> void:
	var scroll := _tab_scroll("Structures")
	_struct_body = _padded_vbox(scroll, 6)


func _build_res_tab() -> void:
	var scroll := _tab_scroll("Research")
	_res_body = _padded_vbox(scroll, 6)


# ── Public API ────────────────────────────────────────────────────────────────

func show_for(body_id: String, colony: ColonyState, sim: SimulationState) -> void:
	_current_body = body_id
	_body_title.text = "  " + body_id.to_upper()
	refresh(colony, sim)
	show()


func refresh(colony: ColonyState, sim: SimulationState) -> void:
	if colony == null:
		_show_no_colony()
		return
	_refresh_home(colony, sim)
	_refresh_env(colony)
	_refresh_struct(colony)
	_refresh_research(sim)


func jump_to_tab(idx: int) -> void:
	_tabs.current_tab = idx


# ── Tab refreshers ────────────────────────────────────────────────────────────

func _show_no_colony() -> void:
	_body_title.text = "  " + _current_body.to_upper()
	_home_pop.text = "No colony"
	_home_env_tier.text = "—"
	_home_struct_sum.text = "—"
	_home_res_name.text = "—"


func _refresh_home(colony: ColonyState, sim: SimulationState) -> void:
	_home_pop.text = "%.1f B" % (colony.population_units * 0.3)

	var tier := _env_tier(colony.environment)
	var col   := _tier_color(tier)
	_apply_bar(_home_env_bar, colony.environment, col)
	_home_env_tier.text = tier
	_home_env_tier.add_theme_color_override("font_color", col)

	var total   := colony.structures.size()
	var offline := 0
	for i in colony.online_flags.size():
		if not colony.online_flags[i]: offline += 1
	_home_struct_sum.text = "%d built" % total + (
		("  (%d offline)" % offline) if offline > 0 else "")

	if sim.active_research.is_empty():
		_home_res_name.text = "None active"
		_home_res_bar.value = 0.0
	else:
		_home_res_name.text = sim.active_research.replace("_", " ").capitalize()
		_home_res_bar.value = clampf(sim.research_progress, 0.0, 100.0)


func _refresh_env(colony: ColonyState) -> void:
	var tier := _env_tier(colony.environment)
	var col   := _tier_color(tier)
	_apply_bar(_env_bar, colony.environment, col)
	_env_tier_lbl.text = tier
	_env_tier_lbl.add_theme_color_override("font_color", col)

	var rate_sign := "+" if colony.env_rate >= 0 else ""
	_env_rate_lbl.text = "%s%.1f/yr" % [rate_sign, colony.env_rate]

	for c in _env_breakdown.get_children(): c.queue_free()

	# Per-structure env breakdown
	var counts: Dictionary = {}   # sid → count
	var online_counts: Dictionary = {}
	for i in colony.structures.size():
		var sid: String = colony.structures[i]
		counts[sid] = counts.get(sid, 0) + 1
		if colony.online_flags[i]:
			online_counts[sid] = online_counts.get(sid, 0) + 1

	for sid: String in counts:
		var delta := _struct_db.get_env_delta(sid)
		if delta == 0.0: continue
		var n_online: int = online_counts.get(sid, 0)
		var n_total:  int = counts[sid]
		var sign := "+" if delta >= 0 else ""
		var text := "%s  %s%.1f/yr" % [
			_struct_db.get_display_name(sid),
			sign, delta * n_online
		]
		if n_online < n_total:
			text += "  (%d/%d online)" % [n_online, n_total]
		var row := UIUtil.make_label(text, 10,
			UIUtil.COL_CREAM if n_online > 0 else UIUtil.COL_DIM)
		_env_breakdown.add_child(row)

	if _env_breakdown.get_child_count() == 0:
		_env_breakdown.add_child(UIUtil.make_label("No structures affecting environment", 10, UIUtil.COL_DIM))


func _refresh_struct(colony: ColonyState) -> void:
	for c in _struct_body.get_children(): c.queue_free()

	# Count instances and online counts
	var counts: Dictionary        = {}
	var online_counts: Dictionary = {}
	for i in colony.structures.size():
		var sid: String = colony.structures[i]
		counts[sid] = counts.get(sid, 0) + 1
		if colony.online_flags[i]:
			online_counts[sid] = online_counts.get(sid, 0) + 1

	# Separate surface vs orbital, then group by resource
	var surface_groups: Dictionary = {}
	var orbital_groups: Dictionary = {}

	for sid: String in counts:
		var grp := _struct_group(sid)
		if _struct_db.get_orbit_km(sid) != null:
			if not orbital_groups.has(grp): orbital_groups[grp] = []
			orbital_groups[grp].append(sid)
		else:
			if not surface_groups.has(grp): surface_groups[grp] = []
			surface_groups[grp].append(sid)

	var section_order := ["Energy", "Materials", "Knowledge", "Consumables", "Environment", "Infrastructure"]

	if not surface_groups.is_empty():
		_struct_body.add_child(UIUtil.make_label("SURFACE", 9, UIUtil.COL_DIM))
		for grp in section_order:
			if not surface_groups.has(grp): continue
			_struct_body.add_child(UIUtil.make_label("  " + grp, 9, UIUtil.COL_CYAN))
			for sid: String in surface_groups[grp]:
				_struct_body.add_child(_struct_row(sid, counts[sid], online_counts.get(sid, 0)))

	if not orbital_groups.is_empty():
		if not surface_groups.is_empty():
			_struct_body.add_child(HSeparator.new())
		_struct_body.add_child(UIUtil.make_label("ORBITAL", 9, UIUtil.COL_DIM))
		for grp in section_order:
			if not orbital_groups.has(grp): continue
			_struct_body.add_child(UIUtil.make_label("  " + grp, 9, UIUtil.COL_CYAN))
			for sid: String in orbital_groups[grp]:
				_struct_body.add_child(_struct_row(sid, counts[sid], online_counts.get(sid, 0)))

	if surface_groups.is_empty() and orbital_groups.is_empty():
		_struct_body.add_child(UIUtil.make_label("No structures built.", 10, UIUtil.COL_DIM))


func _struct_row(sid: String, count: int, n_online: int) -> HBoxContainer:
	var row := UIUtil.make_hbox(4)

	var name_lbl := UIUtil.make_label(
		"    " + _struct_db.get_display_name(sid), 10,
		UIUtil.COL_CREAM if n_online > 0 else UIUtil.COL_DIM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var cnt_lbl := UIUtil.make_label("×%d" % count, 10, UIUtil.COL_MUTED)
	cnt_lbl.custom_minimum_size = Vector2(28, 0)
	cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cnt_lbl)

	# − demolish one
	var minus_btn := _icon_btn("−", UIUtil.COL_WARN)
	minus_btn.pressed.connect(func(): demolish_structure_requested.emit(sid, _current_body))
	row.add_child(minus_btn)

	# + build one (if available)
	var plus_btn := _icon_btn("+", UIUtil.COL_GREEN)
	plus_btn.pressed.connect(func(): build_structure_requested.emit(sid, _current_body))
	row.add_child(plus_btn)

	return row


func _refresh_research(sim: SimulationState) -> void:
	for c in _res_body.get_children(): c.queue_free()

	for grp: String in COLONY_RESEARCH:
		_res_body.add_child(UIUtil.make_label(grp.to_upper(), 9, UIUtil.COL_DIM))
		for node_id: String in COLONY_RESEARCH[grp]:
			_res_body.add_child(_research_row(node_id, sim))

	if _res_body.get_child_count() == 0:
		_res_body.add_child(UIUtil.make_label("No colony research available.", 10, UIUtil.COL_DIM))


func _research_row(node_id: String, sim: SimulationState) -> HBoxContainer:
	var row := UIUtil.make_hbox(4)
	var display := node_id.replace("_", " ").capitalize()

	var done     := node_id in sim.completed_research
	var active   := sim.active_research == node_id
	var col := UIUtil.COL_SUCCESS if done else (UIUtil.COL_CREAM if active else UIUtil.COL_DIM)

	var lbl := UIUtil.make_label("  " + display, 10, col)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	if done:
		row.add_child(UIUtil.make_label("✓", 10, UIUtil.COL_SUCCESS))
	elif active:
		row.add_child(UIUtil.make_label("▶", 10, UIUtil.COL_AMBER))
	else:
		var btn := Button.new()
		btn.text = "Research"
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", UIUtil.COL_CYAN)
		btn.pressed.connect(func(): research_requested.emit(node_id))
		row.add_child(btn)

	return row


# ── Helpers ───────────────────────────────────────────────────────────────────

func _tab_scroll(tab_name: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	return scroll


func _padded_vbox(parent: Control, sep: int) -> VBoxContainer:
	var vb := UIUtil.make_vbox(sep)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 8; pad.content_margin_right = 8
	pad.content_margin_top = 6; pad.content_margin_bottom = 6
	vb.add_theme_stylebox_override("panel", pad)
	parent.add_child(vb)
	return vb


func _card(title: String, on_click: Callable) -> VBoxContainer:
	var vb := UIUtil.make_vbox(3)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var hdr := UIUtil.make_hbox(0)
	hdr.add_child(UIUtil.make_label(title, 9, UIUtil.COL_DIM))
	hdr.add_child(_spacer())
	hdr.add_child(UIUtil.make_label("→", 9, UIUtil.COL_DIM))
	vb.add_child(hdr)

	vb.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
	)
	return vb


func _make_progress_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value     = 0.0
	bar.custom_minimum_size = Vector2(0, 10)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.15, 0.15, 0.20)
	bar.add_theme_stylebox_override("background", bg)
	return bar


func _apply_bar(bar: ProgressBar, value: float, col: Color) -> void:
	bar.value = clampf(value, 0.0, 100.0)
	var fill := StyleBoxFlat.new(); fill.bg_color = col
	bar.add_theme_stylebox_override("fill", fill)


func _icon_btn(text: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", col)
	btn.custom_minimum_size = Vector2(20, 20)
	return btn


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _env_tier(env: float) -> String:
	if env >= 80.0: return "Healthy"
	if env >= 50.0: return "Stressed"
	if env >= 20.0: return "Critical"
	return "Collapse"


func _tier_color(tier: String) -> Color:
	match tier:
		"Healthy":  return _COL_HEALTHY
		"Stressed": return _COL_STRESSED
		"Critical": return _COL_CRITICAL
	return _COL_COLLAPSE


func _struct_group(sid: String) -> String:
	var b := _struct_db.get_struct_bonuses(sid)
	if b.has("energy")      and float(b["energy"])      > 0.0: return "Energy"
	if b.has("materials")   and float(b["materials"])   > 0.0: return "Materials"
	if b.has("knowledge")   and float(b["knowledge"])   > 0.0: return "Knowledge"
	if b.has("consumables") and float(b["consumables"]) > 0.0: return "Consumables"
	if _struct_db.get_env_delta(sid) != 0.0: return "Environment"
	return "Infrastructure"
