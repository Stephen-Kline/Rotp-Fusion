extends Node

enum CompressionLevel {
	PAUSED,
	SLOW,       # 0.2 yr/s  — careful play
	NORMAL,     # 1 yr/s    — standard
	FAST,       # 5 yr/s    — mid-game cruise
	FASTER,     # 10 yr/s   — Earth-era cap
	MAX,        # 100 yr/s  — K ≥ 1.0 unlock
	KILO,       # 1,000 yr/s  — K ≥ 1.5 unlock
	TEN_K,      # 10,000 yr/s — K ≥ 2.0 unlock
	HUNDRED_K,  # 100,000 yr/s — K ≥ 2.5 unlock
}

const YEARS_PER_SECOND := {
	CompressionLevel.PAUSED:    0.0,
	CompressionLevel.SLOW:      0.2,
	CompressionLevel.NORMAL:    1.0,
	CompressionLevel.FAST:      5.0,
	CompressionLevel.FASTER:    10.0,
	CompressionLevel.MAX:       100.0,
	CompressionLevel.KILO:      1_000.0,
	CompressionLevel.TEN_K:     10_000.0,
	CompressionLevel.HUNDRED_K: 100_000.0,
}

const COMPRESSION_LABELS := {
	CompressionLevel.PAUSED:    "⏸",
	CompressionLevel.SLOW:      "0.2×",
	CompressionLevel.NORMAL:    "1×",
	CompressionLevel.FAST:      "5×",
	CompressionLevel.FASTER:    "10×",
	CompressionLevel.MAX:       "100×",
	CompressionLevel.KILO:      "1k×",
	CompressionLevel.TEN_K:     "10k×",
	CompressionLevel.HUNDRED_K: "100k×",
}

# Kardashev level required to unlock each gated speed tier.
const K_UNLOCK := {
	CompressionLevel.MAX:       1.0,
	CompressionLevel.KILO:      1.5,
	CompressionLevel.TEN_K:     2.0,
	CompressionLevel.HUNDRED_K: 2.5,
}

# Always-available speed levels (shown on toolbar at game start).
const BASE_SPEEDS := [
	CompressionLevel.PAUSED,
	CompressionLevel.SLOW,
	CompressionLevel.NORMAL,
	CompressionLevel.FAST,
	CompressionLevel.FASTER,
]

# ── Orbital mechanics ─────────────────────────────────────────────────────────

# Structure build costs: materials (tonnes), energy (J).
# Structures are placed instantly on payment; build time may be added later.
const STRUCTURE_COSTS: Dictionary = {
	"launch_facility": {
		"materials": 1e9,   # 1 Gt
		"energy":    1e19,  # 10 EJ
	},
	"space_launch_facility": {
		"materials": 5e9,   # 5 Gt
		"energy":    5e19,  # 50 EJ
	},
}

# Ship build costs by build_option.
# build_years is the base duration; actual = build_years / construction_speed.
const SHIP_BUILD_COSTS: Dictionary = {
	"satellite": {
		"materials": 5e7,   # 50 Mt
		"energy":    5e17,  # 0.5 EJ
		"build_years": 0.25,
	},
	"lunar_transit_vehicle": {
		"materials": 3e8,   # 300 Mt
		"energy":    3e18,  # 3 EJ
		"build_years": 0.5,
	},
	"crewed_lunar_lander": {
		"materials": 1e9,   # 1 Gt
		"energy":    1e19,  # 10 EJ
		"build_years": 1.5,
	},
}

# Extra energy penalty when launching outside the optimal window (direct trajectory push).
const DIRECT_LAUNCH_ENERGY_COST: float = 5e19  # 50 EJ
