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
const LABEL_TARGET_PX: float = 10.0  # desired screen-pixel height of rendered text
const LABEL_FONT_SIZE:  float = 10.0  # Label3D font_size property
const LABEL_SIZE_2D:    int   = 11    # 2D overlay Label font_size

# Semantic label colors — used by all 3D scene views for consistency
const COL_LABEL_BODY := Color(0.80, 0.90, 1.00, 0.90)  # planet / moon body names
const COL_LABEL_STAR := Color(1.00, 0.92, 0.40, 0.90)  # Sol and star labels
const COL_LABEL_RING := Color(1.00, 1.00, 1.00, 0.65)  # orbit ring distance text
const COL_LABEL_MOON := Color(0.72, 0.85, 1.00, 0.90)  # moon name + distance labels


# Creates a Label3D for use on an orbital ring.
# ring_r: world-unit radius of the ring this label belongs to — used for fade.
static func make_orbit_label(text: String, col: Color, ring_r: float) -> Label3D:
	var lbl := Label3D.new()
	lbl.text           = text
	lbl.font_size      = int(LABEL_FONT_SIZE)
	lbl.pixel_size     = 0.003   # placeholder; overwritten every frame
	lbl.modulate       = col
	lbl.billboard      = 1       # face camera (BaseMaterial3D.BILLBOARD_ENABLED)
	lbl.no_depth_test  = true
	lbl.outline_size = 0   # no outline = no pseudo-shadow effect
	lbl.set_meta("ring_r",     ring_r)
	lbl.set_meta("base_alpha", col.a)
	return lbl


# Call once per frame for every orbital label in a scene.
# Fades labels when their ring is too small on screen OR the camera has passed
# inside the ring radius (ring_r).
# cam_origin: camera's distance from the body centre (scene origin).
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
		# Constant screen size
		lbl.pixel_size = LABEL_TARGET_PX * 2.0 * fov_tan * cam_dist / (LABEL_FONT_SIZE * vp_h)
		var ring_r: float     = lbl.get_meta("ring_r",     cam_origin_dist)
		var base_alpha: float = lbl.get_meta("base_alpha", 1.0)
		# Fade when ring too small on screen
		var ring_screen_r := ring_r * vp_h * 0.5 / (cam_origin_dist * fov_tan)
		var screen_fade   := clampf((ring_screen_r - 30.0) / 70.0, 0.0, 1.0)
		# Fade when camera is near the ring plane (±20%); visible from well inside or outside.
		# ring_r = 999999 on body-name labels → ratio ≈ 0 < 0.8 → always visible.
		var ratio     := cam_origin_dist / ring_r
		var past_fade := 1.0 if (ratio > 1.2 or ratio < 0.8) \
				else clampf(absf(ratio - 1.0) * 5.0, 0.0, 1.0)
		var m := lbl.modulate
		m.a = base_alpha * minf(screen_fade, past_fade)
		lbl.modulate = m


# Fade orbit ring meshes:
#   - screen-size fade: ring too small on screen → fade out
#   - edge-on fade: camera near the ring plane (within ±20% of ring_r) → fade out;
#     fully visible when far outside OR well inside (planet view starts inside outer moon orbits)
# ring_list: Array of MeshInstance3D created with make_orbit_ring.
static func update_rings(ring_list: Array, cam: Camera3D, vp_h: float = 0.0) -> void:
	if cam == null:
		return
	var cam_dist := cam.global_position.length()
	var fov_tan  := tan(deg_to_rad(cam.fov) * 0.5)
	for item in ring_list:
		if not (item is MeshInstance3D) or not is_instance_valid(item):
			continue
		var mi    := item as MeshInstance3D
		var ring_r: float = mi.get_meta("ring_r", 1.0)
		# Fade only when camera is near the ring edge (within ±20%); visible far inside or outside.
		var ratio      := cam_dist / ring_r
		var past_fade: float
		if ratio > 1.2 or ratio < 0.8:
			past_fade = 1.0
		else:
			past_fade = clampf(absf(ratio - 1.0) * 5.0, 0.0, 1.0)
		var screen_fade := 1.0
		if vp_h > 1.0 and cam_dist > 0.001:
			var ring_screen_r := ring_r * vp_h * 0.5 / (cam_dist * fov_tan)
			screen_fade = clampf((ring_screen_r - 30.0) / 120.0, 0.0, 1.0)
		var fade := minf(past_fade, screen_fade)
		var mat  := mi.get_active_material(0)
		if mat is ShaderMaterial:
			var smat := mat as ShaderMaterial
			# Scale tube cross-section to maintain ~1.25px radius on screen at any zoom.
			var baked_tube_r   := ring_r * 0.0019
			var desired_tube_r := 1.25 * cam_dist * fov_tan / (vp_h * 0.5) if vp_h > 1.0 else baked_tube_r
			var tube_scale     := clampf(desired_tube_r / baked_tube_r, 0.1, 3.0)
			smat.set_shader_parameter("ring_r",     ring_r)
			smat.set_shader_parameter("tube_scale", tube_scale)
			smat.set_shader_parameter("fade_alpha", fade)
		elif mat is StandardMaterial3D:
			var base_alpha: float = mi.get_meta("base_alpha", 0.5)
			var c := (mat as StandardMaterial3D).albedo_color
			c.a   = base_alpha * fade
			(mat as StandardMaterial3D).albedo_color = c


