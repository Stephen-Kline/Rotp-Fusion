class_name PropulsionData

# Speed table and tech-gate definitions for ship propulsion tiers.
# Ships always use the best tier available at build time.

enum Tier {
	CHEMICAL,       # ~11 km/s      Apollo era; Hohmann-limited
	NUCLEAR,        # ~25 km/s      NERVA-class nuclear thermal
	ION,            # ~100 km/s     High-efficiency, low-thrust
	FUSION,         # ~1 000 km/s   Unlocks direct trajectory option
	ANTIMATTER,     # ~100 000 km/s ≈ 0.3c
	RELATIVISTIC,   # ~296 794 km/s ≈ 0.99c
	FOLDING,        # Instantaneous — zero transit time
}

# Effective cruise speed in km/s.
# Chemical calibrated so Earth→Moon gives ~3.1 days (Apollo-optimized, not pure Hohmann).
const SPEED_KMPS: Dictionary = {
	Tier.CHEMICAL:     11.0,
	Tier.NUCLEAR:      25.0,
	Tier.ION:          100.0,
	Tier.FUSION:       1_000.0,
	Tier.ANTIMATTER:   100_000.0,
	Tier.RELATIVISTIC: 296_794.0,
	Tier.FOLDING:      0.0,   # handled as special case in FlightPlanner
}

# ALL listed tech nodes must be in completed_research to unlock each tier.
const UNLOCK_NODES: Dictionary = {
	Tier.CHEMICAL:     [],
	Tier.NUCLEAR:      ["nuclear_thermal_drive"],
	Tier.ION:          ["ion_drive"],
	Tier.FUSION:       ["fusion_drive"],
	Tier.ANTIMATTER:   ["antimatter_drive"],
	Tier.RELATIVISTIC: ["relativistic_drive"],
	Tier.FOLDING:      ["space_folding"],
}

# ALL must be completed to unlock the direct (non-Hohmann) trajectory option.
const DIRECT_UNLOCK_NODES: Array = ["fusion_drive", "advanced_navigation"]


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


static func is_direct_unlocked(completed_research: Array) -> bool:
	for node in DIRECT_UNLOCK_NODES:
		if node not in completed_research:
			return false
	return true


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
