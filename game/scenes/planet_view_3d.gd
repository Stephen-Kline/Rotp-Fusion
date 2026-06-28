extends SubViewportContainer
# Generic local-body 3D view. Shows any solar-system body with its moons.
# World scale: Earth radius = 1.5 WU (matches earth_view_3d.gd). Orbit distances
# are in the same units so relative scales are accurate.

const EARTH_R := 1.5   # world units

# Body catalog. Radii are (real_radius / Earth_radius) * EARTH_R.
# Moon dists are in parent-body WU from parent center.
# cam_init / cam_max are camera offset lengths in WU.
const BODY_CATALOG: Dictionary = {
	"Sol": {
		"radius": 10.0, "color": Color(1.00, 0.92, 0.35), "emissive": true,
		"atmo": Color(1.00, 0.72, 0.10, 0.07),
		"cam_init": 28.0, "cam_max": 100.0, "moons": [],
		"reference_rings": [
			{"label": "Photosphere",  "dist": 11.5},
			{"label": "Inner Corona", "dist": 20.0},
			{"label": "Solar Wind",   "dist": 58.0},
		]
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
}

# ── Runtime ────────────────────────────────────────────────────────────────────
var _vp:        SubViewport
var _cam:       Camera3D
var _body_root: Node3D

var _moon_pivots:      Array = []   # {pivot, period, mi, name, radius}
var _orbit_ring_nodes: Array = []   # MeshInstance3D + Label3D per moon, children of _vp
var _hover_ring:      MeshInstance3D = null
var _selection_ring:  MeshInstance3D = null
var _body_radius:     float = 1.5
var _elapsed_days: float = 0.0
var _paused:           bool  = false
var _time: float = 0.0   # body self-rotation only

var _look_at:    Vector3 = Vector3.ZERO
var _cam_offset: Vector3 = Vector3(0.0, 4.0, 8.0)
var _dragging:   bool    = false
const _PAN_SPEED := 0.0035

var _cam_dist_min: float = 1.5
var _cam_dist_max: float = 200.0
var _label_list:   Array[Label3D] = []


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	ScaleEngine.body_changed.connect(_on_body_changed)
	if BODY_CATALOG.has(ScaleEngine.current_body):
		_rebuild(ScaleEngine.current_body)


func _build_viewport() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true           # star_field shows through
	_vp.own_world_3d   = true           # isolated world — never sees earth_view_3d content
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

	var sun_light := DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-15, -20, 0)
	sun_light.light_energy = 1.5
	sun_light.light_color  = Color(1.0, 0.98, 0.95)
	_vp.add_child(sun_light)

	_cam = Camera3D.new()
	_cam.near = 0.01
	_cam.far  = 5000.0
	_vp.add_child(_cam)

	_body_root = Node3D.new()
	_vp.add_child(_body_root)

	_hover_ring = _orbit_ring_mesh(1.0, Color(0.70, 1.00, 1.00, 0.90))
	_hover_ring.visible = false
	_vp.add_child(_hover_ring)

	_selection_ring = _orbit_ring_mesh(1.0, Color(1.00, 0.88, 0.20, 0.85))
	_selection_ring.visible = false
	_vp.add_child(_selection_ring)


# ── Body switching ─────────────────────────────────────────────────────────────

func _on_body_changed(body_name: String) -> void:
	_rebuild(body_name)


