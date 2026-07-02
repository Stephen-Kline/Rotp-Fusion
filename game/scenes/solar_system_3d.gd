extends SubViewportContainer
# 3D space map: zones 3-5 (solar system, AU scale), 6-7 (nearby stars, ly scale).

const _OM = preload("res://scripts/orbital_mechanics.gd")
# Fixed 28° elevation camera with pan and zoom. No orbit/tilt.

signal zone_transition_requested(zone: int)

const CAM_ELEVATION := deg_to_rad(28.0)   # fixed elevation angle above ecliptic
const CAM_DIST_MIN  := 0.1
const CAM_DIST_MAX  := 600.0

# Planet data: [name, semi_major_au, period_yr, ang0_deg, color, radius_au]
# Radii are exaggerated for visibility but maintain relative proportions.
const PLANETS: Array = [
	["Mercury", 0.387,   0.24085,   37.25, Color(0.68, 0.63, 0.52), 0.008],
	["Venus",   0.723,   0.61520,  101.98, Color(0.88, 0.78, 0.45), 0.012],
	["Earth",   1.000,   1.00000,  110.46, Color(0.20, 0.55, 0.85), 0.013],
	["Mars",    1.524,   1.88085,  145.45, Color(0.80, 0.35, 0.20), 0.010],
	["Ceres",   2.770,   4.60700,  295.00, Color(0.62, 0.60, 0.56), 0.006],
	["Jupiter", 5.203,  11.86200,  316.90, Color(0.78, 0.63, 0.45), 0.032],
	["Saturn",  9.537,  29.45700,  158.94, Color(0.88, 0.78, 0.52), 0.028],
	["Uranus", 19.191,  84.01100,   99.23, Color(0.55, 0.80, 0.85), 0.020],
	["Neptune",30.069, 164.80000,  195.88, Color(0.28, 0.42, 0.85), 0.019],
	["Pluto",  39.480, 247.94000,  166.00, Color(0.70, 0.60, 0.52), 0.005],
]

const SUN_RADIUS := 0.022  # AU — small bright point, not a giant ball

# Nearby stars: [name, x_ly, z_ly, color]  (x_pc * 3.26 ≈ ly)
const NEARBY_STARS: Array = [
	["Sol",            0.00,   0.00, Color(1.00, 0.95, 0.60)],
	["Alpha Centauri",-1.66,  -3.91, Color(0.90, 0.82, 0.60)],
	["Proxima Cen",   -1.53,  -3.98, Color(0.80, 0.30, 0.22)],
	["Barnard's Star", 0.33,   5.97, Color(0.78, 0.28, 0.18)],
	["Wolf 359",      -7.60,   1.70, Color(0.70, 0.22, 0.16)],
	["Lalande 21185",  1.14,   8.22, Color(0.72, 0.35, 0.22)],
	["Sirius",         4.40,  -7.34, Color(0.92, 0.92, 1.00)],
	["Luyten 726-8",  -8.55,   1.79, Color(0.68, 0.22, 0.16)],
	["Ross 154",      -1.63,   9.56, Color(0.72, 0.24, 0.16)],
	["Eps Eridani",   -9.20,  -4.96, Color(0.82, 0.65, 0.40)],
	["Ross 248",       3.91,  -9.65, Color(0.68, 0.22, 0.16)],
	["61 Cygni",       2.67,  11.12, Color(0.80, 0.62, 0.35)],
	["Procyon",        7.99,  -8.38, Color(0.95, 0.90, 0.78)],
	["Eps Indi",      -3.98, -10.47, Color(0.82, 0.60, 0.35)],
	["Tau Ceti",      -7.18,  -9.20, Color(0.88, 0.78, 0.55)],
]

# ── Runtime state ──────────────────────────────────────────────────────────────
var _vp:            SubViewport
var _scene_root:    Node3D
var _cam:           Camera3D
var _label_overlay: Control

var _pan:      Vector3 = Vector3.ZERO
var _cam_dist: float   = 3.0

var _dragging:    bool    = false
var _drag_origin: Vector2 = Vector2.ZERO
var _pan_origin:  Vector3 = Vector3.ZERO
var _did_drag:    bool    = false

