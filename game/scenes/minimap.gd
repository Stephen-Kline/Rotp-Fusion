extends Control
# Universe minimap. Shows Earth-Moon when current_body is Earth/Moon,
# or a solar-system overview scaled to the active planet otherwise.

signal body_clicked(body_name: String)

const W := 260.0
const H := 148.0
const BG := Color(0.02, 0.02, 0.07)

# Planet catalog lives in SceneUtil.SOLAR_PLANETS — referenced directly below.

var _state: SimulationState
var _elapsed      := 0.0
var _elapsed_days := 0.0
var _hover_body   := ""


func _init() -> void:
	custom_minimum_size = Vector2(W, H)


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not (mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
		return
	var p    := mb.position
	var body := ScaleEngine.current_body
	var best_name := ""

	if body == "" or body == "Earth" or body == "Moon":
		best_name = _earth_moon_body_at(p)
	else:
		best_name = _solar_local_body_at(p, body)

	if best_name != "":
		body_clicked.emit(best_name)
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	_elapsed += _dt
	if visible:
		_update_hover()
		queue_redraw()


func _update_hover() -> void:
	var p    := get_local_mouse_position()
	var prev := _hover_body

	if p.x < 0.0 or p.x > size.x or p.y < 0.0 or p.y > size.y:
		_hover_body = ""
	else:
		var body := ScaleEngine.current_body
		if body == "" or body == "Earth" or body == "Moon":
			_hover_body = _earth_moon_body_at(p)
		else:
			_hover_body = _solar_local_body_at(p, body)

	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover_body != "" \
			else Control.CURSOR_ARROW
	if _hover_body != prev:
		queue_redraw()


func _earth_moon_body_at(p: Vector2) -> String:
	var center    := Vector2(W * 0.5, H * 0.5)
	var moon_angle := (_elapsed_days / 27.3) * TAU
	var orbit_r    := H * 0.30
	var moon_pos   := center + Vector2(cos(moon_angle), -sin(moon_angle) * 0.55) * orbit_r
	var d_earth    := p.distance_to(center)
	var d_moon     := p.distance_to(moon_pos)
	var nearest    := minf(d_earth, d_moon)
	if nearest > 30.0:
		return ""
	return "Moon" if d_moon < d_earth else "Earth"


func _solar_local_body_at(p: Vector2, body: String) -> String:
	var center   := Vector2(W * 0.5, H * 0.5)
	var max_r    := minf(W, H) * 0.44
	var au_scale := _solar_au_scale(body)
	return SceneUtil.solar_local_body_at(p, center, float(Time.get_ticks_msec()), au_scale, max_r)


func _solar_au_scale(body: String) -> float:
	return SceneUtil.solar_au_scale(body, minf(W, H) * 0.44)


func update_state(state: SimulationState) -> void:
	_state = state
	_elapsed_days = state.elapsed_days


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), BG, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.25, 0.30, 0.45, 0.5), false, 1.0)

	if _state == null:
		return

	var body := ScaleEngine.current_body
	if body == "" or body == "Earth" or body == "Moon":
		_draw_earth_moon()
	else:
		_draw_solar_local(body)


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
	# Sync to 3D view: Moon orbits every 27.3 game-days
	var moon_angle := (_elapsed_days / 27.3) * TAU

	var orbit_r := H * 0.30
	# 3D Y-rotation: +X → -Z (away from cam = north = minimap up = -Y), so Y uses -sin
	var moon_off := Vector2(cos(moon_angle), -sin(moon_angle) * 0.55) * orbit_r
	var moon_pos := center + moon_off

	# Orbit ring as ellipse matching the moon's actual path
	var orbit_pts := PackedVector2Array()
	for i in 65:
		var a := float(i) / 64.0 * TAU
		orbit_pts.append(center + Vector2(cos(a), -sin(a) * 0.55) * orbit_r)
	draw_polyline(orbit_pts, Color(0.40, 0.45, 0.60, 0.22), 0.8, false)

	# Earth
	draw_circle(center, 8.0, Color(0.08, 0.32, 0.82))
	draw_circle(center, 8.0, Color(0.18, 0.60, 0.35, 0.45))   # land tint
	draw_arc(center, 8.0, 0, TAU, 32, Color(0.35, 0.65, 1.0, 0.55), 1.2, false)

	# Moon
	draw_circle(moon_pos, 3.2, Color(0.62, 0.62, 0.65))
	draw_arc(moon_pos, 3.2, 0, TAU, 20, Color(0.8, 0.8, 0.8, 0.4), 0.8, false)

	# Hover ring (cyan, drawn before selection so selection is always on top)
	if _hover_body == "Moon":
		draw_arc(moon_pos, 7.5, 0, TAU, 24, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)
	elif _hover_body == "Earth":
		draw_arc(center, 13.0, 0, TAU, 32, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)

	# Labels
	draw_string(ThemeDB.fallback_font, center + Vector2(10.0, -7.0),
			"Earth", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.50, 0.72, 1.0, 0.85))
	draw_string(ThemeDB.fallback_font, moon_pos + Vector2(5.0, -3.0),
			"Moon", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.72, 0.72, 0.72, 0.80))

	# Selection highlight (gold) — topmost, drawn after everything else
	var cur := ScaleEngine.current_body
	if cur == "Moon":
		draw_arc(moon_pos, 6.5, 0, TAU, 24, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)
	else:
		draw_arc(center, 11.5, 0, TAU, 32, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)

	# Scale bar + label
	_scale_bar("~400,000 km")


