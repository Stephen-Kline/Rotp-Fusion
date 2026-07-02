extends SubViewportContainer
# Unified local-body 3D view for all solar-system bodies including Earth.
# World scale: Earth radius = 1.5 WU. Orbit distances are in the same units.

signal body_selected(body_id: String)
signal body_deselected()

const _OM = preload("res://scripts/orbital_mechanics.gd")

# 1 WU = 6371 km (Earth radius). Universal scale for this view.
const WU_PER_KM      := 1.5 / 6371.0
const _ARC_STEPS     := 48
const _COL_SHIP      := Color(0.95, 0.82, 0.20, 1.00)
const _COL_ORBIT_RING := Color(0.95, 0.82, 0.20, 0.30)
const _COL_ARC_DIM   := Color(0.95, 0.82, 0.20, 0.15)
const _COL_ARC_TRAIL := Color(0.95, 0.82, 0.20, 0.55)
# Earth gameplay content (satellites, rockets, etc.) activates when body == "Earth".

# ── Earth-specific constants (match historical earth_view_3d) ─────────────────
const EARTH_R   := 1.5
const CLOUD_R   := 1.56
const ATMO_R    := 1.63
const ORBIT_SAT := 2.05
const ORBIT_STN := 2.28
const MOON_DIST := 90.0   # true-to-scale Moon orbit

const SAT_ORBIT_PARAMS: Array = [
	[2.05, 0.0,    0.0,   48.0],
	[2.18, 130.0, 28.0,  -44.0],
	[2.32, 250.0, 51.6,   40.0],
	[2.12,  70.0, -35.0, -46.0],
	[2.45, 190.0, 97.0,   37.0],
]
const LAUNCH_INTERVAL := 4.0
const PROPULSION_NODES := [
	"suborbital_flight", "orbital_satellite", "crewed_orbit",
	"long_duration_crewed", "modular_station", "expanded_station",
	"lunar_transit", "crewed_lunar_vehicle",
]
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
const _CONTINENTS_UV: Array = [
	[0.722, 0.250, 0.042, 0.095, Color(0.38, 0.54, 0.32)],
	[0.833, 0.583, 0.026, 0.095, Color(0.36, 0.52, 0.30)],
	[0.042, 0.211, 0.020, 0.050, Color(0.40, 0.56, 0.34)],
	[0.061, 0.472, 0.032, 0.110, Color(0.36, 0.52, 0.28)],
	[0.125, 0.361, 0.016, 0.038, Color(0.70, 0.56, 0.28)],
	[0.217, 0.389, 0.014, 0.044, Color(0.38, 0.54, 0.32)],
	[0.250, 0.250, 0.065, 0.078, Color(0.38, 0.54, 0.32)],
	[0.294, 0.444, 0.014, 0.032, Color(0.36, 0.52, 0.30)],
	[0.383, 0.300, 0.010, 0.026, Color(0.38, 0.54, 0.32)],
	[0.375, 0.639, 0.026, 0.036, Color(0.36, 0.52, 0.30)],
	[0.883, 0.100, 0.015, 0.034, Color(0.94, 0.90, 0.80)],
]

# ── Body catalog ──────────────────────────────────────────────────────────────
# Radii: (real_km / 6371) * 1.5 WU.  cam_init / cam_max in WU.
const BODY_CATALOG: Dictionary = {
	"Sol": {
		"radius": 10.0, "color": Color(1.00, 0.92, 0.35), "emissive": true,
		"atmo": Color(1.00, 0.72, 0.10, 0.07),
		"cam_init": 28.0, "cam_max": 100.0, "moons": [],
		"reference_rings": [
			{"label": "~800,000 km", "dist": 11.5},
			{"label": "~1.4 M km",   "dist": 20.0},
			{"label": "~4 M km",     "dist": 58.0},
		]
	},
	"Earth": {
		"radius": 1.5, "cam_init": 6.8, "cam_max": 200.0, "moons": []
		# No atmo key — Earth overlay builds its own layered cloud+atmo.
	},
	"Moon": {
		"radius": 0.409, "color": Color(0.62, 0.60, 0.58),
		"cam_init": 1.8, "cam_max": 12.0, "moons": []
	},
	"Mercury": {
		"radius": 0.574, "color": Color(0.65, 0.60, 0.55),
		"cam_init": 2.5, "cam_max": 15.0, "moons": []
	},
	"Venus": {
		"radius": 1.424, "color": Color(0.88, 0.78, 0.50),
		"atmo": Color(0.85, 0.74, 0.38, 0.28),
		"cam_init": 4.5, "cam_max": 20.0, "moons": []
	},
	"Mars": {
		"radius": 0.798, "color": Color(0.75, 0.32, 0.18),
		"atmo": Color(0.80, 0.50, 0.30, 0.05),
		"cam_init": 9.0, "cam_max": 25.0,
		"moons": [
			{"name": "Phobos", "radius": 0.050, "dist": 2.20,  "period":  0.319, "color": Color(0.52, 0.48, 0.44)},
			{"name": "Deimos", "radius": 0.035, "dist": 5.52,  "period":  1.263, "color": Color(0.54, 0.50, 0.46)},
		]
	},
	"Ceres": {
		"radius": 0.111, "color": Color(0.62, 0.60, 0.56),
		"cam_init": 0.7, "cam_max": 5.0, "moons": []
	},
	"Jupiter": {
		"radius": 16.814, "color": Color(0.78, 0.63, 0.45),
		"atmo": Color(0.75, 0.60, 0.40, 0.05),
		"cam_init": 160.0, "cam_max": 600.0,
		"moons": [
			{"name": "Io",       "radius": 0.430, "dist":  99.2, "period":  1.769, "color": Color(0.92, 0.78, 0.30)},
			{"name": "Europa",   "radius": 0.368, "dist": 158.0, "period":  3.551, "color": Color(0.82, 0.72, 0.60)},
			{"name": "Ganymede", "radius": 0.620, "dist": 251.7, "period":  7.155, "color": Color(0.68, 0.62, 0.55)},
			{"name": "Callisto", "radius": 0.568, "dist": 442.6, "period": 16.690, "color": Color(0.55, 0.50, 0.45)},
		]
	},
	"Saturn": {
		"radius": 14.174, "color": Color(0.88, 0.78, 0.52),
		"rings": true,
		"cam_init": 140.0, "cam_max": 450.0,
		"moons": [
			{"name": "Mimas",     "radius": 0.050, "dist":  43.6, "period":  0.942, "color": Color(0.72, 0.70, 0.68)},
			{"name": "Enceladus", "radius": 0.060, "dist":  55.9, "period":  1.370, "color": Color(0.92, 0.92, 0.94)},
			{"name": "Titan",     "radius": 0.606, "dist": 287.4, "period": 15.950, "color": Color(0.82, 0.62, 0.30)},
		]
	},
	"Uranus": {
		"radius": 6.011, "color": Color(0.55, 0.80, 0.85),
		"atmo": Color(0.50, 0.78, 0.82, 0.10),
		"cam_init": 55.0, "cam_max": 220.0,
		"moons": [
			{"name": "Miranda", "radius": 0.054, "dist":  30.5, "period":  1.413, "color": Color(0.72, 0.68, 0.65)},
			{"name": "Titania", "radius": 0.177, "dist": 103.0, "period":  8.706, "color": Color(0.68, 0.65, 0.62)},
			{"name": "Oberon",  "radius": 0.174, "dist": 137.2, "period": 13.463, "color": Color(0.65, 0.62, 0.58)},
		]
	},
	"Neptune": {
		"radius": 5.825, "color": Color(0.28, 0.42, 0.85),
		"atmo": Color(0.22, 0.38, 0.80, 0.12),
		"cam_init": 45.0, "cam_max": 160.0,
		"moons": [
			{"name": "Triton", "radius": 0.318, "dist": 83.3, "period": -5.877, "color": Color(0.72, 0.68, 0.65)},
		]
	},
	"Pluto": {
		"radius": 0.279, "color": Color(0.72, 0.62, 0.52),
		"cam_init": 8.0, "cam_max": 30.0,
		"moons": [
			{"name": "Charon", "radius": 0.143, "dist": 4.60, "period": 6.387, "color": Color(0.62, 0.58, 0.55)},
		]
	},
	# ── Moon bodies — selectable as current_body from parent planet view ──────
	"Io":       {"radius": 0.430, "color": Color(0.92, 0.78, 0.30), "cam_init": 2.5,  "cam_max": 20.0, "moons": []},
	"Europa":   {"radius": 0.368, "color": Color(0.82, 0.72, 0.60), "cam_init": 2.0,  "cam_max": 18.0, "moons": []},
	"Ganymede": {"radius": 0.620, "color": Color(0.68, 0.62, 0.55), "cam_init": 3.5,  "cam_max": 25.0, "moons": []},
	"Callisto": {"radius": 0.568, "color": Color(0.55, 0.50, 0.45), "cam_init": 3.0,  "cam_max": 22.0, "moons": []},
	"Phobos":   {"radius": 0.050, "color": Color(0.52, 0.48, 0.44), "cam_init": 0.4,  "cam_max":  3.0, "moons": []},
	"Deimos":   {"radius": 0.035, "color": Color(0.54, 0.50, 0.46), "cam_init": 0.3,  "cam_max":  2.0, "moons": []},
	"Mimas":    {"radius": 0.050, "color": Color(0.72, 0.70, 0.68), "cam_init": 0.4,  "cam_max":  3.0, "moons": []},
	"Enceladus":{"radius": 0.060, "color": Color(0.92, 0.92, 0.94), "cam_init": 0.4,  "cam_max":  3.0, "moons": []},
	"Titan":    {"radius": 0.606, "color": Color(0.82, 0.62, 0.30), "cam_init": 3.5,  "cam_max": 25.0, "moons": []},
	"Miranda":  {"radius": 0.054, "color": Color(0.72, 0.68, 0.65), "cam_init": 0.4,  "cam_max":  3.0, "moons": []},
	"Titania":  {"radius": 0.177, "color": Color(0.68, 0.65, 0.62), "cam_init": 1.0,  "cam_max":  9.0, "moons": []},
	"Oberon":   {"radius": 0.174, "color": Color(0.65, 0.62, 0.58), "cam_init": 1.0,  "cam_max":  9.0, "moons": []},
	"Triton":   {"radius": 0.318, "color": Color(0.72, 0.68, 0.65), "cam_init": 1.8,  "cam_max": 16.0, "moons": []},
	"Charon":   {"radius": 0.143, "color": Color(0.62, 0.58, 0.55), "cam_init": 0.8,  "cam_max":  7.0, "moons": []},
}

