extends Control
# Universe minimap. Shows Earth-Moon when current_body is Earth/Moon,
# or a local planet-system view (planet + moons) for other bodies.
# Only visible in zones ≤ 2 (set by main.gd).

signal body_clicked(body_name: String)

const W  := 260.0
const H  := 148.0
const BG := Color(0.02, 0.02, 0.07)

const MOON_COLOR     := Color(0.72, 0.70, 0.68)
const MOON_RADIUS_PX := 2.5

const BODY_COLORS: Dictionary = {
	"Mercury": Color(0.65, 0.60, 0.55),
	"Venus":   Color(0.88, 0.78, 0.50),
	"Mars":    Color(0.75, 0.32, 0.18),
	"Jupiter": Color(0.82, 0.68, 0.48),
	"Saturn":  Color(0.88, 0.78, 0.52),
	"Uranus":  Color(0.55, 0.80, 0.85),
	"Neptune": Color(0.28, 0.42, 0.85),
	"Pluto":   Color(0.72, 0.62, 0.52),
	"Ceres":   Color(0.62, 0.60, 0.56),
}
const BODY_RADII_PX: Dictionary = {
	"Mercury": 2.0,
	"Venus":   3.5,
	"Mars":    2.8,
	"Jupiter": 5.0,
	"Saturn":  4.5,
	"Uranus":  3.5,
	"Neptune": 3.5,
	"Pluto":   1.5,
	"Ceres":   1.5,
}
const DEFAULT_BODY_COLOR  := Color(0.70, 0.68, 0.65)
const DEFAULT_BODY_RADIUS := 3.0

var _state:      SimulationState
var _hover_body: String = ""


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
	var p         := mb.position
	var body      := ScaleEngine.current_body
	var best_name: String
	if body == "" or body == "Earth" or body == "Moon":
		best_name = _earth_moon_body_at(p)
	else:
		best_name = _planet_local_body_at(p, body)
	if best_name != "":
		body_clicked.emit(best_name)
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if visible:
		_update_hover()
		queue_redraw()


func _update_hover() -> void:
	var p    := get_local_mouse_position()
	var prev := _hover_body
	if p.x < 0.0 or p.x > size.x or p.y < 0.0 or p.y > size.y:
		_hover_body = ""
		if _hover_body != prev:
			queue_redraw()
		return   # mouse outside — don't touch OS cursor
	var body := ScaleEngine.current_body
	if body == "" or body == "Earth" or body == "Moon":
		_hover_body = _earth_moon_body_at(p)
	else:
		_hover_body = _planet_local_body_at(p, body)
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND if _hover_body != "" \
			else DisplayServer.CURSOR_ARROW)
	if _hover_body != prev:
		queue_redraw()


func _earth_moon_body_at(p: Vector2) -> String:
	var center     := Vector2(W * 0.5, H * 0.5)
	var elapsed    := _state.elapsed_days if _state != null else 0.0
	var moon_angle := (elapsed / 27.3) * TAU
	var orbit_r    := H * 0.30
	var moon_pos   := center + Vector2(cos(moon_angle), -sin(moon_angle) * 0.55) * orbit_r
	var d_earth    := p.distance_to(center)
	var d_moon     := p.distance_to(moon_pos)
	if minf(d_earth, d_moon) > 30.0:
		return ""
	return "Moon" if d_moon < d_earth else "Earth"


func _planet_local_body_at(p: Vector2, body: String) -> String:
	var center := Vector2(W * 0.5, H * 0.5)
	var db     := BodyDB.new()
	var moons  := db.get_moons(body)
	if moons.is_empty():
		return body if p.distance_to(center) < 20.0 else ""
	var outer_km := _outer_moon_km(moons)
	var max_r    := minf(W, H) * 0.44
	var km_to_px := (max_r * 0.85) / outer_km
	var best_name := ""
	var best_dist := 20.0
	if p.distance_to(center) < best_dist:
		best_name = body
		best_dist = p.distance_to(center)
	for moon: Dictionary in moons:
		var km     := float(moon.get("orbital_km", 0.0))
		var period := float(moon.get("period_days", 27.0))
		var angle  := ((_state.elapsed_days if _state != null else 0.0) / period) * TAU
		var mpos   := center + Vector2(cos(angle), -sin(angle) * 0.55) * (km * km_to_px)
		var d      := p.distance_to(mpos)
		if d < best_dist:
			best_dist = d
			best_name = str(moon.get("id", ""))
	return best_name


