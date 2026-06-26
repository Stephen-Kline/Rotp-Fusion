extends Control
# 2D space map — zones 3+ (solar system) and 5+ (star map).
# Dispatches rendering based on ScaleEngine.current_zone.
# Emits zone_transition_requested when zoom crosses a boundary.

signal zone_transition_requested(zone: int)

const _CREAM  := Color(0.94, 0.90, 0.80)
const _ORANGE := Color(0.92, 0.48, 0.12)
const _CYAN   := Color(0.20, 0.82, 0.90)
const _DIM    := Color(0.38, 0.45, 0.58)
const _WARN   := Color(1.00, 0.28, 0.10)

# ── Solar system data ─────────────────────────────────────────────────────────
# [name, semi-major axis AU, period years, angle at 1950 deg, color, dot radius px]
const PLANETS := [
	["Mercury", 0.387,  0.24085,   37.25, Color(0.70, 0.65, 0.55), 3.0],
	["Venus",   0.723,  0.61520,  101.98, Color(0.88, 0.78, 0.45), 5.0],
	["Earth",   1.000,  1.00000,  110.46, Color(0.20, 0.55, 0.85), 5.0],
	["Mars",    1.524,  1.88085,  145.45, Color(0.80, 0.35, 0.20), 4.0],
	["Jupiter", 5.203, 11.86200,  316.90, Color(0.75, 0.60, 0.45), 9.0],
	["Saturn",  9.537, 29.45700,  158.94, Color(0.85, 0.75, 0.50), 8.0],
	["Uranus", 19.191, 84.01100,   99.23, Color(0.55, 0.80, 0.85), 6.0],
	["Neptune",30.069,164.80000,  195.88, Color(0.30, 0.45, 0.85), 6.0],
]

# ── Nearby star data (zone 5+) ────────────────────────────────────────────────
# [name, x_pc, y_pc, spectral, has_hz_planet]
# Positions in parsecs relative to Sol, approximate galactic-plane projection.
# Distances from Sol are accurate to ±0.1 pc; directions are approximate.
const NEARBY_STARS := [
	["Sol",             0.00,  0.00, "G2V", true ],
	["Alpha Centauri", -0.51, -1.20, "G2V", true ],
	["Proxima Cen",    -0.47, -1.22, "M5V", false],
	["Barnard's Star",  0.10,  1.83, "M4V", false],
	["Wolf 359",       -2.33,  0.52, "M6V", false],
	["Lalande 21185",   0.35,  2.52, "M2V", false],
	["Sirius",          1.35, -2.25, "A1V", false],
	["Luyten 726-8",   -2.62,  0.55, "M5V", false],
	["Ross 154",       -0.50,  2.93, "M4V", false],
	["Epsilon Eridani",-2.82, -1.52, "K2V", true ],
	["Ross 248",        1.20, -2.96, "M6V", false],
	["61 Cygni",        0.82,  3.41, "K5V", false],
	["Procyon",         2.45, -2.57, "F5V", false],
	["Epsilon Indi",   -1.22, -3.21, "K4V", true ],
	["Tau Ceti",       -2.20, -2.82, "G8V", true ],
]

# ── Camera state ──────────────────────────────────────────────────────────────
# _ppu = pixels per world unit at zoom=1
#   zones 3-4: AU   (80 px/AU  → Neptune at ~2400 px, good full-solar view)
#   zones 5-6: pc   (200 px/pc → nearest stars at 200-700 px)
#   zones 7+:  kpc  (150 px/kpc — future)
var _ppu: float = 80.0
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO   # world-space camera center
var _game_year: float = 1950.0
var _dragging: bool = false
var _star_field: Control = null
var _selected_star: int = -1       # index into NEARBY_STARS, -1 = none

# Zoom boundaries that trigger zone transitions
const _ZOOM_OUT_THRESHOLD := 0.055
const _ZOOM_IN_THRESHOLD  := 18.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	ScaleEngine.zone_changed.connect(_on_zone_changed)


func link_star_field(sf: Control) -> void:
	_star_field = sf


func update_state(state: SimulationState) -> void:
	_game_year = float(state.year)
	queue_redraw()


# Called by ScaleEngine when zone changes — reset camera for new coordinate space.
func _on_zone_changed(zone: int) -> void:
	_ppu = _zone_ppu(zone)
	_zoom = 1.0
	_pan = Vector2.ZERO
	_selected_star = -1
	queue_redraw()


func _zone_ppu(zone: int) -> float:
	if zone <= 4: return 80.0
	if zone <= 6: return 200.0
	return 150.0


# ── Coordinate helpers ────────────────────────────────────────────────────────

func _world_to_screen(world: Vector2) -> Vector2:
	return get_size() * 0.5 + (world - _pan) * _ppu * _zoom

func _screen_to_world(screen: Vector2) -> Vector2:
	return (screen - get_size() * 0.5) / (_ppu * _zoom) + _pan


# ── Draw dispatch ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var zone := ScaleEngine.current_zone
	if zone >= 5:
		_draw_star_map()
	else:
		_draw_solar()
	_draw_zone_label()


