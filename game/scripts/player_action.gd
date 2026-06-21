class_name PlayerAction

# Immutable value objects representing player intent.
# Governor processes these before each tick.

enum Type {
	SET_PILLAR_ALLOCATION,
	SET_ACTIVE_RESEARCH,
	SPEND_POLITICAL_CAPITAL,
	LAUNCH_MOON_MISSION,
}

var type: int
var payload: Dictionary


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