func _rebuild(body_name: String) -> void:
	# Clear old content
	for c in _body_root.get_children():
		c.queue_free()
	for entry: Dictionary in _moon_pivots:
		(entry["pivot"] as Node3D).queue_free()
	_moon_pivots.clear()
	for n: Node3D in _orbit_ring_nodes:
		n.queue_free()
	_orbit_ring_nodes.clear()
	_label_list.clear()
	_time = 0.0

	if _selection_ring:
		_selection_ring.visible = false
	if not BODY_CATALOG.has(body_name):
		return

	var data: Dictionary = BODY_CATALOG[body_name]
	var radius: float = data["radius"]
	_body_radius = radius

	_cam_dist_min = radius * 1.4
	_cam_dist_max = data["cam_max"]
	var d: float   = data["cam_init"]
	_look_at    = Vector3.ZERO
	_cam_offset = Vector3(0.0, d * sin(deg_to_rad(28.0)), d * cos(deg_to_rad(28.0)))
	_update_camera()

	# ── Planet sphere ──────────────────────────────────────────────────────────
	var planet_mat := _body_material(body_name, radius, data)
	var planet_sm  := _sphere(radius, 64, 32)
	planet_sm.surface_set_material(0, planet_mat)
	_body_root.add_child(_inst(planet_sm))

	# ── Atmosphere ─────────────────────────────────────────────────────────────
	if data.has("atmo"):
		var atmo_col: Color = data["atmo"]
		var atmo_sm := _sphere(radius * 1.05, 32, 16)
		var atmo_mat := StandardMaterial3D.new()
		atmo_mat.albedo_color = atmo_col
		atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		atmo_mat.cull_mode    = BaseMaterial3D.CULL_DISABLED
		atmo_sm.surface_set_material(0, atmo_mat)
		_body_root.add_child(_inst(atmo_sm))

	# ── Ring system (Saturn-style) ─────────────────────────────────────────────
	if data.get("rings", false):
		_build_rings(radius, _body_root)

	# ── Moons + labeled orbit rings ───────────────────────────────────────────────
	var cam_init: float = data["cam_init"]
	for md: Dictionary in data.get("moons", []):
		_build_moon(md)
		var dist: float = float(md["dist"])
		var ring := _orbit_ring_mesh(dist, Color(1.0, 1.0, 1.0, 0.5))
		_vp.add_child(ring)
		_orbit_ring_nodes.append(ring)
		# Only label moons that are visually significant (≥ 2px) at the default view
		var apparent_px := float(md["radius"]) / cam_init * 939.0
		if apparent_px >= 2.0:
			var lbl := _ring_label(md["name"], dist)
			_vp.add_child(lbl)
			_orbit_ring_nodes.append(lbl)
			_label_list.append(lbl)

	# ── Selection ring — gold, always visible, slightly outside body surface ──────
	if _selection_ring:
		_selection_ring.position = Vector3.ZERO
		_selection_ring.scale    = Vector3.ONE * radius * 1.35
		_selection_ring.visible  = true

	# ── Reference rings (Sol corona / solar-wind zones, etc.) ────────────────────
	for rd: Dictionary in data.get("reference_rings", []):
		var dist: float = float(rd["dist"])
		var ring := _orbit_ring_mesh(dist, Color(1.0, 1.0, 1.0, 0.5))
		_vp.add_child(ring)
		_orbit_ring_nodes.append(ring)
		var lbl := _ref_label(rd["label"], dist)
		_vp.add_child(lbl)
		_orbit_ring_nodes.append(lbl)
		_label_list.append(lbl)


func _build_rings(planet_r: float, parent: Node3D) -> void:
	# Three ring zones with a gap (Cassini Division) between B and A rings
	var ring_zones: Array[Array] = [
		[planet_r * 1.20, planet_r * 1.53, Color(0.70, 0.65, 0.52, 0.35)],  # C + B rings
		[planet_r * 2.02, planet_r * 2.30, Color(0.78, 0.72, 0.55, 0.30)],  # A ring
	]
	for zone: Array in ring_zones:
		var inner: float = zone[0]
		var outer: float = zone[1]
		var col:   Color = zone[2]
		var disc := _flat_ring(inner, outer, col)
		parent.add_child(disc)


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


# ── Procedural textures ────────────────────────────────────────────────────────

func _body_material(body_name: String, _radius: float, data: Dictionary) -> StandardMaterial3D:
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
		"Moon":
			mat.albedo_texture = _gen_moon_texture()
		"Mercury":
			mat.albedo_texture = _gen_rocky_texture(Color(0.65, 0.60, 0.55), 0.85, false)
		"Venus":
			mat.albedo_texture = _gen_cloud_texture(Color(0.88, 0.78, 0.50))
		"Mars":
			mat.albedo_texture = _gen_rocky_texture(Color(0.75, 0.32, 0.18), 0.50, true)
		"Ceres":
			mat.albedo_texture = _gen_rocky_texture(Color(0.62, 0.60, 0.56), 0.70, false)
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
		"Pluto":
			mat.albedo_texture = _gen_rocky_texture(Color(0.72, 0.62, 0.52), 0.40, true)
		_:
			mat.albedo_color = data.get("color", Color(0.6, 0.6, 0.6))

	mat.roughness = 0.75
	mat.metallic  = 0.05
	return mat