func _outer_moon_km(moons: Array) -> float:
	var out := 1.0
	for moon: Dictionary in moons:
		out = maxf(out, float(moon.get("orbital_km", 0.0)))
	return out


func update_state(state: SimulationState) -> void:
	_state = state


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), BG, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.25, 0.30, 0.45, 0.5), false, 1.0)
	if _state == null:
		return
	var body := ScaleEngine.current_body
	if body == "" or body == "Earth" or body == "Moon":
		_draw_earth_moon()
	else:
		_draw_planet_local(body)


# ── Scale: Earth–Moon binary ──────────────────────────────────────────────────

func _draw_earth_moon() -> void:
	var center     := Vector2(W * 0.5, H * 0.5)
	var elapsed    := _state.elapsed_days if _state != null else 0.0
	var moon_angle := (elapsed / 27.3) * TAU
	var orbit_r    := H * 0.30
	var moon_off   := Vector2(cos(moon_angle), -sin(moon_angle) * 0.55) * orbit_r
	var moon_pos   := center + moon_off

	var orbit_pts := PackedVector2Array()
	for i in 65:
		var a := float(i) / 64.0 * TAU
		orbit_pts.append(center + Vector2(cos(a), -sin(a) * 0.55) * orbit_r)
	draw_polyline(orbit_pts, Color(0.40, 0.45, 0.60, 0.22), 0.8, false)

	draw_circle(center, 8.0, Color(0.08, 0.32, 0.82))
	draw_circle(center, 8.0, Color(0.18, 0.60, 0.35, 0.45))
	draw_arc(center, 8.0, 0, TAU, 32, Color(0.35, 0.65, 1.0, 0.55), 1.2, false)

	draw_circle(moon_pos, 3.2, Color(0.62, 0.62, 0.65))
	draw_arc(moon_pos, 3.2, 0, TAU, 20, Color(0.8, 0.8, 0.8, 0.4), 0.8, false)

	if _hover_body == "Moon":
		draw_arc(moon_pos, 7.5, 0, TAU, 24, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)
	elif _hover_body == "Earth":
		draw_arc(center, 13.0, 0, TAU, 32, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)

	draw_string(ThemeDB.fallback_font, center + Vector2(10.0, -7.0),
			"Earth", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.50, 0.72, 1.0, 0.85))
	draw_string(ThemeDB.fallback_font, moon_pos + Vector2(5.0, -3.0),
			"Moon", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.72, 0.72, 0.72, 0.80))

	var focus := ScaleEngine.local_focus
	var cur   := focus if focus != "" else ScaleEngine.current_body
	if cur == "Moon":
		draw_arc(moon_pos, 6.5, 0, TAU, 24, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)
	else:
		draw_arc(center, 11.5, 0, TAU, 32, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)

	_scale_bar("~400,000 km", "EARTH SYSTEM")


# ── Scale: local planet system ────────────────────────────────────────────────

