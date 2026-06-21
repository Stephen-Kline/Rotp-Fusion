class_name PlayerAction

# Immutable value objects representing player intent.
# Governor processes these before each tick.

enum Type {
	SET_PILLAR_ALLOCATION,
	SPEND_POLITICAL_CAPITAL,
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


static func spend_political_capital(faction_id: String, amount: float) -> PlayerAction:
	return PlayerAction.new(
		Type.SPEND_POLITICAL_CAPITAL,
		{"faction_id": faction_id, "amount": amount}
	)
