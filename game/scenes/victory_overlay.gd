class_name VictoryOverlay
extends Control

@onready var _year_label: Label = $Panel/VBox/YearLabel
@onready var _continue_btn: Button = $Panel/VBox/ContinueBtn


func _ready() -> void:
	hide()
	_continue_btn.pressed.connect(_on_continue_pressed)


func show_victory(year: int) -> void:
	_year_label.text = "Year %d" % year
	show()


func _on_continue_pressed() -> void:
	hide()