func _draw_planet_local(body: String) -> void:
	var center   := Vector2(W * 0.5, H * 0.5)
	var db       := BodyDB.new()
	var moons    := db.get_moons(body)
	var body_col := BODY_COLORS.get(body, DEFAULT_BODY_COLOR) as Color
	var body_r   := float(BODY_RADII_PX.get(body, DEFAULT_BODY_RADIUS))

	draw_circle(center, body_r, body_col)
	draw_arc(center, body_r, 0, TAU, 32, body_col.lightened(0.3), 1.0, false)

	if _hover_body == body:
		draw_arc(center, body_r + 5.0, 0, TAU, 24, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)

	draw_string(ThemeDB.fallback_font, center + Vector2(body_r + 3.0, -3.0),
			body, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, body_col.lightened(0.2))

	if moons.is_empty():
		_scale_bar("no moons", body.to_upper() + " SYSTEM")
		return

	var outer_km := _outer_moon_km(moons)
	var max_r    := minf(W, H) * 0.44
	var km_to_px := (max_r * 0.85) / outer_km
	var focus    := ScaleEngine.local_focus
	var cur_body := focus if focus != "" else ScaleEngine.current_body

	for moon: Dictionary in moons:
		var km     := float(moon.get("orbital_km", 0.0))
		var period := float(moon.get("period_days", 27.0))
		var mname  := str(moon.get("id", "?"))
		var orbit_r := km * km_to_px

		var orbit_pts := PackedVector2Array()
		for i in 49:
			var a := float(i) / 48.0 * TAU
			orbit_pts.append(center + Vector2(cos(a), -sin(a) * 0.55) * orbit_r)
		draw_polyline(orbit_pts, Color(0.30, 0.32, 0.42, 0.20), 0.6, false)

		var angle := ((_state.elapsed_days if _state != null else 0.0) / period) * TAU
		var mpos  := center + Vector2(cos(angle), -sin(angle) * 0.55) * orbit_r
		draw_circle(mpos, MOON_RADIUS_PX, MOON_COLOR)

		if _hover_body == mname:
			draw_arc(mpos, MOON_RADIUS_PX + 4.5, 0, TAU, 20, Color(0.55, 1.0, 0.90, 0.85), 1.5, false)
		if cur_body == mname:
			draw_arc(mpos, MOON_RADIUS_PX + 3.0, 0, TAU, 20, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)

		if orbit_r > 12.0:
			draw_string(ThemeDB.fallback_font, mpos + Vector2(MOON_RADIUS_PX + 2.0, -3.0),
					mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.65, 0.65, 0.68, 0.75))

	if cur_body == body:
		draw_arc(center, body_r + 3.5, 0, TAU, 32, Color(1.0, 0.92, 0.20, 1.0), 2.0, false)

	var scale_km := roundi(outer_km)
	var km_label: String
	if scale_km >= 1_000_000:
		km_label = "~%.1f M km" % (scale_km / 1_000_000.0)
	elif scale_km >= 1_000:
		km_label = "~%d k km" % (scale_km / 1_000)
	else:
		km_label = "~%d km" % scale_km
	_scale_bar(km_label, body.to_upper() + " SYSTEM")


# ── Galaxy backdrop (always drawn faintly) ────────────────────────────────────

func _draw_galaxy_backdrop() -> void:
	var cx := W * 0.5
	var cy := H * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 77331
	for i in 120:
		var x := rng.randf() * W
		var y := rng.randf() * H
		var b := rng.randf_range(0.08, 0.30)
		draw_circle(Vector2(x, y), 0.6, Color(b, b, b + 0.05))

	var gc := Vector2(cx - 35.0, cy)
	for ring in 6:
		var t  := float(ring) / 6.0
		var rx := 70.0 * t
		var ry := 18.0 * t
		var alpha := 0.07 * (1.0 - t * 0.6)
		draw_arc(gc, rx, 0, TAU, 48, Color(0.55, 0.50, 0.75, alpha), ry * 0.9, false)
	draw_circle(gc, 6.0, Color(0.70, 0.62, 0.85, 0.12))
	draw_circle(gc, 3.0, Color(0.85, 0.78, 0.95, 0.18))
	draw_string(ThemeDB.fallback_font, gc + Vector2(-12, 14),
			"GC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 0.45, 0.65, 0.45))


# ── Sol "you are here" marker ─────────────────────────────────────────────────

func _draw_sol_indicator() -> void:
	var sol := Vector2(W * 0.5, H * 0.5)
	draw_circle(sol, 2.5, Color(1.0, 0.95, 0.60, 0.75))
	draw_arc(sol, 4.5, 0, TAU, 16, Color(1.0, 0.90, 0.50, 0.35), 1.0, false)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _scale_bar(label: String, title: String) -> void:
	draw_line(Vector2(8, H - 10), Vector2(38, H - 10), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(Vector2(8, H - 14), Vector2(8, H - 6),   Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_line(Vector2(38, H - 14), Vector2(38, H - 6), Color(0.5, 0.5, 0.6, 0.7), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(42, H - 6),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.45, 0.45, 0.55, 0.75))
	draw_string(ThemeDB.fallback_font, Vector2(5, 12),
			title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.55, 0.60, 0.72, 0.80))
