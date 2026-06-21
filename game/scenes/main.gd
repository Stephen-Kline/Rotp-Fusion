extends Node

@onready var game_loop: Node = $GameLoop
@onready var year_label: Label = $UI/EarthView/HUD/YearLabel
@onready var compression_label: Label = $UI/EarthView/HUD/CompressionLabel
@onready var dashboard: PanelContainer = $UI/EarthView/RightPanel/Dashboard
@onready var budget_panel: PanelContainer = $UI/EarthView/RightPanel/BudgetPanel


func _ready() -> void:
	game_loop.tick_processed.connect(_on_tick)
	EventSystem.time_pause_requested.connect(_on_pause_requested)

	$UI/EarthView/HUD/CompressionControls/PauseBtn.pressed.connect(
		func(): _set_compression(Constants.CompressionLevel.PAUSED))
	$UI/EarthView/HUD/CompressionControls/Btn1x.pressed.connect(
		func(): _set_compression(Constants.CompressionLevel.SLOW))
	$UI/EarthView/HUD/CompressionControls/Btn5x.pressed.connect(
		func(): _set_compression(Constants.CompressionLevel.NORMAL))
	$UI/EarthView/HUD/CompressionControls/Btn20x.pressed.connect(
		func(): _set_compression(Constants.CompressionLevel.FAST))
	$UI/EarthView/HUD/CompressionControls/Btn100x.pressed.connect(
		func(): _set_compression(Constants.CompressionLevel.FASTER))
	$UI/EarthView/HUD/CompressionControls/Btn500x.pressed.connect(
		func(): _set_compression(Constants.CompressionLevel.MAX))

	# Wire budget panel -> action queue
	budget_panel.allocation_changed.connect(_on_allocation_changed)

	# Prime the dashboard with the initial state
	dashboard.refresh(game_loop.state)
	budget_panel.refresh(game_loop.state)


func _on_tick(state: SimulationState) -> void:
	year_label.text = "Year: %d" % state.year
	dashboard.refresh(state)
	budget_panel.refresh(state)


func _on_allocation_changed(food: float, education: float, industry: float, energy: float) -> void:
	var action := PlayerAction.set_pillar_allocation(food, education, industry, energy)
	game_loop.queue_action(action)


func _set_compression(level: int) -> void:
	game_loop.set_compression(level)
	compression_label.text = "Speed: %s" % Constants.COMPRESSION_LABELS[level]


func _on_pause_requested() -> void:
	game_loop.pause()
	compression_label.text = "Speed: Paused"
