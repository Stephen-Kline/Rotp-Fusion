extends Control

# Draws orbital objects and launch effects on top of the Earth.
# Driven by SimulationState — shows what the player has actually built/researched.

const EARTH_CENTER := Vector2(220, 220)  # matches earth_placeholder RADIUS
const EARTH_RADIUS := 220.0

# Orbital radii
const ORBIT_SAT     := 255.0
const ORBIT_STATION := 275.0
const MOON_DIST     := 370.0

var _time: float = 0.0
var _completed: Array = []
var _active_research: String = ""
var _moon_mission_active: bool = false
var _moon_landing: bool = false
var _milestone_flags: Dictionary = {}

# Launch effects: list of {progress 0-1, lane float}
var _launches: Array = []
var _launch_timer: float = 0.0
const LAUNCH_INTERVAL := 4.0  # seconds between launches while researching propulsion

const PROPULSION_NODES := [
	"suborbital_flight", "orbital_satellite", "crewed_orbit",
	"long_duration_crewed", "modular_station", "expanded_station",
	"lunar_transit", "crewed_lunar_vehicle",
]


func _ready() -> void:
	custom_minimum_size = Vector2(EARTH_RADIUS * 2 + MOON_DIST, EARTH_RADIUS * 2)


func update_state(state: SimulationState) -> void:
	_completed = state.completed_research
	_active_research = state.active_research
	_moon_mission_active = state.moon_mission_active
	_moon_landing = state.milestone_flags.get("moon_landing", false)
	_milestone_flags = state.milestone_flags


func _process(delta: float) -> void:
	_time += delta

	# Spawn rocket launches when actively researching a propulsion node
	if _active_research in PROPULSION_NODES:
		_launch_timer -= delta
		if _launch_timer <= 0.0:
			_launch_timer = LAUNCH_INTERVAL * randf_range(0.7, 1.3)
			_launches.append({"progress": 0.0, "lane": randf_range(-0.3, 0.3)})

	# Advance launches
	for launch in _launches:
		launch["progress"] += delta * 0.18
	_launches = _launches.filter(func(l): return l["progress"] < 1.0)

	queue_redraw()


func _draw() -> void:
	var c := EARTH_CENTER

	# --- Orbit rings (faint guides) ---
	if "orbital_satellite" in _completed:
		_draw_orbit_ring(c, ORBIT_SAT, Color(0.4, 0.7, 1.0, 0.15))
	if "modular_station" in _completed:
		_draw_orbit_ring(c, ORBIT_STATION, Color(0.6, 0.9, 1.0, 0.18))

	# --- Satellites ---
	if "orbital_satellite" in _completed:
		var sat_angle := _time * 0.6
		var sat_pos := c + Vector2(cos(sat_angle), sin(sat_angle) * 0.4) * ORBIT_SAT
		_draw_satellite(sat_pos, sat_angle)
		if "crewed_orbit" in _completed:
			# Second crewed craft, slower, different phase
			var crew_angle := _time * 0.45 + 1.2
			var crew_pos := c + Vector2(cos(crew_angle), sin(crew_angle) * 0.4) * (ORBIT_SAT + 12)
			_draw_crewed_capsule(crew_pos, crew_angle)

	# --- Space Station ---
	if "modular_station" in _completed:
		var stn_angle := _time * 0.25 + 0.8
		var stn_pos := c + Vector2(cos(stn_angle), sin(stn_angle) * 0.4) * ORBIT_STATION
		_draw_station(stn_pos, stn_angle, "expanded_station" in _completed)

	# --- Rocket launches ---
	for launch in _launches:
		_draw_launch(launch["progress"], launch["lane"])

	# --- Moon ---
	_draw_moon(c)

	# --- Moon mission transit ---
	if _moon_mission_active:
		var t := fmod(_time * 0.07, 1.0)
		var moon_pos := _moon_screen_pos(c)
		var start := c + Vector2(0, -EARTH_RADIUS - 20)
		var craft_pos := start.lerp(moon_pos, t)
		draw_circle(craft_pos, 4.0, Color(1.0, 0.9, 0.6))
		draw_circle(craft_pos, 7.0, Color(1.0, 0.9, 0.6, 0.3))
		# Trail
		for i in 5:
			var trail_t := t - (i + 1) * 0.015
			if trail_t >= 0:
				var tp := start.lerp(moon_pos, trail_t)
				draw_circle(tp, 2.0, Color(1.0, 0.9, 0.5, 0.2 - i * 0.04))


func _draw_orbit_ring(center: Vector2, radius: float, color: Color) -> void:
	var pts: PackedVector2Array = []
	for i in 64:
		var a := float(i) / 64.0 * TAU
		pts.append(center + Vector2(cos(a), sin(a) * 0.4) * radius)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, 1.0, true)


