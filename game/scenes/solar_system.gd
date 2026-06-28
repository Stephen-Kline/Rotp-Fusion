extends Control
# 2D space map — zones 3-5 (solar system), 6-7 (star map), 8-10 (galactic).
# Dispatches rendering based on ScaleEngine.current_zone.
# Emits zone_transition_requested when zoom crosses a boundary.

signal zone_transition_requested(zone: int)

const _CREAM  := Color(0.94, 0.90, 0.80)
const _ORANGE := Color(0.92, 0.48, 0.12)
const _CYAN   := Color(0.20, 0.82, 0.90)
const _DIM    := Color(0.38, 0.45, 0.58)

# ── Solar system bodies ───────────────────────────────────────────────────────
# [name, semi-major axis AU, period years, angle at 1950 deg, color, dot radius px]
const PLANETS := [
	["Mercury", 0.387,   0.24085,   37.25, Color(0.70, 0.65, 0.55), 3.0],
	["Venus",   0.723,   0.61520,  101.98, Color(0.88, 0.78, 0.45), 5.0],
	["Earth",   1.000,   1.00000,  110.46, Color(0.20, 0.55, 0.85), 5.0],
	["Mars",    1.524,   1.88085,  145.45, Color(0.80, 0.35, 0.20), 4.0],
	["Ceres",   2.770,   4.60700,  295.00, Color(0.65, 0.62, 0.58), 2.0],
	["Jupiter", 5.203,  11.86200,  316.90, Color(0.75, 0.60, 0.45), 9.0],
	["Saturn",  9.537,  29.45700,  158.94, Color(0.85, 0.75, 0.50), 8.0],
	["Uranus", 19.191,  84.01100,   99.23, Color(0.55, 0.80, 0.85), 6.0],
	["Neptune",30.069, 164.80000,  195.88, Color(0.30, 0.45, 0.85), 6.0],
	["Pluto",  39.480, 247.94000,  166.00, Color(0.72, 0.62, 0.55), 2.0],
]

# Moon systems — shown as mini overlay when planet is clicked to focus.
# [name, dist_AU from host, period_yr, angle_at_1950 deg, color, dot_r px]
const MOONS := {
	"Earth": [
		["Moon",     0.002570, 0.074800,   0.0, Color(0.88, 0.88, 0.80), 3.0],
	],
	"Jupiter": [
		["Io",       0.002819, 0.004843,   0.0, Color(0.92, 0.82, 0.40), 2.5],
		["Europa",   0.004485, 0.009722,  90.0, Color(0.80, 0.72, 0.65), 2.0],
		["Ganymede", 0.007155, 0.019590, 180.0, Color(0.70, 0.65, 0.55), 3.0],
		["Callisto", 0.012585, 0.045670, 270.0, Color(0.55, 0.52, 0.48), 2.5],
	],
	"Saturn": [
		["Titan",    0.008168, 0.043640,  45.0, Color(0.88, 0.75, 0.45), 2.5],
	],
}

# Fixed pixel radius for outermost moon in the mini moon-system overlay.
const MOON_SYSTEM_RADIUS_PX := 80.0

# ── Nearby star data (zones 6-7) ──────────────────────────────────────────────
# [name, x_pc, y_pc, spectral, has_hz_planet]
# Positions in parsecs relative to Sol. Distances accurate to ~0.1 pc.
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

# ── Galactic map data (zones 8-10) ────────────────────────────────────────────
# Sol sits in the Orion Spur at ~8.5 kpc from galactic center.
# World coords: galactic center at (0,0) kpc; Y positive = down on screen.
const SOL_GALACTIC_POS := Vector2(0.0, 8.5)   # kpc from galactic center

const GALAXY_B := 0.25
const GALACTIC_RADIUS := 14.0   # kpc, visual clip radius

# [name, r0_kpc, theta0_rad, n_turns, color, width_kpc, is_sol_arm]
const GALAXY_ARMS := [
	["Sagittarius-Carina", 2.30, 0.50, 1.5, Color(0.62, 0.52, 0.34), 1.2, false],
	["Scutum-Centaurus",   2.30, 2.07, 1.5, Color(0.58, 0.48, 0.30), 1.2, false],
	["Perseus",            8.00, 3.64, 1.2, Color(0.65, 0.55, 0.36), 1.0, false],
	["Norma-Outer",        8.00, 5.21, 1.2, Color(0.60, 0.50, 0.32), 1.0, false],
	["Orion Spur",         7.50, 4.21, 0.30, Color(0.90, 0.82, 0.54), 0.7, true ],
]

