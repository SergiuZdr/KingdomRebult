# KingdomRebuild TODO

## Immediate Priority

Target milestone:

`Version 0.2 - Real Campaign Loop`

## M1: Stabilize the Rules Layer

- [x] Create `scripts/data/BuildingData.gd`
- [x] Define a canonical schema for building resources
- [x] Wire `data/buildings/*.tres` into runtime loading
- [x] Replace hardcoded building production definitions in `scripts/autoload/GameState.gd`
- [x] Normalize naming across code and scenes
- [x] Resolve `Training Ground` vs `Training Grounds`
- [x] Make tavern behavior match intended design
- [x] Remove tavern gold production if tavern becomes recruit-focused only
- [x] Split static rules from mutable runtime state
- [x] Audit all building references in popups, scenes, and state scripts

## M2: Real Management Loop

- [ ] Replace fixed every-2-turn combat with threat scheduling
- [ ] Add visible wave countdown or threat forecast
- [ ] Refactor `end_turn()` into explicit phases
- [ ] Add upkeep phase
- [ ] Add production phase
- [ ] Add training phase
- [ ] Add event phase
- [ ] Add threat resolution phase
- [ ] Add optional action phase
- [ ] Expand recap to reflect all phases

## M2: Buildings From the Design

- [ ] Define construction building group
- [ ] Define military building group
- [ ] Define intermediary resource building group
- [ ] Define resource obtaining building group
- [ ] Define resource processing building group
- [ ] Define special building group
- [ ] Implement Barracks gameplay role
- [ ] Implement Workforce Housing gameplay role
- [ ] Implement Dungeon or Expedition building role
- [ ] Review whether Market, Butchery, and Weapon Forge should unlock actions or only passive output

## M3: Economy and Pressure

- [ ] Add food upkeep for soldiers
- [ ] Add food upkeep for workforce or population
- [ ] Add morale penalties for shortages
- [ ] Add morale penalties for defeat or casualties
- [ ] Add morale bonuses from tavern or victories
- [ ] Add recovery or hospital-style support rules if needed later
- [ ] Add population or workforce growth pressure
- [ ] Decide whether idle workforce has a cost, benefit, or event interaction

## M3: Soldiers and Progression

- [ ] Add recruit archetypes or classes
- [ ] Add starter trait pool
- [ ] Assign traits on recruit or level-up
- [ ] Add persistent injuries from combat
- [ ] Add recovery flow between combats
- [ ] Expand barracks or training effects on soldier growth
- [ ] Review level-up stat scaling
- [ ] Connect equipment access to city progression instead of a flat shop

## M4: Combat Depth

- [ ] Make limb data affect actual combat outcomes
- [ ] Add head, arm, and leg targeting
- [ ] Add limb-based penalties and death rules
- [ ] Add more player actions beyond `Attack` and `Defend`
- [ ] Add enemy roles and behavior differences
- [ ] Add stronger wave composition logic
- [ ] Add auto-resolve for low-risk fights
- [ ] Add post-combat consequences to the campaign layer

## M5: UX and Balancing

- [ ] Improve city HUD clarity
- [ ] Add threat forecast widget
- [ ] Redesign building popup around decisions and consequences
- [ ] Improve soldier menu readability
- [ ] Improve recap organization and formatting
- [ ] Balance the first 10 turns
- [ ] Tune recruit costs, production rates, and enemy scaling

## Suggested Build Order

### Week 1

- [ ] Create `BuildingData.gd`
- [ ] Connect `.tres` files
- [ ] Normalize building naming
- [ ] Implement threat scheduling
- [ ] Refactor `end_turn()` into phases

### Week 2

- [ ] Implement Barracks
- [ ] Implement Workforce Housing
- [ ] Add upkeep economy
- [ ] Add one expedition or dungeon action
- [ ] Add HUD threat forecast

## Notes

- Keep the campaign loop aligned with the intended design: management first, combat as consequence or planned risk.
- Prefer data-driven building and item rules before adding large amounts of content.
- Avoid adding more one-off logic to `GameState.gd` unless it is clearly temporary.
