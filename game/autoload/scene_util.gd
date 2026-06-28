class_name SceneUtil
extends RefCounted
# Static utilities shared across all 3D scene views.

# ── Planet catalog ────────────────────────────────────────────────────────────
# [name, AU, period_yr, color, minimap_radius_px]
const SOLAR_PLANETS: Array = [
	["Mercury", 0.387,   0.241, Color(0.70, 0.60, 0.50), 1.4],
	["Venus",   0.723,   0.615, Color(0.90, 0.82, 0.50), 2.0],
	["Earth",   1.000,   1.000, Color(0.18, 0.50, 0.90), 2.2],
	["Mars",    1.524,   1.881, Color(0.80, 0.30, 0.18), 1.8],
	["Ceres",   2.770,   4.607, Color(0.62, 0.60, 0.56), 1.0],
	["Jupiter", 5.203,  11.862, Color(0.78, 0.63, 0.45), 3.2],
	["Saturn",  9.537,  29.457, Color(0.88, 0.78, 0.52), 2.8],
	["Uranus", 19.191,  84.011, Color(0.55, 0.80, 0.85), 2.2],
	["Neptune",30.069, 164.800, Color(0.28, 0.42, 0.85), 2.2],
	["Pluto",  39.480, 247.940, Color(0.70, 0.60, 0.52), 1.0],
]

# ── Label constants ───────────────────────────────────────────────────────────
const LABEL_TARGET_PX: float = 10.0   # desired screen-pixel height of rendered text
const LABEL_FONT_SIZE:  float = 10.0  # Label3D font_size property


# Creates a Label3D for use on an orbital ring.
# ring_r: world-unit radius of the ring this label belongs to — used for fade.
static func make_orbit_label(text: String, col: Color, ring_r: float) -> Label3D:
	var lbl := Label3D.new()
	lbl.text          = text
	lbl.font_size     = int(LABEL_FONT_SIZE)
	lbl.pixel_size    = 0.003   # placeholder; overwritten every frame
	lbl.modulate      = col
	lbl.billboard     = 1       # face camera (BaseMaterial3D.BILLBOARD_ENABLED)
	lbl.no_depth_test = true
	lbl.set_meta("ring_r",     ring_r)
	lbl.set_meta("base_alpha", col.a)
	return lbl


# Call once per frame for every orbital label in a scene.
# Keeps all labels the same apparent screen size and fades them when their
# ring is too small to be useful.
# label_list: Array of Label3D created with make_orbit_label.
# cam: the scene Camera3D.  vp_h: viewport height in pixels.
static func update_labels(label_list: Array, cam: Camera3D, vp_h: float) -> void:
	if vp_h < 1.0 or cam == null:
		return
	var fov_tan         := tan(deg_to_rad(cam.fov) * 0.5)
	var cam_origin_dist := maxf(cam.global_position.length(), 0.001)
	for item in label_list:
		if not (item is Label3D) or not is_instance_valid(item as Label3D):
			continue
		var lbl := item as Label3D
		var cam_dist := maxf(cam.global_position.distance_to(lbl.global_position), 0.001)
		# Constant screen size: pixel_size = target_px * 2*tan(fov/2) * cam_dist / (font_size * vp_h)
		lbl.pixel_size = LABEL_TARGET_PX * 2.0 * fov_tan * cam_dist / (LABEL_FONT_SIZE * vp_h)
		# Fade when the orbital ring it belongs to appears small on screen
		var ring_r: float     = lbl.get_meta("ring_r",     cam_dist)
		var base_alpha: float = lbl.get_meta("base_alpha", 1.0)
		var ring_screen_r := ring_r * vp_h * 0.5 / (cam_origin_dist * fov_tan)
		var fade := clampf((ring_screen_r - 30.0) / 70.0, 0.0, 1.0)
		var m := lbl.modulate
		m.a = base_alpha * fade
		lbl.modulate = m


# ── Orbit ring mesh ───────────────────────────────────────────────────────────

# Creates a 128-segment PRIMITIVE_LINES orbit ring.
# no_depth_test: set true for hover/selection indicator rings.
static func make_orbit_ring(radius: float, col: Color, no_depth_test: bool = false) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arr  := []; arr.resize(Mesh.ARRAY_MAX)
	var verts := PackedVector3Array()
	const N := 128
	for i in N:
		var a0 := float(i)     / N * TAU
		var a1 := float(i + 1) / N * TAU
		verts.append(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		verts.append(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
	arr[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color  = col
	mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = no_depth_test
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


# ── Hover hit-test ────────────────────────────────────────────────────────────

# Finds the nearest body to the mouse cursor.
# cam: Camera3D.
# mouse_vp: mouse position in VIEWPORT pixel coordinates
#   (convert with: get_local_mouse_position() * vp_size / container_size).
# bodies: Array of {world_pos: Vector3, radius: float, screen_threshold_px: float}
# Returns {world_pos: Vector3, radius: float}; radius == 0.0 means nothing hit.
static func nearest_hit(cam: Camera3D, mouse_vp: Vector2, bodies: Array) -> Dictionary:
	var best_dist := INF
	var best_pos  := Vector3.ZERO
	var best_r    := 0.0
	for b: Dictionary in bodies:
		var wpos: Vector3 = b["world_pos"]
		if cam.is_position_behind(wpos):
			continue
		var sp        := cam.unproject_position(wpos)   # viewport pixels
		var threshold := float(b.get("screen_threshold_px", 30.0))
		var d         := mouse_vp.distance_to(sp)
		if d < threshold and d < best_dist:
			best_dist = d
			best_pos  = wpos
			best_r    = b["radius"]
	return {"world_pos": best_pos, "radius": best_r}


# ── Minimap helpers ───────────────────────────────────────────────────────────

# AU-per-pixel scale so the active body sits at ~75% of the minimap half-width.
static func solar_au_scale(body: String, max_r: float) -> float:
	var sel_au := 5.2
	if body != "Sol":
		for pd: Array in SOLAR_PLANETS:
			if str(pd[0]) == body:
				sel_au = float(pd[1]); break
	return max_r / sel_au * 0.75


# Hit-tests the solar-local minimap view.
# p: mouse position (local to minimap).  center: minimap center.
# elapsed_ms: Time.get_ticks_msec().  au_scale: pixels per AU.  max_r: clip radius.
static func solar_local_body_at(p: Vector2, center: Vector2,
		elapsed_ms: float, au_scale: float, max_r: float) -> String:
	var t         := elapsed_ms / 14000.0
	var best_name := ""
	var best_d    := 16.0
	for pd: Array in SOLAR_PLANETS:
		var orbit_r: float = float(pd[1]) * au_scale
		if orbit_r > max_r * 1.1:
			continue
		var angle := t / float(pd[2]) * TAU
		var pos   := center + Vector2(cos(angle), sin(angle) * 0.88) * orbit_r
		var d     := p.distance_to(pos)
		if d < best_d:
			best_d = d; best_name = str(pd[0])
	return best_name
