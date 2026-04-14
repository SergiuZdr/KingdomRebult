# KingdomRebuild Roadmap

## Goal

Move the project from a prototype loop into a real campaign strategy game built around:

- city management
- scheduled and optional battles
- stronger building identity
- soldier progression with persistence
- clearer pressure from economy, morale, and defense

The target for the next major milestone is:

`Version 0.2 - Real Campaign Loop`

## Current State

The repository already has a functional prototype with:

- city management scene
- worker assignment
- recruitment through the tavern
- equipment purchasing
- automatic combat waves
- end-turn recap

What is still missing is a stable rules layer and a campaign structure that matches the intended design.

The biggest gaps are:

- building logic is still mostly hardcoded
- building data files exist but are not properly wired into runtime logic
- combat is forced on a simple fixed timer
- soldier progression exists, but does not yet drive the wider campaign
- economy, buildings, combat, and rewards are not fully connected

## Product Direction

The game should be built around two major phases:

1. Management time
2. Combat resolution

Management time should include:

- scheduled battles and future threat visibility
- optional battles such as expeditions or dungeon runs
- random or authored events
- resource and workforce management
- building management
- soldier management
- recap at the end of the turn

Combat should support:

- turn-based battles
- fixed arena presentation
- up to 5v5 units
- meaningful action choice
- long-term consequences that feed back into city management

## Milestones

### M1: Stabilize the Rules Layer

Objective:
Make buildings, progression rules, and turn flow data-driven and consistent.

Deliverables:

- add a working `BuildingData` resource script
- connect existing `.tres` building assets to runtime logic
- normalize all building IDs and names across scenes and code
- move building definitions out of hardcoded dictionaries where possible
- separate static definitions from mutable runtime state

Success criteria:

- buildings can be tuned from resource files instead of code edits
- tavern, training, barracks, and other special buildings follow one canonical definition
- `GameState` becomes orchestration rather than the source of all rules

### M2: Build the Real Management Loop

Objective:
Replace the fixed combat timer with a proper campaign turn structure.

Deliverables:

- threat scheduling instead of forced combat every two turns
- visible future battle forecast
- end-turn phases for upkeep, production, events, threat checks, optional action, combat, and recap
- one optional expedition or dungeon activity
- first-pass implementation of barracks and workforce housing

Success criteria:

- the player can see incoming threats before committing the turn
- management choices feel strategic instead of automatic
- the turn recap reflects separate campaign phases

### M3: Expand Progression and City Pressure

Objective:
Make economy and soldiers matter over multiple turns.

Deliverables:

- food upkeep for workers and soldiers
- morale changes based on shortages, losses, and building effects
- soldier traits
- persistent injuries and recovery
- recruitment archetypes or class identity
- equipment progression tied to production buildings

Success criteria:

- soldiers feel distinct
- losses carry forward into later turns
- economy and morale create real pressure

### M4: Deepen Combat and Content

Objective:
Make combat tactically interesting and better connected to campaign outcomes.

Deliverables:

- limb targeting and limb consequences
- enemy roles and formations
- manual combat for important fights
- auto-resolve for trivial fights
- post-battle outcomes such as loot, injuries, morale swings, and pressure on the city

Success criteria:

- battle tactics matter
- different enemy waves feel different
- combat outcome meaningfully changes the next management turn

### M5: UX Polish and Balancing

Objective:
Improve clarity, pacing, and early-game readability.

Deliverables:

- stronger city HUD
- clearer building popup decisions
- better recap formatting
- turn forecast panel
- balancing pass for the first 10 turns

Success criteria:

- players can understand the kingdom state quickly
- choices are legible without digging through menus
- the first 10 turns are challenging but fair

## Recommended Next Milestone

The best immediate target is `Version 0.2 - Real Campaign Loop`.

This version should include:

- data-driven building logic
- scheduled wave previews
- optional expedition or dungeon action
- barracks and workforce housing
- tavern focused on recruitment and recruit quality
- expanded recap with economy, training, threats, and combat consequences

This milestone gives the project a real campaign structure before investing heavily in more content.

## Building Design Direction

The current design direction should treat buildings as gameplay roles, not just production numbers.

Suggested structure:

- Construction: wood, stone
- Military: leather, steel, magic crystals
- Intermediary: iron ore, animals
- Resource obtaining: forest, quarry, mine, farm
- Resource processing: steel forge, market, butchery, weapon forge
- Other: dungeon, training grounds, workforce housing, tavern

Each building should do at least one of the following:

- unlock a new strategic option
- alter a campaign pressure value
- create a meaningful tradeoff
- influence combat readiness

## Technical Priorities

Highest-priority technical debt:

- missing `BuildingData.gd`
- hardcoded building behavior in `GameState.gd`
- design mismatch between code and intended tavern/combat rules
- weak connection between economy, equipment, and combat rewards

## Suggested Two-Week Build Order

### Week 1

- create `BuildingData` and connect `.tres` files
- normalize naming and building definitions
- replace the forced combat timer with threat scheduling
- split end-turn into explicit phases

### Week 2

- implement barracks and workforce housing
- add upkeep economy
- add one optional expedition or dungeon action
- add a turn forecast panel to the HUD

## Long-Term Outcome

If these milestones are completed in order, the game should evolve from a prototype with combat attached into a strategy RPG campaign where:

- city growth drives military strength
- soldier losses matter
- battles are anticipated, not random interruptions
- buildings shape the way the player approaches survival and expansion
