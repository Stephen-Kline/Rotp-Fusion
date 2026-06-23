extends SubViewportContainer
# Full 3D Earth built from primitives — no external assets.
# The 2D star_field.gd behind this container shows through the transparent
# viewport background.

const EARTH_R   := 1.5
const CLOUD_R   := 1.56
const ATMO_R    := 1.63
const ORBIT_SAT := 2.05
const ORBIT_STN := 2.28
const MOON_DIST := 4.3

var _time        := 0.0
var _earth_root: Node3D   # rotates (slow Earth spin)
var _cloud_root: Node3D   # rotates slightly faster (clouds)

var _city_lights: Array[Node3D] = []

var _sat_orbit:  Node3D
var _crew_orbit: Node3D
var _stn_orbit:  Node3D
var _moon_orbit: Node3D
var _moon_mesh:  MeshInstance3D
var _flag_node:  MeshInstance3D
var _transit_craft: Node3D
var _rocket_root: Node3D

var _launches: Array = []   # [{node, start, end, t}]
var _launch_timer := 0.0

# State cached from SimulationState
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

# [lat_rad, lon_rad]
const CITY_LATLONS: Array = [
	[ 0.65,  0.70], [ 0.65, -0.40], [ 0.88,  0.30],
	[ 0.55,  0.60], [ 0.35,  1.30], [ 0.18,  1.78],
	[ 0.60,  2.10], [-0.55,  2.55], [-0.35, -1.20],
	[-0.30,  0.40], [ 1.00,  0.25], [ 0.60,  2.45],
]

# [lat, lon, blob_radius, color]
const CONTINENTS: Array = [
	[ 0.70, -1.00, 0.52, Color(0.18, 0.48, 0.16)],  # N. America
	[-0.30, -1.20, 0.36, Color(0.16, 0.46, 0.14)],  # S. America
	[ 0.90,  0.25, 0.30, Color(0.20, 0.50, 0.18)],  # Europe
	[ 0.05,  0.28, 0.44, Color(0.22, 0.48, 0.13)],  # Africa
	[ 0.65,  0.90, 0.32, Color(0.20, 0.50, 0.18)],  # W. Asia
	[ 0.50,  1.60, 0.52, Color(0.18, 0.48, 0.16)],  # Asia
	[ 0.60,  2.30, 0.30, Color(0.20, 0.50, 0.18)],  # E. Asia
	[-0.50,  2.50, 0.30, Color(0.18, 0.46, 0.14)],  # Australia
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
	env.ambient_light_color = Color(0.06, 0.08, 0.14)
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25, -50, 0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.97, 0.90)
	vp.add_child(sun)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.8, 6.0)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)

	_earth_root = Node3D.new()
	vp.add_child(_earth_root)

	_cloud_root = Node3D.new()
	vp.add_child(_cloud_root)

	_build_earth()
	_build_orbital_objects(vp)

	_rocket_root = Node3D.new()
	vp.add_child(_rocket_root)


