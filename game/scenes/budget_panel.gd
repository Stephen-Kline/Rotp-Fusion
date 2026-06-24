extends PanelContainer

# Four-pillar budget allocation panel.
# Row names match the toolbar KPIs (Power/Population/Research/Construction).
# Each row header shows both the allocation % and the current output value.

signal allocation_changed(food: float, education: float, industry: float, energy: float)

# Energy → Power
@onready var _energy_slider:  HSlider = $MarginContainer/VBox/PowerRow/Slider
@onready var _energy_pct:     Label   = $MarginContainer/VBox/PowerRow/Header/Pct
@onready var _energy_outcome: Label   = $MarginContainer/VBox/PowerRow/Header/Outcome

# Food → Population
@onready var _food_slider:    HSlider = $MarginContainer/VBox/PopRow/Slider
@onready var _food_pct:       Label   = $MarginContainer/VBox/PopRow/Header/Pct
@onready var _food_outcome:   Label   = $MarginContainer/VBox/PopRow/Header/Outcome

# Education → Research
@onready var _education_slider:   HSlider = $MarginContainer/VBox/ResearchRow/Slider
@onready var _education_pct:      Label   = $MarginContainer/VBox/ResearchRow/Header/Pct
@onready var _education_outcome:  Label   = $MarginContainer/VBox/ResearchRow/Header/Outcome

# Industry → Construction
@onready var _industry_slider:   HSlider = $MarginContainer/VBox/BuildRow/Slider
@onready var _industry_pct:      Label   = $MarginContainer/VBox/BuildRow/Header/Pct
@onready var _industry_outcome:  Label   = $MarginContainer/VBox/BuildRow/Header/Outcome

var _updating: bool = false


func _ready() -> void:
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

	# Outcome values — what each allocation is currently producing
	var low_power := state.energy_capacity < 0.3
	_energy_outcome.text = "%d%%" % roundi(state.energy_capacity * 100.0)
	_energy_outcome.modulate = Color(1.0, 0.35, 0.35) if low_power else Color(0.65, 0.75, 0.9)

	_food_outcome.text      = "%.0fM pop" % state.population_units
	_education_outcome.text = "%.1f/yr" % state.research_rate
	_industry_outcome.text  = "%d%% spd" % roundi(state.construction_speed * 100.0)


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
