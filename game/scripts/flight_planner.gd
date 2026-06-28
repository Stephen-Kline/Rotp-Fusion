class_name FlightPlanner

# Computes mission profiles for ship transits.
# All times are in game-days. departure_from is elapsed_days at mission authorization.

const SECS_PER_DAY := 86400.0

# Baseline transit days at CHEMICAL tier (Apollo-class trajectories).
const BASELINE_TRANSIT_DAYS: Dictionary = {
	"earth_moon":  3.1,
	"moon_earth":  3.1,
	"earth_mars":  258.7,   # Hohmann minimum ~8.5 months
	"mars_earth":  258.7,
	"earth_venus": 146.0,   # Hohmann minimum ~4.8 months
	"venus_earth": 146.0,
	"earth_l2":    1.0,
	"l2_earth":    1.0,
}

# How often a good launch window repeats (days, synodic periods).
const WINDOW_PERIOD_DAYS: Dictionary = {
	"earth_moon":  27.3,
	"moon_earth":  27.3,
	"earth_mars":  779.9,
	"earth_venus": 583.9,
	"earth_l2":    365.25,
}

# Maximum distance between bodies in km.
const DISTANCE_KM: Dictionary = {
	"earth_moon":  384_400.0,
	"moon_earth":  384_400.0,
	"earth_mars":  401_300_000.0,
	"earth_venus": 261_000_000.0,
	"earth_l2":    1_500_000.0,
}

const WINDOW_ALIGNMENT_THRESHOLD := 0.15


class MissionProfile:
	var window_wait_days: float = 0.0
	var transit_days: float = 0.0
	var departure_day: float = 0.0
	var arrival_day: float = 0.0
	var direct_available: bool = false
	var direct_transit_days: float = 0.0
	var direct_arrival_day: float = 0.0


static func plan(
		origin: String,
		destination: String,
		departure_from: float,
		propulsion_tier: int,
		direct_unlocked: bool) -> MissionProfile:

	var prof := MissionProfile.new()
	var pair := "%s_%s" % [origin, destination]

	if propulsion_tier == PropulsionData.Tier.FOLDING:
		prof.departure_day = departure_from
		prof.arrival_day = departure_from
		prof.direct_available = true
		prof.direct_arrival_day = departure_from
		return prof

	var speed_kmps: float = PropulsionData.SPEED_KMPS.get(propulsion_tier,
		PropulsionData.SPEED_KMPS[PropulsionData.Tier.CHEMICAL])
	var chem_speed: float = PropulsionData.SPEED_KMPS[PropulsionData.Tier.CHEMICAL]
	var speed_factor := speed_kmps / chem_speed

	var base_transit: float = BASELINE_TRANSIT_DAYS.get(pair, 365.0)
	var transit_days := base_transit / speed_factor

	var window_period: float = WINDOW_PERIOD_DAYS.get(pair, 365.25)
	var phase := fmod(departure_from, window_period)
	var window_wait := 0.0 if phase < window_period * WINDOW_ALIGNMENT_THRESHOLD \
		else (window_period - phase)

	prof.window_wait_days = window_wait
	prof.transit_days = transit_days
	prof.departure_day = departure_from + window_wait
	prof.arrival_day = prof.departure_day + transit_days

	prof.direct_available = direct_unlocked
	if direct_unlocked and speed_kmps > 0.0:
		var dist_km: float = DISTANCE_KM.get(pair, 1_000_000.0)
		var direct_days := (dist_km / speed_kmps) / SECS_PER_DAY
		prof.direct_transit_days = direct_days
		prof.direct_arrival_day = departure_from + direct_days

	return prof
