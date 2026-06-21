extends Control

# Event log panel. Toggled open/closed by a HUD button.
# Connects to EventSystem.event_logged on _ready.
# Shows all events in reverse-chronological order. Does NOT pause time.

@onready var scroll_container: ScrollContainer = $PanelContainer/VBoxContainer/ScrollContainer
@onready var log_list: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/LogList
@onready var close_btn: Button = $PanelContainer/VBoxContainer/HeaderRow/CloseButton


func _ready() -> void:
	EventSystem.event_logged.connect(_on_event_logged)
	close_btn.pressed.connect(hide)
	hide()

	# Populate with any events already in the log (if opened after events fired)
	for entry in EventSystem.get_log():
		_add_entry(entry)


func _on_event_logged(entry: EventSystem.EventEntry) -> void:
	_add_entry(entry)


func _add_entry(entry: EventSystem.EventEntry) -> void:
	var label := Label.new()
	var category_text: String = entry.category if entry.category != "" else _priority_label(entry.priority)
	label.text = "[%d] [%s] %s" % [entry.year, category_text, entry.message]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.theme_override_font_sizes = {}
	label.add_theme_font_size_override("font_size", 13)

	# Insert at top (index 0) for reverse-chronological order
	log_list.add_child(label)
	log_list.move_child(label, 0)

	# Scroll to top to show newest entry
	await get_tree().process_frame
	scroll_container.scroll_vertical = 0


func _priority_label(priority: int) -> String:
	match priority:
		EventSystem.Priority.CRITICAL:
			return "CRISIS"
		EventSystem.Priority.HIGH:
			return "MILESTONE"
		_:
			return "INFO"