var _elapsed_days: float = 0.0
var _current_zone: int   = 3
var _ships_data:   Array = []
var _paused:       bool  = false

# Scene objects (rebuilt per zone regime)
var _sun_mesh:     MeshInstance3D = null
var _planet_nodes: Array = []   # {mi, au, period, ang0, name, label, radius}
var _orbit_rings:  Array[MeshInstance3D] = []
var _star_nodes:   Array = []   # {mi, name, label, radius}
var _ship_nodes:   Array = []   # {mi, label, ship}

var _hover_ring:      MeshInstance3D = null
var _selection_ring:  MeshInstance3D = null
var _orbit_ring_labels: Array = []   # Label3D nodes, parented to orbit rings
var _hover_name:      String = ""

const _ARC_STEPS     := 64       # polyline resolution for trajectory arcs
const _COL_SHIP      := Color(0.95, 0.82, 0.20, 1.00)   # amber — ship dot
const _COL_ARC_DIM   := Color(0.95, 0.82, 0.20, 0.15)   # remaining arc
const _COL_ARC_TRAIL := Color(0.95, 0.82, 0.20, 0.55)   # trail already flown


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true   # isolate from earth_view_3d's shared world
	add_child(_vp)

	_scene_root = Node3D.new()
	_vp.add_child(_scene_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)   # transparent — star_field shows through
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.20, 0.22, 0.30)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_scene_root.add_child(we)

	_cam = Camera3D.new()
	_cam.near = 0.0001
	_cam.far  = 2000.0
	_scene_root.add_child(_cam)

	_label_overlay = Control.new()
	_label_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_label_overlay)

	# Hover/selection rings — added to _vp so they survive _clear_scene()
	_hover_ring = SceneUtil.make_orbit_ring(1.0, Color(0.70, 1.00, 1.00, 0.90))
	_hover_ring.visible = false
	_vp.add_child(_hover_ring)

	_selection_ring = SceneUtil.make_orbit_ring(1.0, Color(1.00, 0.88, 0.20, 0.85))
	_selection_ring.visible = false
	_vp.add_child(_selection_ring)

	ScaleEngine.zone_changed.connect(_on_zone_changed)
	_on_zone_changed(ScaleEngine.current_zone)


# ── Public API ────────────────────────────────────────────────────────────────

func link_star_field(_sf: Control) -> void:
	pass  # 3D view has its own dark background


func update_state(state: SimulationState) -> void:
	_elapsed_days = state.elapsed_days
	_ships_data   = state.ships
	_update_dynamic_objects()


# ── Zone handling ─────────────────────────────────────────────────────────────

func _on_zone_changed(zone: int) -> void:
	_current_zone = zone

	# Only rebuild content when entering a solar/star zone
	if zone < 3 or zone > 7:
		return

	_clear_scene()

	if zone <= 5:
		_build_solar_system()
		match zone:
			3: _cam_dist = 2.5;  _pan = Vector3.ZERO
			4: _cam_dist = 7.0;  _pan = Vector3.ZERO
			5: _cam_dist = 50.0; _pan = Vector3.ZERO
	else:
		_build_star_map()
		match zone:
			6: _cam_dist = 8.0;  _pan = Vector3.ZERO
			7: _cam_dist = 80.0; _pan = Vector3.ZERO

	_update_camera()
	_update_dynamic_objects()


func _clear_scene() -> void:
	if _sun_mesh:
		_sun_mesh.queue_free()
		_sun_mesh = null
	for entry in _planet_nodes:
		(entry["mi"] as MeshInstance3D).queue_free()
		if entry["label"]: (entry["label"] as Label).queue_free()
	_planet_nodes.clear()
	for mi in _orbit_rings:
		mi.queue_free()
	_orbit_rings.clear()
	for lbl in _orbit_ring_labels:
		if is_instance_valid(lbl): lbl.queue_free()
	_orbit_ring_labels.clear()
	for entry in _star_nodes:
		(entry["mi"] as MeshInstance3D).queue_free()
		if entry["label"]: (entry["label"] as Label).queue_free()
	_star_nodes.clear()
	_clear_ship_nodes()
	# Remove any leftover children (corona etc.)
	for c in _scene_root.get_children():
		if c is MeshInstance3D or c is OmniLight3D:
			c.queue_free()