# Sidereal rotation period in days per body (prograde unless negative)
const ROTATION_PERIOD_DAYS: Dictionary = {
	"Sol": 25.4, "Earth": 1.0, "Moon": 27.3, "Mars": 1.026,
	"Mercury": 58.6, "Venus": -243.0, "Jupiter": 0.414, "Saturn": 0.444,
	"Uranus": -0.718, "Neptune": 0.671, "Ceres": 0.378, "Pluto": -6.387,
	"Io": 1.769, "Europa": 3.551, "Ganymede": 7.155, "Callisto": 16.69,
	"Phobos": 0.319, "Deimos": 1.263, "Titan": 15.95, "Triton": -5.877,
	"Charon": 6.387, "Mimas": 0.942, "Enceladus": 1.370,
	"Miranda": 1.413, "Titania": 8.706, "Oberon": 13.46,
}

# ── Runtime state ─────────────────────────────────────────────────────────────
var _vp:        SubViewport
var _cam:       Camera3D
var _body_root: Node3D

var _db:         BodyDB      # loaded once; body catalog for local position queries
var _struct_db:  StructureDB # loaded once; structure definitions

var _moon_pivots:      Array = []   # {pivot, period, mi, name, radius}
var _orbit_ring_nodes: Array = []   # all vp-level nodes freed on rebuild
var _ring_mesh_list:   Array = []
var _hover_ring:      MeshInstance3D = null
var _selection_ring:  MeshInstance3D = null
var _body_radius:     float = 1.5
var _paused: bool = false
var _time:   float = 0.0
var _elapsed_days:  float = 0.0
var _ships_data:    Array = []
var _colonies_data: Array = []   # Array[ColonyState]
var _ship_nodes:       Array = []   # per-ship render entries
var _struct_nodes:     Array = []   # per-orbital-structure render entries
var _label_list: Array[Label3D] = []

var _look_at:    Vector3 = Vector3.ZERO
var _cam_offset: Vector3 = Vector3(0.0, 4.0, 8.0)
var _hover_name:    String  = ""
var _selected_body: String  = ""
var _vis_frames: int = 0   # frames since last became visible; skip hover until ≥ 2
var _dragging:   bool    = false
var _did_drag:   bool    = false
var _sun_light:  DirectionalLight3D = null
const _PAN_SPEED := 0.0035
var _cam_dist_min: float = 1.5
var _cam_dist_max: float = 200.0

# ── Earth-specific runtime state ──────────────────────────────────────────────
var _cloud_root:      Node3D           = null
var _city_lights:     Array[Node3D]    = []
var _sat_orbits:      Array[Node3D]    = []
var _crew_orbit:      Node3D           = null
var _stn_orbit:       Node3D           = null
var _rocket_root:     Node3D           = null
var _transit_craft:   Node3D           = null
var _flag_node:       MeshInstance3D   = null
var _earth_moon_mat:  StandardMaterial3D = null
var _earth_moon_mi:   MeshInstance3D   = null
var _launches:        Array            = []
var _launch_timer:    float            = 0.0
var _population:      float            = 0.0
var _completed:       Array            = []
var _active_research: String           = ""
var _moon_mission_active: bool         = false
var _moon_landing:        bool         = false


# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_db        = BodyDB.new()
	_struct_db = StructureDB.new()
	_build_viewport()
	ScaleEngine.body_changed.connect(_on_body_changed)
	ScaleEngine.zone_changed.connect(_on_zone_changed)
	if BODY_CATALOG.has(ScaleEngine.current_body):
		_rebuild(ScaleEngine.current_body)


func _build_viewport() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d   = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var env := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.05, 0.10, 0.20)
	env.ambient_light_energy = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	_sun_light = DirectionalLight3D.new()
	_sun_light.rotation_degrees = Vector3(-15, -20, 0)
	_sun_light.light_energy = 1.5
	_sun_light.light_color  = Color(1.0, 0.98, 0.95)
	_vp.add_child(_sun_light)

	_cam = Camera3D.new()
	_cam.near = 0.01
	_cam.far  = 5000.0
	_vp.add_child(_cam)

	_body_root = Node3D.new()
	_vp.add_child(_body_root)

	_hover_ring = SceneUtil.make_orbit_ring(1.0, Color(0.70, 1.00, 1.00, 0.90))
	_hover_ring.visible = false
	_vp.add_child(_hover_ring)

	_selection_ring = SceneUtil.make_orbit_ring(1.0, Color(1.00, 0.88, 0.20, 0.85))
	_selection_ring.visible = false
	_vp.add_child(_selection_ring)


# ── Body switching ─────────────────────────────────────────────────────────────

func _on_body_changed(body_name: String) -> void:
	_hover_name = ""
	if _selected_body != "":
		_selected_body = ""
		body_deselected.emit()
	_rebuild(body_name)


