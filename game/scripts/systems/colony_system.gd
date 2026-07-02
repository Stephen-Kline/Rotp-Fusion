class_name ColonySystem
extends RefCounted

# Manages per-colony state. Currently thin (Earth only); will expand in Milestone 2
# to handle per-colony resource production, population dynamics, and infrastructure.

var _struct_db: StructureDB

# Starting environment by body ID; used when initialising new colonies.
const ENV_START_BY_BODY: Dictionary = {
	"Earth": 85.0,
	"Moon": 15.0, "Phobos": 15.0, "Deimos": 15.0,
	"Mars": 35.0, "Venus": 35.0, "Mercury": 15.0,
	"Ceres": 15.0, "Pluto": 15.0, "Charon": 15.0, "Eris": 15.0,
	"Jupiter": 5.0, "Saturn": 5.0, "Uranus": 5.0, "Neptune": 5.0,
	"Io": 5.0, "Europa": 5.0, "Ganymede": 5.0, "Callisto": 5.0,
	"Titan": 5.0, "Enceladus": 5.0, "Rhea": 5.0, "Dione": 5.0,
	"Triton": 5.0,
}

# Natural environment recovery rate per tier (points / game-year, no structure help)
const ENV_NATURAL_RECOVERY: Dictionary = {
	"HEALTHY": 2.0, "STRESSED": 0.5, "CRITICAL": 0.1, "COLLAPSE": 0.01,
}

# Yield multiplier applied to all resource rates when in this tier
const ENV_YIELD_MULT: Dictionary = {
	"HEALTHY": 1.00, "STRESSED": 0.85, "CRITICAL": 0.60, "COLLAPSE": 0.25,
}

# Fractional population decline per year when in this tier (0 = none)
const ENV_POP_DECLINE: Dictionary = {
	"HEALTHY": 0.00, "STRESSED": 0.02, "CRITICAL": 0.08, "COLLAPSE": 0.25,
}


func _init() -> void:
	_struct_db = StructureDB.new()


func tick(s: SimulationState, delta_years: float, _result: TickResult) -> void:
	for col in s.colonies:
		_recompute_colony(col as ColonyState, s, delta_years)


func _recompute_colony(colony: ColonyState, s: SimulationState, delta_years: float) -> void:
	var n := colony.structures.size()

	# Sync online_flags length; new entries default online
	while colony.online_flags.size() < n:
		colony.online_flags.append(true)
	if colony.online_flags.size() > n:
		colony.online_flags.resize(n)

	# Determine total operational energy cost for all candidate-online structures
	var total_op := 0.0
	for sid: String in colony.structures:
		total_op += _struct_db.get_energy_op(sid)

	# Use previous tick's energy_rate as available budget (one-tick lag is fine)
	var available := colony.energy_rate

	# Shed structures when operational costs exceed available energy:
	# dirty (env_delta < 0) first, then clean — lowest production value within each group
	if total_op > available:
		# Reset all to online before shedding
		colony.online_flags.fill(true)
		while total_op > available:
			var shed_idx := _pick_shed_candidate(colony)
			if shed_idx < 0:
				break
			colony.online_flags[shed_idx] = false
			total_op -= _struct_db.get_energy_op(colony.structures[shed_idx])
	else:
		colony.online_flags.fill(true)

	# Recompute struct bonus totals from online structures only
	colony.struct_energy      = 0.0
	colony.struct_consumables = 0.0
	colony.struct_knowledge   = 0.0
	colony.struct_materials   = 0.0
	var struct_env_delta := 0.0

	for i in n:
		if not colony.online_flags[i]:
			continue
		var sid: String = colony.structures[i]
		var b := _struct_db.get_struct_bonuses(sid)
		colony.struct_energy      += float(b.get("energy",      0.0))
		colony.struct_consumables += float(b.get("consumables", 0.0))
		colony.struct_knowledge   += float(b.get("knowledge",   0.0))
		colony.struct_materials   += float(b.get("materials",   0.0))
		struct_env_delta          += _struct_db.get_env_delta(sid)

	# Update environment
	var tier := _env_tier(colony.environment)
	var natural: float = ENV_NATURAL_RECOVERY[tier]
	colony.env_rate = natural + struct_env_delta + s.env_rate_bonus + s.faction_env_bonus
	colony.environment = clampf(colony.environment + colony.env_rate * delta_years, 0.0, 100.0)

	# Derive yield multiplier and apply population decline for next economy tick
	var new_tier := _env_tier(colony.environment)
	colony.env_yield_mult = ENV_YIELD_MULT[new_tier]

	var decline: float = ENV_POP_DECLINE[new_tier]
	if decline > 0.0:
		colony.population_units = maxf(1.0, colony.population_units * (1.0 - decline * delta_years))


