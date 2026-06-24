extends Control
# Universe minimap. Background: faint Milky Way (always visible).
# Foreground scale increases as exploration milestones unlock.

const W := 260.0
const H := 148.0
const BG := Color(0.02, 0.02, 0.07)

var _state: SimulationState
var _elapsed := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)


func _ready() -> void:
	set_process(true)


func _process(dt: float) -> void:
	_elapsed += dt
	if visible:
		queue_redraw()


func update_state(state: SimulationState) -> void:
	_state = state


func _draw() -> void:
	# Solid background
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), BG, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.25, 0.30, 0.45, 0.5), false, 1.0)

	_draw_galaxy_backdrop()

	if _state == null:
		return

	if _state.milestone_flags.get("lunar_transit", false):
		_draw_inner_solar_system()
	else:
		_draw_earth_moon()

	_draw_sol_indicator()


# ── Galaxy backdrop (always drawn faintly) ────────────────────────────────────

func _draw_galaxy_backdrop() -> void:
	var cx := W * 0.5
	var cy := H * 0.5
	# Faint stars scattered across the map
	var rng := RandomNumberGenerator.new()
	rng.seed = 77331
	for i in 120:
		var x := rng.randf() * W
		var y := rng.randf() * H
		var b := rng.randf_range(0.08, 0.30)
		draw_circle(Vector2(x, y), 0.6, Color(b, b, b + 0.05))

	# Milky Way disc — top-down ellipse, very faint
	# Centre of galaxy ~35px left of minimap centre (we're in the Orion arm)
	var gc := Vector2(cx - 35.0, cy)
	for ring in 6:
		var t := float(ring) / 6.0
		var rx := 70.0 * t
		var ry := 18.0 * t
		var alpha := 0.07 * (1.0 - t * 0.6)
		draw_arc(gc, rx, 0, TAU, 48, Color(0.55, 0.50, 0.75, alpha), ry * 0.9, false)
	# Brighter galactic core
	draw_circle(gc, 6.0, Color(0.70, 0.62, 0.85, 0.12))
	draw_circle(gc, 3.0, Color(0.85, 0.78, 0.95, 0.18))

	# "Galactic centre" label
	draw_string(ThemeDB.fallback_font, gc + Vector2(-12, 14),
			"GC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.45, 0.65, 0.45))


# ── Sol "you are here" marker ─────────────────────────────────────────────────

func _draw_sol_indicator() -> void:
	# Sol sits ~35px right of galactic centre, which puts it near minimap centre
	var sol := Vector2(W * 0.5, H * 0.5)
	draw_circle(sol, 2.5, Color(1.0, 0.95, 0.60, 0.75))
	draw_arc(sol, 4.5, 0, TAU, 16, Color(1.0, 0.90, 0.50, 0.35), 1.0, false)


# ── Scale: Earth–Moon binary ──────────────────────────────────────────────────

func _draw_earth_moon() -> void:
	var center := Vector2(W * 0.5, H * 0.5)
	# Sync to 3D view: moon_orbit rotates at 2.8 deg/s, both start at elapsed=0
	var moon_angle := _elapsed * (2.8 * TAU / 360.0)

	var orbit_r := H * 0.30
	# Tilt orbit slightly (Moon's orbit is inclined — represent as ellipse)
	# Negate Y: in top-down map view, +Z world (far side) = up in minimap
	var moon_off := Vector2(cos(moon_angle), -sin(moon_angle) * 0.55) * orbit_r
	var moon_pos := center + moon_off

	# Orbit ring
	draw_arc(center, orbit_r, 0, TAU, 64,
			Color(0.40, 0.45, 0.60, 0.22), 0.8, false)

	# Earth
	draw_circle(center, 8.0, Color(0.08, 0.32, 0.82))
	draw_circle(center, 8.0, Color(0.18, 0.60, 0.35, 0.45))   # land tint
	draw_arc(center, 8.0, 0, TAU, 32, Color(0.35, 0.65, 1.0, 0.55), 1.2, false)

	# Moon
	draw_circle(moon_pos, 3.2, Color(0.62, 0.62, 0.65))
	draw_arc(moon_pos, 3.2, 0, TAU, 20, Color(0.8, 0.8, 0.8, 0.4), 0.8, false)

	# Labels
	draw_string(ThemeDB.fallback_font, center + Vector2(10.0, -7.0),
			"Earth", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.50, 0.72, 1.0, 0.85))
	draw_string(ThemeDB.fallback_font, moon_pos + Vector2(5.0, -3.0),
			"Moon", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.72, 0.72, 0.72, 0.80))

	# Scale bar + label
	_scale_bar("~400,000 km")


# ── Scale: inner solar system ─────────────────────────────────────────────────

func _draw_inner_solar_system() -> void:
	var center := Vector2(W * 0.5, H * 0.5)
	var t := Time.get_ticks_msec() / 14000.0

	# Sun
	draw_circle(center, 5.5, Color(1.0, 0.90, 0.30))
	draw_circle(center, 8.0, Color(1.0, 0.72, 0.10, 0.20))

	var scale_px := H / 115.0
	var planets: Array[Dictionary] = [
		{"name": "Mercury", "au": 14.0, "period": 0.24,  "col": Color(0.70, 0.60, 0.50), "r": 1.6},
		{"name": "Venus",   "au": 22.0, "period": 0.615, "col": Color(0.90, 0.82, 0.50), "r": 2.2},
		{"name": "Earth",   "au": 31.0, "period": 1.0,   "col": Color(0.18, 0.50, 0.90), "r": 2.4},
		{"name": "Mars",    "au": 46.0, "period": 1.88,  "col": Color(0.80, 0.30, 0.18), "r": 1.8},
	]

	for p: Dictionary in planets:
		var orbit_r: float = p["au"] * scale_px
		draw_arc(center, orbit_r, 0, TAU, 64,
				Color(0.30, 0.32, 0.42, 0.18), 0.6, false)
		var angle := t / float(p["period"]) * TAU
		var pos := center + Vector2(cos(angle), sin(angle) * 0.88) * orbit_r
		draw_circle(pos, p["r"], p["col"])
		if p["name"] == "Earth":
			draw_string(ThemeDB.fallback_font, pos + Vector2(4.0, -3.0),
					"Earth", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.50, 0.72, 1.0, 0.85))

	_scale_bar("~300 M km")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _scale_bar(label: String) -> void:
	# Small scale bar at bottom
	draw_line(Vector2(8, H - 10), Vector2(38, H - 10), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(Vector2(8, H - 14), Vector2(8, H - 6), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(Vector2(38, H - 14), Vector2(38, H - 6), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(42, H - 6),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.45, 0.45, 0.55, 0.75))

	# Map title
	var title := "INNER SOLAR SYSTEM" if _state and _state.milestone_flags.get("lunar_transit", false) \
			else "LOCAL SYSTEM"
	draw_string(ThemeDB.fallback_font, Vector2(5, 12),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.60, 0.72, 0.80))