func _rebuild(body_name: String) -> void:
	# ── Clear previous content ────────────────────────────────────────────────
	for c in _body_root.get_children():
		c.queue_free()
	for entry: Dictionary in _moon_pivots:
		(entry["pivot"] as Node3D).queue_free()
	_moon_pivots.clear()
	for n in _orbit_ring_nodes:
		if is_instance_valid(n): (n as Node).queue_free()
	_orbit_ring_nodes.clear()
	_ring_mesh_list.clear()
	_label_list.clear()
	_launches.clear()
	_clear_ship_nodes()
	_clear_struct_nodes()

	# Clear Earth state refs (nodes freed above via _orbit_ring_nodes)
	_cloud_root     = null
	_rocket_root    = null
	_transit_craft  = null
	_city_lights.clear()
	_sat_orbits.clear()
	_crew_orbit     = null
	_stn_orbit      = null
	_flag_node      = null
	_earth_moon_mat = null
	_earth_moon_mi  = null

	if _selection_ring:
		_selection_ring.visible = false
	if not BODY_CATALOG.has(body_name):
		return

	var data: Dictionary = BODY_CATALOG[body_name]
	var radius: float    = data["radius"]
	_body_radius  = radius
	_cam_dist_min = radius * 1.4
	_cam_dist_max = data["cam_max"]

	# ── Main body sphere ───────────────────────────────────────────────────────
	var planet_sm := _sphere(radius, 64, 32)
	planet_sm.surface_set_material(0, _body_material(body_name, data))
	_body_root.add_child(_inst(planet_sm))

	# ── Body name label ────────────────────────────────────────────────────────
	var body_lbl := SceneUtil.make_orbit_label(body_name, Color.WHITE, 999999.0)
	body_lbl.position = Vector3(0.0, radius * 1.5, 0.0)
	body_lbl.set_meta("body_name", body_name)
	_vp.add_child(body_lbl)
	_orbit_ring_nodes.append(body_lbl)
	_label_list.append(body_lbl)

	# ── Earth overlay: clouds, city lights, Moon, satellites, rockets ──────────
	if body_name == "Earth":
		_build_earth_overlay()

	# ── Generic atmosphere ─────────────────────────────────────────────────────
	if data.has("atmo"):
		var atmo_col: Color = data["atmo"]
		var atmo_sm := _sphere(radius * 1.05, 32, 16)
		var atmo_mat := StandardMaterial3D.new()
		atmo_mat.albedo_color = atmo_col
		atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		atmo_mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
		atmo_sm.surface_set_material(0, atmo_mat)
		_body_root.add_child(_inst(atmo_sm))

	# ── Saturn-style ring system ───────────────────────────────────────────────
	if data.get("rings", false):
		_build_rings(radius, _body_root)

	# ── Moons + orbit rings (generic — skipped for Earth; Moon built in overlay) ─
	for md: Dictionary in data.get("moons", []):
		_build_moon(md)
		var moon_entry: Dictionary = _moon_pivots.back()
		var moon_mi    := moon_entry["mi"] as MeshInstance3D
		var moon_r     := float(moon_entry["radius"])
		var mname      := str(moon_entry["name"])
		var name_lbl   := SceneUtil.make_orbit_label(mname, Color.WHITE, 999999.0)
		name_lbl.position = Vector3(0.0, moon_r * 2.0, 0.0)
		name_lbl.set_meta("body_name", mname)
		moon_mi.add_child(name_lbl)
		_label_list.append(name_lbl)
		var dist: float = float(md["dist"])
		var ring := _orbit_ring_mesh(dist, Color(1.0, 1.0, 1.0, 0.25))
		_vp.add_child(ring)
		_orbit_ring_nodes.append(ring)
		_ring_mesh_list.append(ring)
		var lbl := _ring_label(dist)
		_vp.add_child(lbl)
		_orbit_ring_nodes.append(lbl)
		_label_list.append(lbl)

	# ── Selection ring ─────────────────────────────────────────────────────────
	if _selection_ring:
		_selection_ring.position = Vector3.ZERO
		_selection_ring.scale    = Vector3.ONE * radius * 1.35
		_selection_ring.visible  = true

	# ── Reference rings (Sol corona zones, etc.) ───────────────────────────────
	for rd: Dictionary in data.get("reference_rings", []):
		var dist: float = float(rd["dist"])
		var ring := _orbit_ring_mesh(dist, Color(1.0, 1.0, 1.0, 0.25))
		_vp.add_child(ring)
		_orbit_ring_nodes.append(ring)
		_ring_mesh_list.append(ring)
		var lbl := _ref_label(rd["label"], dist)
		_vp.add_child(lbl)
		_orbit_ring_nodes.append(lbl)
		_label_list.append(lbl)

	_apply_zone_camera(ScaleEngine.current_zone)  # bypasses visibility guard


# ── Earth overlay ─────────────────────────────────────────────────────────────

func _build_earth_overlay() -> void:
	# Cloud + atmosphere layer (rotates slightly faster than surface)
	_cloud_root = Node3D.new()
	_vp.add_child(_cloud_root)
	_orbit_ring_nodes.append(_cloud_root)

	var m_cloud := _sphere(CLOUD_R, 48, 24)
	var mat_cloud := StandardMaterial3D.new()
	mat_cloud.albedo_color = Color(0.94, 0.90, 0.80, 0.22)
	mat_cloud.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_cloud.cull_mode    = BaseMaterial3D.CULL_DISABLED
	mat_cloud.roughness    = 1.0
	m_cloud.surface_set_material(0, mat_cloud)
	_cloud_root.add_child(_inst(m_cloud))

	var m_atmo := _sphere(ATMO_R, 32, 16)
	var mat_atmo := StandardMaterial3D.new()
	mat_atmo.albedo_color = Color(0.20, 0.65, 0.85, 0.09)
	mat_atmo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_atmo.cull_mode    = BaseMaterial3D.CULL_DISABLED
	m_atmo.surface_set_material(0, mat_atmo)
	_cloud_root.add_child(_inst(m_atmo))

	# City lights (parented to _body_root so they co-rotate with Earth surface)
	_city_lights.clear()
	for ll: Array in CITY_LATLONS:
		var pos  := _ll(ll[0], ll[1], EARTH_R + 0.035)
		var m    := _sphere(0.038, 6, 4)
		var mat  := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.58, 0.12)
		mat.emission_enabled = true
		mat.emission = Color(0.92, 0.46, 0.06)
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.surface_set_material(0, mat)
		var inst := _inst(m)
		inst.position = pos
		inst.visible  = false
		_body_root.add_child(inst)
		_city_lights.append(inst)

	# Satellite orbital pivots
	_sat_orbits.clear()
	for p: Array in SAT_ORBIT_PARAMS:
		var pivot := _orbit_pivot(_vp, p[1], false)
		pivot.rotation_degrees.z = p[2]
		var arm := Node3D.new()
		arm.position = Vector3(p[0], 0.0, 0.0)
		pivot.add_child(arm)
		_add_satellite(arm)
		_sat_orbits.append(pivot)
		_orbit_ring_nodes.append(pivot)

	# Crewed orbit
	_crew_orbit = _orbit_pivot(_vp, 55.0, false)
	_crew_orbit.rotation_degrees.z = 12.0
	var crew_arm := Node3D.new()
	crew_arm.position = Vector3(ORBIT_SAT + 0.12, 0.0, 0.0)
	_crew_orbit.add_child(crew_arm)
	_add_capsule(crew_arm)
	_orbit_ring_nodes.append(_crew_orbit)

	# Station orbit
	_stn_orbit = _orbit_pivot(_vp, 25.0, false)
	_stn_orbit.rotation_degrees.z = 8.0
	var stn_arm := Node3D.new()
	stn_arm.position = Vector3(ORBIT_STN, 0.1, 0.0)
	_stn_orbit.add_child(stn_arm)
	_add_station(stn_arm)
	_orbit_ring_nodes.append(_stn_orbit)

	# Moon — full-detail: procedural texture, flag, transit craft
	var m_moon := _sphere(0.409, 32, 16)
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_texture = _gen_moon_texture()
	moon_mat.roughness = 0.95
	_earth_moon_mat = moon_mat
	m_moon.surface_set_material(0, moon_mat)
	var moon_pivot := Node3D.new()
	_vp.add_child(moon_pivot)
	_earth_moon_mi = _inst(m_moon)
	_earth_moon_mi.position = Vector3(MOON_DIST, 0.0, 0.0)
	moon_pivot.add_child(_earth_moon_mi)
	# Name label follows the Moon as it orbits
	var moon_name_lbl := SceneUtil.make_orbit_label("Moon", Color.WHITE, 999999.0)
	moon_name_lbl.position = Vector3(0.0, 0.409 * 2.0, 0.0)
	moon_name_lbl.set_meta("body_name", "Moon")
	_earth_moon_mi.add_child(moon_name_lbl)
	_label_list.append(moon_name_lbl)
	# Flag
	var m_flag := BoxMesh.new()
	m_flag.size = Vector3(0.05, 0.09, 0.01)
	var mat_flag := StandardMaterial3D.new()
	mat_flag.albedo_color = Color(0.92, 0.48, 0.12)
	mat_flag.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_flag.surface_set_material(0, mat_flag)
	_flag_node = _inst(m_flag)
	_flag_node.position = Vector3(MOON_DIST + 0.15, 0.409 + 0.05, 0.0)
	_flag_node.visible  = false
	moon_pivot.add_child(_flag_node)
	# Orbit animation driven by same VisualClock system as all other moons
	_moon_pivots.append({"pivot": moon_pivot, "period": 27.3,
			"mi": _earth_moon_mi, "name": "Moon", "radius": 0.409})

	# Transit craft (Earth→Moon path)
	_transit_craft = Node3D.new()
	_transit_craft.visible = false
	_vp.add_child(_transit_craft)
	_orbit_ring_nodes.append(_transit_craft)
	var m_craft := _sphere(0.065, 8, 6)
	var mat_craft := StandardMaterial3D.new()
	mat_craft.albedo_color = Color(0.92, 0.55, 0.12)
	mat_craft.emission_enabled = true
	mat_craft.emission = Color(0.92, 0.48, 0.08)
	mat_craft.emission_energy_multiplier = 2.0
	m_craft.surface_set_material(0, mat_craft)
	_transit_craft.add_child(_inst(m_craft))

	# Rocket root
	_rocket_root = Node3D.new()
	_vp.add_child(_rocket_root)
	_orbit_ring_nodes.append(_rocket_root)

	# Earth system distance rings
	for r_data: Array in [[2.50, "500 km"], [3.70, "36,000 km"], [MOON_DIST + 0.15, "384,000 km"]]:
		var dist: float = float(r_data[0])
		var ring := _orbit_ring_mesh(dist, Color(1.0, 1.0, 1.0, 0.25))
		_vp.add_child(ring)
		_orbit_ring_nodes.append(ring)
		_ring_mesh_list.append(ring)
		var gap := TAU / 6.0
		var lbl := SceneUtil.make_orbit_label(str(r_data[1]), Color.WHITE, dist)
		lbl.position = Vector3(cos(gap) * dist, dist * 0.12, sin(gap) * dist)
		_vp.add_child(lbl)
		_orbit_ring_nodes.append(lbl)
		_label_list.append(lbl)

	# Orbit ring for Moon's orbit (visual only)
	var moon_ring := _orbit_ring_mesh(MOON_DIST, Color(1.0, 1.0, 1.0, 0.15))
	_vp.add_child(moon_ring)
	_orbit_ring_nodes.append(moon_ring)
	_ring_mesh_list.append(moon_ring)


