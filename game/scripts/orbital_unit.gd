class_name OrbitalUnit
extends Resource

# Static asset placed at a celestial body. Provides ongoing bonuses once deployed.
# Placed by a ship mission; no ongoing orbital mechanics needed beyond body tracking.

enum Kind {
	SATELLITE,
	STATION,
	DEPOT,
	WEAPONS_PLATFORM,
}

@export var id: String = ""
@export var kind: int = Kind.SATELLITE
@export var body: String = "earth"     # body it orbits / is anchored to
@export var placed_year: float = 0.0
@export var bonuses: Dictionary = {}   # e.g. {"research_rate_bonus": 0.1}
