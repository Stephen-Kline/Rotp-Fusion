class_name FleetPanel
extends PanelContainer

signal build_structure_requested(structure_type: String, body: String)
signal build_ship_requested(build_option: String)
signal launch_ship_requested(ship_id: String, destination: String, use_direct: bool)

const _NAVY  := Color(0.06, 0.10, 0.22)
const _ORANGE:= Color(0.92, 0.48, 0.12)
const _CREAM := Color(0.94, 0.90, 0.80)
const _CYAN  := Color(0.20, 0.82, 0.90)
const _DIM   := Color(0.38, 0.45, 0.58)
const _GREEN := Color(0.30, 0.85, 0.40)
const _WARN  := Color(1.00, 0.28, 0.10)

const DEST_IDS    := ["moon", "l2"]
const DEST_LABELS := {"moon": "Moon", "l2": "Earth-Moon L2"}
const STRUCTURE_OPTIONS := ["launch_facility", "space_launch_facility"]

var _build_section: VBoxContainer
var _fleet_section: VBoxContainer
var _ship_destinations: Dictionary = {}
var _fleet_rows: Dictionary = {}
var _prev_states: Dictionary = {}
var _ship_db: ShipDB
var _struct_db: StructureDB


func _ready() -> void:
	custom_minimum_size = Vector2(300, 0)
	_ship_db = ShipDB.new()
	_struct_db = StructureDB.new()

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(_NAVY.r, _NAVY.g, _NAVY.b, 0.96)
	bg.border_width_left = 1
	bg.border_color = Color(_CREAM.r, _CREAM.g, _CREAM.b, 0.12)
	add_theme_stylebox_override("panel", bg)

	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 0)
	add_child(outer)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 0)
	outer.add_child(header_row)

	var title := Label.new()
	title.text = "  MISSION CONTROL"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", _ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size = Vector2(0, 34)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", _DIM)
	close_btn.custom_minimum_size = Vector2(28, 0)
	close_btn.pressed.connect(hide)
	header_row.add_child(close_btn)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 8; pad.content_margin_right = 8
	pad.content_margin_top = 6; pad.content_margin_bottom = 6
	body.add_theme_stylebox_override("panel", pad)
	scroll.add_child(body)

	var build_lbl := Label.new()
	build_lbl.text = "BUILD"
	build_lbl.add_theme_font_size_override("font_size", 10)
	build_lbl.add_theme_color_override("font_color", _DIM)
	body.add_child(build_lbl)

	_build_section = VBoxContainer.new()
	_build_section.add_theme_constant_override("separation", 4)
	body.add_child(_build_section)

	body.add_child(HSeparator.new())

	var fleet_lbl := Label.new()
	fleet_lbl.text = "FLEET"
	fleet_lbl.add_theme_font_size_override("font_size", 10)
	fleet_lbl.add_theme_color_override("font_color", _DIM)
	body.add_child(fleet_lbl)

	_fleet_section = VBoxContainer.new()
	_fleet_section.add_theme_constant_override("separation", 8)
	body.add_child(_fleet_section)


func refresh(state: SimulationState) -> void:
	_refresh_build(state)
	_refresh_fleet(state)


func _refresh_build(state: SimulationState) -> void:
	for c in _build_section.get_children():
		c.queue_free()

	if state.available_build_options.is_empty():
		var lbl := Label.new()
		lbl.text = "No options available"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", _DIM)
		_build_section.add_child(lbl)
		return

	var earth_structs: Array = state.structures.get("earth", [])
	var has_facility: bool = "launch_facility" in earth_structs \
		or "space_launch_facility" in earth_structs

	for option: String in state.available_build_options:
		var is_struct: bool = option in STRUCTURE_OPTIONS
		var cost: Dictionary = _struct_db.get_cost(option) if is_struct \
			else _ship_db.get_cost(option)
		var mat: float = float(cost.get("materials", 0.0))
		var nrg: float = float(cost.get("energy", 0.0))
		var build_days: float = float(cost.get("build_days", 0.0))

		var can_afford: bool = state.materials_stockpile >= mat \
			and state.energy_stockpile >= nrg
		var prereq_ok: bool = is_struct or has_facility

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_build_section.add_child(row)

		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)

		var name_lbl := Label.new()
		name_lbl.text = _option_name(option)
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_color_override("font_color", _CREAM if can_afford else _DIM)
		col.add_child(name_lbl)

		var cost_parts: Array = []
		if mat > 0.0:
			cost_parts.append(ResourceHelpers.format_si(mat, "t"))
		if nrg > 0.0:
			cost_parts.append(ResourceHelpers.format_si(nrg, "J"))
		if build_days > 0.0:
			cost_parts.append("%.0fd" % build_days)
		var cost_lbl := Label.new()
		cost_lbl.text = "  ".join(cost_parts)
		cost_lbl.add_theme_font_size_override("font_size", 9)
		cost_lbl.add_theme_color_override("font_color", _WARN if not can_afford else _DIM)
		col.add_child(cost_lbl)

		var btn := Button.new()
		btn.text = "Build"
		btn.flat = false
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size = Vector2(52, 0)
		btn.disabled = not (can_afford and prereq_ok)
		if not prereq_ok:
			btn.tooltip_text = "Requires Launch Facility"
		elif not can_afford:
			btn.tooltip_text = "Insufficient resources"
		row.add_child(btn)

		if is_struct:
			var opt := option
			btn.pressed.connect(func(): build_structure_requested.emit(opt, "earth"))
		else:
			var opt := option
			btn.pressed.connect(func(): build_ship_requested.emit(opt))


