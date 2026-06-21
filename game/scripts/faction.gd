class_name Faction

# Pure data — no logic. Represents one political faction in the simulation.

var id: String = ""
var display_name: String = ""
var ideological_type: String = ""  # militarist/expansionist/technocrat/cooperativist/traditionalist/isolationist
var preferred_pillar: String = ""  # food/education/industry/energy
var satisfaction: float = 50.0    # 0–100
var weight: float = 0.0           # 0–1, how much political capital this faction generates
var dissatisfied_years: int = 0   # consecutive years below crisis threshold (20)

# Tracks last two satisfaction readings for trend arrow
var _prev_satisfaction: float = 50.0
var _cur_satisfaction: float = 50.0


func _init(
	p_id: String,
	p_display_name: String,
	p_ideological_type: String,
	p_preferred_pillar: String,
	p_satisfaction: float,
	p_weight: float
) -> void:
	id = p_id
	display_name = p_display_name
	ideological_type = p_ideological_type
	preferred_pillar = p_preferred_pillar
	satisfaction = p_satisfaction
	weight = p_weight
	_prev_satisfaction = p_satisfaction
	_cur_satisfaction = p_satisfaction


func duplicate() -> Faction:
	var f := Faction.new(id, display_name, ideological_type, preferred_pillar, satisfaction, weight)
	f.dissatisfied_years = dissatisfied_years
	f._prev_satisfaction = _prev_satisfaction
	f._cur_satisfaction = _cur_satisfaction
	return f


# Returns +1 (trending up), -1 (trending down), or 0 (flat)
func trend() -> int:
	var delta := _cur_satisfaction - _prev_satisfaction
	if delta > 1.0:
		return 1
	elif delta < -1.0:
		return -1
	return 0
