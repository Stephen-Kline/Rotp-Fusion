extends Node

@onready var game_loop: Node = $GameLoop
@onready var year_label: Label = $UI/EarthView/HUD/YearLabel
@onready var compression_label: Label = $UI/EarthView/HUD/CompressionLabel
@onready var event_log: Control = $UI/EarthView/EventLog
@onready var event_log_btn: Button = $UI/EarthView/HUD/HUDButtons/EventLogBtn

# Compression button references for active-state highlighting
var _compression_buttons: Array[Button] = []
var _compression_levels: Array[int] = []

# Compression level we were at before an event paused us
var _pre_pause_compression: int = Constants.CompressionLevel.SLOW


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

	# Set initial active button (SLOW = 1x is default in GameLoop)
	_update_active_button(Constants.CompressionLevel.SLOW)


func _on_tick(state: SimulationState) -> void:
	year_label.text = "Year: %d" % state.year


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
