extends Control
# 2D solar system map. Free-camera pan/zoom with real-time planetary orbits.
# Activated when ScaleEngine transitions to zone 3+ (Inner Solar and beyond).

const _NAVY  := Color(0.04, 0.06, 0.16)
const _CREAM := Color(0.94, 0.90, 0.80)
const _ORANGE := Color(0.92, 0.48, 0.12)
const _CYAN  := Color(0.20, 0.82, 0.90)
const _DIM   := Color(0.38, 0.45, 0.58)

# [name, semi-major axis AU, orbital period years, initial angle at 1950 (degrees), color, dot radius px]
# Initial angles computed from J2000 mean longitudes minus 50 years of mean motion.
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

# pixels per AU at zoom = 1.0. Inner planets visible at default zoom.
const BASE_PPU := 80.0
const ZOOM_MIN := 0.04
const ZOOM_MAX := 30.0

var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO  # in AU, world-space camera center
var _game_year: float = 1950.0
var _dragging: bool = false
var _star_field: Control = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func link_star_field(sf: Control) -> void:
	_star_field = sf


func update_state(state: SimulationState) -> void:
	_game_year = float(state.year)
	queue_redraw()


# ── Coordinate helpers ────────────────────────────────────────────────────────

func _world_to_screen(au: Vector2) -> Vector2:
	return get_size() * 0.5 + (au - _pan) * BASE_PPU * _zoom


# ── Draw ──────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_rings()
	_draw_asteroid_belt()
	_draw_sun()
	_draw_planets()
	_draw_zone_label()


func _draw_rings() -> void:
	# Adaptive ring intervals: show rings that land between 40px and screen diagonal.
	const ALL_INTERVALS: Array[float] = [0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 30.0, 50.0, 100.0]
	var sun_screen := _world_to_screen(Vector2.ZERO)
	var font := ThemeDB.fallback_font
	var unit: String = ScaleEngine.zone_data().get("unit", "AU")

	for r_au: float in ALL_INTERVALS:
		var r_px: float = r_au * BASE_PPU * _zoom
		if r_px < 40.0 or r_px > get_size().length() * 1.2:
			continue
		draw_arc(sun_screen, r_px, 0.0, TAU, 128, Color(0.38, 0.45, 0.58, 0.25), 1.0)
		# Label at top of ring
		var lpos := sun_screen + Vector2(4.0, -r_px - 4.0)
		var label: String
		if r_au == floorf(r_au):
			label = "%d %s" % [int(r_au), unit]
		else:
			label = "%.2f %s" % [r_au, unit]
		draw_string(font, lpos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.38, 0.45, 0.58, 0.6))


func _draw_asteroid_belt() -> void:
	# Faint visual band between Mars and Jupiter (2.2–3.2 AU)
	var sun_screen := _world_to_screen(Vector2.ZERO)
	var r_inner := 2.2 * BASE_PPU * _zoom
	var r_outer := 3.2 * BASE_PPU * _zoom
	if r_inner > get_size().length() or r_outer < 20.0:
		return
	draw_arc(sun_screen, (r_inner + r_outer) * 0.5, 0.0, TAU, 256,
		Color(0.55, 0.50, 0.40, 0.12), r_outer - r_inner)


func _draw_sun() -> void:
	var sun_screen := _world_to_screen(Vector2.ZERO)
	var r := maxf(6.0, 10.0 * minf(_zoom, 2.0))
	draw_circle(sun_screen, r, Color(1.0, 0.85, 0.30))
	draw_arc(sun_screen, r + 2.0, 0.0, TAU, 64, Color(0.92, 0.48, 0.12, 0.35), 3.0)
	if _zoom > 0.1:
		draw_string(ThemeDB.fallback_font, sun_screen + Vector2(r + 4.0, 4.0),
			"Sol", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, _ORANGE)


func _draw_planets() -> void:
	var sz := get_size()
	var font := ThemeDB.fallback_font

	for p: Array in PLANETS:
		var pname: String     = p[0]
		var a: float          = float(p[1])
		var period: float     = float(p[2])
		var angle_1950: float = float(p[3])
		var color: Color      = p[4]
		var dot_r: float      = float(p[5])

		# Orbit ring
		var orbit_center := _world_to_screen(Vector2.ZERO)
		var orbit_r := a * BASE_PPU * _zoom
		if orbit_r >= 4.0:
			draw_arc(orbit_center, orbit_r, 0.0, TAU, 128,
				Color(color.r, color.g, color.b, 0.18), 1.0)

		# Current position from real-time orbital angle
		var angle_deg := angle_1950 + (360.0 / period) * (_game_year - 1950.0)
		var angle_rad := deg_to_rad(angle_deg)
		# -sin for screen Y (Y increases downward)
		var world_pos := Vector2(cos(angle_rad), -sin(angle_rad)) * a
		var screen_pos := _world_to_screen(world_pos)

		# Skip if off-screen
		if screen_pos.x < -50 or screen_pos.x > sz.x + 50 \
				or screen_pos.y < -50 or screen_pos.y > sz.y + 50:
			continue

		var r := maxf(2.0, dot_r * clampf(_zoom * 0.5, 0.5, 2.0))
		draw_circle(screen_pos, r, color)
		draw_arc(screen_pos, r + 1.0, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.5), 1.0)

		if _zoom > 0.12:
			draw_string(font, screen_pos + Vector2(r + 3.0, 3.0),
				pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.94, 0.90, 0.80, 0.85))


func _draw_zone_label() -> void:
	var zdata := ScaleEngine.zone_data()
	var label: String = zdata.get("name", "Solar System")
	draw_string(ThemeDB.fallback_font, Vector2(16.0, get_size().y - 12.0),
		label + "  —  scroll to zoom · drag to pan · M to return",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.38, 0.45, 0.58, 0.7))


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
				_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pan -= event.relative / (BASE_PPU * _zoom)
		_push_parallax()
		queue_redraw()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var world_before := (screen_pos - get_size() * 0.5) / (BASE_PPU * _zoom) + _pan
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var world_after := (screen_pos - get_size() * 0.5) / (BASE_PPU * _zoom) + _pan
	_pan += world_before - world_after
	_push_parallax()
	queue_redraw()


func _push_parallax() -> void:
	if _star_field and _star_field.has_method("set_camera_offset"):
		_star_field.set_camera_offset(_pan * BASE_PPU)
