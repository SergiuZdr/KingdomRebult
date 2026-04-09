# KingdomRebuild — Game Development Log

## Project Overview
A 2D turn-based strategy game built in Godot 4. The player controls a prince sent to rebuild a monster-destroyed city and defend the kingdom. The game has two major phases: **City Management** and **Combat** (Fear & Hunger style UI).

---

## Tech Stack
- **Engine:** Godot 4.x
- **Language:** GDScript
- **Renderer:** Compatibility (2D)
- **Resolution:** 1280x720

---

## Project Structure
```
res://
├── scenes/
│   ├── management/
│   │   ├── city_view.tscn        ← Main city scene
│   │   ├── building.tscn         ← Reusable building node
│   │   └── soldier_menu.tscn     ← Soldier management screen
│   └── ui/
│       └── recap_screen.tscn     ← End of turn recap panel
├── scripts/
│   ├── autoload/
│   │   ├── GameState.gd          ← Global state (Autoload)
│   │   └── BuildingPopup.gd      ← Global popup (Autoload)
│   ├── management/
│   │   ├── city_view.gd
│   │   ├── building.gd
│   │   └── soldier_menu.gd
│   ├── resources_data/
│   │   └── SoldierData.gd        ← Soldier Resource class
│   └── ui/
│       └── recap_screen.gd
├── assets/
│   ├── sprites/
│   ├── ui/
│   └── audio/
└── data/
    ├── soldiers/
    ├── buildings/
    └── items/
```

---

## Autoloads (Project Settings → Autoload)
| Name | Path |
|---|---|
| `GameState` | `scripts/autoload/GameState.gd` |
| `BuildingPopup` | `scripts/autoload/BuildingPopup.gd` |

---

## GameState.gd — Full Reference

### Resources
```gdscript
var gold: int = 500
var wood: int = 0
var stone: int = 0
var iron: int = 0
var steel: int = 0
var food: int = 0
var morale: int = 100
var workforce_total: int = 10
var workforce_available: int = 10
```

### UI State
```gdscript
var menu_open: bool = false
var in_city_view: bool = true
```

### Soldiers
```gdscript
var soldiers: Array[SoldierData] = []
var max_soldiers: int = 5
```

### Buildings & Production
```gdscript
var building_workers: Dictionary = {
    "Forest": 0,        # → Wood: 10/worker/turn
    "Quarry": 0,        # → Stone: 8/worker/turn
    "Iron Mine": 0,     # → Iron: 6/worker/turn
    "Farm": 0,          # → Food: 12/worker/turn
    "Steel Forge": 0,   # → Steel: 4/worker/turn
    "Market": 0,        # → Gold: 25/worker/turn
    "Butchery": 0,      # → Food: -5, Gold: +15/worker/turn
    "Weapon Forge": 0,  # → Gold: -10, Steel: -2/worker/turn
    "Tavern": 0,        # → Reduces recruit cost, improves stat rolls
    "Training Ground": 0, # → XP: 10/trainer/turn to all soldiers
    "Barracks": 0,      # → TBD
}
```

### Signals
```gdscript
signal resources_changed
signal turn_ended(turn_number: int)
signal soldiers_changed
signal recap_ready
```

### Key Functions
```gdscript
GameState.end_turn()                          # Processes production, training, increments turn
GameState.assign_worker(building, amount)     # Assigns/removes workers from building
GameState.recruit_soldier(name, innkeeper_bonus) # Recruits soldier from Tavern (costs 100 gold base)
```

---

## Buildings Reference

### Resource Obtaining
| Building | Workers produce | Notes |
|---|---|---|
| Forest | +10 Wood/turn | — |
| Quarry | +8 Stone/turn | — |
| Iron Mine | +6 Iron/turn | — |
| Farm | +12 Food/turn | — |

### Resource Processing
| Building | Workers produce | Notes |
|---|---|---|
| Steel Forge | +4 Steel/turn | — |
| Market | +25 Gold/turn | — |
| Butchery | -5 Food, +15 Gold/turn | Consumes food |
| Weapon Forge | -10 Gold, -2 Steel/turn | Consumes resources |

### Special Buildings
| Building | Effect | Notes |
|---|---|---|
| Tavern | Reduces recruit cost by 10/worker. Improves stat roll range by +5/worker | Does NOT produce gold |
| Training Ground | +10 XP/trainer/turn to all living soldiers | Triggers level up at 100 XP |
| Barracks | TBD | — |
| Dungeon | TBD — expeditions | — |

---

## SoldierData.gd — Resource Class

```gdscript
class_name SoldierData
extends Resource
```

### Stats
| Stat | Base range | Level up gain |
|---|---|---|
| HP | 80–120 | +8 to +15 |
| Power | 8–14 | +1 to +3 |
| Speed | 4–8 | +1 to +2 |
| Dexterity | 4–8 | +1 to +2 |

### Limb System (Fear & Hunger style)
```gdscript
var hp_head: int = 30       # head_disabled = true → soldier dies
var hp_left_arm: int = 25
var hp_right_arm: int = 25
var hp_legs: int = 40
```

### XP & Leveling
- Base XP to level up: `100`
- Each level increases threshold by `+50`
- Formula: `xp_to_next_level = 100 + (level - 1) * 50`

### Key Methods
```gdscript
soldier.add_xp(amount)       # Returns true if leveled up
soldier.is_alive()           # false if hp=0 OR head disabled
soldier.get_display_name()   # "Name (Lv.X)"
```

---

## Tavern — Recruit System
- Base cost: **100 Gold**
- Each innkeeper assigned: **-10 Gold** cost, **+5** to all stat roll ranges
- Minimum cost: **50 Gold**
- Max soldiers: **5**

---

## End Turn Flow
```
end_turn()
  ├── turn_recap.clear()
  ├── _process_production()   → adds resource lines to recap
  ├── _process_training()     → adds XP lines to recap, triggers level up
  ├── current_turn += 1
  ├── emit recap_ready        → RecapScreen shows automatically
  ├── emit turn_ended
  └── emit resources_changed  → HUD updates
```

---

## City View — Controls
- **Arrow keys:** Move camera left/right
- **Click building:** Opens BuildingPopup
- **End Turn button:** Triggers end_turn(), shows recap
- **Soldiers button:** Opens SoldierMenu

---

## UI State Rules
- `GameState.menu_open = true` → buildings are not clickable
- Set to `true` when: SoldierMenu opens, RecapScreen shows
- Set to `false` when: SoldierMenu closes, RecapScreen Continue pressed

---

## Next Steps (TODO)
- [ ] Combat scene — Fear & Hunger style (turn-based, 5v5, fixed arena, limb targeting)
- [ ] Random events system at End Turn
- [ ] Barracks functionality
- [ ] Dungeon expeditions
- [ ] Equipment system (weapons, armor)
- [ ] Soldier skills (passive + active)
- [ ] Soldier traits system
- [ ] Main menu scene
- [ ] Game over / victory conditions
- [ ] Art & sprites
- [ ] Audio
