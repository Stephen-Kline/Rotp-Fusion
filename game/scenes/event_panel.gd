class_name EventPanel
extends PanelContainer

# Active-event panel. Shows all pending events from SimulationState.active_events.
# Each event shows: name, countdown, choice buttons.
# Emits events_appeared when going from 0→1+ events (caller should pause).
# Emits events_cleared when going from 1+→0 events (caller should resume).

signal events_appeared
signal events_cleared
signal event_choice_made(event_id: String, choice_id: String)

var _defs: Dictionary = {}                # event_id -> definition from events.json
var _content: VBoxContainer
var _countdown_labels: Dictionary = {}    # event_id -> Label
var _active_ids: Array = []              # event_ids currently rendered


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	_load_defs()

	add_theme_stylebox_override("panel",
		UIUtil.panel_style(
			Color(UIUtil.COL_NAVY.r, UIUtil.COL_NAVY.g, UIUtil.COL_NAVY.b, 0.97),
			UIUtil.COL_WARN, 1))

	var outer := UIUtil.make_vbox(0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	var hdr := UIUtil.make_hbox(0)
	outer.add_child(hdr)

	var title_lbl := UIUtil.make_label("  ACTIVE EVENTS", 12, UIUtil.COL_WARN)
	title_lbl.custom_minimum_size = Vector2(0, 34)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hdr.add_child(title_lbl)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_content = UIUtil.make_vbox(8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 8
	pad.content_margin_right = 8
	pad.content_margin_top = 6
	pad.content_margin_bottom = 6
	_content.add_theme_stylebox_override("panel", pad)
	scroll.add_child(_content)

	hide()


func refresh(state: SimulationState) -> void:
	var active: Array = []
	for inst: Dictionary in state.active_events:
		if inst.get("choice_made", "") == "":
			active.append(inst)

	var had_events := not _active_ids.is_empty()

	if active.is_empty():
		_active_ids = []
		_countdown_labels.clear()
		if had_events:
			hide()
			events_cleared.emit()
		return

	var ids: Array = active.map(func(i: Dictionary) -> String: return i.get("event_id", ""))
	if ids != _active_ids:
		var was_empty := _active_ids.is_empty()
		_active_ids = ids.duplicate()
		_rebuild(active, state.elapsed_days)
		show()
		if was_empty:
			events_appeared.emit()
	else:
		_update_countdowns(active, state.elapsed_days)


func _load_defs() -> void:
	var file := FileAccess.open("res://data/events.json", FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	for entry: Dictionary in json.data:
		_defs[str(entry.get("id", ""))] = entry


func _rebuild(active: Array, elapsed_days: float) -> void:
	for c in _content.get_children():
		c.queue_free()
	_countdown_labels.clear()

	for i in active.size():
		var inst: Dictionary  = active[i]
		var event_id: String  = inst.get("event_id", "")
		var def: Dictionary   = _defs.get(event_id, {})
		var display_name: String = def.get("display_name", event_id)
		var expiry_day: float = float(inst.get("expiry_day", 0.0))
		var days_left: int    = maxi(0, int(expiry_day - elapsed_days))

		if i > 0:
			_content.add_child(HSeparator.new())

		var name_lbl := UIUtil.make_label(display_name, 13, UIUtil.COL_AMBER)
		_content.add_child(name_lbl)

		var c_lbl := UIUtil.make_label(
			"%d days remaining" % days_left, 11,
			UIUtil.COL_WARN if days_left <= 3 else UIUtil.COL_CREAM)
		_countdown_labels[event_id] = c_lbl
		_content.add_child(c_lbl)

		var desc_text: String = def.get("description", "")
		if desc_text != "":
			var desc_lbl := UIUtil.make_label(desc_text, 11, UIUtil.COL_MUTED)
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(desc_lbl)

		var btn_row := UIUtil.make_hbox(4)
		btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(btn_row)

		for choice: Dictionary in def.get("choices", []):
			var choice_id: String = str(choice.get("id", ""))
			var btn := Button.new()
			btn.text = str(choice.get("label", choice_id))
			btn.add_theme_font_size_override("font_size", 11)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.tooltip_text = str(choice.get("description", ""))
			btn.pressed.connect(_on_choice.bind(event_id, choice_id))
			btn_row.add_child(btn)


func _update_countdowns(active: Array, elapsed_days: float) -> void:
	for inst: Dictionary in active:
		var event_id: String  = inst.get("event_id", "")
		var lbl: Label        = _countdown_labels.get(event_id, null)
		if lbl == null:
			continue
		var expiry_day: float = float(inst.get("expiry_day", 0.0))
		var days_left: int    = maxi(0, int(expiry_day - elapsed_days))
		lbl.text = "%d days remaining" % days_left
		lbl.add_theme_color_override("font_color",
			UIUtil.COL_WARN if days_left <= 3 else UIUtil.COL_CREAM)


func _on_choice(event_id: String, choice_id: String) -> void:
	event_choice_made.emit(event_id, choice_id)
