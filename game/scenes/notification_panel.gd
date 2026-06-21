extends Control

# Overlay notification panel. Shows one event at a time; queues the rest.
# Connects to EventSystem.notification_requested on _ready.
# Dismiss button resumes time (by emitting nothing — main.gd already wired pause/resume).

@onready var category_label: Label = $PanelContainer/VBoxContainer/CategoryLabel
@onready var message_label: Label = $PanelContainer/VBoxContainer/MessageLabel
@onready var year_label: Label = $PanelContainer/VBoxContainer/YearLabel
@onready var dismiss_btn: Button = $PanelContainer/VBoxContainer/DismissButton

var _queue: Array = []  # Array of EventSystem.EventEntry


func _ready() -> void:
	EventSystem.notification_requested.connect(_on_notification)
	dismiss_btn.pressed.connect(_on_dismiss)
	hide()


func _on_notification(entry: EventSystem.EventEntry) -> void:
	_queue.append(entry)
	if not visible:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		hide()
		return

	var entry: EventSystem.EventEntry = _queue.pop_front()
	var category_text: String = entry.category if entry.category != "" else _priority_label(entry.priority)
	category_label.text = "[%s]" % category_text
	message_label.text = entry.message
	year_label.text = "Year %d" % entry.year
	show()


func _on_dismiss() -> void:
	hide()
	_show_next()


func _priority_label(priority: int) -> String:
	match priority:
		EventSystem.Priority.CRITICAL:
			return "CRISIS"
		EventSystem.Priority.HIGH:
			return "MILESTONE"
		_:
			return "INFO"
