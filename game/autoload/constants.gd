extends Node

# ── Speed system ──────────────────────────────────────────────────────────────
# Base rate: Moon trip (4 days) = 30 real seconds at 1×.
const BASE_DAYS_PER_SEC := 4.0 / 30.0   # ≈ 0.1333 game-days per real second at 1×

const SPEED_PAUSE := 0
const SPEED_1X    := 1
const SPEED_10X   := 2
const SPEED_100X  := 3
const SPEED_1000X := 4

const DAYS_PER_SECOND: Dictionary = {
	SPEED_PAUSE:  0.0,
	SPEED_1X:     BASE_DAYS_PER_SEC * 1.0,
	SPEED_10X:    BASE_DAYS_PER_SEC * 10.0,
	SPEED_100X:   BASE_DAYS_PER_SEC * 100.0,
	SPEED_1000X:  BASE_DAYS_PER_SEC * 1000.0,
}

const SPEED_LABELS: Dictionary = {
	SPEED_PAUSE:  "⏸",
	SPEED_1X:     "1×",
	SPEED_10X:    "10×",
	SPEED_100X:   "100×",
	SPEED_1000X:  "1000×",
}

const DIRECT_LAUNCH_ENERGY_COST: float = 5e19