func _pick_shed_candidate(colony: ColonyState) -> int:
	var best_idx := -1
	var best_val := INF
	var found_dirty := false

	for i in colony.structures.size():
		if not colony.online_flags[i]:
			continue
		var sid: String = colony.structures[i]
		var is_dirty := _struct_db.get_env_delta(sid) < 0.0
		var pv := _production_value(sid)

		if is_dirty:
			if not found_dirty or pv < best_val:
				best_idx = i
				best_val = pv
				found_dirty = true
		elif not found_dirty:
			if pv < best_val:
				best_idx = i
				best_val = pv

	return best_idx


# Rough sort key: gross energy production dominates; non-energy bonuses treated as negligible
func _production_value(sid: String) -> float:
	var b := _struct_db.get_struct_bonuses(sid)
	return float(b.get("energy", 0.0))


func _env_tier(env: float) -> String:
	if env >= 80.0: return "HEALTHY"
	if env >= 50.0: return "STRESSED"
	if env >= 20.0: return "CRITICAL"
	return "COLLAPSE"


func apply(s: SimulationState, action: PlayerAction) -> bool:
	match action.type:
		PlayerAction.Type.BUILD_STRUCTURE:
			return _apply_build(s, action.payload)
		PlayerAction.Type.DEMOLISH_STRUCTURE:
			return _apply_demolish(s, action.payload)
	return false


func _apply_build(s: SimulationState, p: Dictionary) -> bool:
	var body: String       = p.get("body", "earth")
	var struct_type: String = p.get("structure_type", "")
	if struct_type.is_empty() or struct_type not in s.available_build_options:
		return true
	var cost := _struct_db.get_cost(struct_type)
	var col := s.colony_for(body)
	if col == null:
		return true
	if col.materials_stockpile < cost["materials"] or col.energy_stockpile < cost["energy"]:
		return true
	col.materials_stockpile -= cost["materials"]
	col.energy_stockpile    -= cost["energy"]
	col.structures.append(struct_type)
	col.online_flags.append(true)
	if not _struct_db.is_repeatable(struct_type):
		s.available_build_options.erase(struct_type)
	# Post-build triggers
	match struct_type:
		"expanded_station":
			_found_station(s)
		"docking_bay":
			if "transport_freighter" not in s.available_build_options:
				s.available_build_options.append("transport_freighter")
	return true


func _found_station(s: SimulationState) -> void:
	if s.colony_for("Station") != null:
		return
	var col := ColonyState.new()
	col.body_id          = "Station"
	col.population_units = 0.05
	col.environment      = 100.0
	col.env_yield_mult   = 1.0
	col.resource_bonus   = {}
	col.structures.append("life_support_module")
	col.online_flags.append(true)
	s.colonies.append(col)
	for sid: String in ["microgravity_lab", "docking_bay"]:
		if sid not in s.available_build_options:
			s.available_build_options.append(sid)


func _apply_demolish(s: SimulationState, p: Dictionary) -> bool:
	var body: String  = p.get("body", "earth")
	var idx: int      = p.get("index", -1)
	var col := s.colony_for(body)
	if not col or idx < 0 or idx >= col.structures.size():
		return true
	col.structures.remove_at(idx)
	col.online_flags.remove_at(idx)
	return true
