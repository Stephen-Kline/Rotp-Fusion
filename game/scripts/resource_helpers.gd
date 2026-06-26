class_name ResourceHelpers

# SI prefix auto-scaling display — covers k through Q (10^3 to 10^30).
# Shows 3 significant figures at every scale.
static func format_si(value: float, base_unit: String) -> String:
	const PREFIXES := ["", "k", "M", "G", "T", "P", "E", "Z", "Y", "R", "Q"]
	var idx := 0
	var v := absf(value)
	while v >= 1000.0 and idx < PREFIXES.size() - 1:
		v /= 1000.0
		idx += 1
	if value < 0.0:
		v = -v
	# 3 significant figures without %g (unsupported in GDScript)
	var s: String
	if absf(v) < 10.0:
		s = "%.2f" % v
	elif absf(v) < 100.0:
		s = "%.1f" % v
	else:
		s = "%d" % roundi(v)
	return s + " " + PREFIXES[idx] + base_unit

# Budget allocation → production factor.
# Soft diminishing returns with a floor so 0% allocation never kills a resource.
#   pct=0   → 0.10  (10% floor — civilization has momentum)
#   pct=25  → ~0.46
#   pct=50  → ~0.68
#   pct=100 → 1.00
static func budget_factor(pct: float) -> float:
	const FLOOR  := 0.10
	const CURVE  := 0.65
	return FLOOR + (1.0 - FLOOR) * pow(clampf(pct, 0.0, 100.0) / 100.0, CURVE)

# Kardashev contribution from Energy production rate (joules/year).
# Formula derived so that game-start energy (~9e19 J/yr) gives K_e = 0.70
# and Type-I energy (~3e27 J/yr) gives K_e = 1.0.
# Range is clamped to [0, 1.5] to allow slight overshoot.
static func k_from_energy(joules_per_year: float) -> float:
	if joules_per_year <= 0.0:
		return 0.0
	var watts := joules_per_year / 3.15e7
	var k := (log(watts) / log(10.0) - 4.33) / 11.67
	return clampf(k, 0.0, 1.5)

# Kardashev contribution from Knowledge production rate (bits/year).
# Calibrated so game-start knowledge (~9e8 bits/yr) gives K_k = 0.70
# and K1-target knowledge (~1e18 bits/yr) gives K_k = 1.0.
static func k_from_knowledge(bits_per_year: float) -> float:
	if bits_per_year <= 0.0:
		return 0.0
	var k := (log(bits_per_year) / log(10.0) + 12.0) / 30.0
	return clampf(k, 0.0, 1.5)