func _build_earth() -> void:
	# Ocean
	var ocean := _make_sphere(EARTH_R, 64, 32)
	var mat_ocean := StandardMaterial3D.new()
	mat_ocean.albedo_color = Color(0.07, 0.22, 0.60)
	mat_ocean.roughness = 0.35
	mat_ocean.metallic = 0.1
	ocean.surface_set_material(0, mat_ocean)
	_earth_root.add_child(_inst(ocean))

	# Continent blobs
	for c: Array in CONTINENTS:
		var lat: float = c[0]; var lon: float = c[1]
		var sz: float  = c[2]; var col: Color = c[3]
		var pos := _ll(lat, lon, EARTH_R + sz * 0.3)
		var m := _make_sphere(sz, 16, 8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.95
		m.surface_set_material(0, mat)
		var inst := _inst(m)
		inst.position = pos
		_earth_root.add_child(inst)

	# Ice caps (polar)
	for pole: Array in [[ 1.35, 0.0, 0.50], [-1.35, 0.0, 0.42]]:
		var pos := _ll(pole[0], pole[1], EARTH_R + pole[2] * 0.28)
		var m := _make_sphere(pole[2], 12, 6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.88, 0.94, 1.0)
		mat.roughness = 0.25
		m.surface_set_material(0, mat)
		var inst := _inst(m)
		inst.position = pos
		_earth_root.add_child(inst)

	# City lights (unshaded, always bright — show on night side naturally)
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

	# Cloud sphere (semi-transparent, separate pivot)
	var m_cloud := _make_sphere(CLOUD_R, 48, 24)
	var mat_cloud := StandardMaterial3D.new()
	mat_cloud.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
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
	# Satellite
	_sat_orbit = _orbit_pivot(vp, 0.0, false)
	var sat_arm := Node3D.new()
	sat_arm.position = Vector3(ORBIT_SAT, 0.0, 0.0)
	_sat_orbit.add_child(sat_arm)
	_add_satellite(sat_arm)

	# Crewed capsule (slightly inclined orbit)
	_crew_orbit = _orbit_pivot(vp, 55.0, false)
	_crew_orbit.rotation_degrees.z = 12.0
	var crew_arm := Node3D.new()
	crew_arm.position = Vector3(ORBIT_SAT + 0.12, 0.0, 0.0)
	_crew_orbit.add_child(crew_arm)
	_add_capsule(crew_arm)

	# Space station
	_stn_orbit = _orbit_pivot(vp, 25.0, false)
	_stn_orbit.rotation_degrees.z = 8.0
	var stn_arm := Node3D.new()
	stn_arm.position = Vector3(ORBIT_STN, 0.1, 0.0)
	_stn_orbit.add_child(stn_arm)
	_add_station(stn_arm)

	# Moon
	_moon_orbit = Node3D.new()
	vp.add_child(_moon_orbit)
	var m_moon := _make_sphere(0.36, 24, 12)
	var mat_moon := StandardMaterial3D.new()
	mat_moon.albedo_color = Color(0.55, 0.55, 0.50)
	mat_moon.roughness = 0.92
	m_moon.surface_set_material(0, mat_moon)
	_moon_mesh = _inst(m_moon)
	_moon_mesh.position = Vector3(MOON_DIST, 0.0, 0.0)
	_moon_orbit.add_child(_moon_mesh)

	# Crater details on moon
	for crater: Array in [[-0.1, 0.05, 0.09], [0.12, -0.08, 0.07], [-0.05, 0.15, 0.05]]:
		var cpos := Vector3(MOON_DIST + crater[0], crater[1], 0.35 + crater[2])
		var cm := _make_sphere(crater[2], 8, 4)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.42, 0.42, 0.38)
		cmat.roughness = 1.0
		cm.surface_set_material(0, cmat)
		var ci := _inst(cm)
		ci.position = cpos
		_moon_orbit.add_child(ci)

	# Flag (appears after landing)
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

	# Moon mission transit craft
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
	# Engine cone
	var m_cone := CylinderMesh.new()
	m_cone.top_radius = 0.0; m_cone.bottom_radius = 0.05; m_cone.height = 0.10
	var mat_cone := StandardMaterial3D.new()
	mat_cone.albedo_color = Color(0.7, 0.7, 0.8)
	m_cone.surface_set_material(0, mat_cone)
	var cone := _inst(m_cone)
	cone.position = Vector3(0, -0.08, 0)
	_transit_craft.add_child(cone)


func _add_satellite(parent: Node3D) -> void:
	var m_body := BoxMesh.new()
	m_body.size = Vector3(0.11, 0.065, 0.065)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.70, 0.75, 0.85)
	mat.metallic = 0.4
	m_body.surface_set_material(0, mat)
	parent.add_child(_inst(m_body))
	for side in [-1, 1]:
		var m_panel := BoxMesh.new()
		m_panel.size = Vector3(0.20, 0.01, 0.09)
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.15, 0.25, 0.72)
		pmat.metallic = 0.6
		m_panel.surface_set_material(0, pmat)
		var panel := _inst(m_panel)
		panel.position = Vector3(side * 0.155, 0.0, 0.0)
		parent.add_child(panel)


func _add_capsule(parent: Node3D) -> void:
	var m := _make_sphere(0.075, 8, 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.90)
	mat.metallic = 0.3
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))
	var m_cone := CylinderMesh.new()
	m_cone.top_radius = 0.0; m_cone.bottom_radius = 0.05; m_cone.height = 0.08
	var mat_cone := StandardMaterial3D.new()
	mat_cone.albedo_color = Color(0.80, 0.82, 0.90)
	m_cone.surface_set_material(0, mat_cone)
	var cone := _inst(m_cone)
	cone.position = Vector3(0, 0.08, 0)
	parent.add_child(cone)


func _add_station(parent: Node3D) -> void:
	var m_hub := CylinderMesh.new()
	m_hub.top_radius = 0.09; m_hub.bottom_radius = 0.09; m_hub.height = 0.22
	m_hub.radial_segments = 8
	var mat_hub := StandardMaterial3D.new()
	mat_hub.albedo_color = Color(0.75, 0.80, 0.90)
	mat_hub.metallic = 0.3
	m_hub.surface_set_material(0, mat_hub)
	var hub := _inst(m_hub)
	hub.rotation_degrees.z = 90.0
	parent.add_child(hub)
	for side in [-1, 1]:
		var m_wing := BoxMesh.new()
		m_wing.size = Vector3(0.38, 0.01, 0.14)
		var mat_wing := StandardMaterial3D.new()
		mat_wing.albedo_color = Color(0.18, 0.28, 0.75)
		mat_wing.metallic = 0.5
		m_wing.surface_set_material(0, mat_wing)
		var wing := _inst(m_wing)
		wing.position = Vector3(side * 0.28, 0.0, 0.0)
		parent.add_child(wing)
	# Docking port connector
	var m_conn := CylinderMesh.new()
	m_conn.top_radius = 0.025; m_conn.bottom_radius = 0.025; m_conn.height = 0.18
	m_conn.radial_segments = 6
	var mat_conn := StandardMaterial3D.new()
	mat_conn.albedo_color = Color(0.65, 0.70, 0.80)
	m_conn.surface_set_material(0, mat_conn)
	parent.add_child(_inst(m_conn))