# Named regions visible in zone 8 (Orion Arm) view.
const GALACTIC_LANDMARKS := [
	["Galactic Centre", 0.0,  0.0],
	["Orion Nebula",    0.42, 8.92],
	["Crab Nebula",    -1.93, 7.30],
	["Vela SNR",       -0.88, 9.82],
]

# ── Camera state ──────────────────────────────────────────────────────────────
# Pixels per world unit at zoom=1:
#   zones 3-5: AU (80 px/AU)
#   zones 6-7: pc (200 px/pc)
#   zones 8-10: kpc (50 px/kpc)
var _ppu: float = 80.0
var _zoom: float = 1.0
var _pan: Vector2 = Vector2.ZERO
var _elapsed_days: float = 0.0
var _dragging: bool = false
var _drag_origin: Vector2 = Vector2.ZERO
var _pan_origin: Vector2 = Vector2.ZERO
var _did_drag: bool = false
var _star_field: Control = null
var _selected_star: int = -1
var _focused_planet: String = ""   # which planet is click-focused for moon display

const _ZOOM_OUT_THRESHOLD := 0.055
const _ZOOM_IN_THRESHOLD  := 18.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	ScaleEngine.zone_changed.connect(_on_zone_changed)


func link_star_field(sf: Control) -> void:
	_star_field = sf


func update_state(state: SimulationState) -> void:
	_elapsed_days = float(state.elapsed_days)
	queue_redraw()


func _on_zone_changed(zone: int) -> void:
	_ppu = _zone_ppu(zone)
	_selected_star = -1
	_focused_planet = ""
	match zone:
		3:
			_zoom = 1.5
			_pan  = Vector2.ZERO
		4:
			_zoom = 0.4
			_pan  = Vector2.ZERO
		5:
			_zoom = 0.1
			_pan  = Vector2.ZERO
		6:   # Near Stars
			_zoom = 1.0
			_pan  = Vector2.ZERO
		7:   # Local Bubble
			_zoom = 0.08
			_pan  = Vector2.ZERO
		8:   # Orion Arm
			_zoom = 2.0
			_pan  = SOL_GALACTIC_POS
		9:   # Galactic Disc
			_zoom = 0.65
			_pan  = Vector2.ZERO
		10:  # Full Galaxy
			_zoom = 0.38
			_pan  = Vector2.ZERO
		_:
			_zoom = 1.0
			_pan  = Vector2.ZERO
	queue_redraw()


func _zone_ppu(zone: int) -> float:
	if zone <= 5: return 80.0
	if zone <= 7: return 200.0
	return 50.0


# ── Coordinate helpers ────────────────────────────────────────────────────────

func _world_to_screen(world: Vector2) -> Vector2:
	return get_size() * 0.5 + (world - _pan) * _ppu * _zoom

func _screen_to_world(screen: Vector2) -> Vector2:
	return (screen - get_size() * 0.5) / (_ppu * _zoom) + _pan


# ── Draw dispatch ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var zone := ScaleEngine.current_zone
	if zone >= 8:
		_draw_galactic_map()
	elif zone >= 6:
		_draw_star_map()
	else:
		_draw_solar()
	_draw_zone_label()


# ── Solar system (zones 3-5) ──────────────────────────────────────────────────

func _draw_solar() -> void:
	var zone := ScaleEngine.current_zone
	match zone:
		3: _draw_distance_rings([0.25, 0.5, 1.0, 2.0, 3.5], "AU")
		4: _draw_distance_rings([1.0, 3.0, 5.0, 8.0, 12.0], "AU")
		5: _draw_distance_rings([10.0, 20.0, 30.0, 40.0, 55.0], "AU")
	_draw_asteroid_belt()
	if zone >= 5:
		_draw_kuiper_belt()
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


