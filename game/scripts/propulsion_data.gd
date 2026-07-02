class_name PropulsionData

# Speed table, tech gates, range caps, and gravity constraints for ship propulsion tiers.

enum Tier {
	CHEMICAL,       # ~11 km/s      Apollo era; Hohmann-limited
	NUCLEAR,        # ~25 km/s      NERVA-class nuclear thermal
	ION,            # ~100 km/s     High-efficiency spiral trajectory
	FUSION,         # ~1 000 km/s   Torch trajectory, unlimited range
	ANTIMATTER,     # ~100 000 km/s ≈ 0.3c
	RELATIVISTIC,   # ~296 794 km/s ≈ 0.99c
	FOLDING,        # Instantaneous — zero transit time
}

# Effective cruise speed in km/s.
const SPEED_KMPS: Dictionary = {
	Tier.CHEMICAL:     11.0,
	Tier.NUCLEAR:      25.0,
	Tier.ION:          100.0,
	Tier.FUSION:       1_000.0,
	Tier.ANTIMATTER:   100_000.0,
	Tier.RELATIVISTIC: 296_794.0,
	Tier.FOLDING:      0.0,
}

# Maximum range per leg in AU.
# Fusion and above have no range cap (interplanetary/interstellar capable).
const RANGE_AU: Dictionary = {
	Tier.CHEMICAL:  2.0,    # inner system: Earth, Mars, asteroid belt edge
	Tier.NUCLEAR:   10.0,   # mid system: reaches Saturn
	Tier.ION:       50.0,   # outer system: reaches Pluto and Kuiper belt
	Tier.FUSION:    INF,
	Tier.ANTIMATTER: INF,
	Tier.RELATIVISTIC: INF,
	Tier.FOLDING:   INF,
}

# Minimum propulsion tier required to depart from high-gravity bodies.
# Bodies not listed here require only CHEMICAL (default).
const MIN_DEPARTURE_TIER: Dictionary = {
	"Jupiter": Tier.FUSION,     # 24.8 m/s² — chemical rockets cannot escape
	"Saturn":  Tier.NUCLEAR,    # 10.4 m/s²
	"Uranus":  Tier.NUCLEAR,    # 8.9 m/s²
	"Neptune": Tier.NUCLEAR,    # 11.1 m/s²
	"Sol":     Tier.FUSION,     # departing the Sun's gravity well from inner system
}

# ALL listed tech nodes must be completed to unlock each tier.
const UNLOCK_NODES: Dictionary = {
	Tier.CHEMICAL:     [],
	Tier.NUCLEAR:      ["nuclear_thermal_drive"],
	Tier.ION:          ["ion_drive"],
	Tier.FUSION:       ["fusion_drive"],
	Tier.ANTIMATTER:   ["antimatter_drive"],
	Tier.RELATIVISTIC: ["relativistic_drive"],
	Tier.FOLDING:      ["space_folding"],
}


static func best_tier(completed_research: Array) -> int:
	var ordered: Array = [
		Tier.FOLDING, Tier.RELATIVISTIC, Tier.ANTIMATTER,
		Tier.FUSION, Tier.ION, Tier.NUCLEAR,
	]
	for tier in ordered:
		var all_done := true
		for node in UNLOCK_NODES[tier]:
			if node not in completed_research:
				all_done = false
				break
		if all_done:
			return tier
	return Tier.CHEMICAL


# Returns true if the given tier can complete the leg from origin_au to dest_au (solar AU).
static func range_ok(tier: int, origin_au: float, dest_au: float) -> bool:
	var cap: float = float(RANGE_AU.get(tier, 2.0))
	return absf(dest_au - origin_au) <= cap


# Returns true if the given tier can depart from the named body.
static func can_depart(tier: int, body: String) -> bool:
	var min_tier: int = int(MIN_DEPARTURE_TIER.get(body, Tier.CHEMICAL))
	return tier >= min_tier


static func tier_name(tier: int) -> String:
	match tier:
		Tier.CHEMICAL:     return "Chemical"
		Tier.NUCLEAR:      return "Nuclear Thermal"
		Tier.ION:          return "Ion Drive"
		Tier.FUSION:       return "Fusion Drive"
		Tier.ANTIMATTER:   return "Antimatter"
		Tier.RELATIVISTIC: return "Relativistic"
		Tier.FOLDING:      return "Space Folding"
	return "Unknown"