# ── Saturn rings / generic moon ────────────────────────────────────────────────

func _build_rings(planet_r: float, parent: Node3D) -> void:
	var ring_zones: Array[Array] = [
		[planet_r * 1.20, planet_r * 1.53, Color(0.70, 0.65, 0.52, 0.35)],
		[planet_r * 2.02, planet_r * 2.30, Color(0.78, 0.72, 0.55, 0.30)],
	]
	for zone: Array in ring_zones:
		parent.add_child(_flat_ring(zone[0], zone[1], zone[2]))


func _build_moon(md: Dictionary) -> void:
	var pivot := Node3D.new()
	_vp.add_child(pivot)
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_texture = _gen_grey_texture(md["color"])
	moon_mat.roughness      = 0.95
	var moon_sm := _sphere(md["radius"], 24, 12)
	moon_sm.surface_set_material(0, moon_mat)
	var moon_mi := _inst(moon_sm)
	moon_mi.position = Vector3(md["dist"], 0.0, 0.0)
	pivot.add_child(moon_mi)
	_moon_pivots.append({"pivot": pivot, "period": float(md["period"]),
			"mi": moon_mi, "name": md["name"], "radius": float(md["radius"])})


# ── Earth orbital object builders ─────────────────────────────────────────────

func _orbit_pivot(parent: Node, y_deg: float, start_visible: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.rotation_degrees.y = y_deg
	pivot.visible = start_visible
	parent.add_child(pivot)
	return pivot


func _add_satellite(parent: Node3D) -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.82, 0.78, 0.66)
	body_mat.metallic     = 0.6
	var body := BoxMesh.new()
	body.size = Vector3(0.045, 0.022, 0.022)
	body.surface_set_material(0, body_mat)
	parent.add_child(_inst(body))
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.08, 0.28, 0.48)
	panel_mat.metallic     = 0.5
	panel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: int in [-1, 1]:
		var panel := BoxMesh.new()
		panel.size = Vector3(0.055, 0.006, 0.032)
		panel.surface_set_material(0, panel_mat)
		var pi := _inst(panel)
		pi.position = Vector3(float(side) * 0.052, 0.0, 0.0)
		parent.add_child(pi)


func _add_capsule(parent: Node3D) -> void:
	var m := _sphere(0.07, 8, 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.84, 0.72)
	mat.metallic     = 0.3
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))


func _add_station(parent: Node3D) -> void:
	var m := BoxMesh.new()
	m.size = Vector3(0.40, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.80, 0.76, 0.64)
	mat.metallic     = 0.4
	m.surface_set_material(0, mat)
	parent.add_child(_inst(m))


# ── Material / texture dispatch ────────────────────────────────────────────────

