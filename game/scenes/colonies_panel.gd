class_name ColoniesPanel
extends PanelContainer

signal colony_selected(body_id: String)

const _WIDTH := 200.0

var _list: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(_WIDTH, 0)
	add_theme_stylebox_override("panel",
		UIUtil.panel_style(Color(UIUtil.COL_NAVY.r, UIUtil.COL_NAVY.g, UIUtil.COL_NAVY.b, 0.96),
		Color(UIUtil.COL_CREAM.r, UIUtil.COL_CREAM.g, UIUtil.COL_CREAM.b, 0.12), 1))

	var outer := UIUtil.make_vbox(0)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	var header := UIUtil.make_hbox(0)
	outer.add_child(header)

	var title := UIUtil.make_label("  COLONIES", 12, UIUtil.COL_ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.custom_minimum_size   = Vector2(0, 34)
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.add_theme_color_override("font_color", UIUtil.COL_DIM)
	close_btn.custom_minimum_size = Vector2(28, 0)
	close_btn.pressed.connect(hide)
	header.add_child(close_btn)

	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_list = UIUtil.make_vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := StyleBoxEmpty.new()
	pad.content_margin_left = 8; pad.content_margin_right = 8
	pad.content_margin_top = 6; pad.content_margin_bottom = 6
	_list.add_theme_stylebox_override("panel", pad)
	scroll.add_child(_list)


func refresh(sim: SimulationState) -> void:
	for c in _list.get_children(): c.queue_free()

	if sim.colonies.is_empty():
		_list.add_child(UIUtil.make_label("No colonies.", 10, UIUtil.COL_DIM))
		return

	for col: ColonyState in sim.colonies:
		var btn := Button.new()
		btn.text = col.body_id
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 11)
		btn.add_theme_color_override("font_color", UIUtil.COL_CREAM)
		btn.add_theme_color_override("font_hover_color", UIUtil.COL_CYAN)

		var tier     := _env_tier(col.environment)
		var tier_col := _tier_color(tier)
		btn.tooltip_text = "%s  •  Env: %s (%.0f)" % [col.body_id, tier, col.environment]

		var body_id := col.body_id
		btn.pressed.connect(func(): colony_selected.emit(body_id))
		_list.add_child(btn)


func _env_tier(env: float) -> String:
	if env >= 80.0: return "Healthy"
	if env >= 50.0: return "Stressed"
	if env >= 20.0: return "Critical"
	return "Collapse"


func _tier_color(tier: String) -> Color:
	match tier:
		"Healthy":  return Color(0.25, 0.85, 0.35)
		"Stressed": return Color(0.95, 0.85, 0.10)
		"Critical": return Color(0.95, 0.50, 0.10)
	return Color(0.88, 0.15, 0.15)