func _draw_kuiper_belt() -> void:
	var center := _world_to_screen(Vector2.ZERO)
	var r_inner := 30.0 * _ppu * _zoom
	var r_outer := 50.0 * _ppu * _zoom
	if r_inner > get_size().length() or r_outer < 20.0:
		return
	draw_arc(center, (r_inner + r_outer) * 0.5, 0.0, TAU, 256,
		Color(0.40, 0.48, 0.60, 0.09), r_outer - r_inner)
	var lpos := _world_to_screen(Vector2.ZERO) + Vector2(4.0, -(39.0 * _ppu * _zoom) - 4.0)
	draw_string(ThemeDB.fallback_font, lpos, "Kuiper Belt",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.40, 0.48, 0.60, 0.50))


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
		var pname: String = p[0]
		var a: float      = float(p[1])
		var period: float = float(p[2])
		var ang0: float   = float(p[3])
		var color: Color  = p[4]
		var dot_r: float  = float(p[5])

		var orbit_r := a * _ppu * _zoom
		if orbit_r >= 4.0:
			draw_arc(_world_to_screen(Vector2.ZERO), orbit_r, 0.0, TAU, 128,
				Color(color.r, color.g, color.b, 0.18), 1.0)

		var angle_rad := deg_to_rad(ang0 + (360.0 / period) * (_elapsed_days / 365.25))
		var sp := _world_to_screen(Vector2(cos(angle_rad), -sin(angle_rad)) * a)
		if sp.x < -50 or sp.x > sz.x + 50 or sp.y < -50 or sp.y > sz.y + 50:
			continue

		var r := maxf(2.0, dot_r * clampf(_zoom * 0.5, 0.5, 2.0))
		var focused := pname == _focused_planet

		if focused:
			draw_arc(sp, r + 5.0, 0.0, TAU, 48, _CYAN, 1.5)
		draw_circle(sp, r, color)
		draw_arc(sp, r + 1.0, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.5), 1.0)
		if _zoom > 0.12:
			draw_string(font, sp + Vector2(r + 3.0, 3.0),
				pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.94, 0.90, 0.80, 0.85))

		if focused:
			_draw_focused_moons(pname, sp)


func _draw_focused_moons(planet_name: String, planet_sp: Vector2) -> void:
	var moon_data: Array = MOONS.get(planet_name, [])
	if moon_data.is_empty():
		return

	# Scale so outermost moon sits at MOON_SYSTEM_RADIUS_PX from planet center.
	var max_dist: float = 0.0
	for m: Array in moon_data:
		max_dist = maxf(max_dist, float(m[1]))
	if max_dist <= 0.0:
		return

	# Translucent backdrop so moons are legible over the star field.
	draw_circle(planet_sp, MOON_SYSTEM_RADIUS_PX + 16.0, Color(0.04, 0.08, 0.18, 0.70))
	draw_arc(planet_sp, MOON_SYSTEM_RADIUS_PX + 16.0, 0.0, TAU, 64,
		Color(_CYAN.r, _CYAN.g, _CYAN.b, 0.25), 1.0)

	var font := ThemeDB.fallback_font
	draw_string(font, planet_sp + Vector2(-38.0, MOON_SYSTEM_RADIUS_PX + 24.0),
		planet_name + " system", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _CYAN)

	for m: Array in moon_data:
		var mname: String  = m[0]
		var dist_au: float = float(m[1])
		var period: float  = float(m[2])
		var ang0: float    = float(m[3])
		var color: Color   = m[4]
		var dot_r: float   = float(m[5])

		var orbit_px := (dist_au / max_dist) * MOON_SYSTEM_RADIUS_PX
		draw_arc(planet_sp, orbit_px, 0.0, TAU, 64,
			Color(color.r, color.g, color.b, 0.25), 1.0)

		var angle := deg_to_rad(ang0 + (360.0 / period) * (_elapsed_days / 365.25))
		var mpos := planet_sp + Vector2(cos(angle), -sin(angle)) * orbit_px
		draw_circle(mpos, dot_r, color)
		draw_string(font, mpos + Vector2(dot_r + 2.0, 3.0),
			mname, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(color.r, color.g, color.b, 0.85))


