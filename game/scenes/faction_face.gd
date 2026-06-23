extends Control
# Civ-style happiness face. Set satisfaction (0-100) and call queue_redraw().

var satisfaction: float = 50.0

const SIZE := 34.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)


func set_satisfaction(value: float) -> void:
	satisfaction = clampf(value, 0.0, 100.0)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var r := SIZE * 0.46

	# Head fill
	draw_circle(c, r, _face_color())
	# Head outline
	draw_arc(c, r, 0.0, TAU, 32, Color(0.0, 0.0, 0.0, 0.55), 1.2, true)

	# Eyes
	var eye_y := c.y - r * 0.22
	draw_circle(Vector2(c.x - r * 0.30, eye_y), r * 0.13, Color(0.08, 0.08, 0.08))
	draw_circle(Vector2(c.x + r * 0.30, eye_y), r * 0.13, Color(0.08, 0.08, 0.08))

	# Brow (angry = angled down toward center)
	if satisfaction < 25.0:
		var bx := r * 0.28; var bw := r * 0.22
		draw_line(Vector2(c.x - bx - bw, eye_y - r * 0.24),
				  Vector2(c.x - bx + bw, eye_y - r * 0.14), Color(0.08, 0.08, 0.08), 1.5)
		draw_line(Vector2(c.x + bx - bw, eye_y - r * 0.14),
				  Vector2(c.x + bx + bw, eye_y - r * 0.24), Color(0.08, 0.08, 0.08), 1.5)

	# Mouth — arc curving up (happy) or down (sad)
	# curve: +1 = big smile, 0 = flat, -1 = big frown
	var curve := (satisfaction - 50.0) / 50.0  # -1 to +1
	var mouth_pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t := float(i) / steps
		var mx := lerpf(-r * 0.40, r * 0.40, t)
		var my := -curve * r * 0.30 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		mouth_pts.append(c + Vector2(mx, r * 0.35 + my))
	draw_polyline(mouth_pts, Color(0.08, 0.08, 0.08), 1.4, true)


func _face_color() -> Color:
	if satisfaction >= 75.0:
		return Color(0.25, 0.82, 0.28)   # green
	elif satisfaction >= 50.0:
		return Color(0.88, 0.82, 0.18)   # yellow
	elif satisfaction >= 25.0:
		return Color(0.92, 0.52, 0.10)   # orange
	else:
		return Color(0.88, 0.18, 0.18)   # red
