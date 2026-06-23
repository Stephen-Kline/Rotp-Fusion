class_name TechTreeDB

var _nodes: Dictionary = {}  # id -> TechNode
var _by_category: Dictionary = {}  # category -> Array[TechNode]


func _init() -> void:
	_load()


func _load() -> void:
	var file := FileAccess.open("res://data/tech_tree.json", FileAccess.READ)
	if not file:
		push_error("TechTreeDB: could not open tech_tree.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("TechTreeDB: JSON parse error: %s" % json.get_error_message())
		return
	for entry in json.data:
		var node := TechNode.from_dict(entry)
		_nodes[node.id] = node
		if not _by_category.has(node.category):
			_by_category[node.category] = []
		_by_category[node.category].append(node)


func get_node(id: String) -> TechNode:
	return _nodes.get(id, null)


func get_nodes_by_category(category: String) -> Array:
	return _by_category.get(category, [])


func get_all_nodes() -> Array:
	return _nodes.values()


func get_categories() -> Array:
	return _by_category.keys()


func is_available(node_id: String, completed: Array, milestone_flags: Dictionary) -> bool:
	var node := get_node(node_id)
	if not node:
		return false
	for prereq in node.prerequisites:
		if not prereq in completed:
			return false
	for m in node.required_milestones:
		if not milestone_flags.get(m, false):
			return false
	return true