# ── Star map (zones 6-7) ──────────────────────────────────────────────────────

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
		var sname: String    = s[0]
		var x: float         = float(s[1])
		var y: float         = float(s[2])
		var spectral: String = s[3]
		var has_hz: bool     = s[4]
		var sp := _world_to_screen(Vector2(x, -y))
		if sp.x < -20 or sp.x > sz.x + 20 or sp.y < -20 or sp.y > sz.y + 20:
			continue
		var color := _star_color(spectral)
		var selected := i == _selected_star
		var is_sol := i == 0
		if selected:
			draw_arc(sp, 10.0, 0.0, TAU, 64, Color(_CYAN.r, _CYAN.g, _CYAN.b, 0.6), 2.0)
		elif is_sol:
			draw_arc(sp, 9.0, 0.0, TAU, 64, Color(_ORANGE.r, _ORANGE.g, _ORANGE.b, 0.4), 2.0)
		if has_hz and _zoom > 0.3:
			draw_arc(sp, 7.0, 0.0, TAU, 32, Color(_CYAN.r, _CYAN.g, _CYAN.b, 0.3), 1.0)
		var r := 6.0 if is_sol else (4.5 if has_hz else 3.5)
		draw_circle(sp, r, color)
		if _zoom > 0.25 or selected:
			var lc := _CYAN if selected else _CREAM
			draw_string(font, sp + Vector2(r + 4.0, 4.0),
				sname, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(lc.r, lc.g, lc.b, 0.9))


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
	var bx := get_size().x - 210.0
	var by := 50.0
	draw_rect(Rect2(bx - pad, by - pad, 198.0 + pad, 90.0 + pad),
		Color(0.06, 0.10, 0.22, 0.88))
	draw_rect(Rect2(bx - pad, by - pad, 198.0 + pad, 90.0 + pad),
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


# ── Galactic map (zones 8-10) ─────────────────────────────────────────────────

func _draw_galactic_map() -> void:
	_draw_galaxy_disc()
	_draw_galaxy_arms()
	_draw_galactic_core()
	var zone := ScaleEngine.current_zone
	if zone >= 9:
		_draw_distance_rings([5.0, 10.0, 15.0, 20.0], "kpc")
	else:
		_draw_distance_rings([0.5, 1.0, 2.0, 5.0], "kpc", SOL_GALACTIC_POS)
	_draw_sol_galactic()
	if zone == 8:
		_draw_galactic_landmarks()
	elif zone >= 9:
		var gc_sp := _world_to_screen(Vector2.ZERO)
		draw_string(ThemeDB.fallback_font, gc_sp + Vector2(12.0, 4.0),
			"Galactic Centre", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1.0, 0.88, 0.55, 0.6))


func _draw_galaxy_disc() -> void:
	var center := _world_to_screen(Vector2.ZERO)
	for i in 5:
		var r := (GALACTIC_RADIUS * (1.0 - i * 0.14)) * _ppu * _zoom
		if r < 2.0: continue
		draw_circle(center, r, Color(0.40, 0.35, 0.22, 0.03 + i * 0.008))


func _draw_galactic_core() -> void:
	var center := _world_to_screen(Vector2.ZERO)
	var bar_half := 3.0 * _ppu * _zoom
	var bar_w := maxf(2.0, 0.9 * _ppu * _zoom)
	var ba := deg_to_rad(25.0)
	var bar_dir := Vector2(cos(ba), sin(ba)) * bar_half
	draw_line(center - bar_dir, center + bar_dir, Color(0.88, 0.72, 0.40, 0.16), bar_w)
	draw_line(center - bar_dir, center + bar_dir, Color(1.00, 0.90, 0.60, 0.22), maxf(1.0, bar_w * 0.3))
	for i in 7:
		var r := maxf(1.0, (2.8 - i * 0.35) * _ppu * _zoom)
		draw_circle(center, r, Color(1.0, 0.88, 0.55, 0.06 + i * 0.04))


