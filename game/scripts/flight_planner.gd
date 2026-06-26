class_name FlightPlanner

# Computes mission profiles for ship transits.
# Hybrid II+III model: Hohmann timing scaled by propulsion tier; direct trajectory
# unlocked by tech gate (fusion_drive + advanced_navigation) and compared dynamically.
# Calibrated transit times use Apollo-optimized trajectories, not pure minimum-energy Hohmann.

const SECS_PER_YEAR := 365.25 * 24.0 * 3600.0

# Baseline transit years at CHEMICAL tier (Apollo-class trajectories).
const BASELINE_TRANSIT_YR: Dictionary = {
	"earth_moon":  3.1 / 365.25,     # Apollo ~3.1 days
	"moon_earth":  3.1 / 365.25,
	"earth_mars":  0.708,             # Hohmann minimum ~8.5 months
	"mars_earth":  0.708,
	"earth_venus": 0.400,             # Hohmann minimum ~4.8 months
	"venus_earth": 0.400,
	"earth_l2":    0.003,             # Near-Earth point
	"l2_earth":    0.003,
}

# How often a good launch window repeats (years).
# Windows are tied to synodic periods of the target body.
const WINDOW_PERIOD_YR: Dictionary = {
	"earth_moon":  0.0748,   # 27.3 days — Moon's orbital period
	"moon_earth":  0.0748,
	"earth_mars":  2.135,    # Synodic period
	"earth_venus": 1.599,
	"earth_l2":    1.0,
}

# Maximum distance between bodies in km, used for direct trajectory time.
# Conservative (worst-case: opposite sides of orbit).
const DISTANCE_KM: Dictionary = {
	"earth_moon":  384_400.0,
	"moon_earth":  384_400.0,
	"earth_mars":  401_300_000.0,
	"earth_venus": 261_000_000.0,
	"earth_l2":    1_500_000.0,
}

# Phase fraction within a window period that counts as "already aligned".
# Below this, no wait is needed.
const WINDOW_ALIGNMENT_THRESHOLD := 0.15


class MissionProfile:
	var window_wait_years: float = 0.0    # time until next optimal window
	var transit_years: float = 0.0        # time from departure to arrival
	var departure_year: float = 0.0       # window_year (player waits until this)
	var arrival_year: float = 0.0
	var direct_available: bool = false
	var direct_transit_years: float = 0.0 # transit if launching right now (direct burn)
	var direct_arrival_year: float = 0.0


static func plan(
		origin: String,
		destination: String,
		departure_from: float,
		propulsion_tier: int,
		direct_unlocked: bool) -> MissionProfile:

	var prof := MissionProfile.new()
	var pair := "%s_%s" % [origin, destination]

	# Space folding: zero transit, no window needed
	if propulsion_tier == PropulsionData.Tier.FOLDING:
		prof.departure_year = departure_from
		prof.arrival_year = departure_from
		prof.direct_available = true
		prof.direct_arrival_year = departure_from
		return prof

	var speed_kmps: float = PropulsionData.SPEED_KMPS.get(propulsion_tier,
		PropulsionData.SPEED_KMPS[PropulsionData.Tier.CHEMICAL])
	var chem_speed: float = PropulsionData.SPEED_KMPS[PropulsionData.Tier.CHEMICAL]
	var speed_factor := speed_kmps / chem_speed

	# Hohmann-scaled transit time
	var base_transit: float = BASELINE_TRANSIT_YR.get(pair, 1.0)
	var transit_yr := base_transit / speed_factor

	# Launch window timing: phase-based, repeats every window_period
	var window_period: float = WINDOW_PERIOD_YR.get(pair, 1.0)
	var phase := fmod(departure_from, window_period)
	var window_wait := 0.0 if phase < window_period * WINDOW_ALIGNMENT_THRESHOLD \
		else (window_period - phase)

	prof.window_wait_years = window_wait
	prof.transit_years = transit_yr
	prof.departure_year = departure_from + window_wait
	prof.arrival_year = prof.departure_year + transit_yr

	# Direct trajectory: distance / speed, available once tech gate is met.
	# Ship uses the better option (whichever gives earlier arrival_year).
	prof.direct_available = direct_unlocked
	if direct_unlocked and speed_kmps > 0.0:
		var dist_km: float = DISTANCE_KM.get(pair, 1_000_000.0)
		var direct_yr := (dist_km / speed_kmps) / SECS_PER_YEAR
		prof.direct_transit_years = direct_yr
		prof.direct_arrival_year = departure_from + direct_yr

	return prof
