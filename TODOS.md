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

- [x] 8.  Station as `ColonyState` — crew population (0.05 units), pre-installed `life_support_module` drains consumables; created automatically when `expanded_station` structure is built
- [x] 9.  Station structures — `microgravity_lab` (+knowledge), `life_support_module` (-2e12 consumables/yr drain), `docking_bay` (unlocks transport_freighter build option); all in structures.json
- [x] 10. Station unlock gate — building `expanded_station` structure triggers `_found_station()` in ColonySystem; station ColonyState appended to `s.colonies`; `microgravity_lab` + `docking_bay` added to `available_build_options`
- [x] 11. First live `TransportSystem` — station's negative `consumables_rate` drives stockpile negative → `_colony_deficit` fires → Earth surplus routed to station; TRANSPORT_CARGO ships enter ORBITING immediately after build (no mission needed)

## Milestone 2 — First Off-World Colony

- [x] 12. `COLONIZER` ship role in `ShipSystem` — `Ship.Role.COLONIZER` added; on arrival `_found_colony()` creates `ColonyState` with colonist population + `colony_habitat` starter structure; ship enters ARRIVED (consumed)
- [x] 13. Planetary colony — any body in `BodyDB`; `ColonyState` gets `resource_bonus` from `BodyDB.resource_bonus()`, `environment` from `ColonySystem.ENV_START_BY_BODY`; gated behind `colony_life_support` tech in `completed_research`
- [x] 14. Transport + colony tech branch — `colony_life_support` (unlocks colonizer + colony_habitat), `colony_habitat_expansion` (unlocks hydroponics_bay + regolith_extractor), `transport_capacity_upgrade` (sets `transport_capacity_mult = 2.0`), `transport_speed_upgrade`; all in tech_tree.json
- [x] 15. Event engine — `NarrativeSystem` (scripts/systems/narrative_system.gd); loads events.json; probabilistic roll per tick; `active_events: Array` on `SimulationState`; detection window → player choice → consequence; immediate events (window=0) apply at trigger
- [x] 16. Event notification UI — `EventPanel` (scenes/event_panel.gd); reads `active_events`; shows name + countdown + choice buttons per event; emits `events_appeared` (pauses game) / `events_cleared` (resumes) / `event_choice_made` → `PlayerAction.resolve_event()`; wired into main.gd `_on_tick`
- [x] 17. Event: asteroid warning — 21-day window; deflect/evacuate/accept choices with energy costs and structure/env consequences; base_probability 0.04/yr
- [x] 18. Event: supply disruption — 7-day window; rationing/reroute/burn stockpile; gated on min_colonies=2; base_probability 0.10/yr
- [x] 19. Event: faction crisis — 14-day window; spend capital/reallocate/accept penalty; gated on max_faction_satisfaction=40; base_probability 0.08/yr
- [x] 20. Event: alien attack — no detection window; immediate consequence; probability 1e-6/yr × kardashev_level; `probability_scales_with_kardashev: true`

## Milestone 2.5 / Late K1

- [x] 21. Terraforming structures — `terraforming_array` in structures.json with `env_delta: 20.0`, high energy cost; gated behind `planetary_engineering` tech (prereqs: colony_habitat_expansion + fusion_drive)
- [x] 22. Piracy events — `piracy` event in events.json; 10-day window; escort/pay off/reroute choices; gated on min_colonies=2, min_elapsed_days=1460; handled by NarrativeSystem
- [x] 23. Transport + colony tech branch depth — `advanced_cargo_systems` (transport_capacity_mult → 4.0), `multi_hop_routing` (milestone flag); both in tech_tree.json; colony structures `hydroponics_bay` + `regolith_extractor` in structures.json

## Pinned / Later

- Global resource pool pathway for megastructures (K2+)
- Parallel research tracks (multi-institution unlock, late K1)
- Multiple species (Stellaris-style, post-K1)
- Alien contact escalation arc (deep space, higher K, diplomatic options)
- Military / combat mechanics
- Economy crash event type
- Solar flare, political revolution, plague event types
- Autonomous colony governors (quality-of-life at 10+ colonies)
- Event notification UI scene (todo 16 UI layer — needs Godot editor, deferred)
