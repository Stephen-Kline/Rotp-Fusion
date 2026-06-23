extends Control

# Animated Earth placeholder driven by SimulationState.
# City lights scale with population. Clouds rotate. Atmosphere pulses with energy.
# No external assets — all procedural drawing.

const RADIUS := 220.0
const CLOUD_SPEED := 0.008  # radians per second

# Fixed city positions (normalized angle + latitude offset on surface)
const CITY_POSITIONS := [
	Vector2(0.05,  0.1),   # N. America east coast
	Vector2(0.18, -0.05),  # N. America west coast
	Vector2(0.30,  0.15),  # Europe
	Vector2(0.36,  0.05),  # Middle East
	Vector2(0.42,  0.0),   # South Asia
	Vector2(0.52,  0.1),   # SE Asia
	Vector2(0.58,  0.05),  # East Asia
	Vector2(0.65, -0.2),   # Australia
	Vector2(0.25, -0.25),  # S. America
	Vector2(0.33, -0.18),  # Africa south
	Vector2(0.35,  0.22),  # Scandinavia
	Vector2(0.55,  0.2),   # Japan/Korea
]

# Cloud arc descriptors [angle_offset, arc_width, y_offset_frac]
const CLOUD_DEFS := [
	[0.0,    0.55, -0.15],
	[1.2,    0.42,  0.30],
	[2.5,    0.60, -0.45],
	[4.0,    0.38,  0.10],
	[5.1,    0.50, -0.62],
]

var _cloud_angle: float = 0.0
var _time: float = 0.0

# State-driven values updated each tick
var _population: float = 30.0
var _energy: float = 1.0
var _completed_research: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2, RADIUS * 2)


func update_state(state: SimulationState) -> void:
	_population = state.population_units
	_energy = state.energy_capacity
	_completed_research = state.completed_research
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_cloud_angle += CLOUD_SPEED * delta
	queue_redraw()


func _draw() -> void:
	var center := Vector2(RADIUS, RADIUS)

	# Atmosphere outer glow (intensity with energy)
	var atmo_alpha := lerpf(0.06, 0.18, _energy)
	for i in 3:
		draw_circle(center, RADIUS + 18.0 - i * 5.0, Color(0.35, 0.55, 1.0, atmo_alpha * (0.5 + i * 0.25)))

	# Ocean base
	draw_circle(center, RADIUS, Color(0.12, 0.30, 0.68))

	# Land masses (crude blobs — placeholder until art arrives)
	var land := Color(0.22, 0.52, 0.24)
	draw_circle(center + Vector2(-65, -38), 82.0, land)   # Americas
	draw_circle(center + Vector2(-40, -30), 55.0, land)
	draw_circle(center + Vector2(55,  -35), 68.0, land)   # Eurasia-Africa
	draw_circle(center + Vector2(70,   10), 50.0, land)
	draw_circle(center + Vector2(45,  -10), 30.0, land)
	draw_circle(center + Vector2(90,   50), 42.0, land)   # Asia
	draw_circle(center + Vector2(88,   65), 32.0, land)
	draw_circle(center + Vector2(78,  -62), 34.0, land)   # Australia

	# Ocean rim clip — redraw a thin ring of ocean to clean up blob edges
	_draw_ring(center, RADIUS - 4.0, RADIUS, Color(0.12, 0.30, 0.68))

	# Clouds (rotating arcs)
	var cloud_col := Color(1.0, 1.0, 1.0, 0.55)
	for cloud in CLOUD_DEFS:
		_draw_cloud_arc(center, cloud[0] + _cloud_angle, cloud[1], cloud[2], cloud_col)

	# City lights — count scales with population
	var visible_cities := int(clampf(_population / 8.0, 1, CITY_POSITIONS.size()))
	for i in visible_cities:
		var cp: Vector2 = CITY_POSITIONS[i]
		# Convert (angle_frac, lat_frac) to screen position on globe surface
		var angle := cp.x * TAU + _cloud_angle * 0.05
		var lat := cp.y
		var surface_pt := center + Vector2(cos(angle), sin(angle) * 0.6 + lat) * (RADIUS * 0.88)
		if _is_on_globe(surface_pt, center):
			var pulse := 0.7 + 0.3 * sin(_time * 1.5 + i * 0.9)
			draw_circle(surface_pt, 3.5, Color(1.0, 0.92, 0.4, pulse))
			draw_circle(surface_pt, 6.0, Color(1.0, 0.85, 0.3, pulse * 0.25))

	# Terminator line (day/night shadow) — slow rotation
	var shadow_angle := _time * 0.01
	var shadow_dir := Vector2(cos(shadow_angle), sin(shadow_angle))
	draw_circle(center + shadow_dir * (RADIUS * 0.15), RADIUS * 1.0, Color(0.0, 0.0, 0.05, 0.38))

	# Polar ice caps
	draw_circle(center + Vector2(0, -RADIUS + 22), 36.0, Color(0.88, 0.94, 1.0, 0.7))
	draw_circle(center + Vector2(0,  RADIUS - 18), 28.0, Color(0.88, 0.94, 1.0, 0.6))

	# Atmosphere thin rim
	_draw_ring(center, RADIUS, RADIUS + 6.0, Color(0.5, 0.72, 1.0, 0.45))


func _draw_cloud_arc(center: Vector2, base_angle: float, arc_width: float, y_frac: float, color: Color) -> void:
	var y_offset := y_frac * RADIUS
	var pts: PackedVector2Array = []
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		var angle := base_angle + (t - 0.5) * arc_width
		var r := RADIUS * 0.72
		var pt := center + Vector2(cos(angle) * r, sin(angle) * r * 0.55 + y_offset)
		if _is_on_globe(pt, center):
			pts.append(pt)
	if pts.size() > 1:
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], color, 4.0, true)


func _draw_ring(center: Vector2, r_inner: float, r_outer: float, color: Color) -> void:
	var steps := 64
	for i in steps:
		var a0 := float(i) / steps * TAU
		var a1 := float(i + 1) / steps * TAU
		var p0 := center + Vector2(cos(a0), sin(a0)) * r_inner
		var p1 := center + Vector2(cos(a1), sin(a1)) * r_inner
		var p2 := center + Vector2(cos(a1), sin(a1)) * r_outer
		var p3 := center + Vector2(cos(a0), sin(a0)) * r_outer
		draw_colored_polygon(PackedVector2Array([p0, p1, p2, p3]), color)


func _is_on_globe(pt: Vector2, center: Vector2) -> bool:
	return pt.distance_to(center) < RADIUS - 2.0
