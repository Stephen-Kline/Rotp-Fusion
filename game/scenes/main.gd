extends Node

const _ColonyPanelScript   = preload("res://scenes/colony_panel.gd")
const _ColoniesPanelScript = preload("res://scenes/colonies_panel.gd")

@onready var game_loop:       Node                = $GameLoop
@onready var toolbar:         PanelContainer      = $UI/EarthView/TopBar
@onready var budget_panel:    PanelContainer      = $UI/EarthView/BudgetDropdown
@onready var faction_panel:   PanelContainer      = $UI/EarthView/RightScroll/RightPanel/FactionPanel
@onready var event_log:       Control             = $UI/EarthView/EventLog
@onready var tech_tree_panel: Control             = $UI/TechTreePanel
@onready var victory_overlay: Control             = $UI/VictoryOverlay
@onready var earth_view:         SubViewportContainer = $UI/EarthView/EarthContainer
@onready var minimap:            Control             = $UI/EarthView/Minimap
@onready var star_field:         Control             = $UI/EarthView/Background
@onready var solar_system:       Control             = $UI/EarthView/SolarSystem
@onready var fade_overlay:       ColorRect           = $UI/FadeOverlay
@onready var notification_panel: Control             = $UI/EarthView/NotificationPanel

var _milestone1_shown: bool = false
var _fleet_panel:     FleetPanel = null
var _colony_panel:    PanelContainer = null
var _colonies_panel:  PanelContainer = null
var _solar_3d:        SubViewportContainer = null
var _planet_view:     SubViewportContainer = null
var _m_prev: bool = false
var _f5_prev: bool = false


func _ready() -> void:
	game_loop.tick_processed.connect(_on_tick)
	EventSystem.time_pause_requested.connect(_on_pause_requested)

	toolbar.speed_change_requested.connect(_on_speed_change)
	toolbar.tech_tree_toggled.connect(func():
		if not tech_tree_panel.visible:
			tech_tree_panel.refresh(game_loop.state)
		tech_tree_panel.toggle()
	)
	toolbar.event_log_toggled.connect(func():
		if event_log.visible: event_log.hide()
		else: event_log.show()
	)
	toolbar.budget_toggled.connect(func():
		if budget_panel.visible: budget_panel.hide()
		else: budget_panel.show()
	)

	tech_tree_panel.research_requested.connect(_on_research_requested)
	tech_tree_panel.get_node("VBox/Header/CloseBtn").pressed.connect(
		func(): tech_tree_panel.hide()
	)

	faction_panel.hide()
	budget_panel.allocation_changed.connect(_on_allocation_changed)
	faction_panel.spend_capital_requested.connect(_on_spend_capital)

	# Generic planet local view (zone 1 for non-Earth bodies)
	var pv_script := load("res://scenes/planet_view_3d.gd")
	_planet_view = pv_script.new() as SubViewportContainer
	_planet_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_planet_view.offset_top = 42.0
	_planet_view.visible = false
	$UI/EarthView.add_child(_planet_view)

	# 3D solar system (zones 3-7)
	var ss3d_script := load("res://scenes/solar_system_3d.gd")
	_solar_3d = ss3d_script.new() as SubViewportContainer
	_solar_3d.set_anchors_preset(Control.PRESET_FULL_RECT)
	_solar_3d.offset_top = 42.0   # below toolbar
	_solar_3d.visible = false
	$UI/EarthView.add_child(_solar_3d)
	(_solar_3d as Object).connect("zone_transition_requested", _do_transition)

	# Minimap must be the last child (highest Z) so its mouse events aren't eaten
	# by the full-rect planet_view / solar_3d containers added above.
	$UI/EarthView.move_child(minimap, $UI/EarthView.get_child_count() - 1)

	ScaleEngine.zone_changed.connect(_on_zone_changed)
	ScaleEngine.body_changed.connect(func(_b: String): _on_zone_changed(ScaleEngine.current_zone))
	minimap.body_clicked.connect(_on_minimap_body_clicked)
	solar_system.link_star_field(star_field)
	solar_system.zone_transition_requested.connect(_do_transition)
	EventSystem.time_slow_requested.connect(_on_time_slow)
	notification_panel.notification_dismissed.connect(_on_notification_dismissed)

	_fleet_panel = FleetPanel.new()
	$UI/EarthView.add_child(_fleet_panel)
	_fleet_panel.anchor_left   = 1.0
	_fleet_panel.anchor_right  = 1.0
	_fleet_panel.anchor_top    = 0.0
	_fleet_panel.anchor_bottom = 1.0
	_fleet_panel.offset_left   = -300.0
	_fleet_panel.offset_right  = 0.0
	_fleet_panel.offset_top    = 42.0
	_fleet_panel.offset_bottom = 0.0
	_fleet_panel.hide()

	toolbar.fleet_toggled.connect(func():
		if _fleet_panel.visible:
			_fleet_panel.hide()
		else:
			_fleet_panel.refresh(game_loop.state)
			_fleet_panel.show()
	)
	_fleet_panel.build_structure_requested.connect(_on_build_structure)
	_fleet_panel.build_ship_requested.connect(_on_build_ship)
	_fleet_panel.launch_ship_requested.connect(_on_launch_ship)

	# Colony panel — slides in from right when a planet body is clicked
	_colony_panel = _ColonyPanelScript.new()
	$UI/EarthView.add_child(_colony_panel)
	_colony_panel.anchor_left   = 1.0
	_colony_panel.anchor_right  = 1.0
	_colony_panel.anchor_top    = 0.0
	_colony_panel.anchor_bottom = 1.0
	_colony_panel.offset_left   = -320.0
	_colony_panel.offset_right  = 0.0
	_colony_panel.offset_top    = 42.0
	_colony_panel.offset_bottom = 0.0
	_colony_panel.hide()
	_colony_panel.build_structure_requested.connect(_on_build_structure)
	_colony_panel.demolish_structure_requested.connect(_on_demolish_structure)
	_colony_panel.research_requested.connect(_on_research_requested)

	# Colonies list panel — persistent toolbar button
	_colonies_panel = _ColoniesPanelScript.new()
	$UI/EarthView.add_child(_colonies_panel)
	_colonies_panel.anchor_left   = 1.0
	_colonies_panel.anchor_right  = 1.0
	_colonies_panel.anchor_top    = 0.0
	_colonies_panel.anchor_bottom = 1.0
	_colonies_panel.offset_left   = -200.0
	_colonies_panel.offset_right  = 0.0
	_colonies_panel.offset_top    = 42.0
	_colonies_panel.offset_bottom = 0.0
	_colonies_panel.hide()
	_colonies_panel.colony_selected.connect(_on_colony_selected)

	toolbar.colonies_toggled.connect(func():
		if _colonies_panel.visible:
			_colonies_panel.hide()
		else:
			_colonies_panel.call("refresh", game_loop.state)
			_colonies_panel.show()
	)

	# Wire planet view selection signals
	if _planet_view:
		(_planet_view as Object).connect("body_selected", _on_planet_body_selected)
		(_planet_view as Object).connect("body_deselected", _on_planet_body_deselected)

	var s: SimulationState = game_loop.state
	# earth_view (EarthContainer) retired — planet_view_3d handles Earth now
	if _planet_view:
		(_planet_view as Object).call("update_state", s)
	minimap.update_state(s)
	toolbar.refresh(s)
	toolbar.apply_speed(Constants.SPEED_PAUSE)
	budget_panel.refresh(s)
	faction_panel.refresh(s)
	tech_tree_panel.refresh(s)
	# Initialize view visibility — no zone/body signal fires at startup so set explicitly
	_on_zone_changed(ScaleEngine.current_zone)


