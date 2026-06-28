class_name Faction
extends Resource

# Pure data — no logic. Represents one political faction in the simulation.

@export var id: String = ""
@export var display_name: String = ""
@export var ideological_type: String = ""  # technocrat/industrialist/environmentalist/internationalist/conservative
@export var preferred_pillar: String = ""  # food/education/industry/energy
@export var satisfaction: float = 50.0    # 0–100
@export var weight: float = 0.0           # 0–1, how much political capital this faction generates
@export var dissatisfied_years: float = 0.0  # accumulated years below crisis threshold

# Tracks last two satisfaction readings for trend arrow
@export var _prev_satisfaction: float = 50.0
@export var _cur_satisfaction: float = 50.0


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_ideological_type: String = "",
	p_preferred_pillar: String = "",
	p_satisfaction: float = 50.0,
	p_weight: float = 0.0
) -> void:
	id = p_id
	display_name = p_display_name
	ideological_type = p_ideological_type
	preferred_pillar = p_preferred_pillar
	satisfaction = p_satisfaction
	weight = p_weight
	_prev_satisfaction = p_satisfaction
	_cur_satisfaction = p_satisfaction


# Returns +1 (trending up), -1 (trending down), or 0 (flat)
func trend() -> int:
	var delta := _cur_satisfaction - _prev_satisfaction
	if delta > 1.0:
		return 1
	elif delta < -1.0:
		return -1
	return 0
