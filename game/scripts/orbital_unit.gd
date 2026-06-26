class_name OrbitalUnit

# Static asset placed at a celestial body. Provides ongoing bonuses once deployed.
# Placed by a ship mission; no ongoing orbital mechanics needed beyond body tracking.

enum Kind {
	SATELLITE,
	STATION,
	DEPOT,
	WEAPONS_PLATFORM,
}

var id: String = ""
var kind: int = Kind.SATELLITE
var body: String = "earth"     # body it orbits / is anchored to
var placed_year: float = 0.0
var bonuses: Dictionary = {}   # e.g. {"research_rate_bonus": 0.1}


func duplicate() -> OrbitalUnit:
	var u := OrbitalUnit.new()
	u.id = id; u.kind = kind; u.body = body
	u.placed_year = placed_year; u.bonuses = bonuses.duplicate()
	return u
