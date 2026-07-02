class_name FleetPanel
extends PanelContainer

signal build_structure_requested(structure_type: String, body: String)
signal build_ship_requested(build_option: String)
signal launch_ship_requested(ship_id: String, destination: String, use_direct: bool)

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

	add_theme_stylebox_override("panel",
		UIUtil.panel_style(Color(UIUtil.COL_NAVY.r, UIUtil.COL_NAVY.g, UIUtil.COL_NAVY.b, 0.96),
		Color(UIUtil.COL_CREAM.r, UIUtil.COL_CREAM.g, UIUtil.COL_CREAM.b, 0.12), 1))

	var outer := UIUtil.make_vbox(0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	var header_row := UIUtil.make_hbox(0)
	outer.add_child(header_row)

	var title := UIUtil.make_label("  MISSION CONTROL", 12, UIUtil.COL_ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size = Vector2(0, 34)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", UIUtil.COL_DIM)
	close_btn.custom_minimum_size = Vector2(28, 0)
	close_btn.pressed.connect(hide)
	header_row.add_child(close_btn)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := UIUtil.make_vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 8; pad.content_margin_right = 8
	pad.content_margin_top = 6; pad.content_margin_bottom = 6
	body.add_theme_stylebox_override("panel", pad)
	scroll.add_child(body)

	body.add_child(UIUtil.make_label("BUILD", 10, UIUtil.COL_DIM))

	_build_section = UIUtil.make_vbox(4)
	body.add_child(_build_section)

	body.add_child(HSeparator.new())

	body.add_child(UIUtil.make_label("FLEET", 10, UIUtil.COL_DIM))

	_fleet_section = UIUtil.make_vbox(8)
	body.add_child(_fleet_section)


func refresh(state: SimulationState) -> void:
	_refresh_build(state)
	_refresh_fleet(state)


func _refresh_build(state: SimulationState) -> void:
	for c in _build_section.get_children():
		c.queue_free()

	if state.available_build_options.is_empty():
		_build_section.add_child(UIUtil.make_label("No options available", 10, UIUtil.COL_DIM))
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

		var row := UIUtil.make_hbox(4)
		_build_section.add_child(row)

		var col := UIUtil.make_vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)

		col.add_child(UIUtil.make_label(_option_name(option), 10,
			UIUtil.COL_CREAM if can_afford else UIUtil.COL_DIM))

		var cost_parts: Array = []
		if mat > 0.0:
			cost_parts.append(ResourceHelpers.format_si(mat, "t"))
		if nrg > 0.0:
			cost_parts.append(ResourceHelpers.format_si(nrg, "J"))
		if build_days > 0.0:
			cost_parts.append("%.0fd" % build_days)
		col.add_child(UIUtil.make_label("  ".join(cost_parts), 9,
			UIUtil.COL_WARN if not can_afford else UIUtil.COL_DIM))

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
			var lbl := UIUtil.make_label("No ships", 10, UIUtil.COL_DIM)
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
	var vbox := UIUtil.make_vbox(3)
	_fleet_section.add_child(vbox)

	var header := UIUtil.make_hbox(6)
	vbox.add_child(header)

	var name_lbl := UIUtil.make_label(ship.label if ship.label != "" else "Ship", 11, UIUtil.COL_CREAM)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 10)
	header.add_child(status_lbl)

	vbox.add_child(UIUtil.make_label(PropulsionData.tier_name(ship.propulsion_tier), 9, UIUtil.COL_DIM))

	var refs := {"vbox": vbox, "pb": null, "eta": null}

	match ship.ship_state:
		Ship.ShipState.BUILDING:
			status_lbl.text = "Building"
			status_lbl.add_theme_color_override("font_color", UIUtil.COL_DIM)

			var pb := ProgressBar.new()
			pb.min_value = 0.0
			pb.max_value = 1.0
			var total := maxf(0.001, ship.build_complete_day - ship.build_start_day)
			pb.value = clampf((state.elapsed_days - ship.build_start_day) / total, 0.0, 1.0)
			pb.custom_minimum_size = Vector2(0, 8)
			vbox.add_child(pb)
			refs["pb"] = pb

			var eta := UIUtil.make_label(
				"Ready in %.0f days" % maxf(0.0, ship.build_complete_day - state.elapsed_days),
				9, UIUtil.COL_DIM)
			vbox.add_child(eta)
			refs["eta"] = eta

		Ship.ShipState.AWAITING_WINDOW:
			status_lbl.text = "Ready ✓"
			status_lbl.add_theme_color_override("font_color", UIUtil.COL_GREEN)

			if ship.id not in _ship_destinations:
				_ship_destinations[ship.id] = "moon"

			var dest_row := UIUtil.make_hbox(4)
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
			var prof := FlightPlanner.plan(
				ship.origin_body, dest_str, state.elapsed_days, ship.propulsion_tier, BodyDB.new())

			vbox.add_child(UIUtil.make_label(
				"Window: %.0fd  Transit: %.1fd" % [prof.window_wait_days, prof.transit_days],
				9, UIUtil.COL_DIM))

		Ship.ShipState.IN_TRANSIT:
			var dest_name: String = DEST_LABELS.get(ship.destination_body,
				ship.destination_body.capitalize())
			status_lbl.text = "→ %s" % dest_name
			status_lbl.add_theme_color_override("font_color", UIUtil.COL_CYAN)

			var pb := ProgressBar.new()
			pb.min_value = 0.0
			var dur := maxf(0.001, ship.arrival_day - ship.mission_authorized_day)
			pb.max_value = dur
			pb.value = clampf(state.elapsed_days - ship.mission_authorized_day, 0.0, dur)
			pb.custom_minimum_size = Vector2(0, 8)
			vbox.add_child(pb)
			refs["pb"] = pb

			var eta := UIUtil.make_label(
				"ETA %.0f days" % maxf(0.0, ship.arrival_day - state.elapsed_days),
				9, UIUtil.COL_DIM)
			vbox.add_child(eta)
			refs["eta"] = eta

		Ship.ShipState.ARRIVED:
			var dest_name: String = DEST_LABELS.get(ship.destination_body,
				ship.destination_body.capitalize())
			status_lbl.text = "Arrived"
			status_lbl.add_theme_color_override("font_color", UIUtil.COL_GREEN)
			vbox.add_child(UIUtil.make_label("At %s" % dest_name, 9, UIUtil.COL_DIM))

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