# ── Solar system (zones 3-5) ──────────────────────────────────────────────────

func _build_solar_system() -> void:
	# Sun
	_sun_mesh = _sphere(SUN_RADIUS, Color(1.0, 0.92, 0.35), true)
	_scene_root.add_child(_sun_mesh)
	var corona := _sphere(SUN_RADIUS * 2.5, Color(1.0, 0.75, 0.10, 0.06), true)
	_scene_root.add_child(corona)
	# Sun label (stored in planet_nodes so label overlay updates it)
	var sun_lbl := _make_label("Sol")
	sun_lbl.set_meta("body", "Sol")
	sun_lbl.add_theme_color_override("font_color", Color.WHITE)
	sun_lbl.gui_input.connect(_on_label_input.bind("Sol"))
	_planet_nodes.append({"mi": _sun_mesh, "au": 0.0, "period": 1.0,
			"ang0": 0.0, "name": "Sol", "label": sun_lbl, "radius": SUN_RADIUS})

	# Sun point light
	var sun_light := OmniLight3D.new()
	sun_light.light_energy = 1.2
	sun_light.omni_range   = 1000.0
	sun_light.omni_attenuation = 0.05
	_scene_root.add_child(sun_light)

	# Planets
	for p: Array in PLANETS:
		var pname:  String = p[0]
		var au:     float  = p[1]
		var period: float  = p[2]
		var ang0:   float  = p[3]
		var col:    Color  = p[4]
		var radius: float  = p[5]

		var gap      := TAU / 6.0
		var ring     := SceneUtil.make_orbit_ring(au, Color(1.0, 1.0, 1.0, 0.25))
		var ring_lbl := SceneUtil.make_orbit_label(UIUtil.fmt_au(au), Color.WHITE, au)
		ring_lbl.position = Vector3(cos(gap) * au, 0.02, sin(gap) * au)
		_scene_root.add_child(ring)
		_orbit_rings.append(ring)
		_scene_root.add_child(ring_lbl)
		_orbit_ring_labels.append(ring_lbl)

		var mi := _sphere(radius, col, false)
		_scene_root.add_child(mi)

		# Saturn rings
		if pname == "Saturn":
			var disc := _flat_ring(0.016, 0.027, Color(0.86, 0.76, 0.52, 0.50))
			mi.add_child(disc)

		var lbl := _make_label(pname)
		lbl.set_meta("body", pname)
		lbl.gui_input.connect(_on_label_input.bind(pname))

		_planet_nodes.append({"mi": mi, "au": au, "period": period,
				"ang0": ang0, "name": pname, "label": lbl, "radius": radius})

	_update_planet_positions()


func _update_planet_positions() -> void:
	for entry: Dictionary in _planet_nodes:
		var au:     float = entry["au"]
		var period: float = entry["period"]
		var ang0:   float = entry["ang0"]
		var angle := deg_to_rad(ang0 + (360.0 / period) * (_elapsed_days / 365.25))
		var pos := Vector3(cos(angle) * au, 0.0, sin(angle) * au)
		(entry["mi"] as MeshInstance3D).position = pos


# ── Nearby star map (zones 6-7) ───────────────────────────────────────────────

func _build_star_map() -> void:
	for s: Array in NEARBY_STARS:
		var sname: String = s[0]
		var x: float      = s[1]
		var z: float      = s[2]
		var col: Color    = s[3]

		var r := 0.12 if sname == "Sol" else 0.06
		var mi := _sphere(r, col, true)
		mi.position = Vector3(x, 0.0, z)
		_scene_root.add_child(mi)

		var lbl := _make_label(sname)
		lbl.set_meta("body", sname)
		lbl.gui_input.connect(_on_label_input.bind(sname))

		_star_nodes.append({"mi": mi, "name": sname, "label": lbl, "radius": r})


# ── Ship rendering ─────────────────────────────────────────────────────────────

