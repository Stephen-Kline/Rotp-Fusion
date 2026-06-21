class_name TechNode

var id: String = ""
var display_name: String = ""
var category: String = ""
var prerequisites: Array[String] = []
var required_milestones: Array[String] = []
var research_cost: float = 0.0
var unlock_payload: Dictionary = {}
var kardashev_tier: int = 1
var description: String = ""


static func from_dict(d: Dictionary) -> TechNode:
	var node := TechNode.new()
	node.id = d.get("id", "")
	node.display_name = d.get("display_name", "")
	node.category = d.get("category", "")
	node.research_cost = float(d.get("research_cost", 0.0))
	node.unlock_payload = d.get("unlock_payload", {})
	node.kardashev_tier = int(d.get("kardashev_tier", 1))
	node.description = d.get("description", "")
	for p in d.get("prerequisites", []):
		node.prerequisites.append(str(p))
	for m in d.get("required_milestones", []):
		node.required_milestones.append(str(m))
	return node