func _draw_galaxy_arms() -> void:
	for arm: Array in GALAXY_ARMS:
		var r0: float        = float(arm[1])
		var theta0: float    = float(arm[2])
		var n_turns: float   = float(arm[3])
		var color: Color     = arm[4]
		var width_kpc: float = float(arm[5])
		var is_sol_arm: bool = arm[6]

		var pts := _galactic_arm_points(r0, theta0, n_turns)
		if pts.size() < 2:
			continue

		var spts := PackedVector2Array()
		spts.resize(pts.size())
		for i in pts.size():
			spts[i] = _world_to_screen(pts[i])

		var w := maxf(1.0, width_kpc * _ppu * _zoom)
		var ca := 0.30 if is_sol_arm else 0.20

		draw_polyline(spts, Color(color.r, color.g, color.b, 0.04), w * 2.5, true)
		draw_polyline(spts, Color(color.r, color.g, color.b, 0.12), w, true)
		draw_polyline(spts, Color(color.r, color.g, color.b, ca),   w * 0.35, true)

		# Arm label in zone 8-9 when arm is large enough
		if _ppu * _zoom > 20.0 and pts.size() > 10:
			var mid_pt := spts[pts.size() / 3]
			var sz := get_size()
			if mid_pt.x > 10 and mid_pt.x < sz.x - 10 and mid_pt.y > 10 and mid_pt.y < sz.y - 10:
				var arm_name: String = arm[0]
				draw_string(ThemeDB.fallback_font, mid_pt + Vector2(4, -4),
					arm_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					Color(color.r + 0.2, color.g + 0.2, color.b + 0.1, 0.7))


func _galactic_arm_points(r0: float, theta0: float, n_turns: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 250
	for i in steps + 1:
		var t := float(i) / float(steps)
		var theta := theta0 + t * n_turns * TAU
		var r := r0 * exp(GALAXY_B * t * n_turns * TAU)
		if r > GALACTIC_RADIUS + 2.0:
			break
		pts.append(Vector2(r * cos(theta), -r * sin(theta)))
	return pts


func _draw_sol_galactic() -> void:
	var sp := _world_to_screen(SOL_GALACTIC_POS)
	var sz := get_size()
	if sp.x < -20 or sp.x > sz.x + 20 or sp.y < -20 or sp.y > sz.y + 20:
		return
	draw_circle(sp, 4.5, Color(1.0, 0.90, 0.60))
	draw_arc(sp, 7.0, 0.0, TAU, 32, Color(0.92, 0.48, 0.12, 0.55), 1.5)
	if ScaleEngine.current_zone >= 9:
		draw_arc(sp, 11.0, 0.0, TAU, 48, Color(0.92, 0.48, 0.12, 0.25), 1.0)
	if _ppu * _zoom > 25.0:
		draw_string(ThemeDB.fallback_font, sp + Vector2(9.0, 4.0),
			"Sol", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, _ORANGE)


func _draw_galactic_landmarks() -> void:
	var sz := get_size()
	for lm: Array in GALACTIC_LANDMARKS:
		var lname: String = lm[0]
		var lx: float     = float(lm[1])
		var ly: float     = float(lm[2])
		var sp := _world_to_screen(Vector2(lx, ly))
		if sp.x < 10 or sp.x > sz.x - 10 or sp.y < 10 or sp.y > sz.y - 10:
			continue
		draw_circle(sp, 2.5, Color(0.60, 0.80, 0.90, 0.6))
		draw_string(ThemeDB.fallback_font, sp + Vector2(5, 3),
			lname, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.60, 0.80, 0.90, 0.55))


# ── Shared helpers ────────────────────────────────────────────────────────────

