class_name VictoryOverlay
extends Control

@onready var _year_label: Label = $Panel/VBox/YearLabel
@onready var _continue_btn: Button = $Panel/VBox/ContinueBtn


func _ready() -> void:
	hide()
	_continue_btn.pressed.connect(_on_continue_pressed)


func show_victory(elapsed_days: int) -> void:
	_year_label.text = "Day %d" % (elapsed_days + 1)
	show()


func _on_continue_pressed() -> void:
	hide()
