# Kardashev — Development Todos

## Architecture Prerequisites
_Must be done before any milestone content. These are blocking._

- [x] 1. Move energy/materials/consumables stockpiles to `ColonyState`; knowledge stays global on `SimulationState`
- [x] 2. Refactor `EconomySystem` to tick per-colony, sum to aggregates for toolbar display
- [x] 3. Remove `SimulationState` compat delegate fields; replace with aggregate read-only getters; fixed write sites in `colony_system.gd` and `ship_system.gd`
- [x] 4. Add `TransportSystem` skeleton — auto-sources deficits from surplus colonies, capped by orbiting transport fleet capacity; no-op until Milestone 1.5 adds a second colony
- [x] 5. Add `transport_freighter` to ships.json with `capacity: 1e12`; `Ship` now carries `capacity` field; `ShipDB.get_capacity()` added
- [x] 6. Add faction passive effects — satisfaction tiers (≥70/30-69/<30) drive bonus/penalty on `research_rate` (Technocrats ±0.8), `construction_speed` (Industrialists ±0.4), `env_rate` (Environmentalists ±3/yr); FactionSystem now runs first in tick order
- [x] 7. Add per-body resource bonuses to `body_catalog.json` — Mars `{materials:1.5}`, Europa `{consumables:1.4}`, Titan `{energy:1.6}`; `BodyDB.resource_bonus()` added; set on `ColonyState` at creation

## Milestone 1.5 — Space Station
_Needs its own design session to finalize scope._

- [ ] 8.  Station as `ColonyState` — crew population, consumes consumables for life support, produces knowledge + materials bonuses
- [ ] 9.  Station structures — microgravity_lab, life_support_module, docking_bay (docking_bay unlocks transport ship build option)
- [ ] 10. Station unlock gate — `expanded_station` tech triggers station `ColonyState` creation
- [ ] 11. First live `TransportSystem` test — Earth → Station consumables route validates multi-colony architecture

## Milestone 2 — First Off-World Colony

- [ ] 12. `COLONIZER` ship role in `ShipSystem` — on arrival at destination body, `_found_colony()` creates `ColonyState` with `population = ship.payload["colonists"]` and 1-2 starter structures; ship consumed on founding
- [ ] 13. Planetary colony — Moon first; `ColonyState` with local production, per-body resource bonuses applied, habitability gated behind life support tech
- [ ] 14. Transport + colony tech branch — new nodes: transport_capacity_upgrade, transport_speed_upgrade, colony_life_support, colony_habitat_expansion
- [ ] 15. Event engine — `EventDefinition` (base_probability, conditions, detection_window_days, choices[], default_consequence); `active_events: Array` on `SimulationState`; consequence functions applied to state
- [ ] 16. Event notification UI — detection window panel with countdown, choice buttons, consequence preview
- [ ] 17. Event: asteroid warning — 2-3 week window; choices: deflect (costs energy), evacuate (loses structures), accept impact
- [ ] 18. Event: supply disruption — transport route blocked; choices: emergency rationing, reroute, burn stockpile
- [ ] 19. Event: faction crisis — satisfaction collapse; choices: spend political capital, emergency reallocation, accept penalty
- [ ] 20. Event: alien attack — 1-in-a-million probability per year at K1, no detection window, probability scales with K level

## Milestone 2.5 / Late K1

- [ ] 21. Terraforming structures — `terraforming_array` with high env_delta (+20/yr), high energy cost, gated behind late tech node; reuses existing env system
- [ ] 22. Piracy events — hostile disruption of transport routes; choices: escort ships, pay off, reroute
- [ ] 23. Transport + colony tech branch depth — advanced nodes for higher capacity, faster transit, multi-hop routes

## Pinned / Later

- Global resource pool pathway for megastructures (K2+)
- Parallel research tracks (multi-institution unlock, late K1)
- Multiple species (Stellaris-style, post-K1)
- Alien contact escalation arc (deep space, higher K, diplomatic options)
- Military / combat mechanics
- Economy crash event type
- Solar flare, political revolution, plague event types
- Autonomous colony governors (quality-of-life at 10+ colonies)
