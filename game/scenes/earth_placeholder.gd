extends Control

# Draws a placeholder circle for Earth until real art arrives.
# All visual properties go through AssetRegistry when art is ready.

var _radius: float = 250.0
var _color: Color = Color(0.15, 0.35, 0.75)        # ocean blue
var _land_color: Color = Color(0.2, 0.55, 0.25)    # land green
var _atmosphere: Color = Color(0.4, 0.6, 1.0, 0.18)


func _ready() -> void:
	custom_minimum_size = Vector2(_radius * 2, _radius * 2)


func _draw() -> void:
	var center := Vector2(_radius, _radius)
	# Atmosphere glow (slightly larger)
	draw_circle(center, _radius + 12.0, Color(0.4, 0.6, 1.0, 0.12))
	# Ocean base
	draw_circle(center, _radius, _color)
	# Crude land masses (fixed arcs as placeholder blobs)
	draw_circle(center + Vector2(-60, -40), 90.0, _land_color)
	draw_circle(center + Vector2(80, 30), 70.0, _land_color)
	draw_circle(center + Vector2(-20, 90), 55.0, _land_color)
	# Re-clip to circle by drawing ocean over the corners (cheap masking)
	# Nothing needed — draw_circle already clips to its own boundary
	# Thin atmosphere rim
	var rim_style := 4.0
	for i in 32:
		var angle := i * TAU / 32.0
		var outer := center + Vector2(cos(angle), sin(angle)) * (_radius + rim_style * 0.5)
		var inner := center + Vector2(cos(angle), sin(angle)) * (_radius - rim_style * 0.5)
		draw_line(inner, outer, _atmosphere, rim_style)
