extends Control

signal research_requested(node_id: String)

const STATE_LOCKED := "locked"
const STATE_AVAILABLE := "available"
const STATE_ACTIVE := "active"
const STATE_COMPLETE := "complete"

var _db: TechTreeDB
var _state: SimulationState
var _category_tabs: TabContainer
var _category_containers: Dictionary = {}  # category -> VBoxContainer

@onready var _tab_container: TabContainer = $VBox/TabContainer
@onready var _k2_notice: Label = $VBox/K2Notice


func _ready() -> void:
	_db = TechTreeDB.new()
	_build_tabs()
	hide()


func _build_tabs() -> void:
	var categories: Array = _db.get_categories()
	categories.sort()
	for cat in categories:
		var scroll := ScrollContainer.new()
		scroll.name = cat
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		_tab_container.add_child(scroll)
		_category_containers[cat] = vbox

	# K2 placeholder tab
	var k2_tab := PanelContainer.new()
	k2_tab.name = "K2+"
	var k2_label := Label.new()
	k2_label.text = "K2+ technologies become available\nafter reaching Kardashev 1 threshold."
	k2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k2_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k2_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	k2_tab.add_child(k2_label)
	_tab_container.add_child(k2_tab)


func refresh(state: SimulationState) -> void:
	_state = state
	for cat in _category_containers:
		var vbox: VBoxContainer = _category_containers[cat]
		for child in vbox.get_children():
			child.queue_free()
		for node: TechNode in _db.get_nodes_by_category(cat):
			_add_node_card(vbox, node)


func _add_node_card(parent: VBoxContainer, node: TechNode) -> void:
	var node_state := _get_node_state(node)

	var card := PanelContainer.new()
	var hbox := HBoxContainer.new()
	card.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = node.display_name
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = node.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	info.add_child(desc_label)

	if node_state == STATE_ACTIVE:
		var progress := ProgressBar.new()
		progress.min_value = 0.0
		progress.max_value = node.research_cost
		progress.value = _state.research_progress
		info.add_child(progress)

	var cost_label := Label.new()
	match node_state:
		STATE_COMPLETE:
			cost_label.text = "[Complete]"
			card.modulate = Color(0.6, 0.8, 0.6)
		STATE_ACTIVE:
			cost_label.text = "In progress…"
			card.modulate = Color(0.7, 0.9, 1.0)
		STATE_AVAILABLE:
			cost_label.text = "Cost: %.0f" % node.research_cost if node.research_cost > 0.0 else "Political"
		STATE_LOCKED:
			cost_label.text = "Locked"
			card.modulate = Color(0.5, 0.5, 0.5)
	info.add_child(cost_label)

	if node_state == STATE_AVAILABLE:
		var btn := Button.new()
		btn.text = "Research" if node.research_cost > 0.0 else "Establish"
		btn.pressed.connect(_on_research_clicked.bind(node.id))
		hbox.add_child(btn)

	parent.add_child(card)


func _get_node_state(node: TechNode) -> String:
	if node.id in _state.completed_research:
		return STATE_COMPLETE
	if _state.active_research == node.id:
		return STATE_ACTIVE
	if _db.is_available(node.id, _state.completed_research, _state.milestone_flags):
		return STATE_AVAILABLE
	return STATE_LOCKED


func _on_research_clicked(node_id: String) -> void:
	research_requested.emit(node_id)


func toggle() -> void:
	if visible:
		hide()
	else:
		show()
