extends Node

@onready var game_loop: Node = $GameLoop
@onready var year_label: Label = $UI/EarthView/HUD/YearLabel
@onready var compression_label: Label = $UI/EarthView/HUD/CompressionLabel


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


func _on_tick(state: SimulationState) -> void:
	year_label.text = "Year: %d" % state.year


func _set_compression(level: int) -> void:
	game_loop.set_compression(level)
	compression_label.text = "Speed: %s" % Constants.COMPRESSION_LABELS[level]


func _on_pause_requested() -> void:
	game_loop.pause()
	compression_label.text = "Speed: Paused"