func _refresh_fleet(state: SimulationState) -> void:
	var live_ids: Array = state.ships.map(func(s: Ship) -> String: return s.id)
	for sid in _fleet_rows.keys():
		if sid not in live_ids:
			_fleet_rows[sid]["vbox"].queue_free()
			_fleet_rows.erase(sid)

	if state.ships.is_empty():
		if not _fleet_section.has_meta("empty_label"):
			var lbl := Label.new()
			lbl.text = "No ships"
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", _DIM)
			_fleet_section.add_child(lbl)
			_fleet_section.set_meta("empty_label", lbl)
		return
	elif _fleet_section.has_meta("empty_label"):
		_fleet_section.get_meta("empty_label").queue_free()
		_fleet_section.remove_meta("empty_label")

	for ship: Ship in state.ships:
		var prev_state: int = _prev_states.get(ship.id, -1)
		if ship.id not in _fleet_rows:
			_fleet_rows[ship.id] = _create_ship_row(ship, state)
		elif prev_state != ship.ship_state:
			_fleet_rows[ship.id]["vbox"].queue_free()
			_fleet_rows[ship.id] = _create_ship_row(ship, state)
		else:
			_update_ship_row_progress(ship, state, _fleet_rows[ship.id])

		_prev_states[ship.id] = ship.ship_state