func _process(_delta: float) -> void:
	var m_now := Input.is_key_pressed(KEY_M)
	if m_now and not _m_prev:
		_handle_map_key()
	_m_prev = m_now

	var f5_now := Input.is_key_pressed(KEY_F5)
	if f5_now and not _f5_prev:
		get_tree().reload_current_scene()
	_f5_prev = f5_now


func _handle_map_key() -> void:
	var zone := ScaleEngine.current_zone
	if zone <= 2:
		_do_transition(3)
	elif zone <= 5:
		_do_transition(1)
	elif zone == 6:
		_do_transition(3)
	elif zone == 7:
		_do_transition(6)
	elif zone == 8:
		_do_transition(7)
	else:
		_do_transition(zone - 1)


func _on_tick(state: SimulationState) -> void:
	minimap.update_state(state)
	toolbar.refresh(state)
	budget_panel.refresh(state)
	faction_panel.refresh(state)
	if tech_tree_panel.visible:
		tech_tree_panel.refresh(state)
	solar_system.update_state(state)
	if _solar_3d:
		(_solar_3d as Object).call("update_state", state)
	if _planet_view:
		(_planet_view as Object).call("update_state", state)
	if _fleet_panel.visible:
		_fleet_panel.refresh(state)
	if _colony_panel and _colony_panel.visible:
		var body_id: String = _colony_panel.get("_current_body")
		var col: ColonyState = state.colony_for(body_id)
		_colony_panel.call("refresh", col, state)
	if _colonies_panel and _colonies_panel.visible:
		_colonies_panel.call("refresh", state)
	if not _milestone1_shown and state.milestone_flags.get("moon_landing", false):
		_milestone1_shown = true
		victory_overlay.show_victory(int(state.elapsed_days))


