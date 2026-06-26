extends Control

# Procedural star field. Replaces the flat dark background ColorRect.
# Stars twinkle via sine wave on their individual phase offsets.

const STAR_COUNT := 280
const SEED := 42

var _stars: Array = []  # [{pos, size, base_alpha, phase}]
var _time: float = 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),   # normalized 0-1
			"size": rng.randf_range(0.5, 2.5),
			"base_alpha": rng.randf_range(0.4, 1.0),
			"phase": rng.randf() * TAU,
			"twinkle_speed": rng.randf_range(0.3, 1.2),
		})
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var sz := get_size()
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.06, 0.16))
	for s in _stars:
		var twinkle := sin(_time * s["twinkle_speed"] + s["phase"]) * 0.2
		var alpha: float = clampf(s["base_alpha"] + twinkle, 0.1, 1.0)
		var pos := Vector2(s["pos"].x * sz.x, s["pos"].y * sz.y)
		draw_circle(pos, s["size"], Color(0.94, 0.90, 0.80, alpha))