func _orbit_pivot(parent: Node, y_deg: float, visible: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation_degrees.y = y_deg
	pivot.visible = visible
	parent.add_child(pivot)
	return pivot


func update_state(state: SimulationState) -> void:
	_population      = state.population_units
	_completed       = state.completed_research
	_active_research = state.active_research
	_moon_mission_active = state.moon_mission_active
	_moon_landing    = state.milestone_flags.get("moon_landing", false)

	var visible_cities := int(clampf(_population / 8.0, 1, _city_lights.size()))
	for i in _city_lights.size():
		_city_lights[i].visible = i < visible_cities

	if _sat_orbit:
		_sat_orbit.visible  = "orbital_satellite"    in _completed
	if _crew_orbit:
		_crew_orbit.visible = "crewed_orbit"          in _completed
	if _stn_orbit:
		_stn_orbit.visible  = "modular_station"       in _completed

	if _moon_mesh:
		var mat: StandardMaterial3D = _moon_mesh.mesh.surface_get_material(0)
		if _moon_landing:
			mat.albedo_color = Color(0.88, 0.86, 0.72)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.85, 0.55)
			mat.emission_energy_multiplier = 0.6
		elif "lunar_transit" in _completed:
			mat.albedo_color = Color(0.72, 0.72, 0.67)
		else:
			mat.albedo_color = Color(0.55, 0.55, 0.50)
			mat.emission_enabled = false

	if _flag_node:
		_flag_node.visible = _moon_landing
	if _transit_craft:
		_transit_craft.visible = _moon_mission_active and not _moon_landing


func _process(delta: float) -> void:
	_time += delta

	if _earth_root:
		_earth_root.rotation_degrees.y += delta * 3.0
	if _cloud_root:
		_cloud_root.rotation_degrees.y += delta * 4.0

	if _sat_orbit:
		_sat_orbit.rotation_degrees.y  += delta * 48.0
	if _crew_orbit:
		_crew_orbit.rotation_degrees.y -= delta * 38.0
	if _stn_orbit:
		_stn_orbit.rotation_degrees.y  += delta * 22.0
	if _moon_orbit:
		_moon_orbit.rotation_degrees.y += delta * 2.8

	# Moon mission transit craft
	if _transit_craft and _transit_craft.visible and _moon_mesh:
		var t := fmod(_time * 0.05, 1.0)
		var moon_pos := _moon_mesh.global_position
		var start := Vector3(0.0, 0.0, EARTH_R + 0.25)
		_transit_craft.position = start.lerp(moon_pos, t)

	# Rocket launches while researching propulsion
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
			if is_instance_valid(node):
				node.queue_free()
			_launches.remove_at(i)


func _spawn_rocket() -> void:
	var lon := randf() * TAU
	var lat := randf_range(-0.4, 0.4)
	var surface := _ll(lat, lon, EARTH_R + 0.06)
	var apex    := _ll(lat, lon, EARTH_R + 1.3)

	var root := Node3D.new()
	root.position = surface
	_orient_y_up(root, surface)
	_rocket_root.add_child(root)

	# Body
	var m_body := CylinderMesh.new()
	m_body.top_radius = 0.022; m_body.bottom_radius = 0.038; m_body.height = 0.14
	m_body.radial_segments = 6
	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.90, 0.90, 0.95)
	mat_body.metallic = 0.4
	m_body.surface_set_material(0, mat_body)
	root.add_child(_inst(m_body))

	# Nose cone
	var m_nose := CylinderMesh.new()
	m_nose.top_radius = 0.0; m_nose.bottom_radius = 0.022; m_nose.height = 0.06
	var mat_nose := StandardMaterial3D.new()
	mat_nose.albedo_color = Color(0.85, 0.12, 0.12)
	m_nose.surface_set_material(0, mat_nose)
	var nose := _inst(m_nose)
	nose.position = Vector3(0, 0.10, 0)
	root.add_child(nose)

	# Engine flame
	var m_flame := _make_sphere(0.042, 6, 4)
	var mat_flame := StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.55, 0.10)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.45, 0.05)
	mat_flame.emission_energy_multiplier = 5.0
	mat_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_flame.surface_set_material(0, mat_flame)
	var flame := _inst(m_flame)
	flame.position = Vector3(0, -0.10, 0)
	root.add_child(flame)

	_launches.append({"node": root, "start": surface, "end": apex, "t": 0.0})


# ── helpers ──────────────────────────────────────────────────────────────────

func _ll(lat: float, lon: float, radius: float) -> Vector3:
	return Vector3(
		radius * cos(lat) * cos(lon),
		radius * sin(lat),
		radius * cos(lat) * sin(lon)
	)


func _make_sphere(radius: float, radial: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = radial
	m.rings = rings
	return m


func _inst(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _orient_y_up(node: Node3D, pos: Vector3) -> void:
	var up := pos.normalized()
	var ref := Vector3(0, 0, 1) if abs(up.dot(Vector3(0, 1, 0))) > 0.99 else Vector3(0, 1, 0)
	var right := ref.cross(up).normalized()
	var fwd   := up.cross(right)
	node.basis = Basis(right, up, fwd)
