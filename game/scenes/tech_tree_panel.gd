extends Control

signal research_requested(node_id: String)

@onready var _graph: Control = $VBox/Scroll/TechGraph

var _db: TechTreeDB


func _ready() -> void:
	_db = TechTreeDB.new()
	_graph.setup(_db)
	_graph.research_requested.connect(func(id: String): research_requested.emit(id))
	hide()


func refresh(state: SimulationState) -> void:
	_graph.refresh(state)


func toggle() -> void:
	if visible:
		hide()
	else:
		show()
