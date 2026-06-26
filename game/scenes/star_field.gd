extends Control
# Procedural star field with 4 depth layers for parallax.
# Layer 0 = slowest (galactic dust), Layer 3 = fastest (near stars).
# Call set_camera_offset() when the active camera pans.

const SEED := 42

# [count, scroll_factor, size_min, size_max, alpha_max]
const LAYERS := [
	[40,  0.02, 0.4, 1.0, 0.35],
	[80,  0.08, 0.5, 1.5, 0.55],
	[120, 0.25, 0.7, 2.2, 0.80],
	[40,  0.60, 1.2, 3.5, 1.00],
]

var _layers: Array = []
var _time: float = 0.0
var _camera_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for cfg in LAYERS:
		var layer := []
		for i in cfg[0]:
			layer.append({
				"pos":           Vector2(rng.randf(), rng.randf()),
				"size":          rng.randf_range(cfg[2], cfg[3]),
				"base_alpha":    rng.randf_range(cfg[4] * 0.5, cfg[4]),
				"phase":         rng.randf() * TAU,
				"twinkle_speed": rng.randf_range(0.3, 1.2),
			})
		_layers.append(layer)
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_camera_offset(offset: Vector2) -> void:
	_camera_offset = offset
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var sz := get_size()
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.06, 0.16))

	for li in _layers.size():
		var scroll: float = LAYERS[li][1]
		var alpha_cap: float = LAYERS[li][4]
		var offset := _camera_offset * scroll
		for s in _layers[li]:
			var twinkle := sin(_time * s["twinkle_speed"] + s["phase"]) * 0.2
			var alpha := clampf(s["base_alpha"] + twinkle, 0.05, alpha_cap)
			# fposmod wraps seamlessly as camera pans
			var px := fposmod(s["pos"].x * sz.x - offset.x, sz.x)
			var py := fposmod(s["pos"].y * sz.y - offset.y, sz.y)
			draw_circle(Vector2(px, py), s["size"], Color(0.94, 0.90, 0.80, alpha))