func _draw_satellite(pos: Vector2, angle: float) -> void:
	# Tiny cross shape with solar panels
	var fwd := Vector2(cos(angle), sin(angle))
	var side := fwd.rotated(PI * 0.5)
	draw_rect(Rect2(pos - Vector2(5, 2), Vector2(10, 4)), Color(0.7, 0.8, 1.0))
	draw_line(pos - side * 9, pos + side * 9, Color(0.3, 0.5, 0.9), 3.0)
	draw_circle(pos, 2.5, Color(1.0, 0.95, 0.5))  # antenna dot


func _draw_crewed_capsule(pos: Vector2, angle: float) -> void:
	draw_circle(pos, 4.0, Color(0.85, 0.85, 0.9))
	draw_circle(pos, 5.5, Color(0.85, 0.85, 0.9, 0.3))


func _draw_station(pos: Vector2, angle: float, expanded: bool) -> void:
	var arm_len := 18.0 if expanded else 12.0
	var side := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
	var fwd  := Vector2(cos(angle), sin(angle))
	# Central hub
	draw_circle(pos, 6.0, Color(0.75, 0.82, 0.95))
	# Solar panels
	draw_line(pos - side * arm_len, pos + side * arm_len, Color(0.25, 0.45, 0.85), 5.0)
	if expanded:
		draw_line(pos - fwd * (arm_len * 0.6), pos + fwd * (arm_len * 0.6), Color(0.75, 0.82, 0.95), 4.0)
	# Glow
	draw_circle(pos, 9.0, Color(0.6, 0.8, 1.0, 0.2))


func _draw_launch(progress: float, lane: float) -> void:
	# Rocket rises from Earth surface toward orbit
	var start := EARTH_CENTER + Vector2(lane * EARTH_RADIUS * 0.5, -EARTH_RADIUS + 10)
	var end_pt := EARTH_CENTER + Vector2(lane * EARTH_RADIUS * 0.3, -(EARTH_RADIUS + 120))
	var pos := start.lerp(end_pt, progress)

	# Flame trail (fades as rocket rises)
	var trail_alpha := (1.0 - progress) * 0.8
	for i in 8:
		var trail_t := progress - (i + 1) * 0.04
		if trail_t > 0:
			var tp := start.lerp(end_pt, trail_t)
			var r := lerpf(4.0, 1.0, float(i) / 8.0)
			draw_circle(tp, r, Color(1.0, 0.55 + 0.45 * (1.0 - float(i)/8.0), 0.1, trail_alpha * (1.0 - float(i)/8.0)))

	# Rocket body
	var fwd := (end_pt - start).normalized()
	var side := fwd.rotated(PI * 0.5)
	var tip  := pos + fwd * 7
	var bl   := pos - fwd * 5 - side * 3
	var br   := pos - fwd * 5 + side * 3
	draw_colored_polygon(PackedVector2Array([tip, bl, br]), Color(0.9, 0.9, 0.95))
	# Engine glow
	draw_circle(pos - fwd * 5, 3.5, Color(1.0, 0.7, 0.2, 0.9))


func _moon_screen_pos(center: Vector2) -> Vector2:
	# Moon drifts slowly for visual interest
	var moon_angle := _time * 0.01 + 0.5
	return center + Vector2(cos(moon_angle), sin(moon_angle) * 0.3) * MOON_DIST


func _draw_moon(center: Vector2) -> void:
	var moon_pos := _moon_screen_pos(center)
	var researched := "lunar_transit" in _completed
	var landed := _moon_landing
	var glow_alpha := 0.6 if researched else 0.25
	var moon_color := Color(0.88, 0.88, 0.80) if researched else Color(0.5, 0.5, 0.47)

	if landed:
		# Victory: bright glowing moon
		draw_circle(moon_pos, 26.0, Color(1.0, 0.95, 0.7, 0.25))
		draw_circle(moon_pos, 20.0, Color(0.95, 0.92, 0.78))
		draw_circle(moon_pos, 20.0, Color(1.0, 0.98, 0.8, 0.5))
		# Flag dot
		draw_circle(moon_pos + Vector2(4, -6), 2.5, Color(1.0, 0.2, 0.2))
	else:
		if researched:
			draw_circle(moon_pos, 20.0, Color(0.7, 0.75, 1.0, 0.15))
		draw_circle(moon_pos, 16.0, moon_color)
		# Craters
		draw_circle(moon_pos + Vector2(-4, 3), 4.0, Color(0.7, 0.7, 0.65, 0.5))
		draw_circle(moon_pos + Vector2(6, -5), 3.0, Color(0.7, 0.7, 0.65, 0.4))
		draw_circle(moon_pos + Vector2(2, 7), 2.5, Color(0.7, 0.7, 0.65, 0.35))
		# Shadow side
		draw_circle(moon_pos + Vector2(5, 0), 14.0, Color(0.02, 0.02, 0.06, glow_alpha))