func _clear_ship_nodes() -> void:
	for entry in _ship_nodes:
		(entry["mi"]       as MeshInstance3D).queue_free()
		(entry["arc_mi"]   as MeshInstance3D).queue_free()
		(entry["trail_mi"] as MeshInstance3D).queue_free()
		if entry["label"]: (entry["label"] as Label).queue_free()
	_ship_nodes.clear()


func _update_dynamic_objects() -> void:
	if _current_zone < 3 or _current_zone > 7:
		return

	_update_planet_positions()

	# Ships visible in solar view: in-flight or orbiting
	var visible_ships: Array = []
	for s in _ships_data:
		var ship := s as Ship
		if ship.ship_state == Ship.ShipState.IN_TRANSIT \
				or ship.ship_state == Ship.ShipState.ORBITING:
			visible_ships.append(ship)

	# Rebuild node list when the visible set changes
	var needs_rebuild := _ship_nodes.size() != visible_ships.size()
	if not needs_rebuild:
		for i in _ship_nodes.size():
			if (_ship_nodes[i]["ship"] as Ship) != visible_ships[i]:
				needs_rebuild = true
				break

	if needs_rebuild:
		_clear_ship_nodes()
		for s in visible_ships:
			var ship := s as Ship
			var dot        := _sphere(0.003, _COL_SHIP, true)
			var arc_mi     := _line_mi(_COL_ARC_DIM)
			var trail_mi   := _line_mi(_COL_ARC_TRAIL)
			_scene_root.add_child(dot)
			_scene_root.add_child(arc_mi)
			_scene_root.add_child(trail_mi)
			var lbl := _make_label(ship.label)
			_ship_nodes.append({
				"mi": dot, "arc_mi": arc_mi, "trail_mi": trail_mi,
				"label": lbl, "ship": ship,
				"arc_mat":   arc_mi.get_meta("mat"),
				"trail_mat": trail_mi.get_meta("mat"),
			})

	# Update positions and arcs each frame
	for i in _ship_nodes.size():
		var ship: Ship = _ship_nodes[i]["ship"]
		var pos := _ship_solar_pos(ship)
		(_ship_nodes[i]["mi"] as MeshInstance3D).position = pos
		_update_ship_arc(_ship_nodes[i], ship)

	_update_label_positions()


# 3D position of the ship in solar-view AU coordinates.
func _ship_solar_pos(ship: Ship) -> Vector3:
	match ship.ship_state:
		Ship.ShipState.IN_TRANSIT:
			if not ship.is_local:
				return ship.position_at(_elapsed_days)
			# Local (moon) transfer: cluster near parent planet
			return _body_pos_au(ship.origin_body)
		Ship.ShipState.ORBITING:
			return _body_pos_au(ship.origin_body)
	return Vector3.ZERO


# Rebuild arc + trail line meshes for this ship node.
func _update_ship_arc(entry: Dictionary, ship: Ship) -> void:
	var arc_mi:   MeshInstance3D = entry["arc_mi"]
	var trail_mi: MeshInstance3D = entry["trail_mi"]

	# Only solar IN_TRANSIT ships get arc rendering
	if ship.ship_state != Ship.ShipState.IN_TRANSIT or ship.is_local \
			or ship.arc_type == Ship.TrajectoryType.FOLDING:
		_clear_line_mesh(arc_mi)
		_clear_line_mesh(trail_mi)
		return

	var dur := ship.arrival_day - ship.departure_day
	var t   := clampf((_elapsed_days - ship.departure_day) / maxf(dur, 1.0), 0.0, 1.0)

	var all_pts: PackedVector3Array
	match ship.arc_type:
		Ship.TrajectoryType.HOHMANN:
			all_pts = _OM.hohmann_arc_points(
					ship.origin_pos, ship.dest_pos, _ARC_STEPS)
		Ship.TrajectoryType.SPIRAL:
			all_pts = _OM.spiral_arc_points(
					ship.origin_pos, ship.dest_pos, ship.n_turns, _ARC_STEPS)
		Ship.TrajectoryType.TORCH:
			all_pts = _OM.torch_arc_points(
					ship.origin_pos, ship.dest_pos, _ARC_STEPS)
		_:
			_clear_line_mesh(arc_mi)
			_clear_line_mesh(trail_mi)
			return

	var split := clampi(int(t * (_ARC_STEPS - 1)), 0, _ARC_STEPS - 2)
	_set_line_mesh(trail_mi, all_pts.slice(0, split + 1),
			entry["trail_mat"] as StandardMaterial3D)
	_set_line_mesh(arc_mi,   all_pts.slice(split),
			entry["arc_mat"]   as StandardMaterial3D)