# ── Scale: solar system centered on active body ───────────────────────────────

func _draw_solar_local(body: String) -> void:
	var center   := Vector2(W * 0.5, H * 0.5)
	var t        := Time.get_ticks_msec() / 14000.0
	var au_scale := _solar_au_scale(body)
	var max_r    := minf(W, H) * 0.44

	# Sol
	draw_circle(center, 4.0, Color(1.0, 0.90, 0.30))
	draw_circle(center, 6.5, Color(1.0, 0.72, 0.10, 0.20))
	draw_string(ThemeDB.fallback_font, center + Vector2(5.0, -3.0),
			"Sol", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.88, 0.40, 0.70))

	var cur_body := ScaleEngine.current_body
	var sel_pos  := Vector2.ZERO
	var sel_r    := 0.0

	for pd: Array in SceneUtil.SOLAR_PLANETS:
		var orbit_r: float = float(pd[1]) * au_scale
		if orbit_r > max_r * 1.1:
			continue
		draw_arc(center, orbit_r, 0, TAU, 64, Color(0.30, 0.32, 0.42, 0.18), 0.6, false)
		var angle := t / float(pd[2]) * TAU
		var pos   := center + Vector2(cos(angle), sin(angle) * 0.88) * orbit_r
		var pname := str(pd[0])
		var pr    := float(pd[4])
		draw_circle(pos, pr, pd[3] as Color)
		# Label the active body and Earth for orientation
		if pname == body or pname == "Earth":
			draw_string(ThemeDB.fallback_font, pos + Vector2(pr + 2.0, -3.0),
					pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.80, 0.80, 0.80, 0.85))
		if pname == _hover_body:
			draw_arc(pos, pr + 5.0, 0, TAU, 24, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)
		if pname == cur_body:
			sel_pos = pos; sel_r = pr

	# Selection highlight (gold) drawn last
	if sel_r > 0.0:
		draw_arc(sel_pos, sel_r + 3.5, 0, TAU, 24, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)

	# Scale bar — show the AU extent visible
	var visible_au := max_r / au_scale
	var label_str: String
	if visible_au < 2.0:
		label_str = "~%.2f AU" % visible_au
	elif visible_au < 30.0:
		label_str = "~%.1f AU" % visible_au
	else:
		label_str = "~%.0f AU" % visible_au
	_scale_bar(label_str)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _scale_bar(label: String) -> void:
	# Small scale bar at bottom
	draw_line(Vector2(8, H - 10), Vector2(38, H - 10), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(Vector2(8, H - 14), Vector2(8, H - 6), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(Vector2(38, H - 14), Vector2(38, H - 6), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(42, H - 6),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.45, 0.45, 0.55, 0.75))

	# Map title
	var body  := ScaleEngine.current_body
	var title := "EARTH SYSTEM" if (body == "" or body == "Earth" or body == "Moon") \
			else "SOLAR SYSTEM"
	draw_string(ThemeDB.fallback_font, Vector2(5, 12),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.60, 0.72, 0.80))