func _on_zone_changed(zone: int) -> void:
	var body       := ScaleEngine.current_body
	var earth_body := body == "Earth" or body == ""
	var in_solar3  := zone >= 3 and zone <= 7
	var in_solar2  := zone >= 8

	# Drive VisualClock mode for the active view
	if zone <= 2:
		VisualClock.set_body(body if not earth_body else "Earth")
	elif zone <= 5:
		VisualClock.set_solar()
	else:
		VisualClock.set_rate(0.0)  # static star/galactic maps

	# Zone 1-2: unified planet_view_3d handles all bodies including Earth
	earth_view.visible = false
	minimap.visible    = zone <= 2
	if _planet_view:
		_planet_view.visible = zone <= 2
	if zone > 2 and _colony_panel and _colony_panel.visible:
		_colony_panel.hide()

	if _solar_3d:
		_solar_3d.visible = in_solar3
	solar_system.visible = in_solar2
	star_field.visible   = zone <= 7 or in_solar2   # stars behind all views except pure galactic
	if zone <= 2 and earth_body:
		star_field.set_camera_offset(Vector2.ZERO)


func _do_transition(to_zone: int) -> void:
	if to_zone == ScaleEngine.current_zone:
		return
	ScaleEngine.transition_to(to_zone)
	fade_overlay.modulate.a = 0.5
	fade_overlay.visible = true
	var t := create_tween()
	t.tween_property(fade_overlay, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): fade_overlay.visible = false)


func _on_speed_change(speed_index: int) -> void:
	game_loop.set_speed(speed_index)
	_set_views_paused(speed_index == Constants.SPEED_PAUSE)
	var base: float = Constants.DAYS_PER_SECOND.get(Constants.SPEED_1X, 1.0)
	var rate: float = Constants.DAYS_PER_SECOND.get(speed_index, base)
	VisualClock.set_speed_mult(rate / base if base > 0.0 else 1.0)


func _on_pause_requested() -> void:
	game_loop.pause()
	toolbar.apply_speed(Constants.SPEED_PAUSE)
	_set_views_paused(true)


func _on_time_slow() -> void:
	game_loop.set_speed(Constants.SPEED_1X)
	toolbar.apply_speed(Constants.SPEED_1X)
	_set_views_paused(false)
	VisualClock.set_speed_mult(1.0)


func _on_minimap_body_clicked(body: String) -> void:
	# If the body is already rendered in the local view, focus in-place (no rebuild)
	if _planet_view and _planet_view.visible:
		var handled := (_planet_view as Object).call("try_focus_local", body) as bool
		if handled:
			return
	ScaleEngine.select_body(body)
	_do_transition(1)


func _set_views_paused(paused: bool) -> void:
	VisualClock.set_paused(paused)
	if _solar_3d:
		(_solar_3d as Object).set("_paused", paused)
	if _planet_view:
		(_planet_view as Object).set("_paused", paused)


func _on_notification_dismissed() -> void:
	if game_loop.is_paused():
		game_loop.set_speed(Constants.SPEED_1X)
		toolbar.apply_speed(Constants.SPEED_1X)


func _on_allocation_changed(food: float, education: float, industry: float, energy: float) -> void:
	game_loop.queue_action(PlayerAction.set_pillar_allocation(food, education, industry, energy))


func _on_spend_capital(faction_id: String, amount: float) -> void:
	game_loop.queue_action(PlayerAction.spend_political_capital(faction_id, amount))


func _on_research_requested(node_id: String) -> void:
	game_loop.queue_action(PlayerAction.set_active_research(node_id))


func _on_build_structure(structure_type: String, body: String) -> void:
	game_loop.queue_action(PlayerAction.build_structure(structure_type, body))


func _on_build_ship(build_option: String) -> void:
	game_loop.queue_action(PlayerAction.build_ship(build_option))


func _on_launch_ship(ship_id: String, destination: String, use_direct: bool) -> void:
	game_loop.queue_action(PlayerAction.launch_ship(ship_id, destination, use_direct))


func _on_planet_body_selected(body_id: String) -> void:
	var s: SimulationState = game_loop.state as SimulationState
	var col: ColonyState   = s.colony_for(body_id)
	_colony_panel.call("show_for", body_id, col, s)
	_colonies_panel.hide()


func _on_planet_body_deselected() -> void:
	_colony_panel.hide()


func _on_colony_selected(body_id: String) -> void:
	_colonies_panel.hide()
	ScaleEngine.select_body(body_id)
	if ScaleEngine.current_zone > 2:
		_do_transition(1)
	var s: SimulationState = game_loop.state as SimulationState
	var col: ColonyState   = s.colony_for(body_id)
	_colony_panel.call("show_for", body_id, col, s)


func _on_demolish_structure(structure_type: String, body: String) -> void:
	var s: SimulationState = game_loop.state as SimulationState
	var col: ColonyState   = s.colony_for(body)
	if col == null: return
	var idx: int = col.structures.rfind(structure_type)
	if idx >= 0:
		game_loop.queue_action(PlayerAction.demolish_structure(idx, body))
