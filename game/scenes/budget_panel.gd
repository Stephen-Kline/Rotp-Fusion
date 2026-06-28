extends PanelContainer

# Four-pillar budget allocation panel.
# Each row: allocation slider + % label + live SI-formatted production rate.

signal allocation_changed(food: float, education: float, industry: float, energy: float)

const _RH = preload("res://scripts/resource_helpers.gd")

# Energy pillar
@onready var _energy_slider:  HSlider = $MarginContainer/VBox/PowerRow/Slider
@onready var _energy_pct:     Label   = $MarginContainer/VBox/PowerRow/Header/Pct
@onready var _energy_outcome: Label   = $MarginContainer/VBox/PowerRow/Header/Outcome

# Consumables pillar
@onready var _food_slider:    HSlider = $MarginContainer/VBox/PopRow/Slider
@onready var _food_pct:       Label   = $MarginContainer/VBox/PopRow/Header/Pct
@onready var _food_outcome:   Label   = $MarginContainer/VBox/PopRow/Header/Outcome

# Knowledge pillar
@onready var _education_slider:   HSlider = $MarginContainer/VBox/ResearchRow/Slider
@onready var _education_pct:      Label   = $MarginContainer/VBox/ResearchRow/Header/Pct
@onready var _education_outcome:  Label   = $MarginContainer/VBox/ResearchRow/Header/Outcome

# Materials pillar
@onready var _industry_slider:   HSlider = $MarginContainer/VBox/BuildRow/Slider
@onready var _industry_pct:      Label   = $MarginContainer/VBox/BuildRow/Header/Pct
@onready var _industry_outcome:  Label   = $MarginContainer/VBox/BuildRow/Header/Outcome

var _updating: bool = false


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.panel_style(UIUtil.COL_NAVY))

	_energy_slider.value_changed.connect(_on_slider_changed.bind("energy"))
	_food_slider.value_changed.connect(_on_slider_changed.bind("food"))
	_education_slider.value_changed.connect(_on_slider_changed.bind("education"))
	_industry_slider.value_changed.connect(_on_slider_changed.bind("industry"))


func refresh(state: SimulationState) -> void:
	_updating = true
	_energy_slider.value    = state.pillar_energy
	_food_slider.value      = state.pillar_food
	_education_slider.value = state.pillar_education
	_industry_slider.value  = state.pillar_industry
	_update_alloc_labels(state.pillar_energy, state.pillar_food,
			state.pillar_education, state.pillar_industry)
	_updating = false

	# Outcome values — live SI-formatted production rates
	var low_energy := state.energy_capacity < 0.15
	_energy_outcome.text = _RH.format_si(state.energy_rate, "J")
	_energy_outcome.modulate = UIUtil.COL_ERROR if low_energy else Color.WHITE

	_food_outcome.text      = _RH.format_si(state.consumables_rate, "cal")
	_education_outcome.text = _RH.format_si(state.knowledge_rate,   "bits")
	_industry_outcome.text  = _RH.format_si(state.materials_rate,   "t")


func _on_slider_changed(value: float, pillar: String) -> void:
	if _updating:
		return
	_updating = true

	var energy    := _energy_slider.value
	var food      := _food_slider.value
	var education := _education_slider.value
	var industry  := _industry_slider.value

	var locked       := value
	var others_total := 100.0 - locked

	match pillar:
		"energy":
			energy = locked
			var rest := food + education + industry
			if rest > 0.0:
				var scale := others_total / rest
				food *= scale; education *= scale; industry *= scale
			else:
				food = others_total / 3.0; education = others_total / 3.0; industry = others_total / 3.0
		"food":
			food = locked
			var rest := energy + education + industry
			if rest > 0.0:
				var scale := others_total / rest
				energy *= scale; education *= scale; industry *= scale
			else:
				energy = others_total / 3.0; education = others_total / 3.0; industry = others_total / 3.0
		"education":
			education = locked
			var rest := energy + food + industry
			if rest > 0.0:
				var scale := others_total / rest
				energy *= scale; food *= scale; industry *= scale
			else:
				energy = others_total / 3.0; food = others_total / 3.0; industry = others_total / 3.0
		"industry":
			industry = locked
			var rest := energy + food + education
			if rest > 0.0:
				var scale := others_total / rest
				energy *= scale; food *= scale; education *= scale
			else:
				energy = others_total / 3.0; food = others_total / 3.0; education = others_total / 3.0

	energy    = clampf(energy,    0.0, 100.0)
	food      = clampf(food,      0.0, 100.0)
	education = clampf(education, 0.0, 100.0)
	industry  = clampf(industry,  0.0, 100.0)

	_energy_slider.value    = energy
	_food_slider.value      = food
	_education_slider.value = education
	_industry_slider.value  = industry

	_update_alloc_labels(energy, food, education, industry)
	_updating = false

	allocation_changed.emit(food, education, industry, energy)


func _update_alloc_labels(energy: float, food: float, education: float, industry: float) -> void:
	_energy_pct.text    = "%.0f%%" % energy
	_food_pct.text      = "%.0f%%" % food
	_education_pct.text = "%.0f%%" % education
	_industry_pct.text  = "%.0f%%" % industry
