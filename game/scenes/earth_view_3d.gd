extends SubViewportContainer
# 3D Earth view. Earth and Moon surfaces use procedurally generated
# equirectangular image textures — no external asset files needed.
# Swap _generate_earth_texture() / _generate_moon_texture() for real art later.

const EARTH_R   := 1.5
const CLOUD_R   := 1.56
const ATMO_R    := 1.63
const ORBIT_SAT := 2.05
const ORBIT_STN := 2.28
const MOON_DIST := 90.0   # 60× Earth radius — true to scale (Moon ~384,000 km, Earth radius ~6,371 km)

var _time          := 0.0
var _moon_angle_deg: float = 0.0   # driven by state.elapsed_days
var _earth_root: Node3D
var _cloud_root: Node3D
var _city_lights: Array[Node3D] = []

var _sat_orbits: Array[Node3D] = []   # grows as more satellites are built
var _crew_orbit: Node3D
var _stn_orbit:  Node3D
var _moon_orbit: Node3D
var _moon_mesh:  MeshInstance3D
var _moon_mat:   StandardMaterial3D
var _flag_node:  MeshInstance3D
var _transit_craft: Node3D
var _rocket_root: Node3D

var _launches: Array = []
var _launch_timer := 0.0
var _vp:         SubViewport      = null
var _hover_ring: MeshInstance3D   = null
var _label_list: Array[Label3D]   = []

var _population       := 30.0
var _completed:       Array = []
var _active_research  := ""
var _moon_mission_active := false
var _moon_landing        := false

# ── Camera pan/zoom state ─────────────────────────────────────────────────────
var _cam: Camera3D = null
var _look_at: Vector3 = Vector3.ZERO
var _cam_offset: Vector3 = Vector3(0.0, 3.2, 6.0)   # default viewing angle
var _dragging: bool = false
var _did_drag: bool = false

const _CAM_DIST_MIN := 2.5
const _CAM_DIST_MAX := 200.0
const _PAN_SPEED    := 0.0035   # world units per pixel per unit of cam distance

# Satellite orbit slots — [orbital_radius, y_start_deg, z_inclination_deg, y_speed_deg_per_sec]
# Speeds scaled by Kepler r^1.5 relative to the base LEO slot.
const SAT_ORBIT_PARAMS: Array = [
	[2.05, 0.0,    0.0,   48.0],   # equatorial LEO
	[2.18, 130.0, 28.0,  -44.0],   # inclined (retrograde for visual variety)
	[2.32, 250.0, 51.6,   40.0],   # ISS-like inclination, higher
	[2.12,  70.0,-35.0,  -46.0],   # low inclined, retrograde
	[2.45, 190.0, 97.0,   37.0],   # near-polar (sun-synchronous-like)
]

const LAUNCH_INTERVAL := 4.0
const PROPULSION_NODES := [
	"suborbital_flight", "orbital_satellite", "crewed_orbit",
	"long_duration_crewed", "modular_station", "expanded_station",
	"lunar_transit", "crewed_lunar_vehicle",
]

# Real geographic positions [lat_rad, lon_rad]
const CITY_LATLONS: Array = [
	[ 0.710, -1.291],  # New York
	[ 0.593, -2.059],  # Los Angeles
	[ 0.916,  0.234],  # Berlin
	[ 0.431,  0.815],  # Riyadh
	[ 0.332,  1.271],  # Mumbai
	[ 0.241,  1.754],  # Bangkok
	[ 0.698,  2.031],  # Beijing
	[-0.592,  2.636],  # Sydney
	[-0.410, -0.813],  # São Paulo
	[-0.454,  0.489],  # Johannesburg
	[ 1.045,  0.187],  # Oslo
	[ 0.623,  2.438],  # Tokyo
]

# Continent ellipses in equirectangular UV space
# [u_center, v_center, u_radius, v_radius, color]
# UV convention: U=lon/TAU (0 = prime meridian, wrapping), V=(PI/2-lat)/PI
const _CONTINENTS_UV: Array = [
	[0.722, 0.250, 0.042, 0.095, Color(0.38, 0.54, 0.32)],  # N. America  (sage)
	[0.833, 0.583, 0.026, 0.095, Color(0.36, 0.52, 0.30)],  # S. America  (sage)
	[0.042, 0.211, 0.020, 0.050, Color(0.40, 0.56, 0.34)],  # Europe      (sage)
	[0.061, 0.472, 0.032, 0.110, Color(0.36, 0.52, 0.28)],  # Africa      (sage)
	[0.125, 0.361, 0.016, 0.038, Color(0.70, 0.56, 0.28)],  # Arabia      (sandy cream)
	[0.217, 0.389, 0.014, 0.044, Color(0.38, 0.54, 0.32)],  # India       (sage)
	[0.250, 0.250, 0.065, 0.078, Color(0.38, 0.54, 0.32)],  # Asia        (sage)
	[0.294, 0.444, 0.014, 0.032, Color(0.36, 0.52, 0.30)],  # SE Asia     (sage)
	[0.383, 0.300, 0.010, 0.026, Color(0.38, 0.54, 0.32)],  # Japan       (sage)
	[0.375, 0.639, 0.026, 0.036, Color(0.36, 0.52, 0.30)],  # Australia   (sage)
	[0.883, 0.100, 0.015, 0.034, Color(0.94, 0.90, 0.80)],  # Greenland   (cream)
]


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_3d_world()
	ScaleEngine.zone_changed.connect(_on_zone_changed)


func _build_3d_world() -> void:
	var vp := SubViewport.new()
	_vp = vp
	vp.size = Vector2i(720, 580)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.10, 0.20)
	env.ambient_light_energy = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-15, -20, 0)
	sun.light_energy = 1.5
	sun.light_color = Color(1.0, 0.98, 0.95)
	vp.add_child(sun)

	_cam = Camera3D.new()
	vp.add_child(_cam)
	_update_camera()

	_earth_root = Node3D.new()
	vp.add_child(_earth_root)

	_cloud_root = Node3D.new()
	vp.add_child(_cloud_root)

	_build_earth()
	_build_orbital_objects(vp)
	_build_distance_rings(vp)

	_rocket_root = Node3D.new()
	vp.add_child(_rocket_root)

	_hover_ring = SceneUtil.make_orbit_ring(1.0, Color(0.70, 1.00, 1.00, 0.90), true)
	_hover_ring.visible = false
	vp.add_child(_hover_ring)


func _build_earth() -> void:
	# Textured sphere
	var earth_mesh := _make_sphere(EARTH_R, 64, 32)
	var earth_mat := StandardMaterial3D.new()
	earth_mat.albedo_texture = _generate_earth_texture()
	earth_mat.roughness = 0.7
	earth_mat.metallic = 0.05
	earth_mesh.surface_set_material(0, earth_mat)
	_earth_root.add_child(_inst(earth_mesh))

	# City lights
	for i in CITY_LATLONS.size():
		var ll: Array = CITY_LATLONS[i]
		var pos := _ll(ll[0], ll[1], EARTH_R + 0.035)
		var m := _make_sphere(0.038, 6, 4)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.58, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.92, 0.46, 0.06)
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.surface_set_material(0, mat)
		var inst := _inst(m)
		inst.position = pos
		inst.visible = false
		_earth_root.add_child(inst)
		_city_lights.append(inst)

	# Cloud sphere
	var m_cloud := _make_sphere(CLOUD_R, 48, 24)
	var mat_cloud := StandardMaterial3D.new()
	mat_cloud.albedo_color = Color(0.94, 0.90, 0.80, 0.22)
	mat_cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cloud.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cloud.roughness = 1.0
	m_cloud.surface_set_material(0, mat_cloud)
	_cloud_root.add_child(_inst(m_cloud))

	# Atmosphere rim
	var m_atmo := _make_sphere(ATMO_R, 32, 16)
	var mat_atmo := StandardMaterial3D.new()
	mat_atmo.albedo_color = Color(0.20, 0.65, 0.85, 0.09)
	mat_atmo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_atmo.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_atmo.surface_set_material(0, mat_atmo)
	_cloud_root.add_child(_inst(m_atmo))


func _build_orbital_objects(vp: Node) -> void:
	for i in SAT_ORBIT_PARAMS.size():
		var p: Array   = SAT_ORBIT_PARAMS[i]
		var pivot := _orbit_pivot(vp, p[1], false)
		pivot.rotation_degrees.z = p[2]
		var arm := Node3D.new()
		arm.position = Vector3(p[0], 0.0, 0.0)
		pivot.add_child(arm)
		_add_satellite(arm)
		_sat_orbits.append(pivot)

	_crew_orbit = _orbit_pivot(vp, 55.0, false)
	_crew_orbit.rotation_degrees.z = 12.0
	var crew_arm := Node3D.new()
	crew_arm.position = Vector3(ORBIT_SAT + 0.12, 0.0, 0.0)
	_crew_orbit.add_child(crew_arm)
	_add_capsule(crew_arm)

	_stn_orbit = _orbit_pivot(vp, 25.0, false)
	_stn_orbit.rotation_degrees.z = 8.0
	var stn_arm := Node3D.new()
	stn_arm.position = Vector3(ORBIT_STN, 0.1, 0.0)
	_stn_orbit.add_child(stn_arm)
	_add_station(stn_arm)

	# Moon with texture
	_moon_orbit = Node3D.new()
	vp.add_child(_moon_orbit)
	var m_moon := _make_sphere(0.36, 32, 16)
	_moon_mat = StandardMaterial3D.new()
	_moon_mat.albedo_texture = _generate_moon_texture()
	_moon_mat.roughness = 0.95
	m_moon.surface_set_material(0, _moon_mat)
	_moon_mesh = _inst(m_moon)
	_moon_mesh.position = Vector3(MOON_DIST, 0.0, 0.0)
	_moon_orbit.add_child(_moon_mesh)

	# Flag
	var m_flag := BoxMesh.new()
	m_flag.size = Vector3(0.05, 0.09, 0.01)
	var mat_flag := StandardMaterial3D.new()
	mat_flag.albedo_color = Color(0.92, 0.48, 0.12)  # orange
	mat_flag.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_flag.surface_set_material(0, mat_flag)
	_flag_node = _inst(m_flag)
	_flag_node.position = Vector3(MOON_DIST + 0.15, 0.38, 0.0)
	_flag_node.visible = false
	_moon_orbit.add_child(_flag_node)

	# Transit craft
	_transit_craft = Node3D.new()
	_transit_craft.visible = false
	vp.add_child(_transit_craft)
	var m_craft := _make_sphere(0.065, 8, 6)
	var mat_craft := StandardMaterial3D.new()
	mat_craft.albedo_color = Color(0.92, 0.55, 0.12)  # orange
	mat_craft.emission_enabled = true
	mat_craft.emission = Color(0.92, 0.48, 0.08)
	mat_craft.emission_energy_multiplier = 2.0
	m_craft.surface_set_material(0, mat_craft)
	_transit_craft.add_child(_inst(m_craft))


func _build_distance_rings(vp: Node) -> void:
	var ring_root := Node3D.new()
	vp.add_child(ring_root)

	# [radius_in_scene_units, label_text]
	var rings: Array[Array] = [
		[2.50,             "500 km"],
		[3.70,             "36,000 km"],
		[MOON_DIST + 0.15, "384,000 km"],
	]

	for r_data: Array in rings:
		_ring(ring_root, float(r_data[0]), Color(1.0, 1.0, 1.0, 0.5), str(r_data[1]))


func _ring(parent: Node3D, radius: float, col: Color, label: String) -> void:
	parent.add_child(SceneUtil.make_orbit_ring(radius, col))
	if label != "":
		var gap := TAU / 6.0
		var lbl := SceneUtil.make_orbit_label(label, Color(1.0, 1.0, 1.0, 0.80), radius)
		lbl.position = Vector3(cos(gap) * radius, 0.06, sin(gap) * radius)
		parent.add_child(lbl)
		_label_list.append(lbl)


func _add_satellite(parent: Node3D) -> void:
	# Body
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.82, 0.78, 0.66)  # cream
	body_mat.metallic = 0.6
	var body := BoxMesh.new()
	body.size = Vector3(0.045, 0.022, 0.022)
	body.surface_set_material(0, body_mat)
	parent.add_child(_inst(body))

	# Solar panels — two flat wings extending along X
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.08, 0.28, 0.48)  # dark navy-blue
	panel_mat.metallic = 0.5
	panel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: int in [-1, 1]:
		var panel := BoxMesh.new()
		panel.size = Vector3(0.055, 0.006, 0.032)
		panel.surface_set_material(0, panel_mat)
		var pi := _inst(panel)
		pi.position = Vector3(float(side) * 0.052, 0.0, 0.0)
		parent.add_child(pi)


func _add_capsule(parent: Node3D) -> void:
	var m := _make_sphere(0.07, 8, 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.84, 0.72)  # cream
	mat.metallic = 0.3
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))


func _add_station(parent: Node3D) -> void:
	var m := BoxMesh.new()
	m.size = Vector3(0.40, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.76, 0.64)  # cream
	mat.metallic = 0.4
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))


func _orbit_pivot(parent: Node, y_deg: float, visible: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation_degrees.y = y_deg
	pivot.visible = visible
	parent.add_child(pivot)
	return pivot


# ── Texture generation ────────────────────────────────────────────────────────

func _generate_earth_texture() -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var ocean := Color(0.08, 0.16, 0.38)  # deep navy
	img.fill(ocean)

	for c: Array in _CONTINENTS_UV:
		_fill_ellipse(img, c[0], c[1], c[2], c[3], c[4])

	# Ice caps
	for py in H:
		var v := float(py) / H
		if v < 0.065:
			for px in W: img.set_pixel(px, py, Color(0.94, 0.90, 0.80))
		elif v < 0.095:
			var t := (v - 0.065) / 0.03
			for px in W:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.94, 0.90, 0.80), 1.0 - t))
		elif v > 0.935:
			for px in W: img.set_pixel(px, py, Color(0.94, 0.90, 0.80))
		elif v > 0.905:
			var t := (v - 0.905) / 0.03
			for px in W:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.94, 0.90, 0.80), t))

	# Subtle per-pixel noise for texture variation
	for py in H:
		for px in W:
			var n := (_hash(px, py) - 0.5) * 0.06
			var c2 := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(
				clampf(c2.r + n, 0.0, 1.0),
				clampf(c2.g + n * 0.8, 0.0, 1.0),
				clampf(c2.b + n * 0.6, 0.0, 1.0)))

	return ImageTexture.create_from_image(img)


func _generate_moon_texture() -> ImageTexture:
	var W := 256; var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.82, 0.78, 0.66))  # warm cream-gray base

	# Maria (dark plains)
	var mare := Color(0.54, 0.50, 0.40)
	_fill_ellipse(img, 0.35, 0.40, 0.12, 0.14, mare)
	_fill_ellipse(img, 0.60, 0.45, 0.09, 0.10, mare)
	_fill_ellipse(img, 0.20, 0.55, 0.07, 0.08, mare)
	_fill_ellipse(img, 0.72, 0.35, 0.06, 0.07, mare)

	# Craters (bright rim, dark floor)
	var craters := [
		[0.45, 0.38, 0.05], [0.25, 0.42, 0.04], [0.65, 0.52, 0.035],
		[0.55, 0.28, 0.03], [0.38, 0.60, 0.04], [0.78, 0.45, 0.03],
		[0.15, 0.35, 0.025],[0.82, 0.58, 0.025],[0.50, 0.70, 0.03],
	]
	for cr: Array in craters:
		_fill_ellipse(img, cr[0], cr[1], cr[2], cr[2], Color(0.88, 0.84, 0.72))
		_fill_ellipse(img, cr[0], cr[1], cr[2] * 0.7, cr[2] * 0.7, Color(0.44, 0.40, 0.34))

	# Noise
	for py in H:
		for px in W:
			var n := (_hash(px * 3 + 7, py * 5 + 11) - 0.5) * 0.05
			var c2 := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(
				clampf(c2.r + n, 0.0, 1.0),
				clampf(c2.g + n, 0.0, 1.0),
				clampf(c2.b + n, 0.0, 1.0)))

	return ImageTexture.create_from_image(img)


func _fill_ellipse(img: Image, uc: float, vc: float, ur: float, vr: float, col: Color) -> void:
	var W := img.get_width(); var H := img.get_height()
	var x0 := int((uc - ur) * W); var x1 := int((uc + ur) * W)
	var y0 := maxi(0, int((vc - vr) * H)); var y1 := mini(H - 1, int((vc + vr) * H))
	for py in range(y0, y1 + 1):
		var dv := (float(py) / H - vc) / vr
		for px in range(x0, x1 + 1):
			var wpx := posmod(px, W)
			var du := (float(wpx) / W - uc) / ur
			if du * du + dv * dv <= 1.0:
				img.set_pixel(wpx, py, col)


func _hash(x: int, y: int) -> float:
	var n := x + y * 57
	n = (n << 13) ^ n
	return float((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 2147483647.0


# ── State update ──────────────────────────────────────────────────────────────

func update_state(state: SimulationState) -> void:
	_population      = state.population_units
	_completed       = state.completed_research
	_active_research = state.active_research
	_moon_mission_active = state.moon_mission_active
	_moon_landing    = state.milestone_flags.get("moon_landing", false)
	_moon_angle_deg  = state.elapsed_days / 27.3 * 360.0

	var visible_cities := int(clampf(_population / 8.0, 1, _city_lights.size()))
	for i in _city_lights.size():
		_city_lights[i].visible = i < visible_cities

	var n_sats := _satellite_count()
	for i in _sat_orbits.size():
		_sat_orbits[i].visible = i < n_sats
	if _crew_orbit: _crew_orbit.visible = "crewed_orbit"    in _completed
	if _stn_orbit:  _stn_orbit.visible  = "modular_station" in _completed

	if _moon_mat:
		if _moon_landing:
			_moon_mat.emission_enabled = true
			_moon_mat.emission = Color(0.8, 0.75, 0.5)
			_moon_mat.emission_energy_multiplier = 0.5
		elif "lunar_transit" in _completed:
			_moon_mat.albedo_color = Color(1.1, 1.1, 1.0)  # slightly brightened tint
		else:
			_moon_mat.albedo_color = Color(1.0, 1.0, 1.0)
			_moon_mat.emission_enabled = false

	if _flag_node:    _flag_node.visible    = _moon_landing
	if _transit_craft: _transit_craft.visible = _moon_mission_active and not _moon_landing


func _satellite_count() -> int:
	if not "orbital_satellite" in _completed: return 0
	# Each subsequent milestone unlocks another satellite slot
	var unlocks := ["long_duration_crewed", "modular_station", "expanded_station", "lunar_transit"]
	var n := 1
	for m in unlocks:
		if m in _completed: n += 1
	return mini(n, SAT_ORBIT_PARAMS.size())


# ── Animation ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta

	if _earth_root: _earth_root.rotation_degrees.y += delta * 3.0
	if _cloud_root: _cloud_root.rotation_degrees.y += delta * 4.0
	for i in _sat_orbits.size():
		if _sat_orbits[i].visible:
			_sat_orbits[i].rotation_degrees.y += delta * (SAT_ORBIT_PARAMS[i] as Array)[3]
	if _crew_orbit: _crew_orbit.rotation_degrees.y -= delta * 38.0
	if _stn_orbit:  _stn_orbit.rotation_degrees.y  += delta * 22.0
	if _moon_orbit: _moon_orbit.rotation_degrees.y = _moon_angle_deg

	_update_hover_ring()
	if _cam and _label_list.size() > 0:
		SceneUtil.update_labels(_label_list, _cam, float(_vp.size.y))

	if _transit_craft and _transit_craft.visible and _moon_mesh:
		var t := fmod(_time * 0.05, 1.0)
		var moon_pos := _moon_mesh.global_position
		var start := Vector3(0.0, 0.0, EARTH_R + 0.25)
		_transit_craft.position = start.lerp(moon_pos, t)

	if _active_research in PROPULSION_NODES:
		_launch_timer -= delta
		if _launch_timer <= 0.0:
			_launch_timer = LAUNCH_INTERVAL * randf_range(0.8, 1.3)
			_spawn_rocket()

	for i in range(_launches.size() - 1, -1, -1):
		var launch: Dictionary = _launches[i]
		launch["t"] += delta * 0.14
		var node: Node3D = launch["node"]
		if is_instance_valid(node):
			node.position = (launch["start"] as Vector3).lerp(launch["end"], launch["t"])
			var fade: float = 1.0 - float(launch["t"])
			node.scale = Vector3.ONE * maxf(fade, 0.0)
		if launch["t"] >= 1.0:
			if is_instance_valid(node): node.queue_free()
			_launches.remove_at(i)


func _spawn_rocket() -> void:
	# Near-equatorial launch — most launches stay close to equator for orbital efficiency.
	# The apex is on the equatorial plane at orbital altitude so the trajectory arcs
	# toward the orbital plane (gravity-turn visual).
	var lon := randf() * TAU
	var lat := randf_range(-0.15, 0.15)
	var surface := _ll(lat, lon, EARTH_R + 0.06)
	var apex    := Vector3(cos(lon) * (EARTH_R + 1.15), 0.0, sin(lon) * (EARTH_R + 1.15))

	var m := CylinderMesh.new()
	m.top_radius = 0.018; m.bottom_radius = 0.035; m.height = 0.15
	m.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.48, 0.12)  # burnt orange
	mat.emission_enabled = true
	mat.emission = Color(0.88, 0.36, 0.04)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.surface_set_material(0, mat)

	var root := _inst(m)
	root.position = surface
	_orient_y_up(root, surface)
	_rocket_root.add_child(root)
	_launches.append({"node": root, "start": surface, "end": apex, "t": 0.0})


# ── Helpers ───────────────────────────────────────────────────────────────────

func _ll(lat: float, lon: float, radius: float) -> Vector3:
	return Vector3(
		radius * cos(lat) * cos(lon),
		radius * sin(lat),
		radius * cos(lat) * sin(lon)
	)



func _update_hover_ring() -> void:
	if not _cam or not _hover_ring:
		return
	var vp_size  := Vector2(_cam.get_viewport().size)
	var mouse_vp := get_local_mouse_position() * vp_size / size
	var best_pos  := Vector3.ZERO
	var best_r    := 0.0
	var best_dist := INF

	if not _dragging:
		# Moon — fixed pixel threshold (Moon is a small dot at cis-lunar scale)
		if _moon_mesh:
			var sp := _cam.unproject_position(_moon_mesh.global_position)
			var d  := mouse_vp.distance_to(sp)
			if d < 50.0 and d < best_dist:
				best_dist = d
				best_pos  = _moon_mesh.global_position
				best_r    = 0.36 * 1.4   # Moon sphere radius * ring factor

		# Earth — use projected screen radius so it scales with zoom
		var earth_sp   := _cam.unproject_position(Vector3.ZERO)
		var earth_edge := _cam.unproject_position(Vector3(EARTH_R, 0.0, 0.0))
		var screen_r   := maxf(earth_sp.distance_to(earth_edge), 14.0)
		var d_earth    := mouse_vp.distance_to(earth_sp)
		if d_earth < screen_r * 1.5 and d_earth < best_dist:
			best_pos = Vector3.ZERO
			best_r   = EARTH_R * 1.35

	if best_r > 0.0:
		_hover_ring.position = best_pos
		_hover_ring.scale    = Vector3.ONE * best_r
		_hover_ring.visible  = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_hover_ring.visible = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _make_sphere(radius: float, radial: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius; m.height = radius * 2.0
	m.radial_segments = radial; m.rings = rings
	return m


func _inst(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _orient_y_up(node: Node3D, pos: Vector3) -> void:
	var up  := pos.normalized()
	var ref := Vector3(0, 0, 1) if abs(up.dot(Vector3(0, 1, 0))) > 0.99 else Vector3(0, 1, 0)
	var right := ref.cross(up).normalized()
	node.basis = Basis(right, up, right.cross(up).cross(right))


# ── Zone-aware camera presets ─────────────────────────────────────────────────

func _on_zone_changed(zone: int) -> void:
	if zone == 1:
		# Earth System — close up, Moon off to the side
		_look_at    = Vector3.ZERO
		_cam_offset = Vector3(0.0, 3.2, 6.0)
	elif zone == 2:
		# Cis-lunar — frame both Earth and Moon
		_look_at    = Vector3(MOON_DIST * 0.42, 0.0, 0.0)
		_cam_offset = Vector3(0.0, MOON_DIST * 0.75, MOON_DIST * 1.5)
	_update_camera()


# ── Pan / zoom ────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		# Trackpad pinch: factor > 1 = spreading = zoom in
		_zoom_by(1.0 / event.factor)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		# Two-finger drag on trackpad
		_pan(event.delta * 6.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_by(1.0 / 1.15)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_by(1.15)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = true
					_did_drag = false
				else:
					_dragging = false
					if not _did_drag:
						_try_click_body(event.position)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_reset_camera()
	elif event is InputEventMouseMotion and _dragging:
		_did_drag = true
		_pan(event.relative)


func _zoom_by(factor: float) -> void:
	var new_offset := _cam_offset * factor
	var dist := new_offset.length()
	if dist < _CAM_DIST_MIN or dist > _CAM_DIST_MAX:
		return
	_cam_offset = new_offset
	_update_camera()


func _pan(delta_px: Vector2) -> void:
	if not _cam:
		return
	var dist := _cam_offset.length()
	# Project camera right onto the XZ plane — no elevation change.
	var right_xz := Vector3(_cam.global_transform.basis.x.x, 0.0,
		_cam.global_transform.basis.x.z).normalized()
	var fwd_xz := Vector3(-_cam.global_transform.basis.z.x, 0.0,
		-_cam.global_transform.basis.z.z).normalized()
	_look_at += (right_xz * -delta_px.x + fwd_xz * -delta_px.y) * _PAN_SPEED * dist
	_look_at.y = 0.0  # never leave the equatorial plane
	var max_pan := MOON_DIST * 0.9
	_look_at.x = clampf(_look_at.x, -max_pan, max_pan)
	_look_at.z = clampf(_look_at.z, -max_pan, max_pan)
	_update_camera()


func _reset_camera() -> void:
	_on_zone_changed(ScaleEngine.current_zone)


func _try_click_body(container_pos: Vector2) -> void:
	if not _cam:
		return
	var vp_size := Vector2(_cam.get_viewport().size)
	var vp_pos  := container_pos * vp_size / size

	# Moon click → transition to Moon local view
	if _moon_mesh:
		var moon_world := _moon_mesh.global_position
		var moon_sp    := _cam.unproject_position(moon_world)
		if vp_pos.distance_to(moon_sp) < 50.0:
			ScaleEngine.select_body("Moon")
			return

	# Earth click → pan/zoom toward Earth
	var dist := _cam_offset.length()
	var dir  := _cam_offset.normalized()
	var earth_sp := _cam.unproject_position(Vector3.ZERO)
	if vp_pos.distance_to(earth_sp) < 80.0:
		_look_at    = Vector3.ZERO
		_cam_offset = dir * clampf(dist * 0.4, _CAM_DIST_MIN, 4.0)
		_update_camera()

func _update_camera() -> void:
	if not _cam:
		return
	_cam.position = _look_at + _cam_offset
	_cam.look_at(_look_at, Vector3.UP)
