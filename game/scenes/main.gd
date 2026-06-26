extends Node

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
var _transitioning: bool = false
var _fleet_panel: FleetPanel = null


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

	ScaleEngine.zone_changed.connect(_on_zone_changed)
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

	var s: SimulationState = game_loop.state
	earth_view.update_state(s)
	minimap.update_state(s)
	toolbar.refresh(s)
	toolbar.apply_compression(Constants.CompressionLevel.PAUSED)
	budget_panel.refresh(s)
	faction_panel.refresh(s)
	tech_tree_panel.refresh(s)


func _on_tick(state: SimulationState) -> void:
	earth_view.update_state(state)
	minimap.update_state(state)
	toolbar.refresh(state)
	budget_panel.refresh(state)
	faction_panel.refresh(state)
	if tech_tree_panel.visible:
		tech_tree_panel.refresh(state)
	solar_system.update_state(state)
	if _fleet_panel.visible:
		_fleet_panel.refresh(state)
	if not _milestone1_shown and state.milestone_flags.get("moon_landing", false):
		_milestone1_shown = true
		victory_overlay.show_victory(int(state.year))
	_check_speed_unlocks(state)


func _on_zone_changed(zone: int) -> void:
	var in_earth := zone <= 2
	earth_view.visible = in_earth
	minimap.visible    = in_earth
	solar_system.visible = not in_earth
	if in_earth:
		star_field.set_camera_offset(Vector2.ZERO)


# Fade to black → swap zone → fade in. Guards against re-entrancy.
func _do_transition(to_zone: int) -> void:
	if _transitioning or to_zone == ScaleEngine.current_zone:
		return
	_transitioning = true

	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	var t1 := create_tween()
	t1.tween_property(fade_overlay, "modulate:a", 1.0, 0.25)
	await t1.finished

	ScaleEngine.transition_to(to_zone)

	var t2 := create_tween()
	t2.tween_property(fade_overlay, "modulate:a", 0.0, 0.35)
	await t2.finished
	fade_overlay.visible = false
	_transitioning = false


func _on_speed_change(level: int) -> void:
	game_loop.set_compression(level)


func _on_pause_requested() -> void:
	game_loop.pause()
	toolbar.apply_compression(Constants.CompressionLevel.PAUSED)


func _on_time_slow() -> void:
	game_loop.set_compression(Constants.CompressionLevel.SLOW)
	toolbar.apply_compression(Constants.CompressionLevel.SLOW)


# After the last queued notification is dismissed, auto-resume if we hard-stopped.
func _on_notification_dismissed() -> void:
	if game_loop.is_paused():
		game_loop.set_compression(Constants.CompressionLevel.SLOW)
		toolbar.apply_compression(Constants.CompressionLevel.SLOW)


func _check_speed_unlocks(state: SimulationState) -> void:
	for level in Constants.K_UNLOCK:
		var k_req: float = Constants.K_UNLOCK[level]
		if state.kardashev_level >= k_req and not game_loop.can_use_speed(level):
			game_loop.unlock_speed(level)
			toolbar.unlock_speed(level)


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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				get_tree().reload_current_scene()
			KEY_M:
				# M retreats one scale level: Earth ↔ Solar ↔ Near Stars ↔ Local Bubble ↔ Galactic
				var zone := ScaleEngine.current_zone
				if zone <= 2:
					_do_transition(3)
				elif zone <= 4:
					_do_transition(1)
				elif zone == 5:
					_do_transition(3)
				elif zone == 6:
					_do_transition(5)
				elif zone == 7:
					_do_transition(6)
				else:
					_do_transition(zone - 1)