func _body_pos_au(body_name: String) -> Vector3:
	for entry: Dictionary in _planet_nodes:
		if (entry["name"] as String).to_lower() == body_name.to_lower():
			return (entry["mi"] as MeshInstance3D).position
	return Vector3.ZERO


# ── Line mesh helpers ─────────────────────────────────────────────────────────

func _line_mi(col: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi  := MeshInstance3D.new()
	mi.mesh  = ArrayMesh.new()
	mi.set_meta("mat", mat)
	return mi


func _clear_line_mesh(mi: MeshInstance3D) -> void:
	(mi.mesh as ArrayMesh).clear_surfaces()


func _set_line_mesh(mi: MeshInstance3D, pts: PackedVector3Array,
		mat: StandardMaterial3D) -> void:
	var mesh := mi.mesh as ArrayMesh
	mesh.clear_surfaces()
	if pts.size() < 2:
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	mesh.surface_set_material(0, mat)


# ── Label overlay ─────────────────────────────────────────────────────────────

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", SceneUtil.LABEL_SIZE_2D)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_label_overlay.add_child(lbl)
	return lbl


func _update_label_positions() -> void:
	if not _cam:
		return
	var vp_size := Vector2(_vp.size)
	var cont_size := size

	for entry: Dictionary in _planet_nodes:
		var lbl: Label = entry["label"]
		var r: float   = float(entry.get("radius", 0.01))
		var world_pos  := (entry["mi"] as MeshInstance3D).global_position + Vector3(0, r * 1.8, 0)
		_position_label(lbl, world_pos, vp_size, cont_size, Vector2(0, -4))

	for entry: Dictionary in _star_nodes:
		var lbl: Label = entry["label"]
		var r: float   = float(entry.get("radius", 0.06))
		var world_pos  := (entry["mi"] as MeshInstance3D).global_position + Vector3(0, r * 1.8, 0)
		_position_label(lbl, world_pos, vp_size, cont_size, Vector2(0, -4))

	for entry: Dictionary in _ship_nodes:
		var lbl: Label = entry["label"]
		var world_pos: Vector3 = (entry["mi"] as MeshInstance3D).global_position
		_position_label(lbl, world_pos, vp_size, cont_size, Vector2(6, -6))


func _position_label(lbl: Label, world_pos: Vector3,
		vp_size: Vector2, cont_size: Vector2, offset: Vector2) -> void:
	if _cam.is_position_behind(world_pos):
		lbl.visible = false
		return
	var sp := _cam.unproject_position(world_pos)
	# Scale from viewport coords to container coords
	var cp := sp * cont_size / vp_size
	lbl.position = cp + offset
	lbl.visible = true


# ── Input ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _current_zone >= 3 and _current_zone <= 5:
		_update_planet_positions()
	_update_hover()
	_update_label_positions()
	_update_camera_keys(delta)
	if _cam:
		if _orbit_rings.size() > 0:
			SceneUtil.update_rings(_orbit_rings, _cam, float(_vp.size.y))
		if _orbit_ring_labels.size() > 0:
			SceneUtil.update_labels(_orbit_ring_labels, _cam, float(_vp.size.y))


func _update_camera_keys(delta: float) -> void:
	if not visible or not _cam:
		return
	var right  := _cam.global_transform.basis.x
	var fwd_xz := Vector3(-_cam.global_transform.basis.z.x, 0.0,
			-_cam.global_transform.basis.z.z).normalized()
	var speed  := _cam_dist * delta
	var moved  := false
	if Input.is_action_pressed("ui_left"):
		_pan -= right * speed;   moved = true
	if Input.is_action_pressed("ui_right"):
		_pan += right * speed;   moved = true
	if Input.is_action_pressed("ui_up"):
		_pan += fwd_xz * speed;  moved = true
	if Input.is_action_pressed("ui_down"):
		_pan -= fwd_xz * speed;  moved = true
	if moved:
		_update_camera()


func _update_hover() -> void:
	if not visible or not _cam or not _hover_ring:
		return
	var mouse_pos := get_local_mouse_position()
	if mouse_pos.x < 0.0 or mouse_pos.y < 0.0 or mouse_pos.x > size.x or mouse_pos.y > size.y:
		if _hover_ring: _hover_ring.visible = false
		if _hover_name != "":
			_hover_name = ""
			for entry: Dictionary in _planet_nodes:
				(entry["label"] as Label).add_theme_color_override("font_color", SceneUtil.COL_LABEL_BODY)
			for entry: Dictionary in _star_nodes:
				(entry["label"] as Label).add_theme_color_override("font_color", SceneUtil.COL_LABEL_STAR)
		return
	var vp_size   := Vector2(_vp.size)
	var mouse_vp  := mouse_pos * vp_size / size   # container → viewport pixels

	var min_r   := _min_ring_world_r(22.0)
	var vp_h    := float(_vp.size.y)
	var fov_tan := tan(deg_to_rad(_cam.fov) * 0.5)
	var to_scr  := vp_h * 0.5 / maxf(_cam_dist * fov_tan, 0.001)

	var bodies: Array = []
	for entry: Dictionary in _planet_nodes + _star_nodes:
		var mi_pos := (entry["mi"] as MeshInstance3D).global_position
		var r      := float(entry.get("radius", 0.013))
		var name   := str(entry["name"])
		var threshold := maxf(44.0, maxf(r * 2.5, min_r) * to_scr + 8.0)
		bodies.append({"name": name, "world_pos": mi_pos,
				"radius": r, "screen_threshold_px": threshold})
		# Label sits slightly above body — include as detection target; ring stays on body.
		bodies.append({"name": name,
				"world_pos": mi_pos + Vector3(0.0, r * 1.8, 0.0),
				"ring_world_pos": mi_pos,
				"radius": r, "screen_threshold_px": threshold * 0.7})

	var hit   := SceneUtil.update_hover(_cam, mouse_vp, bodies, _hover_ring, 2.5, min_r)
	_hover_name = str(hit.get("name", ""))
	for entry: Dictionary in _planet_nodes:
		(entry["label"] as Label).add_theme_color_override("font_color",
				Color(0.70, 1.00, 1.00, 1.00) if str(entry["name"]) == _hover_name \
				else SceneUtil.COL_LABEL_BODY)
	for entry: Dictionary in _star_nodes:
		(entry["label"] as Label).add_theme_color_override("font_color",
				Color(0.70, 1.00, 1.00, 1.00) if str(entry["name"]) == _hover_name \
				else SceneUtil.COL_LABEL_STAR)

	# Selection ring — tracks current_body each frame
	var cur := ScaleEngine.current_body
	var sel_r := 0.0; var sel_pos := Vector3.ZERO
	for entry: Dictionary in _planet_nodes:
		if entry["name"] == cur:
			sel_r   = entry.get("radius", 0.013)
			sel_pos = (entry["mi"] as MeshInstance3D).global_position
			break
	if sel_r == 0.0:
		for entry: Dictionary in _star_nodes:
			if entry["name"] == cur:
				sel_r   = entry.get("radius", 0.06)
				sel_pos = (entry["mi"] as MeshInstance3D).global_position
				break
	if _selection_ring:
		if sel_r > 0.0:
			_selection_ring.position = sel_pos
			_selection_ring.scale    = Vector3.ONE * maxf(sel_r * 3.2, min_r * 1.2)
			_selection_ring.visible  = true
		else:
			_selection_ring.visible = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_cam_dist = clampf(_cam_dist * 0.85, CAM_DIST_MIN, CAM_DIST_MAX)
					_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_cam_dist = clampf(_cam_dist * 1.18, CAM_DIST_MIN, CAM_DIST_MAX)
					_update_camera()
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = true
					_did_drag = false
					_drag_origin = mb.position
					_pan_origin  = _pan
				else:
					_dragging = false
					if not _did_drag:
						_try_click(mb.position)
	elif event is InputEventMouseMotion:
		if _dragging:
			_did_drag = true
			var total_delta := (event as InputEventMouseMotion).position - _drag_origin
			var right  := _cam.global_transform.basis.x
			var fwd_xz := Vector3(-_cam.global_transform.basis.z.x, 0.0,
					-_cam.global_transform.basis.z.z).normalized()
			var speed := _cam_dist * 0.0018
			_pan = _pan_origin \
				+ right   * (-total_delta.x * speed) \
				+ fwd_xz  * (-total_delta.y * speed)
			_update_camera()
	elif event is InputEventMagnifyGesture:
		var factor := 1.0 / (event as InputEventMagnifyGesture).factor
		_cam_dist = clampf(_cam_dist * factor, CAM_DIST_MIN, CAM_DIST_MAX)
		_update_camera()
	elif event is InputEventPanGesture:
		var delta_px := (event as InputEventPanGesture).delta * 6.0
		var right  := _cam.global_transform.basis.x
		var fwd_xz := Vector3(-_cam.global_transform.basis.z.x, 0.0,
				-_cam.global_transform.basis.z.z).normalized()
		var speed := _cam_dist * 0.0018
		_pan += right * (-delta_px.x * speed) + fwd_xz * (-delta_px.y * speed)
		_update_camera()


func _on_label_input(event: InputEvent, body_name: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_body_click(body_name)
			get_viewport().set_input_as_handled()


func _try_click(_screen_pos: Vector2) -> void:
	if _hover_name != "":
		_handle_body_click(_hover_name)


func _handle_body_click(_body_name: String) -> void:
	if _current_zone >= 3 and _current_zone <= 5:
		ScaleEngine.select_body(_body_name)
		zone_transition_requested.emit(1)
	elif _current_zone >= 6 and _current_zone <= 7:
		if _body_name == "Sol":
			zone_transition_requested.emit(3)
		else:
			for entry: Dictionary in _star_nodes:
				if entry["name"] == _body_name:
					var mi: MeshInstance3D = entry["mi"]
					_pan = Vector3(mi.position.x, 0.0, mi.position.z)
					_cam_dist = 1.0
					_update_camera()
					return


# ── Camera ────────────────────────────────────────────────────────────────────

func _update_camera() -> void:
	if not _cam:
		return
	# Camera sits at elevation angle above look-at point (pan)
	var offset := Vector3(
		0.0,
		_cam_dist * sin(CAM_ELEVATION),
		_cam_dist * cos(CAM_ELEVATION)
	)
	_cam.position = _pan + offset
	_cam.look_at(_pan, Vector3.UP)


func _min_ring_world_r(min_px: float) -> float:
	# Returns the world-unit radius needed for a ring to appear at least min_px wide on screen.
	var vp_h := float(Vector2(_vp.size).y)
	if vp_h < 1.0 or _cam == null: return 0.0
	return min_px * _cam_dist * tan(deg_to_rad(_cam.fov) * 0.5) / (vp_h * 0.5)


# ── Mesh helpers ──────────────────────────────────────────────────────────────

func _sphere(radius: float, col: Color, emissive: bool) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if emissive:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	return mi


func _orbit_ring(au_radius: float, col: Color) -> MeshInstance3D:
	return SceneUtil.make_orbit_ring(au_radius, col)


func _flat_ring(inner_r: float, outer_r: float, col: Color) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arr  := []
	arr.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var inds  := PackedInt32Array()
	const N := 40
	for i in N:
		var a := float(i) / N * TAU
		verts.append(Vector3(cos(a) * inner_r, 0.0, sin(a) * inner_r))
		verts.append(Vector3(cos(a) * outer_r, 0.0, sin(a) * outer_r))
	for i in N:
		var vi  := i * 2
		var vi1 := ((i + 1) % N) * 2
		inds.append_array([vi, vi1, vi + 1, vi1, vi1 + 1, vi + 1])
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX]  = inds
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color  = col
	mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode     = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi
