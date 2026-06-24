extends SubViewportContainer
# 3D Earth view. Earth and Moon surfaces use procedurally generated
# equirectangular image textures — no external asset files needed.
# Swap _generate_earth_texture() / _generate_moon_texture() for real art later.

const EARTH_R   := 1.5
const CLOUD_R   := 1.56
const ATMO_R    := 1.63
const ORBIT_SAT := 2.05
const ORBIT_STN := 2.28
const MOON_DIST := 4.3

var _time        := 0.0
var _earth_root: Node3D
var _cloud_root: Node3D
var _city_lights: Array[Node3D] = []

var _sat_orbit:  Node3D
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

var _population       := 30.0
var _completed:       Array = []
var _active_research  := ""
var _moon_mission_active := false
var _moon_landing        := false

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
	[0.722, 0.250, 0.042, 0.095, Color(0.20, 0.50, 0.17)],  # N. America
	[0.833, 0.583, 0.026, 0.095, Color(0.18, 0.48, 0.14)],  # S. America
	[0.042, 0.211, 0.020, 0.050, Color(0.22, 0.52, 0.19)],  # Europe
	[0.061, 0.472, 0.032, 0.110, Color(0.24, 0.50, 0.14)],  # Africa
	[0.125, 0.361, 0.016, 0.038, Color(0.60, 0.52, 0.28)],  # Arabia (desert)
	[0.217, 0.389, 0.014, 0.044, Color(0.20, 0.50, 0.15)],  # India
	[0.250, 0.250, 0.065, 0.078, Color(0.20, 0.50, 0.17)],  # Asia
	[0.294, 0.444, 0.014, 0.032, Color(0.18, 0.48, 0.14)],  # SE Asia
	[0.383, 0.300, 0.010, 0.026, Color(0.20, 0.50, 0.17)],  # Japan
	[0.375, 0.639, 0.026, 0.036, Color(0.20, 0.48, 0.14)],  # Australia
	[0.883, 0.100, 0.015, 0.034, Color(0.88, 0.94, 1.00)],  # Greenland
]


func _ready() -> void:
	stretch = true
	_build_3d_world()


func _build_3d_world() -> void:
	var vp := SubViewport.new()
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

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 3.2, 6.0)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)

	_earth_root = Node3D.new()
	vp.add_child(_earth_root)

	_cloud_root = Node3D.new()
	vp.add_child(_cloud_root)

	_build_earth()
	_build_orbital_objects(vp)
	_build_distance_rings(vp)

	_rocket_root = Node3D.new()
	vp.add_child(_rocket_root)


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
		mat.albedo_color = Color(1.0, 0.88, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.2)
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
	mat_cloud.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	mat_cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cloud.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_cloud.roughness = 1.0
	m_cloud.surface_set_material(0, mat_cloud)
	_cloud_root.add_child(_inst(m_cloud))

	# Atmosphere rim
	var m_atmo := _make_sphere(ATMO_R, 32, 16)
	var mat_atmo := StandardMaterial3D.new()
	mat_atmo.albedo_color = Color(0.28, 0.52, 1.0, 0.07)
	mat_atmo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_atmo.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_atmo.surface_set_material(0, mat_atmo)
	_cloud_root.add_child(_inst(m_atmo))


func _build_orbital_objects(vp: Node) -> void:
	_sat_orbit = _orbit_pivot(vp, 0.0, false)
	var sat_arm := Node3D.new()
	sat_arm.position = Vector3(ORBIT_SAT, 0.0, 0.0)
	_sat_orbit.add_child(sat_arm)
	_add_satellite(sat_arm)

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
	mat_flag.albedo_color = Color(1.0, 0.15, 0.15)
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
	mat_craft.albedo_color = Color(1.0, 0.90, 0.60)
	mat_craft.emission_enabled = true
	mat_craft.emission = Color(1.0, 0.85, 0.5)
	mat_craft.emission_energy_multiplier = 2.0
	m_craft.surface_set_material(0, mat_craft)
	_transit_craft.add_child(_inst(m_craft))


func _build_distance_rings(vp: Node) -> void:
	var ring_root := Node3D.new()
	vp.add_child(ring_root)

	# [radius_in_scene_units, label_text, alpha]
	var rings: Array[Array] = [
		[2.50, "~500 km",        0.30],
		[3.70, "~36,000 km",     0.22],
		[MOON_DIST + 0.15, "~384,000 km", 0.18],
	]

	for r_data: Array in rings:
		var radius: float = r_data[0]
		var label: String = r_data[1]
		var alpha: float  = r_data[2]
		_ring(ring_root, radius, Color(1.0, 1.0, 1.0, alpha), label)


func _ring(parent: Node3D, radius: float, col: Color, label: String) -> void:
	# Label sits at the 5-o'clock position on the ring: angle = TAU/6 in XZ
	const GAP_ANGLE := TAU / 6.0
	const GAP_HALF  := 0.22        # radians either side of label — cuts ring open
	const SEG       := 128

	var verts := PackedVector3Array()
	var idx   := PackedInt32Array()
	for i in SEG:
		var a := float(i) / SEG * TAU
		verts.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	for i in SEG:
		# Mid-angle of this segment — skip if inside the label gap
		var a_mid := (float(i) + 0.5) / SEG * TAU
		var diff  := fmod(a_mid - GAP_ANGLE, TAU)
		if diff > PI:  diff -= TAU
		if diff < -PI: diff += TAU
		if absf(diff) < GAP_HALF:
			continue
		idx.append(i)
		idx.append((i + 1) % SEG)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX]  = idx

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	# Normal transparent material — opaque objects (Earth, Moon) depth-test and
	# naturally occlude the ring where they are in front. No depth tricks needed.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	parent.add_child(inst)

	if label != "":
		var lbl := Label3D.new()
		lbl.text = label
		lbl.pixel_size = 0.004
		lbl.font_size = 18
		lbl.font = ThemeDB.fallback_font
		lbl.modulate = col
		lbl.position = Vector3(radius * 0.5, 0.06, radius * 0.866)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = false
		parent.add_child(lbl)


func _add_satellite(parent: Node3D) -> void:
	var m := BoxMesh.new()
	m.size = Vector3(0.14, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.35, 0.80)
	mat.metallic = 0.5
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))


func _add_capsule(parent: Node3D) -> void:
	var m := _make_sphere(0.07, 8, 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.90)
	mat.metallic = 0.3
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))


func _add_station(parent: Node3D) -> void:
	var m := BoxMesh.new()
	m.size = Vector3(0.40, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.78, 0.95)
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
	var ocean := Color(0.02, 0.14, 0.88)
	img.fill(ocean)

	for c: Array in _CONTINENTS_UV:
		_fill_ellipse(img, c[0], c[1], c[2], c[3], c[4])

	# Ice caps
	for py in H:
		var v := float(py) / H
		if v < 0.065:
			for px in W: img.set_pixel(px, py, Color(0.88, 0.94, 1.0))
		elif v < 0.095:
			var t := (v - 0.065) / 0.03
			for px in W:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.88, 0.94, 1.0), 1.0 - t))
		elif v > 0.935:
			for px in W: img.set_pixel(px, py, Color(0.88, 0.94, 1.0))
		elif v > 0.905:
			var t := (v - 0.905) / 0.03
			for px in W:
				img.set_pixel(px, py, img.get_pixel(px, py).lerp(Color(0.88, 0.94, 1.0), t))

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
	img.fill(Color(0.68, 0.68, 0.68))

	# Maria (dark plains) as large dark ellipses
	var mare := Color(0.44, 0.44, 0.44)
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
		_fill_ellipse(img, cr[0], cr[1], cr[2], cr[2], Color(0.72, 0.72, 0.72))
		_fill_ellipse(img, cr[0], cr[1], cr[2] * 0.7, cr[2] * 0.7, Color(0.35, 0.35, 0.35))

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

	var visible_cities := int(clampf(_population / 8.0, 1, _city_lights.size()))
	for i in _city_lights.size():
		_city_lights[i].visible = i < visible_cities

	if _sat_orbit:  _sat_orbit.visible  = "orbital_satellite" in _completed
	if _crew_orbit: _crew_orbit.visible = "crewed_orbit"       in _completed
	if _stn_orbit:  _stn_orbit.visible  = "modular_station"    in _completed

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


# ── Animation ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_time += delta

	if _earth_root: _earth_root.rotation_degrees.y += delta * 3.0
	if _cloud_root: _cloud_root.rotation_degrees.y += delta * 4.0
	if _sat_orbit:  _sat_orbit.rotation_degrees.y  += delta * 48.0
	if _crew_orbit: _crew_orbit.rotation_degrees.y -= delta * 38.0
	if _stn_orbit:  _stn_orbit.rotation_degrees.y  += delta * 22.0
	if _moon_orbit: _moon_orbit.rotation_degrees.y += delta * 2.8

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
	var lon := randf() * TAU
	var lat := randf_range(-0.4, 0.4)
	var surface := _ll(lat, lon, EARTH_R + 0.06)
	var apex    := _ll(lat, lon, EARTH_R + 1.3)

	var m := CylinderMesh.new()
	m.top_radius = 0.018; m.bottom_radius = 0.035; m.height = 0.15
	m.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.60, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.50, 0.05)
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