# ── Solar system (zones 3-4) ──────────────────────────────────────────────────

func _draw_solar() -> void:
	_draw_distance_rings([0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 50.0, 100.0], "AU")
	_draw_asteroid_belt()
	_draw_sol_dot()
	_draw_planets()


func _draw_asteroid_belt() -> void:
	var center := _world_to_screen(Vector2.ZERO)
	var r_inner := 2.2 * _ppu * _zoom
	var r_outer := 3.2 * _ppu * _zoom
	if r_inner > get_size().length() or r_outer < 20.0:
		return
	draw_arc(center, (r_inner + r_outer) * 0.5, 0.0, TAU, 256,
		Color(0.55, 0.50, 0.40, 0.12), r_outer - r_inner)


func _draw_sol_dot() -> void:
	var pos := _world_to_screen(Vector2.ZERO)
	var r := maxf(6.0, 10.0 * minf(_zoom, 2.0))
	draw_circle(pos, r, Color(1.0, 0.85, 0.30))
	draw_arc(pos, r + 2.0, 0.0, TAU, 64, Color(0.92, 0.48, 0.12, 0.35), 3.0)
	if _zoom > 0.1:
		draw_string(ThemeDB.fallback_font, pos + Vector2(r + 4.0, 4.0),
			"Sol", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _ORANGE)


func _draw_planets() -> void:
	var sz := get_size()
	var font := ThemeDB.fallback_font
	for p: Array in PLANETS:
		var pname: String     = p[0]
		var a: float          = float(p[1])
		var period: float     = float(p[2])
		var ang0: float       = float(p[3])
		var color: Color      = p[4]
		var dot_r: float      = float(p[5])

		var orbit_r := a * _ppu * _zoom
		if orbit_r >= 4.0:
			draw_arc(_world_to_screen(Vector2.ZERO), orbit_r, 0.0, TAU, 128,
				Color(color.r, color.g, color.b, 0.18), 1.0)

		var angle_rad := deg_to_rad(ang0 + (360.0 / period) * (_game_year - 1950.0))
		var sp := _world_to_screen(Vector2(cos(angle_rad), -sin(angle_rad)) * a)
		if sp.x < -50 or sp.x > sz.x + 50 or sp.y < -50 or sp.y > sz.y + 50:
			continue
		var r := maxf(2.0, dot_r * clampf(_zoom * 0.5, 0.5, 2.0))
		draw_circle(sp, r, color)
		draw_arc(sp, r + 1.0, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.5), 1.0)
		if _zoom > 0.12:
			draw_string(font, sp + Vector2(r + 3.0, 3.0),
				pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.94, 0.90, 0.80, 0.85))


# ── Star map (zones 5+) ───────────────────────────────────────────────────────

func _draw_star_map() -> void:
	_draw_distance_rings([0.5, 1.0, 2.0, 5.0, 10.0, 25.0, 50.0], "pc")
	_draw_stars()
	if _selected_star >= 0:
		_draw_star_info()


func _draw_stars() -> void:
	var sz := get_size()
	var font := ThemeDB.fallback_font
	for i in NEARBY_STARS.size():
		var s: Array = NEARBY_STARS[i]
		var sname: String  = s[0]
		var x: float       = float(s[1])
		var y: float       = float(s[2])
		var spectral: String = s[3]
		var has_hz: bool   = s[4]

		var sp := _world_to_screen(Vector2(x, -y))  # flip Y for screen coords
		if sp.x < -20 or sp.x > sz.x + 20 or sp.y < -20 or sp.y > sz.y + 20:
			continue

		var color := _star_color(spectral)
		var selected := i == _selected_star
		var is_sol := i == 0

		# Glow ring for selected or Sol
		if selected:
			draw_arc(sp, 10.0, 0.0, TAU, 64, Color(_CYAN.r, _CYAN.g, _CYAN.b, 0.6), 2.0)
		elif is_sol:
			draw_arc(sp, 9.0, 0.0, TAU, 64, Color(_ORANGE.r, _ORANGE.g, _ORANGE.b, 0.4), 2.0)

		# HZ planet indicator (faint cyan ring inside)
		if has_hz and _zoom > 0.3:
			draw_arc(sp, 7.0, 0.0, TAU, 32, Color(_CYAN.r, _CYAN.g, _CYAN.b, 0.3), 1.0)

		var r := 6.0 if is_sol else (4.5 if has_hz else 3.5)
		draw_circle(sp, r, color)

		if _zoom > 0.25 or selected:
			var lcolor := _CYAN if selected else _CREAM
			draw_string(font, sp + Vector2(r + 4.0, 4.0),
				sname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(lcolor.r, lcolor.g, lcolor.b, 0.9))


func _draw_star_info() -> void:
	var s: Array = NEARBY_STARS[_selected_star]
	var sname: String    = s[0]
	var x: float         = float(s[1])
	var y: float         = float(s[2])
	var spectral: String = s[3]
	var has_hz: bool     = s[4]

	var dist := sqrt(x * x + y * y)
	var font := ThemeDB.fallback_font
	var pad := 12.0
	var bx := get_size().x - 200.0
	var by := 50.0

	# Background panel
	draw_rect(Rect2(bx - pad, by - pad, 188.0 + pad, 90.0 + pad),
		Color(0.06, 0.10, 0.22, 0.88))
	draw_rect(Rect2(bx - pad, by - pad, 188.0 + pad, 90.0 + pad),
		Color(_CYAN.r, _CYAN.g, _CYAN.b, 0.3), false, 1.0)

	draw_string(font, Vector2(bx, by),       sname,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _CYAN)
	draw_string(font, Vector2(bx, by + 20.0),
		"%.2f pc  (%.2f ly)" % [dist, dist * 3.2616],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _CREAM)
	draw_string(font, Vector2(bx, by + 38.0), "Class: " + spectral,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _CREAM)
	draw_string(font, Vector2(bx, by + 56.0),
		"HZ planet: " + ("yes" if has_hz else "no"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		_CYAN if has_hz else Color(_DIM.r, _DIM.g, _DIM.b, 0.8))
	draw_string(font, Vector2(bx, by + 74.0), "Status: unexplored",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _DIM)


# ── Shared helpers ────────────────────────────────────────────────────────────

func _draw_distance_rings(intervals: Array, unit: String) -> void:
	var anchor := _world_to_screen(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	for r_v in intervals:
		var r_world: float = float(r_v)
		var r_px: float = r_world * _ppu * _zoom
		if r_px < 40.0 or r_px > get_size().length() * 1.2:
			continue
		draw_arc(anchor, r_px, 0.0, TAU, 128, Color(0.38, 0.45, 0.58, 0.25), 1.0)
		var lpos := anchor + Vector2(4.0, -r_px - 4.0)
		var label: String
		if r_world == floorf(r_world):
			label = "%d %s" % [int(r_world), unit]
		else:
			label = "%.2f %s" % [r_world, unit]
		draw_string(font, lpos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.38, 0.45, 0.58, 0.6))


func _draw_zone_label() -> void:
	var zone := ScaleEngine.current_zone
	var zname: String = ScaleEngine.zone_data().get("name", "Space")
	var hint: String
	if zone >= 5:
		hint = "scroll to zoom · drag to pan · click star to select · zoom in → solar system"
	else:
		hint = "scroll to zoom · drag to pan · zoom out → star map · M to return"
	draw_string(ThemeDB.fallback_font,
		Vector2(16.0, get_size().y - 12.0),
		zname + "  —  " + hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.38, 0.45, 0.58, 0.7))


func _star_color(spectral: String) -> Color:
	if spectral.is_empty(): return _CREAM
	match spectral[0]:
		"O": return Color(0.60, 0.70, 1.00)
		"B": return Color(0.70, 0.80, 1.00)
		"A": return Color(0.95, 0.95, 1.00)
		"F": return Color(1.00, 0.97, 0.85)
		"G": return Color(1.00, 0.90, 0.60)
		"K": return Color(1.00, 0.65, 0.35)
		"M": return Color(1.00, 0.40, 0.20)
	return _CREAM


# ── Input ─────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(event.position, 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.0 / 1.15)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
				else:
					# Only treat as click if no drag occurred
					if not _dragging:
						_try_select_star(event.position)
					_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_pan -= event.relative / (_ppu * _zoom)
		_push_parallax()
		queue_redraw()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var world_before := _screen_to_world(screen_pos)
	_zoom = clampf(_zoom * factor, 0.02, 30.0)
	var world_after := _screen_to_world(screen_pos)
	_pan += world_before - world_after
	_push_parallax()
	queue_redraw()
	_check_zoom_thresholds()


func _check_zoom_thresholds() -> void:
	var zone := ScaleEngine.current_zone
	if _zoom <= _ZOOM_OUT_THRESHOLD:
		# Zoom out: advance to next major zone
		if zone <= 4:
			zone_transition_requested.emit(5)   # solar → star map
		elif zone <= 6:
			zone_transition_requested.emit(7)   # star map → galactic (future)
	elif _zoom >= _ZOOM_IN_THRESHOLD:
		# Zoom in: retreat to previous major zone
		if zone >= 5:
			zone_transition_requested.emit(3)   # star map → solar


func _try_select_star(screen_pos: Vector2) -> void:
	if ScaleEngine.current_zone < 5:
		return
	var best_i := -1
	var best_d := 16.0   # pixel threshold for click
	for i in NEARBY_STARS.size():
		var s: Array = NEARBY_STARS[i]
		var sp := _world_to_screen(Vector2(float(s[1]), -float(s[2])))
		var d := screen_pos.distance_to(sp)
		if d < best_d:
			best_d = d
			best_i = i
	_selected_star = best_i
	queue_redraw()


func _push_parallax() -> void:
	if _star_field and _star_field.has_method("set_camera_offset"):
		_star_field.set_camera_offset(_pan * _ppu)