func _draw_distance_rings(intervals: Array, unit: String,
		world_anchor: Vector2 = Vector2.ZERO) -> void:
	var anchor := _world_to_screen(world_anchor)
	var font := ThemeDB.fallback_font
	for r_v in intervals:
		var r_world: float = float(r_v)
		var r_px: float    = r_world * _ppu * _zoom
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
	match zone:
		10: hint = "scroll to zoom · drag to pan · zoom in → Galactic Disc · M to retreat"
		9:  hint = "scroll to zoom · drag to pan · zoom in → Orion Arm · zoom out → Full Galaxy · M to retreat"
		8:  hint = "scroll to zoom · drag to pan · zoom out → Galactic Disc · M → Local Bubble"
		7:  hint = "scroll to zoom · drag to pan · zoom in → Near Stars · zoom out → Orion Arm · M → Near Stars"
		6:  hint = "scroll to zoom · drag to pan · click star · zoom in → solar · M to retreat"
		5:  hint = "scroll to zoom · drag to pan · click planet to focus moons · zoom out → star map · M to return"
		4:  hint = "scroll to zoom · drag to pan · click planet to focus moons · M to return"
		_:  hint = "scroll to zoom · drag to pan · click planet to focus moons · zoom out → Mid Solar · M to return"
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
					if event.double_click:
						_dragging = false
						_try_double_click(event.position)
					else:
						_dragging = true
						_did_drag = false
						_drag_origin = event.position
						_pan_origin  = _pan
				else:
					if not _did_drag:
						_try_select_star(event.position)
						_try_select_planet(event.position)
					_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var delta := (event as InputEventMouseMotion).position - _drag_origin
		if delta.length() > 4.0:
			_did_drag = true
		_pan = _pan_origin - delta / (_ppu * _zoom)
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
		match zone:
			3, 4, 5: zone_transition_requested.emit(6)
			6:        zone_transition_requested.emit(7)
			7:        zone_transition_requested.emit(8)
			8:        zone_transition_requested.emit(9)
			9:        zone_transition_requested.emit(10)
	elif _zoom >= _ZOOM_IN_THRESHOLD:
		match zone:
			6:        zone_transition_requested.emit(3)
			7:        zone_transition_requested.emit(6)
			8:        zone_transition_requested.emit(7)
			9:        zone_transition_requested.emit(8)
			10:       zone_transition_requested.emit(9)


func _try_select_star(screen_pos: Vector2) -> void:
	var zone := ScaleEngine.current_zone
	if zone < 6 or zone > 7:
		return
	var best_i := -1
	var best_d := 16.0
	for i in NEARBY_STARS.size():
		var s: Array = NEARBY_STARS[i]
		var sp := _world_to_screen(Vector2(float(s[1]), -float(s[2])))
		var d := screen_pos.distance_to(sp)
		if d < best_d:
			best_d = d
			best_i = i
	_selected_star = best_i
	queue_redraw()


func _try_select_planet(screen_pos: Vector2) -> void:
	var zone := ScaleEngine.current_zone
	if zone < 3 or zone > 5:
		return
	var best_name := ""
	var best_d := 20.0
	for p: Array in PLANETS:
		var pname: String = p[0]
		var a: float      = float(p[1])
		var period: float = float(p[2])
		var ang0: float   = float(p[3])
		var angle := deg_to_rad(ang0 + (360.0 / period) * (_elapsed_days / 365.25))
		var sp := _world_to_screen(Vector2(cos(angle), -sin(angle)) * a)
		var d := screen_pos.distance_to(sp)
		if d < best_d:
			best_d = d
			best_name = pname
	# Toggle off if same planet clicked again; do nothing if no planet nearby.
	if best_name.is_empty():
		return
	_focused_planet = "" if best_name == _focused_planet else best_name
	queue_redraw()


func _try_double_click(screen_pos: Vector2) -> void:
	var zone := ScaleEngine.current_zone
	if zone < 3 or zone > 5:
		return
	# Sun
	if screen_pos.distance_to(_world_to_screen(Vector2.ZERO)) < 22.0:
		if zone > 3:
			zone_transition_requested.emit(3)
		return
	# Planets
	for p: Array in PLANETS:
		var pname:  String = p[0]
		var a:      float  = float(p[1])
		var period: float  = float(p[2])
		var ang0:   float  = float(p[3])
		var angle := deg_to_rad(ang0 + (360.0 / period) * (_elapsed_days / 365.25))
		var sp := _world_to_screen(Vector2(cos(angle), -sin(angle)) * a)
		if screen_pos.distance_to(sp) < 20.0:
			if pname == "Earth":
				zone_transition_requested.emit(1)
			else:
				# No dedicated local view yet — pan and zoom to planet
				_pan = Vector2(cos(angle), -sin(angle)) * a
				_zoom = clampf(_zoom * 3.0, 0.1, 30.0)
				_push_parallax()
				queue_redraw()
			return


func _push_parallax() -> void:
	if _star_field and _star_field.has_method("set_camera_offset"):
		_star_field.set_camera_offset(_pan * _ppu)