func _gen_rocky_texture(base: Color, crater_density: float, polar_caps: bool) -> ImageTexture:
	var W := 512; var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(base)

	# Craters
	var rng := RandomNumberGenerator.new(); rng.seed = base.to_argb32()
	var n_craters := int(crater_density * 120)
	for _i in n_craters:
		var cx := rng.randf(); var cy := rng.randf_range(0.05, 0.95)
		var cr := rng.randf_range(0.012, 0.055)
		_fill_ellipse(img, cx, cy, cr, cr, base.lightened(0.18))
		_fill_ellipse(img, cx, cy, cr * 0.65, cr * 0.65, base.darkened(0.22))

	if polar_caps:
		for py in H:
			var v := float(py) / H
			if v < 0.06:
				for px in W: img.set_pixel(px, py, Color(0.94, 0.90, 0.86))
			elif v > 0.92:
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
		var t := float(py) / H
		# Multi-frequency sine for irregular bands
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
		var t := float(py) / H
		var wave := sin(t * 8.0 * PI + 0.5) * 0.04
		var col := Color(base.r + wave, base.g + wave * 0.5, base.b + wave * 0.2)
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


func _gen_moon_texture() -> ImageTexture:
	var W := 256; var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(Color(0.82, 0.78, 0.66))
	var mare := Color(0.54, 0.50, 0.40)
	_fill_ellipse(img, 0.35, 0.40, 0.12, 0.14, mare)
	_fill_ellipse(img, 0.60, 0.45, 0.09, 0.10, mare)
	_fill_ellipse(img, 0.20, 0.55, 0.07, 0.08, mare)
	_fill_ellipse(img, 0.72, 0.35, 0.06, 0.07, mare)
	var craters := [
		[0.45, 0.38, 0.05], [0.25, 0.42, 0.04], [0.65, 0.52, 0.035],
		[0.55, 0.28, 0.03], [0.38, 0.60, 0.04], [0.78, 0.45, 0.03],
		[0.15, 0.35, 0.025],[0.82, 0.58, 0.025],[0.50, 0.70, 0.03],
	]
	for cr: Array in craters:
		_fill_ellipse(img, cr[0], cr[1], cr[2], cr[2], Color(0.88, 0.84, 0.72))
		_fill_ellipse(img, cr[0], cr[1], cr[2] * 0.7, cr[2] * 0.7, Color(0.44, 0.40, 0.34))
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
			var du  := (float(wpx) / W - uc) / ur
			if du * du + dv * dv <= 1.0:
				img.set_pixel(wpx, py, col)


func _add_noise(img: Image, strength: float) -> void:
	var W := img.get_width(); var H := img.get_height()
	for py in H:
		for px in W:
			var n := (_hash(px, py) - 0.5) * strength
			var c := img.get_pixel(px, py)
			img.set_pixel(px, py, Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1)))


func _hash(x: int, y: int) -> float:
	var n := x + y * 57
	n = (n << 13) ^ n
	return float((n * (n * n * 15731 + 789221) + 1376312589) & 0x7fffffff) / 2147483647.0


# ── Mesh helpers ───────────────────────────────────────────────────────────────

func _sphere(radius: float, radial: int, rings: int) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius; m.height = radius * 2.0
	m.radial_segments = radial; m.rings = rings
	return m