# ── Orbit ring mesh ───────────────────────────────────────────────────────────

# Shader for orbit rings.
# tube_scale: dynamically adjusted each frame so tube cross-section appears constant
# width on screen regardless of camera distance. ring_r: major orbit radius (model space).
# Far side dimmed to 30% brightness for depth cue.
const _RING_SHADER_SRC := """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform float ring_r : hint_range(0.0,10000.0) = 1.0;
uniform float tube_scale : hint_range(0.01,50.0) = 1.0;
uniform vec4 ring_color : source_color = vec4(1.0,1.0,1.0,0.5);
uniform float fade_alpha : hint_range(0.0,1.0) = 1.0;
varying vec3 v_world;
void vertex() {
float xz_len = length(VERTEX.xz);
if (xz_len > 0.001) {
float new_xz = ring_r + (xz_len - ring_r) * tube_scale;
VERTEX.xz = normalize(VERTEX.xz) * new_xz;
}
VERTEX.y *= tube_scale;
v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
vec2 cam_xz = CAMERA_POSITION_WORLD.xz;
float brightness = 1.0;
float l = length(cam_xz);
if (l > 0.001) { float n = dot(normalize(v_world.xz), cam_xz / l); brightness = mix(0.3, 1.0, n * 0.5 + 0.5); }
ALBEDO = ring_color.rgb * brightness;
ALPHA = ring_color.a * fade_alpha;
}"""

static var _ring_shader: Shader


# Creates a tube-geometry (torus) orbit ring — 128 major × 6 tube segments.
# Tube cross-section = 0.3% of ring radius. Depth-shaded on far side via shader.
# no_depth_test=true (hover rings): uses simple StandardMaterial3D, no shader.
static func make_orbit_ring(radius: float, col: Color, no_depth_test: bool = false) -> MeshInstance3D:
	var mesh   := ArrayMesh.new()
	var arr    := []; arr.resize(Mesh.ARRAY_MAX)
	const N    := 128
	const M    := 6
	var tube_r := radius * 0.0019
	var verts  := PackedVector3Array()
	var inds   := PackedInt32Array()
	for i in N:
		var theta := float(i) / N * TAU
		for j in M:
			var phi := float(j) / M * TAU
			verts.append(Vector3(
				(radius + tube_r * cos(phi)) * cos(theta),
				tube_r * sin(phi),
				(radius + tube_r * cos(phi)) * sin(theta)
			))
	for i in N:
		for j in M:
			var v00 := i * M + j
			var v01 := i * M + (j + 1) % M
			var v10 := ((i + 1) % N) * M + j
			var v11 := ((i + 1) % N) * M + (j + 1) % M
			inds.append(v00); inds.append(v10); inds.append(v01)
			inds.append(v10); inds.append(v11); inds.append(v01)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX]  = inds
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if no_depth_test:
		var mat := StandardMaterial3D.new()
		mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color  = col
		mat.transparency  = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.cull_mode     = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(0, mat)
	else:
		if _ring_shader == null:
			_ring_shader = Shader.new()
			_ring_shader.code = _RING_SHADER_SRC
		var smat := ShaderMaterial.new()
		smat.shader = _ring_shader
		smat.set_shader_parameter("ring_r",     radius)
		smat.set_shader_parameter("tube_scale", 1.0)
		smat.set_shader_parameter("ring_color", col)
		smat.set_shader_parameter("fade_alpha", 1.0)
		mesh.surface_set_material(0, smat)
	mi.set_meta("ring_r",     radius)
	mi.set_meta("base_alpha", col.a)
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
	var best_pos  := Vector3.ZERO   # where ring appears
	var best_r    := 0.0
	var best_name := ""
	for b: Dictionary in bodies:
		var wpos: Vector3 = b["world_pos"]   # detection point
		if cam.is_position_behind(wpos):
			continue
		var sp        := cam.unproject_position(wpos)   # viewport pixels
		var threshold := float(b.get("screen_threshold_px", 30.0))
		var d         := mouse_vp.distance_to(sp)
		if d < threshold and d < best_dist:
			best_dist = d
			# ring_world_pos overrides where the ring appears (e.g. label → ring at body center)
			best_pos  = b.get("ring_world_pos", wpos)
			best_r    = b["radius"]
			best_name = str(b.get("name", ""))
	return {"world_pos": best_pos, "radius": best_r, "name": best_name}


# Shared hover update: runs hit-test, positions/scales/shows hover_ring, sets OS cursor.
# Returns the hit dict (name, world_pos, radius; radius == 0.0 means nothing hit).
static func update_hover(cam: Camera3D, mouse_vp: Vector2, bodies: Array,
		hover_ring: Node3D, ring_scale: float, min_ring_r: float = 0.0) -> Dictionary:
	var hit := nearest_hit(cam, mouse_vp, bodies)
	if hit["radius"] > 0.0:
		hover_ring.position = hit["world_pos"]
		hover_ring.scale    = Vector3.ONE * maxf(float(hit["radius"]) * ring_scale, min_ring_r)
		hover_ring.visible  = true
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
	else:
		hover_ring.visible = false
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	return hit


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