func _body_material(body_name: String, data: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if data.get("emissive", false):
		var col: Color = data["color"]
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return mat
	match body_name:
		"Earth":
			mat.albedo_texture = _gen_earth_texture()
		"Moon", "Charon":
			mat.albedo_texture = _gen_moon_texture()
		"Mercury", "Ceres", "Phobos", "Deimos", "Mimas", "Miranda":
			mat.albedo_texture = _gen_rocky_texture(data["color"], 0.85, false)
		"Mars":
			mat.albedo_texture = _gen_rocky_texture(data["color"], 0.50, true)
		"Pluto":
			mat.albedo_texture = _gen_rocky_texture(data["color"], 0.40, true)
		"Venus":
			mat.albedo_texture = _gen_cloud_texture(data["color"])
		"Jupiter":
			mat.albedo_texture = _gen_gas_giant_texture([
				Color(0.88, 0.74, 0.52), Color(0.72, 0.55, 0.38),
				Color(0.92, 0.82, 0.64), Color(0.68, 0.50, 0.34)])
		"Saturn":
			mat.albedo_texture = _gen_gas_giant_texture([
				Color(0.90, 0.82, 0.60), Color(0.80, 0.72, 0.50),
				Color(0.94, 0.88, 0.68), Color(0.78, 0.70, 0.48)])
		"Uranus":
			mat.albedo_texture = _gen_ice_giant_texture(Color(0.55, 0.80, 0.85))
		"Neptune":
			mat.albedo_texture = _gen_ice_giant_texture(Color(0.28, 0.42, 0.85))
		"Titan":
			mat.albedo_texture = _gen_cloud_texture(Color(0.82, 0.62, 0.30))
		"Europa":
			mat.albedo_texture = _gen_rocky_texture(data["color"], 0.20, false)
		_:
			mat.albedo_texture = _gen_grey_texture(data.get("color", Color(0.6, 0.6, 0.6)))
	mat.roughness = 0.75
	mat.metallic  = 0.05
	return mat


# ── Procedural textures ────────────────────────────────────────────────────────

func _gen_earth_texture() -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.16, 0.38))
	for c: Array in _CONTINENTS_UV:
		_fill_ellipse(img, c[0], c[1], c[2], c[3], c[4])
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
	for py in H:
		for px in W:
			var n := (_hash(px, py) - 0.5) * 0.06
			var c2 := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(
				clampf(c2.r + n, 0.0, 1.0),
				clampf(c2.g + n * 0.8, 0.0, 1.0),
				clampf(c2.b + n * 0.6, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _gen_moon_texture() -> ImageTexture:
	var W := 256; var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.82, 0.78, 0.66))
	var mare := Color(0.54, 0.50, 0.40)
	_fill_ellipse(img, 0.35, 0.40, 0.12, 0.14, mare)
	_fill_ellipse(img, 0.60, 0.45, 0.09, 0.10, mare)
	_fill_ellipse(img, 0.20, 0.55, 0.07, 0.08, mare)
	_fill_ellipse(img, 0.72, 0.35, 0.06, 0.07, mare)
	for cr: Array in [
			[0.45, 0.38, 0.05], [0.25, 0.42, 0.04], [0.65, 0.52, 0.035],
			[0.55, 0.28, 0.03], [0.38, 0.60, 0.04], [0.78, 0.45, 0.03],
			[0.15, 0.35, 0.025],[0.82, 0.58, 0.025],[0.50, 0.70, 0.03]]:
		_fill_ellipse(img, cr[0], cr[1], cr[2], cr[2], Color(0.88, 0.84, 0.72))
		_fill_ellipse(img, cr[0], cr[1], cr[2] * 0.7, cr[2] * 0.7, Color(0.44, 0.40, 0.34))
	for py in H:
		for px in W:
			var n := (_hash(px * 3 + 7, py * 5 + 11) - 0.5) * 0.05
			var c2 := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(
				clampf(c2.r + n, 0.0, 1.0), clampf(c2.g + n, 0.0, 1.0), clampf(c2.b + n, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _gen_rocky_texture(base: Color, crater_density: float, polar_caps: bool) -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(base)
	var rng := RandomNumberGenerator.new(); rng.seed = base.to_argb32()
	for _i in int(crater_density * 120):
		var cx := rng.randf(); var cy := rng.randf_range(0.05, 0.95)
		var cr := rng.randf_range(0.012, 0.055)
		_fill_ellipse(img, cx, cy, cr, cr, base.lightened(0.18))
		_fill_ellipse(img, cx, cy, cr * 0.65, cr * 0.65, base.darkened(0.22))
	if polar_caps:
		for py in H:
			var v := float(py) / H
			if v < 0.06 or v > 0.92:
				for px in W: img.set_pixel(px, py, Color(0.94, 0.90, 0.86))
	_add_noise(img, 0.06)
	return ImageTexture.create_from_image(img)


func _gen_cloud_texture(base: Color) -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(base)
	var rng := RandomNumberGenerator.new(); rng.seed = 99887
	for _i in 60:
		var cx := rng.randf(); var cy := rng.randf_range(0.05, 0.95)
		_fill_ellipse(img, cx, cy, rng.randf_range(0.04, 0.18), rng.randf_range(0.02, 0.06),
				base.lightened(0.12))
	_add_noise(img, 0.04)
	return ImageTexture.create_from_image(img)


func _gen_gas_giant_texture(bands: Array) -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for py in H:
		var t    := float(py) / H
		var wave := (sin(t * 14.0 * PI) + sin(t * 7.5 * PI + 1.2) + sin(t * 22.0 * PI)) / 3.0
		var idx  := int((wave * 0.5 + 0.5) * bands.size()) % bands.size()
		var col: Color = bands[idx]
		for px in W:
			var jitter := (_hash(px, py) - 0.5) * 0.05
			img.set_pixel(px, py, Color(
				clampf(col.r + jitter, 0, 1),
				clampf(col.g + jitter * 0.8, 0, 1),
				clampf(col.b + jitter * 0.6, 0, 1)))
	return ImageTexture.create_from_image(img)


func _gen_ice_giant_texture(base: Color) -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	for py in H:
		var t    := float(py) / H
		var wave := sin(t * 8.0 * PI + 0.5) * 0.04
		var col  := Color(base.r + wave, base.g + wave * 0.5, base.b + wave * 0.2)
		for px in W: img.set_pixel(px, py, col)
	_add_noise(img, 0.025)
	return ImageTexture.create_from_image(img)


func _gen_grey_texture(base: Color) -> ImageTexture:
	var W := 256; var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(base)
	var rng := RandomNumberGenerator.new(); rng.seed = base.to_argb32() ^ 0xABCD
	for _i in 30:
		var cx := rng.randf(); var cy := rng.randf_range(0.05, 0.95)
		var cr := rng.randf_range(0.02, 0.08)
		_fill_ellipse(img, cx, cy, cr, cr, base.lightened(0.15))
		_fill_ellipse(img, cx, cy, cr * 0.6, cr * 0.6, base.darkened(0.20))
	_add_noise(img, 0.04)
	return ImageTexture.create_from_image(img)


func _fill_ellipse(img: Image, uc: float, vc: float, ur: float, vr: float, col: Color) -> void:
	var W := img.get_width(); var H := img.get_height()
	var x0 := int((uc - ur) * W); var x1 := int((uc + ur) * W)
	var y0 := maxi(0, int((vc - vr) * H)); var y1 := mini(H - 1, int((vc + vr) * H))
	for py in range(y0, y1 + 1):
		var dv := (float(py) / H - vc) / vr
		for px in range(x0, x1 + 1):
			var wpx := posmod(px, W)
			var du  := (float(wpx) / W - uc) / ur
			if du * du + dv * dv <= 1.0:
				img.set_pixel(wpx, py, col)


func _add_noise(img: Image, strength: float) -> void:
	var W := img.get_width(); var H := img.get_height()
	for py in H:
		for px in W:
			var n := (_hash(px, py) - 0.5) * strength
			var c := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(
				clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1)))