func _create_ship_row(ship: Ship, state: SimulationState) -> Dictionary:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_fleet_section.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = ship.label if ship.label != "" else "Ship"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", _CREAM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 10)
	header.add_child(status_lbl)

	var prop_lbl := Label.new()
	prop_lbl.text = PropulsionData.tier_name(ship.propulsion_tier)
	prop_lbl.add_theme_font_size_override("font_size", 9)
	prop_lbl.add_theme_color_override("font_color", _DIM)
	vbox.add_child(prop_lbl)

	var refs := {"vbox": vbox, "pb": null, "eta": null}

	match ship.ship_state:
		Ship.ShipState.BUILDING:
			status_lbl.text = "Building"
			status_lbl.add_theme_color_override("font_color", _DIM)

			var pb := ProgressBar.new()
			pb.min_value = 0.0
			pb.max_value = 1.0
			var total := maxf(0.001, ship.build_complete_day - ship.build_start_day)
			pb.value = clampf((state.elapsed_days - ship.build_start_day) / total, 0.0, 1.0)
			pb.custom_minimum_size = Vector2(0, 8)
			vbox.add_child(pb)
			refs["pb"] = pb

			var eta := Label.new()
			var days_left := maxf(0.0, ship.build_complete_day - state.elapsed_days)
			eta.text = "Ready in %.0f days" % days_left
			eta.add_theme_font_size_override("font_size", 9)
			eta.add_theme_color_override("font_color", _DIM)
			vbox.add_child(eta)
			refs["eta"] = eta

		Ship.ShipState.AWAITING_WINDOW:
			status_lbl.text = "Ready ✓"
			status_lbl.add_theme_color_override("font_color", _GREEN)

			if ship.id not in _ship_destinations:
				_ship_destinations[ship.id] = "moon"

			var dest_row := HBoxContainer.new()
			dest_row.add_theme_constant_override("separation", 4)
			vbox.add_child(dest_row)

			var dest_opt := OptionButton.new()
			dest_opt.add_theme_font_size_override("font_size", 10)
			dest_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for dest_id in DEST_IDS:
				dest_opt.add_item(DEST_LABELS.get(dest_id, dest_id))
			var sel_idx := DEST_IDS.find(_ship_destinations.get(ship.id, "moon"))
			if sel_idx >= 0:
				dest_opt.select(sel_idx)
			var sid := ship.id
			dest_opt.item_selected.connect(func(idx: int):
				_ship_destinations[sid] = DEST_IDS[idx]
				_prev_states.erase(sid)
			)
			dest_row.add_child(dest_opt)

			var launch_btn := Button.new()
			launch_btn.text = "Launch"
			launch_btn.add_theme_font_size_override("font_size", 10)
			var cap := ship.id
			launch_btn.pressed.connect(func():
				var dest: String = _ship_destinations.get(cap, "moon")
				launch_ship_requested.emit(cap, dest, false)
			)
			dest_row.add_child(launch_btn)

			var dest_str: String = _ship_destinations.get(ship.id, "moon")
			var direct_ok := PropulsionData.is_direct_unlocked(state.completed_research)
			var prof := FlightPlanner.plan(
				ship.origin_body, dest_str, state.elapsed_days, ship.propulsion_tier, direct_ok)

			var info_lbl := Label.new()
			info_lbl.text = "Window: %.0fd  Transit: %.1fd" % [prof.window_wait_days, prof.transit_days]
			info_lbl.add_theme_font_size_override("font_size", 9)
			info_lbl.add_theme_color_override("font_color", _DIM)
			vbox.add_child(info_lbl)

			if direct_ok:
				var direct_btn := Button.new()
				direct_btn.text = "Launch Direct (%.1fd, +cost)" % prof.direct_transit_days
				direct_btn.add_theme_font_size_override("font_size", 9)
				direct_btn.add_theme_color_override("font_color", _CYAN)
				var cap2 := ship.id
				direct_btn.pressed.connect(func():
					var dest: String = _ship_destinations.get(cap2, "moon")
					launch_ship_requested.emit(cap2, dest, true)
				)
				vbox.add_child(direct_btn)

		Ship.ShipState.IN_TRANSIT:
			var dest_name: String = DEST_LABELS.get(ship.destination_body,
				ship.destination_body.capitalize())
			status_lbl.text = "→ %s" % dest_name
			status_lbl.add_theme_color_override("font_color", _CYAN)

			var pb := ProgressBar.new()
			pb.min_value = 0.0
			var dur := maxf(0.001, ship.arrival_day - ship.mission_authorized_day)
			pb.max_value = dur
			pb.value = clampf(state.elapsed_days - ship.mission_authorized_day, 0.0, dur)
			pb.custom_minimum_size = Vector2(0, 8)
			vbox.add_child(pb)
			refs["pb"] = pb

			var eta := Label.new()
			var days_left := maxf(0.0, ship.arrival_day - state.elapsed_days)
			eta.text = "ETA %.0f days" % days_left
			eta.add_theme_font_size_override("font_size", 9)
			eta.add_theme_color_override("font_color", _DIM)
			vbox.add_child(eta)
			refs["eta"] = eta

		Ship.ShipState.ARRIVED:
			var dest_name: String = DEST_LABELS.get(ship.destination_body,
				ship.destination_body.capitalize())
			status_lbl.text = "Arrived"
			status_lbl.add_theme_color_override("font_color", _GREEN)
			var at_lbl := Label.new()
			at_lbl.text = "At %s" % dest_name
			at_lbl.add_theme_font_size_override("font_size", 9)
			at_lbl.add_theme_color_override("font_color", _DIM)
			vbox.add_child(at_lbl)

	vbox.add_child(HSeparator.new())
	return refs


func _update_ship_row_progress(ship: Ship, state: SimulationState,
		refs: Dictionary) -> void:
	var pb: ProgressBar = refs.get("pb")
	var eta: Label = refs.get("eta")

	match ship.ship_state:
		Ship.ShipState.BUILDING:
			if pb:
				var total := maxf(0.001, ship.build_complete_day - ship.build_start_day)
				pb.value = clampf((state.elapsed_days - ship.build_start_day) / total, 0.0, 1.0)
			if eta:
				var days_left := maxf(0.0, ship.build_complete_day - state.elapsed_days)
				eta.text = "Ready in %.0f days" % days_left

		Ship.ShipState.IN_TRANSIT:
			if pb:
				var dur := maxf(0.001, ship.arrival_day - ship.mission_authorized_day)
				pb.value = clampf(state.elapsed_days - ship.mission_authorized_day, 0.0, dur)
			if eta:
				var days_left := maxf(0.0, ship.arrival_day - state.elapsed_days)
				eta.text = "ETA %.0f days" % days_left


func _option_name(option: String) -> String:
	if option in STRUCTURE_OPTIONS:
		return _struct_db.get_display_name(option)
	return _ship_db.get_display_name(option)