func _inst(mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _orbit_ring_mesh(radius: float, col: Color) -> MeshInstance3D:
	return SceneUtil.make_orbit_ring(radius, col)


func _ring_label(moon_name: String, dist: float) -> Label3D:
	var km  := dist * (6371.0 / 1.5)
	var gap := TAU / 6.0
	var lbl := SceneUtil.make_orbit_label(
		moon_name + "\n" + _fmt_km(km), Color(0.72, 0.85, 1.00, 0.90), dist)
	lbl.position = Vector3(cos(gap) * dist, dist * 0.06, sin(gap) * dist)
	return lbl


func _ref_label(text: String, dist: float) -> Label3D:
	var gap := TAU / 6.0
	var lbl := SceneUtil.make_orbit_label(text, Color(1.00, 0.90, 0.40, 0.92), dist)
	lbl.position = Vector3(cos(gap) * dist, dist * 0.06, sin(gap) * dist)
	return lbl


func _fmt_km(km: float) -> String:
	if km >= 1_000_000.0:
		return "%.2f M km" % (km / 1_000_000.0)
	var k := int(km)
	if k >= 1000:
		return "%d,%03d km" % [k / 1000, k % 1000]
	return "%d km" % k


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
	var mi := MeshInstance3D.new(); mi.mesh = mesh
	return mi


# ── Animation ──────────────────────────────────────────────────────────────────

func update_state(state: Object) -> void:
	_elapsed_days = state.get("elapsed_days") if state.has_method("get") else float(state.elapsed_days)


func _process(delta: float) -> void:
	_time += delta
	if not _paused:
		if _body_root:
			_body_root.rotation_degrees.y += delta * 3.0
		# Drive moon orbit angles from game elapsed_days — stays in sync with
		# earth_view_3d and the minimap which both use the same elapsed_days base.
		for entry: Dictionary in _moon_pivots:
			var pivot: Node3D = entry["pivot"]
			var period: float = entry["period"]
			if period != 0.0:
				pivot.rotation_degrees.y = _elapsed_days * (360.0 / absf(period)) * signf(period)
	_update_hover()
	if _cam and _label_list.size() > 0:
		SceneUtil.update_labels(_label_list, _cam, float(_vp.size.y))


func _update_hover() -> void:
	if not visible or not _cam or not _hover_ring:
		return
	var vp_size := Vector2(_vp.size)
	if vp_size.x < 1.0 or vp_size.y < 1.0:
		return
	var mouse_pos := get_local_mouse_position()
	var mouse_vp  := mouse_pos * vp_size / size   # container → viewport pixels

	var bodies: Array = []

	# Main body — threshold scales with projected screen radius
	if _body_radius > 0.0:
		var center_vp := _cam.unproject_position(Vector3.ZERO)
		var edge_vp   := _cam.unproject_position(Vector3(_body_radius, 0.0, 0.0))
		var screen_r  := maxf(center_vp.distance_to(edge_vp), 14.0)
		bodies.append({"world_pos": Vector3.ZERO, "radius": _body_radius,
				"screen_threshold_px": screen_r * 1.5})

	# Moons — fixed threshold
	for entry: Dictionary in _moon_pivots:
		bodies.append({"world_pos": (entry["mi"] as MeshInstance3D).global_position,
				"radius": entry["radius"], "screen_threshold_px": 35.0})

	var hit := SceneUtil.nearest_hit(_cam, mouse_vp, bodies)
	if hit["radius"] > 0.0:
		_hover_ring.position = hit["world_pos"]
		_hover_ring.scale    = Vector3.ONE * float(hit["radius"]) * 1.15
		_hover_ring.visible  = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_hover_ring.visible = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW


# ── Camera ─────────────────────────────────────────────────────────────────────

func _update_camera() -> void:
	if not _cam: return
	_cam.position = _look_at + _cam_offset
	_cam.look_at(_look_at, Vector3.UP)


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
				if mb.pressed: _zoom_by(1.0 / 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed: _zoom_by(1.15)
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_dragging = mb.pressed
				else:
					_dragging = false
			MOUSE_BUTTON_RIGHT:
				if mb.pressed: _reset_camera()
	elif event is InputEventMouseMotion and _dragging:
		_pan((event as InputEventMouseMotion).relative)


func _zoom_by(factor: float) -> void:
	var new_off := _cam_offset * factor
	var dist := new_off.length()
	if dist < _cam_dist_min or dist > _cam_dist_max:
		return
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
	if BODY_CATALOG.has(ScaleEngine.current_body):
		var data: Dictionary = BODY_CATALOG[ScaleEngine.current_body]
		var d: float = data["cam_init"]
		_look_at    = Vector3.ZERO
		_cam_offset = Vector3(0.0, d * sin(deg_to_rad(28.0)), d * cos(deg_to_rad(28.0)))
		_update_camera()
