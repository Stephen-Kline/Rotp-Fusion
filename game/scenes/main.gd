extends Node

@onready var game_loop: Node = $GameLoop
@onready var year_label: Label = $UI/EarthView/HUD/YearLabel
@onready var compression_label: Label = $UI/EarthView/HUD/CompressionLabel
@onready var milestone_ladder: PanelContainer = $UI/EarthView/RightScroll/RightPanel/MilestoneLadder
@onready var dashboard: PanelContainer = $UI/EarthView/RightScroll/RightPanel/Dashboard
@onready var budget_panel: PanelContainer = $UI/EarthView/RightScroll/RightPanel/BudgetPanel
@onready var gsa_panel: PanelContainer = $UI/EarthView/RightScroll/RightPanel/GsaPanel
@onready var faction_panel: PanelContainer = $UI/EarthView/RightScroll/RightPanel/FactionPanel
@onready var moon_mission_panel: MoonMissionPanel = $UI/EarthView/RightScroll/RightPanel/MoonMissionPanel
@onready var event_log: Control = $UI/EarthView/EventLog
@onready var event_log_btn: Button = $UI/EarthView/HUD/HUDButtons/EventLogBtn
@onready var tech_tree_panel: Control = $UI/TechTreePanel
@onready var tech_tree_btn: Button = $UI/EarthView/HUD/HUDButtons/TechTreeBtn
@onready var victory_overlay: Control = $UI/VictoryOverlay
@onready var earth: Control = $UI/EarthView/EarthContainer/Earth
@onready var orbital_layer: Control = $UI/EarthView/EarthContainer/OrbitalLayer

var _compression_buttons: Array[Button] = []
var _compression_levels: Array[int] = []
var _pre_pause_compression: int = Constants.CompressionLevel.SLOW
var _milestone1_shown: bool = false


func _ready() -> void:
	game_loop.tick_processed.connect(_on_tick)
	EventSystem.time_pause_requested.connect(_on_pause_requested)

	# Build the button list in level order so we can highlight the active one
	var controls := $UI/EarthView/HUD/CompressionControls
	_compression_buttons = [
		controls.get_node("PauseBtn"),
		controls.get_node("Btn1x"),
		controls.get_node("Btn5x"),
		controls.get_node("Btn20x"),
		controls.get_node("Btn100x"),
		controls.get_node("Btn500x"),
	]
	_compression_levels = [
		Constants.CompressionLevel.PAUSED,
		Constants.CompressionLevel.SLOW,
		Constants.CompressionLevel.NORMAL,
		Constants.CompressionLevel.FAST,
		Constants.CompressionLevel.FASTER,
		Constants.CompressionLevel.MAX,
	]

	# Wire compression buttons
	_compression_buttons[0].pressed.connect(func(): _set_compression(Constants.CompressionLevel.PAUSED))
	_compression_buttons[1].pressed.connect(func(): _set_compression(Constants.CompressionLevel.SLOW))
	_compression_buttons[2].pressed.connect(func(): _set_compression(Constants.CompressionLevel.NORMAL))
	_compression_buttons[3].pressed.connect(func(): _set_compression(Constants.CompressionLevel.FAST))
	_compression_buttons[4].pressed.connect(func(): _set_compression(Constants.CompressionLevel.FASTER))
	_compression_buttons[5].pressed.connect(func(): _set_compression(Constants.CompressionLevel.MAX))

	# Event log toggle
	event_log_btn.pressed.connect(_on_event_log_toggled)

	# Tech tree toggle and research action wiring
	tech_tree_btn.pressed.connect(func(): tech_tree_panel.toggle())
	tech_tree_panel.research_requested.connect(_on_research_requested)
	tech_tree_panel.get_node("VBox/Header/CloseBtn").pressed.connect(func(): tech_tree_panel.hide())

	# Game starts paused so player can orient before time runs
	_update_active_button(Constants.CompressionLevel.PAUSED)

	# Wire budget panel -> action queue
	budget_panel.allocation_changed.connect(_on_allocation_changed)

	# Wire faction panel -> action queue
	faction_panel.spend_capital_requested.connect(_on_spend_capital)

	# Wire GSA panel -> action queue
	gsa_panel.gsa_establish_requested.connect(_on_gsa_establish)

	# Wire moon mission panel
	moon_mission_panel.mission_launch_requested.connect(_on_moon_mission_launch)

	# Prime the dashboard and visual layer with the initial state
	earth.update_state(game_loop.state)
	orbital_layer.update_state(game_loop.state)
	milestone_ladder.refresh(game_loop.state)
	dashboard.refresh(game_loop.state)
	budget_panel.refresh(game_loop.state)
	gsa_panel.refresh(game_loop.state)
	faction_panel.refresh(game_loop.state)
	moon_mission_panel.refresh(game_loop.state)


func _on_tick(state: SimulationState) -> void:
	year_label.text = "Year: %d" % state.year
	earth.update_state(state)
	orbital_layer.update_state(state)
	milestone_ladder.refresh(state)
	dashboard.refresh(state)
	budget_panel.refresh(state)
	gsa_panel.refresh(state)
	faction_panel.refresh(state)
	moon_mission_panel.refresh(state)
	if tech_tree_panel.visible:
		tech_tree_panel.refresh(state)
	if not _milestone1_shown and state.milestone_flags.get("moon_landing", false):
		_milestone1_shown = true
		victory_overlay.show_victory(state.year)


func _on_allocation_changed(food: float, education: float, industry: float, energy: float) -> void:
	var action := PlayerAction.set_pillar_allocation(food, education, industry, energy)
	game_loop.queue_action(action)


func _on_spend_capital(faction_id: String, amount: float) -> void:
	var action := PlayerAction.spend_political_capital(faction_id, amount)
	game_loop.queue_action(action)


func _on_moon_mission_launch() -> void:
	game_loop.queue_action(PlayerAction.launch_moon_mission())


func _set_compression(level: int) -> void:
	_pre_pause_compression = level
	game_loop.set_compression(level)
	compression_label.text = "Speed: %s" % Constants.COMPRESSION_LABELS[level]
	_update_active_button(level)


func _on_pause_requested() -> void:
	# Remember what we were running at before pausing
	_pre_pause_compression = game_loop.compression if not game_loop.is_paused() else _pre_pause_compression
	game_loop.pause()
	compression_label.text = "Speed: %s" % Constants.COMPRESSION_LABELS[Constants.CompressionLevel.PAUSED]
	_update_active_button(Constants.CompressionLevel.PAUSED)


func _update_active_button(active_level: int) -> void:
	for i in _compression_buttons.size():
		var btn: Button = _compression_buttons[i]
		var is_active: bool = _compression_levels[i] == active_level
		btn.button_pressed = is_active


func _on_event_log_toggled() -> void:
	if event_log.visible:
		event_log.hide()
	else:
		event_log.show()


func _on_research_requested(node_id: String) -> void:
	game_loop.queue_action(PlayerAction.set_active_research(node_id))


func _on_gsa_establish() -> void:
	game_loop.queue_action(PlayerAction.set_active_research("global_space_agency"))
