class_name PlayerAction

# Immutable value objects representing player intent.
# Governor processes these before each tick.

enum Type {
	SET_PILLAR_ALLOCATION,
	SET_ACTIVE_RESEARCH,
	SPEND_POLITICAL_CAPITAL,
	LAUNCH_MOON_MISSION,  # deprecated no-op; kept so old callers don't break
	BUILD_STRUCTURE,      # construct a ground/orbital structure at a body
	BUILD_SHIP,           # begin ship construction at a launch facility
	LAUNCH_SHIP,          # authorize departure of a built or orbiting ship
}

var type: int
var payload: Dictionary
var category: String  # subsystem routing hint: "economy", "research", "ships", "colony", "faction"


func _init(p_type: int, p_payload: Dictionary = {}) -> void:
	type = p_type
	payload = p_payload


# Factory helpers
static func set_pillar_allocation(
		food: float, education: float, industry: float, energy: float
) -> PlayerAction:
	return PlayerAction.new(
		Type.SET_PILLAR_ALLOCATION,
		{"food": food, "education": education, "industry": industry, "energy": energy}
	)


static func set_active_research(node_id: String) -> PlayerAction:
	return PlayerAction.new(Type.SET_ACTIVE_RESEARCH, {"node_id": node_id})


static func spend_political_capital(faction_id: String, amount: float) -> PlayerAction:
	return PlayerAction.new(
		Type.SPEND_POLITICAL_CAPITAL,
		{"faction_id": faction_id, "amount": amount}
	)


static func launch_moon_mission() -> PlayerAction:
	return PlayerAction.new(Type.LAUNCH_MOON_MISSION, {})


static func build_structure(structure_type: String, body: String = "earth") -> PlayerAction:
	return PlayerAction.new(Type.BUILD_STRUCTURE,
		{"structure_type": structure_type, "body": body})


static func build_ship(build_option: String, origin: String = "earth") -> PlayerAction:
	return PlayerAction.new(Type.BUILD_SHIP,
		{"build_option": build_option, "origin": origin})


static func launch_ship(ship_id: String, destination: String = "",
		use_direct: bool = false) -> PlayerAction:
	return PlayerAction.new(Type.LAUNCH_SHIP,
		{"ship_id": ship_id, "destination": destination, "use_direct": use_direct})