func _hash(x: int, y: int) -> float:
	var n := x + y * 57
	n = (n << 13) ^ n
	return float((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 2147483647.0


func _ll(lat: float, lon: float, radius: float) -> Vector3:
	return Vector3(radius * cos(lat) * cos(lon), radius * sin(lat), radius * cos(lat) * sin(lon))


func _orient_y_up(node: Node3D, pos: Vector3) -> void:
	var up    := pos.normalized()
	var ref   := Vector3(0, 0, 1) if abs(up.dot(Vector3(0, 1, 0))) > 0.99 else Vector3(0, 1, 0)
	var right := ref.cross(up).normalized()
	node.basis = Basis(right, up, right.cross(up).cross(right))


# ── Mesh helpers ───────────────────────────────────────────────────────────────

func _sphere(radius: float, radial: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius; m.height = radius * 2.0
	m.radial_segments = radial; m.rings = rings
	return m


func _inst(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; return mi


func _orbit_ring_mesh(radius: float, col: Color) -> MeshInstance3D:
	return SceneUtil.make_orbit_ring(radius, col)


func _ring_label(dist: float) -> Label3D:
	var km  := dist * (6371.0 / 1.5)
	var gap := TAU / 6.0
	var lbl := SceneUtil.make_orbit_label(UIUtil.fmt_km(km), Color.WHITE, dist)
	lbl.position = Vector3(cos(gap) * dist, dist * 0.18, sin(gap) * dist)
	return lbl


func _ref_label(text: String, dist: float) -> Label3D:
	var gap := TAU / 6.0
	var lbl := SceneUtil.make_orbit_label(text, Color.WHITE, dist)
	lbl.position = Vector3(cos(gap) * dist, dist * 0.18, sin(gap) * dist)
	return lbl


func _flat_ring(inner_r: float, outer_r: float, col: Color) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arr  := []; arr.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	var inds  := PackedInt32Array()
	const N := 64
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
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new(); mi.mesh = mesh; return mi


# ── State update (Earth gameplay) ─────────────────────────────────────────────

func update_state(state: Object) -> void:
	var s := state as SimulationState
	_elapsed_days  = s.elapsed_days
	_ships_data    = s.ships
	_colonies_data = s.colonies
	_sync_ship_nodes()
	_sync_struct_nodes()

	if ScaleEngine.current_body != "Earth":
		return
	_population          = float(s.population_units)
	_completed           = s.completed_research
	_active_research     = s.active_research
	_moon_mission_active = s.moon_mission_active
	_moon_landing        = s.milestone_flags.get("moon_landing", false)

	var visible_cities := int(clampf(_population / 8.0, 1, _city_lights.size()))
	for i in _city_lights.size():
		_city_lights[i].visible = i < visible_cities

	var n_sats := _satellite_count()
	for i in _sat_orbits.size():
		_sat_orbits[i].visible = i < n_sats
	if _crew_orbit: _crew_orbit.visible = "crewed_orbit"    in _completed
	if _stn_orbit:  _stn_orbit.visible  = "modular_station" in _completed

	if _earth_moon_mat:
		if _moon_landing:
			_earth_moon_mat.emission_enabled = true
			_earth_moon_mat.emission = Color(0.8, 0.75, 0.5)
			_earth_moon_mat.emission_energy_multiplier = 0.5
		elif "lunar_transit" in _completed:
			_earth_moon_mat.albedo_color = Color(1.1, 1.1, 1.0)
		else:
			_earth_moon_mat.albedo_color = Color(1.0, 1.0, 1.0)
			_earth_moon_mat.emission_enabled = false
	if _flag_node:     _flag_node.visible     = _moon_landing
	if _transit_craft: _transit_craft.visible  = _moon_mission_active and not _moon_landing


func _satellite_count() -> int:
	if not "orbital_satellite" in _completed: return 0
	var n := 1
	for m in ["long_duration_crewed", "modular_station", "expanded_station", "lunar_transit"]:
		if m in _completed: n += 1
	return mini(n, SAT_ORBIT_PARAMS.size())


# ── Ship nodes (local view: orbiting + in-transit ships) ─────────────────────

func _clear_ship_nodes() -> void:
	for entry in _ship_nodes:
		for key in ["dot_mi", "ring_mi", "arc_mi", "trail_mi"]:
			var mi = entry.get(key)
			if mi and is_instance_valid(mi): (mi as Node).queue_free()
		var lbl = entry.get("label")
		if lbl and is_instance_valid(lbl): (lbl as Node).queue_free()
	_ship_nodes.clear()


func _sync_ship_nodes() -> void:
	var body := ScaleEngine.current_body
	var relevant: Array = []
	for s in _ships_data:
		var ship := s as Ship
		var kind := _ship_kind_for(ship, body)
		if kind != "":
			relevant.append({"kind": kind, "ship": ship})

	# Rebuild when the ship set changes
	var needs_rebuild := relevant.size() != _ship_nodes.size()
	if not needs_rebuild:
		for i in relevant.size():
			if (relevant[i]["ship"] as Ship) != (_ship_nodes[i]["ship"] as Ship) \
					or str(relevant[i]["kind"]) != str(_ship_nodes[i]["kind"]):
				needs_rebuild = true
				break

	if not needs_rebuild:
		return

	_clear_ship_nodes()
	for item in relevant:
		var ship: Ship = item["ship"]
		var kind: String = item["kind"]
		var entry := {"ship": ship, "kind": kind,
				"dot_mi": null, "ring_mi": null,
				"arc_mi": null, "trail_mi": null,
				"arc_mat": null, "trail_mat": null, "label": null,
				"orbit_r_wu": 0.0, "orbit_period_days": 1.0}

		# Dot (all kinds)
		var dot := _ship_dot()
		_vp.add_child(dot)
		entry["dot_mi"] = dot

		if kind == "orbit":
			var orbit_r_wu := ship.orbit_radius_km(_body_radius / WU_PER_KM) * WU_PER_KM
			var period     := _orbit_period_days(orbit_r_wu, body)
			entry["orbit_r_wu"]        = orbit_r_wu
			entry["orbit_period_days"] = period
			var ring := SceneUtil.make_orbit_ring(orbit_r_wu, _COL_ORBIT_RING)
			_vp.add_child(ring)
			entry["ring_mi"] = ring

		elif kind == "transit_local":
			var arc_mi   := _line_mi(_COL_ARC_DIM)
			var trail_mi := _line_mi(_COL_ARC_TRAIL)
			_vp.add_child(arc_mi)
			_vp.add_child(trail_mi)
			entry["arc_mi"]   = arc_mi
			entry["trail_mi"] = trail_mi
			entry["arc_mat"]  = arc_mi.get_meta("mat")
			entry["trail_mat"] = trail_mi.get_meta("mat")

		# Label parented to dot
		var lbl := SceneUtil.make_orbit_label(ship.label, Color.WHITE, 999999.0)
		lbl.position = Vector3(0.0, 0.12, 0.0)
		dot.add_child(lbl)
		entry["label"] = lbl
		_ship_nodes.append(entry)


func _update_ship_positions() -> void:
	var body := ScaleEngine.current_body
	for entry in _ship_nodes:
		var ship: Ship = entry["ship"]
		var kind: String = entry["kind"]
		var dot: MeshInstance3D = entry["dot_mi"]

		match kind:
			"orbit":
				var r:      float = entry["orbit_r_wu"]
				var period: float = entry["orbit_period_days"]
				var angle := fmod(_elapsed_days * TAU / maxf(period, 0.001), TAU)
				dot.position = Vector3(cos(angle) * r, 0.0, sin(angle) * r)

			"transit_local":
				var dur := ship.arrival_day - ship.departure_day
				var t   := clampf((_elapsed_days - ship.departure_day) / maxf(dur, 1.0), 0.0, 1.0)
				var origin_wu := _local_pos_wu(ship.origin_body,      ship.departure_day)
				var dest_wu   := _local_pos_wu(ship.destination_body, ship.arrival_day)
				var all_pts: PackedVector3Array
				match ship.arc_type:
					Ship.TrajectoryType.SPIRAL:
						all_pts = _OM.spiral_arc_points(origin_wu, dest_wu, ship.n_turns, _ARC_STEPS)
					Ship.TrajectoryType.TORCH:
						all_pts = _OM.torch_arc_points(origin_wu, dest_wu, _ARC_STEPS)
					_:   # HOHMANN (default for local transfers)
						all_pts = _OM.hohmann_arc_points(origin_wu, dest_wu, _ARC_STEPS)
				var split := clampi(int(t * (_ARC_STEPS - 1)), 0, _ARC_STEPS - 2)
				_set_line_mesh(entry["trail_mi"], all_pts.slice(0, split + 1), entry["trail_mat"])
				_set_line_mesh(entry["arc_mi"],   all_pts.slice(split),        entry["arc_mat"])
				dot.position = all_pts[clampi(split, 0, all_pts.size() - 1)]

			"transit_solar":
				# Solar arc is not meaningful at local scale — show dot entering/leaving.
				var far_r := _body_radius * 18.0
				var dir   := _solar_direction_of(
						ship.destination_body if ship.origin_body == body else ship.origin_body)
				var dur   := ship.arrival_day - ship.departure_day
				var t     := clampf((_elapsed_days - ship.departure_day) / maxf(dur, 1.0), 0.0, 1.0)
				if ship.origin_body == body:
					dot.position = Vector3.ZERO.lerp(dir * far_r, t)
				else:
					dot.position = (dir * far_r).lerp(Vector3.ZERO, t)


# ── Ship rendering helpers ────────────────────────────────────────────────────

# Returns the render kind for a ship relative to the current body, or "" to skip.
func _ship_kind_for(ship: Ship, body: String) -> String:
	match ship.ship_state:
		Ship.ShipState.ORBITING:
			if ship.origin_body == body:
				return "orbit"
		Ship.ShipState.IN_TRANSIT:
			if ship.is_local:
				# Belongs to this body's system
				if ship.origin_body == body or ship.destination_body == body:
					return "transit_local"
				if _is_moon_of(ship.origin_body, body) or _is_moon_of(ship.destination_body, body):
					return "transit_local"
			else:
				if ship.origin_body == body or ship.destination_body == body:
					return "transit_solar"
	return ""


func _is_moon_of(moon_id: String, parent_id: String) -> bool:
	return str(_db.get_body(moon_id).get("parent", "")) == parent_id


# Body position in planet-view WU, local frame (planet = origin).
func _local_pos_wu(body_id: String, elapsed_days: float) -> Vector3:
	if body_id == ScaleEngine.current_body:
		return Vector3.ZERO
	# body_pos_at for moons returns km from their parent — perfect for local frame.
	return _db.body_pos_at(body_id, elapsed_days) * WU_PER_KM


# Circular orbit period (days) for a ship at orbit_r_wu around body_name.
func _orbit_period_days(orbit_r_wu: float, body_name: String) -> float:
	var r_km := orbit_r_wu / WU_PER_KM
	var gm   := _body_gm_km3(body_name)
	return TAU * sqrt(pow(r_km, 3.0) / gm)


# GM of a body in km³/day². Uses GM_PLANETS table or estimates from mass ratio.
func _body_gm_km3(body_name: String) -> float:
	if _OM.GM_PLANETS.has(body_name):
		return float(_OM.GM_PLANETS[body_name])
	var mr := _db.mass_ratio(body_name)
	if mr > 0.0:
		var gm_sun_km3 := _OM.GM_SUN * pow(_OM.AU_TO_KM, 3.0)
		return mr * gm_sun_km3
	return float(_OM.GM_PLANETS.get("Earth", 3.008e15))


func _ship_dot() -> MeshInstance3D:
	var sm := _sphere(0.06, 8, 6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _COL_SHIP
	mat.emission_enabled = true
	mat.emission = _COL_SHIP
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.surface_set_material(0, mat)
	return _inst(sm)


func _solar_direction_of(planet_name: String) -> Vector3:
	var b := _db.get_body(planet_name)
	if b.is_empty():
		return Vector3(1.0, 0.0, 0.0)
	var au:     float = float(b.get("orbital_au", 1.0))
	var period: float = float(b.get("orbital_period_years", 1.0)) * 365.25
	var ang0:   float = float(b.get("ang0_deg", 0.0))
	var angle := deg_to_rad(ang0) + (_elapsed_days / period) * TAU
	return Vector3(cos(angle), 0.0, sin(angle))


# ── Orbital structure nodes ───────────────────────────────────────────────────

func _clear_struct_nodes() -> void:
	for entry in _struct_nodes:
		var dot = entry.get("dot_mi")
		if dot and is_instance_valid(dot): (dot as Node).queue_free()
		var ring = entry.get("ring_mi")
		if ring and is_instance_valid(ring): (ring as Node).queue_free()
		var lbl = entry.get("label")
		if lbl and is_instance_valid(lbl): (lbl as Node).queue_free()
	_struct_nodes.clear()


func _sync_struct_nodes() -> void:
	var body := ScaleEngine.current_body

	# Collect all orbital structures at the current body.
	# Each (colony, struct_id) pair that has orbit_km becomes one render entry.
	var relevant: Array = []   # Array of {struct_id, orbit_km, display_name}
	for col in _colonies_data:
		var colony := col as ColonyState
		if colony.body_id != body:
			continue
		for sid: String in colony.structures:
			var km = _struct_db.get_orbit_km(sid)
			if km == null:
				continue
			relevant.append({
				"struct_id":    sid,
				"orbit_km":     float(km),
				"display_name": _struct_db.get_display_name(sid),
			})

	# Rebuild only when the set changes
	var needs_rebuild := relevant.size() != _struct_nodes.size()
	if not needs_rebuild:
		for i in relevant.size():
			if str(relevant[i]["struct_id"]) != str(_struct_nodes[i]["struct_id"]):
				needs_rebuild = true
				break

	if not needs_rebuild:
		return

	_clear_struct_nodes()
	for item in relevant:
		# orbit_km is altitude above surface; add body radius for total orbital radius.
		var body_radius_km := _body_radius / WU_PER_KM
		var orbit_r_wu     := (body_radius_km + float(item["orbit_km"])) * WU_PER_KM
		var period         := _orbit_period_days(orbit_r_wu, body)

		var ring := SceneUtil.make_orbit_ring(orbit_r_wu, _COL_ORBIT_RING)
		_vp.add_child(ring)

		var dot := _ship_dot()
		_vp.add_child(dot)

		var lbl := SceneUtil.make_orbit_label(
				str(item["display_name"]), Color.WHITE, 999999.0)
		lbl.position = Vector3(0.0, 0.12, 0.0)
		dot.add_child(lbl)

		_struct_nodes.append({
			"struct_id":         str(item["struct_id"]),
			"ring_mi":           ring,
			"dot_mi":            dot,
			"label":             lbl,
			"orbit_r_wu":        orbit_r_wu,
			"orbit_period_days": period,
		})


func _update_struct_positions() -> void:
	for entry in _struct_nodes:
		var r:      float = entry["orbit_r_wu"]
		var period: float = entry["orbit_period_days"]
		# Each structure gets a fixed angular offset based on its index so they
		# don't all stack at the same point on shared-altitude rings.
		var idx_offset := float(_struct_nodes.find(entry)) * TAU / maxf(float(_struct_nodes.size()), 1.0)
		var angle := fmod(_elapsed_days * TAU / maxf(period, 0.001) + idx_offset, TAU)
		(entry["dot_mi"] as MeshInstance3D).position = Vector3(cos(angle) * r, 0.0, sin(angle) * r)


# ── Line mesh helpers (shared with solar_system_3d) ──────────────────────────

func _line_mi(col: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi  := MeshInstance3D.new()
	mi.mesh  = ArrayMesh.new()
	mi.set_meta("mat", mat)
	return mi


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


# ── Animation ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if visible:
		_vis_frames += 1
	else:
		_vis_frames = 0
	_time += delta
	var anim := VisualClock.anim_days
	if not _paused and _body_root:
		var body := ScaleEngine.current_body
		var rot_period := ROTATION_PERIOD_DAYS.get(body, 1.0) as float
		# Planet body: absolute tick-based position (surface orientation is simulation-accurate)
		if rot_period != 0.0:
			_body_root.rotation_degrees.y = fmod(_elapsed_days * (360.0 / absf(rot_period)), 360.0) * signf(rot_period)
		# Sun direction: orbital offset (which face toward Sol) + diurnal sweep at visual rate.
		# Driving at diurnal rate makes the terminator visibly move across the surface each game-day.
		if _sun_light:
			var ang0: float        = _db.ang0_deg(body) if _db.has_body(body) else 0.0
			var period_days: float = _db.orbital_period_years(body) * 365.25 if _db.has_body(body) else 365.25
			# Slow drift: which longitude faces Sol based on orbital position
			var orbital_offset := ang0 + _elapsed_days * 360.0 / maxf(period_days, 1.0)
			# Fast sweep: sun completes one pass per game-day in visual (anim) time
			var diurnal := anim * 360.0 / maxf(absf(rot_period), 0.001) * signf(rot_period)
			_sun_light.rotation_degrees.x = -15.0
			_sun_light.rotation_degrees.y = 90.0 - orbital_offset - diurnal
	if _cloud_root:
		_cloud_root.rotation_degrees.y += delta * 4.0
	_update_camera_keys(delta)
	# Moon / generic moon orbits — driven by VisualClock.anim_days for smooth continuous animation
	for entry: Dictionary in _moon_pivots:
		var pivot: Node3D = entry["pivot"]
		var period: float = entry["period"]
		if period != 0.0:
			pivot.rotation_degrees.y = fmod(anim * (360.0 / absf(period)), 360.0) * signf(period)
	_update_ship_positions()
	_update_struct_positions()
	_update_selection_ring()
	# Earth satellite orbits
	for i in _sat_orbits.size():
		if (_sat_orbits[i] as Node3D).visible:
			(_sat_orbits[i] as Node3D).rotation_degrees.y += delta * float((SAT_ORBIT_PARAMS[i] as Array)[3])
	if _crew_orbit: _crew_orbit.rotation_degrees.y -= delta * 38.0
	if _stn_orbit:  _stn_orbit.rotation_degrees.y  += delta * 22.0
	# Transit craft
	if _transit_craft and _transit_craft.visible and _earth_moon_mi:
		var t        := fmod(_time * 0.05, 1.0)
		var moon_pos := _earth_moon_mi.global_position
		_transit_craft.position = Vector3(0.0, 0.0, EARTH_R + 0.25).lerp(moon_pos, t)
	# Rocket launches
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
			node.scale    = Vector3.ONE * maxf(1.0 - float(launch["t"]), 0.0)
		if launch["t"] >= 1.0:
			if is_instance_valid(node): node.queue_free()
			_launches.remove_at(i)
	_update_hover()
	if _cam:
		if _ring_mesh_list.size() > 0:
			SceneUtil.update_rings(_ring_mesh_list, _cam, float(_vp.size.y))
		if _label_list.size() > 0:
			SceneUtil.update_labels(_label_list, _cam, float(_vp.size.y))


func _spawn_rocket() -> void:
	if not _rocket_root: return
	var lon     := randf() * TAU
	var lat     := randf_range(-0.15, 0.15)
	var surface := _ll(lat, lon, EARTH_R + 0.06)
	var apex    := Vector3(cos(lon) * (EARTH_R + 1.15), 0.0, sin(lon) * (EARTH_R + 1.15))
	var m := CylinderMesh.new()
	m.top_radius = 0.018; m.bottom_radius = 0.035; m.height = 0.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.48, 0.12)
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


# ── Camera ─────────────────────────────────────────────────────────────────────

func _on_zone_changed(zone: int) -> void:
	if not visible: return
	_apply_zone_camera(zone)


func _apply_zone_camera(zone: int) -> void:
	var body := ScaleEngine.current_body
	if not BODY_CATALOG.has(body): return
	var data: Dictionary = BODY_CATALOG[body]
	_look_at = Vector3.ZERO

	if body == "Earth":
		if zone == 2:
			_look_at    = Vector3(MOON_DIST * 0.42, 0.0, 0.0)
			_cam_offset = Vector3(0.0, MOON_DIST * 0.75, MOON_DIST * 1.5)
		else:
			_cam_offset = Vector3(0.0, 3.2, 6.0)
	else:
		var d := float(data["cam_init"])
		if zone == 2 and not data.get("moons", []).is_empty():
			var outermost := 0.0
			for md: Dictionary in data.get("moons", []):
				outermost = maxf(outermost, float(md["dist"]))
			d = minf(outermost * 1.5, float(data["cam_max"]))
		_cam_offset = Vector3(0.0, d * sin(deg_to_rad(28.0)), d * cos(deg_to_rad(28.0)))
	_update_camera()


func _update_camera() -> void:
	if not _cam: return
	_cam.position = _look_at + _cam_offset
	_cam.look_at(_look_at, Vector3.UP)


func _update_camera_keys(delta: float) -> void:
	if not visible: return
	var spd := delta / _PAN_SPEED
	if Input.is_action_pressed("ui_left"):  _pan(Vector2( spd, 0.0))
	if Input.is_action_pressed("ui_right"): _pan(Vector2(-spd, 0.0))
	if Input.is_action_pressed("ui_up"):    _pan(Vector2(0.0, -spd))
	if Input.is_action_pressed("ui_down"):  _pan(Vector2(0.0,  spd))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		_zoom_by(1.0 / (event as InputEventMagnifyGesture).factor)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		_pan((event as InputEventPanGesture).delta * 6.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed: _zoom_by(1.0 / 1.15); get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed: _zoom_by(1.15); get_viewport().set_input_as_handled()
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = true; _did_drag = false
				else:
					_dragging = false
					if not _did_drag: _try_click_body(mb.position)
			MOUSE_BUTTON_RIGHT:
				if mb.pressed: _reset_camera()
	elif event is InputEventMouseMotion and _dragging:
		_did_drag = true
		_pan((event as InputEventMouseMotion).relative)


func _zoom_by(factor: float) -> void:
	var new_off := _cam_offset * factor
	var dist    := new_off.length()
	if dist < _cam_dist_min or dist > _cam_dist_max: return
	_cam_offset = new_off
	_update_camera()


func _pan(delta_px: Vector2) -> void:
	if not _cam: return
	var dist     := _cam_offset.length()
	var right_xz := Vector3(_cam.global_transform.basis.x.x, 0.0,
			_cam.global_transform.basis.x.z).normalized()
	var fwd_xz := Vector3(-_cam.global_transform.basis.z.x, 0.0,
			-_cam.global_transform.basis.z.z).normalized()
	_look_at += (right_xz * -delta_px.x + fwd_xz * -delta_px.y) * _PAN_SPEED * dist
	_look_at.y = 0.0
	_update_camera()


func _reset_camera() -> void:
	ScaleEngine.focus_local("")
	_apply_zone_camera(ScaleEngine.current_zone)


func _try_click_body(_container_pos: Vector2) -> void:
	if _hover_name == "":
		# Click on empty space — deselect
		if _selected_body != "":
			_selected_body = ""
			body_deselected.emit()
		return
	if _hover_name == ScaleEngine.current_body:
		# Toggle selection of the central body
		if _selected_body == _hover_name:
			_selected_body = ""
			body_deselected.emit()
			ScaleEngine.focus_local("")
			_reset_camera()
		else:
			_selected_body = _hover_name
			body_selected.emit(_hover_name)
		return
	# Moon body — focus and select
	ScaleEngine.focus_local(_hover_name)
	_focus_on_moon(_hover_name)
	_selected_body = _hover_name
	body_selected.emit(_hover_name)


# Called by main.gd when a minimap body is clicked, to avoid a full rebuild
# if the body is already in this scene. Returns true if handled locally.
func try_focus_local(name: String) -> bool:
	if name == ScaleEngine.current_body:
		ScaleEngine.focus_local("")
		_reset_camera()
		return true
	for entry: Dictionary in _moon_pivots:
		if str(entry["name"]) == name:
			ScaleEngine.focus_local(name)
			_focus_on_moon(name)
			return true
	return false


func _focus_on_moon(name: String) -> void:
	for entry: Dictionary in _moon_pivots:
		if str(entry["name"]) == name:
			var moon_pos    := (entry["mi"] as MeshInstance3D).global_position
			var moon_radius := float(entry["radius"])
			var dist        := maxf(moon_radius * 8.0, _cam_dist_min)
			_cam_dist_min = moon_radius * 1.4
			_cam_dist_max = moon_radius * 60.0
			_look_at   = moon_pos
			_cam_offset = Vector3(0.0, dist * sin(deg_to_rad(28.0)), dist * cos(deg_to_rad(28.0)))
			_update_camera()
			return


# ── Hover ring ─────────────────────────────────────────────────────────────────

func _update_hover() -> void:
	if not visible or not _cam or not _hover_ring: return
	if _vis_frames < 2: return
	if size.x < 4.0 or _vp.size.x < 4: return   # layout not ready yet

	var mouse_pos := get_local_mouse_position()
	# If mouse is outside this container, clear hover and don't touch the OS cursor
	if mouse_pos.x < 0.0 or mouse_pos.y < 0.0 or mouse_pos.x > size.x or mouse_pos.y > size.y:
		if _hover_ring: _hover_ring.visible = false
		_hover_name = ""
		return

	var vp_size   := Vector2(_vp.size)
	var mouse_vp  := mouse_pos * vp_size / size   # container → viewport pixels

	# Dynamic threshold: matches the visible ring size so clicking inside the ring always works.
	var vp_h    := float(_vp.size.y)
	var fov_tan := tan(deg_to_rad(_cam.fov) * 0.5)
	var cam_d   := maxf(_cam_offset.length(), 0.001)
	var min_r   := _min_hover_ring_r(28.0)
	var to_scr  := vp_h * 0.5 / (cam_d * fov_tan)  # world-unit → screen-px conversion

	var bodies: Array = []
	var cb_ring := maxf(_body_radius * 1.5, min_r)
	bodies.append({"name": ScaleEngine.current_body, "world_pos": Vector3.ZERO,
			"radius": _body_radius, "screen_threshold_px": maxf(72.0, cb_ring * to_scr + 8.0)})

	for entry: Dictionary in _moon_pivots:
		var moon_pos := (entry["mi"] as MeshInstance3D).global_position
		var moon_r   := float(entry["radius"])
		var mname    := str(entry["name"])
		var ring_r   := maxf(moon_r * 1.5, min_r)
		var threshold := maxf(48.0, ring_r * to_scr + 8.0)
		bodies.append({"name": mname, "world_pos": moon_pos,
				"radius": moon_r, "screen_threshold_px": threshold})
		# Label sits above moon in world space — include as secondary hit target.
		# ring_world_pos keeps the hover ring centered on the moon, not the label.
		bodies.append({"name": mname,
				"world_pos": moon_pos + Vector3(0.0, moon_r * 2.0, 0.0),
				"ring_world_pos": moon_pos,
				"radius": moon_r, "screen_threshold_px": threshold * 0.6})

	var hit    := SceneUtil.update_hover(_cam, mouse_vp, bodies, _hover_ring, 1.5, min_r)
	_hover_name = str(hit.get("name", ""))
	for item in _label_list:
		if not (item is Label3D) or not item.has_meta("body_name"): continue
		var lbl := item as Label3D
		var col := Color(0.70, 1.00, 1.00, lbl.modulate.a) if str(lbl.get_meta("body_name")) == _hover_name \
				else Color(1.0, 1.0, 1.0, lbl.modulate.a)
		lbl.modulate = col


func _update_selection_ring() -> void:
	if not _selection_ring: return
	var focus := ScaleEngine.local_focus
	if focus == "":
		_selection_ring.position = Vector3.ZERO
		_selection_ring.scale    = Vector3.ONE * _body_radius * 1.35
		return
	for entry: Dictionary in _moon_pivots:
		if str(entry["name"]) == focus:
			var moon_r := float(entry["radius"])
			_selection_ring.position = (entry["mi"] as MeshInstance3D).global_position
			_selection_ring.scale    = Vector3.ONE * moon_r * 1.35
			return


func _min_hover_ring_r(min_px: float) -> float:
	var vp_h := float(Vector2(_vp.size).y)
	if vp_h < 1.0 or not _cam: return 0.0
	var dist := _cam_offset.length()
	return min_px * dist * tan(deg_to_rad(_cam.fov) * 0.5) / (vp_h * 0.5)
