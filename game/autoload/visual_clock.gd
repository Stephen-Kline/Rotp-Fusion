extends Node
# Central visual animation clock. All 3D views and the minimap read anim_days
# to drive orbital animations at a visually pleasing rate independent of game speed.
#
# Rate formula: target_secs = BASE_SECS * sqrt(orbital_km / REF_KM)
# This gives constant linear visual speed — wide orbits take proportionally longer.

const BODY_BASE_SECS  := 10.0
const BODY_REF_KM     := 9_376.0       # Phobos (tight reference orbit)
const SOLAR_BASE_SECS := 30.0
const SOLAR_REF_KM    := 57_909_050.0  # Mercury
const AU_TO_KM        := 149_597_870.7

var anim_days:   float = 0.0
var _rate:       float = 1.0
var _speed_mult: float = 1.0
var _paused:     bool  = true   # starts paused; game explicitly unpauses on first play


func _process(delta: float) -> void:
	if not _paused:
		anim_days += delta * _rate * _speed_mult


func set_body(body_name: String) -> void:
	var db    := BodyDB.new()
	var moons := db.get_moons(body_name)
	if moons.is_empty():
		_rate = 1.0
		return
	var fastest_period := INF
	var fastest_km     := BODY_REF_KM
	for moon: Dictionary in moons:
		var p := absf(float(moon.get("period_days", 27.0)))
		if p < fastest_period:
			fastest_period = p
			fastest_km     = float(moon.get("orbital_km", BODY_REF_KM))
	var target_secs := BODY_BASE_SECS * sqrt(fastest_km / BODY_REF_KM)
	_rate = fastest_period / target_secs


func set_solar() -> void:
	# anim_days carries over — planets keep positions across zone 3-5 transitions.
	var db      := BodyDB.new()
	var mercury := db.get_body("Mercury")
	if mercury.is_empty():
		_rate = 3.0
		return
	var period_days := float(mercury.get("orbital_period_years", 0.24085)) * 365.25
	var orbital_km  := float(mercury.get("orbital_au", 0.387)) * AU_TO_KM
	var target_secs := SOLAR_BASE_SECS * sqrt(orbital_km / SOLAR_REF_KM)
	_rate = period_days / target_secs


func set_rate(r: float) -> void:
	_rate = r


func set_speed_mult(mult: float) -> void:
	_speed_mult = mult


func set_paused(p: bool) -> void:
	_paused = p
