extends PanelContainer

# Four-pillar budget allocation panel.
# UI reads SimulationState; player intent is sent via PlayerAction — no pillar logic here.

signal allocation_changed(food: float, education: float, industry: float, energy: float)

@onready var _food_slider: HSlider = $MarginContainer/VBox/FoodRow/Slider
@onready var _food_label: Label = $MarginContainer/VBox/FoodRow/Header/Pct

@onready var _education_slider: HSlider = $MarginContainer/VBox/EducationRow/Slider
@onready var _education_label: Label = $MarginContainer/VBox/EducationRow/Header/Pct

@onready var _industry_slider: HSlider = $MarginContainer/VBox/IndustryRow/Slider
@onready var _industry_label: Label = $MarginContainer/VBox/IndustryRow/Header/Pct

@onready var _energy_slider: HSlider = $MarginContainer/VBox/EnergyRow/Slider
@onready var _energy_label: Label = $MarginContainer/VBox/EnergyRow/Header/Pct

var _updating: bool = false  # guard against recursive slider callbacks


func _ready() -> void:
	_food_slider.value_changed.connect(_on_slider_changed.bind("food"))
	_education_slider.value_changed.connect(_on_slider_changed.bind("education"))
	_industry_slider.value_changed.connect(_on_slider_changed.bind("industry"))
	_energy_slider.value_changed.connect(_on_slider_changed.bind("energy"))


func refresh(state: SimulationState) -> void:
	_updating = true
	_food_slider.value = state.pillar_food
	_education_slider.value = state.pillar_education
	_industry_slider.value = state.pillar_industry
	_energy_slider.value = state.pillar_energy
	_update_labels(state.pillar_food, state.pillar_education, state.pillar_industry, state.pillar_energy)
	_updating = false


func _on_slider_changed(value: float, pillar: String) -> void:
	if _updating:
		return
	_updating = true

	# Read current values
	var food := _food_slider.value
	var education := _education_slider.value
	var industry := _industry_slider.value
	var energy := _energy_slider.value

	# The changed pillar is locked to its new value; redistribute the remainder
	# proportionally among the other three.
	var locked := value
	var others_total := 100.0 - locked

	match pillar:
		"food":
			food = locked
			var rest := education + industry + energy
			if rest > 0.0:
				var scale := others_total / rest
				education *= scale
				industry *= scale
				energy *= scale
			else:
				education = others_total / 3.0
				industry = others_total / 3.0
				energy = others_total / 3.0
		"education":
			education = locked
			var rest := food + industry + energy
			if rest > 0.0:
				var scale := others_total / rest
				food *= scale
				industry *= scale
				energy *= scale
			else:
				food = others_total / 3.0
				industry = others_total / 3.0
				energy = others_total / 3.0
		"industry":
			industry = locked
			var rest := food + education + energy
			if rest > 0.0:
				var scale := others_total / rest
				food *= scale
				education *= scale
				energy *= scale
			else:
				food = others_total / 3.0
				education = others_total / 3.0
				energy = others_total / 3.0
		"energy":
			energy = locked
			var rest := food + education + industry
			if rest > 0.0:
				var scale := others_total / rest
				food *= scale
				education *= scale
				industry *= scale
			else:
				food = others_total / 3.0
				education = others_total / 3.0
				industry = others_total / 3.0

	# Clamp all to [0, 100]
	food = clampf(food, 0.0, 100.0)
	education = clampf(education, 0.0, 100.0)
	industry = clampf(industry, 0.0, 100.0)
	energy = clampf(energy, 0.0, 100.0)

	_food_slider.value = food
	_education_slider.value = education
	_industry_slider.value = industry
	_energy_slider.value = energy

	_update_labels(food, education, industry, energy)
	_updating = false

	allocation_changed.emit(food, education, industry, energy)


func _update_labels(food: float, education: float, industry: float, energy: float) -> void:
	_food_label.text = "%.0f%%" % food
	_education_label.text = "%.0f%%" % education
	_industry_label.text = "%.0f%%" % industry
	_energy_label.text = "%.0f%%" % energy
