extends Node

@onready var game_loop:      Node                = $GameLoop
@onready var toolbar:        PanelContainer      = $UI/EarthView/TopBar
@onready var budget_panel:   PanelContainer      = $UI/EarthView/RightScroll/RightPanel/BudgetPanel
@onready var faction_panel:  PanelContainer      = $UI/EarthView/RightScroll/RightPanel/FactionPanel
@onready var event_log:      Control             = $UI/EarthView/EventLog
@onready var tech_tree_panel: Control            = $UI/TechTreePanel
@onready var victory_overlay: Control            = $UI/VictoryOverlay
@onready var earth_view:     SubViewportContainer = $UI/EarthView/EarthContainer
@onready var minimap:        Control             = $UI/EarthView/Minimap

var _milestone1_shown: bool = false


func _ready() -> void:
	game_loop.tick_processed.connect(_on_tick)
	EventSystem.time_pause_requested.connect(_on_pause_requested)

	# Toolbar signals
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

	tech_tree_panel.research_requested.connect(_on_research_requested)
	tech_tree_panel.get_node("VBox/Header/CloseBtn").pressed.connect(
		func(): tech_tree_panel.hide()
	)

	faction_panel.hide()
	budget_panel.allocation_changed.connect(_on_allocation_changed)
	faction_panel.spend_capital_requested.connect(_on_spend_capital)

	# Prime all panels with initial state (game starts paused)
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
	if not _milestone1_shown and state.milestone_flags.get("moon_landing", false):
		_milestone1_shown = true
		victory_overlay.show_victory(state.year)


func _on_speed_change(level: int) -> void:
	game_loop.set_compression(level)


func _on_pause_requested() -> void:
	game_loop.pause()
	toolbar.apply_compression(Constants.CompressionLevel.PAUSED)


func _on_allocation_changed(food: float, education: float, industry: float, energy: float) -> void:
	game_loop.queue_action(PlayerAction.set_pillar_allocation(food, education, industry, energy))


func _on_spend_capital(faction_id: String, amount: float) -> void:
	game_loop.queue_action(PlayerAction.spend_political_capital(faction_id, amount))


func _on_research_requested(node_id: String) -> void:
	game_loop.queue_action(PlayerAction.set_active_research(node_id))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		get_tree().reload_current_scene()
