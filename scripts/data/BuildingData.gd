class_name BuildingData
extends Resource

enum BuildingCategory {
	RESOURCE_OBTAINING,
	RESOURCE_PROCESSING,
	MILITARY,
	SPECIAL,
	CONSTRUCTION,
	INTERMEDIARY,
}

@export var building_id: String = ""
@export var building_name: String = ""
@export_multiline var description: String = ""
@export var category: BuildingCategory = BuildingCategory.RESOURCE_OBTAINING

@export var cost_gold: int = 0
@export var cost_wood: int = 0
@export var cost_stone: int = 0
@export var build_time: int = 0
@export var workforce_required: int = 0
@export var max_level: int = 1
@export var starts_built: bool = false
@export var increases_population: int = 0
@export var consumes_food: int = 0

# Flat (legacy / fallback) production fields
@export var produces_gold: int = 0
@export var produces_wood: int = 0
@export var produces_stone: int = 0
@export var produces_iron: int = 0
@export var produces_steel: int = 0
@export var produces_food: int = 0
@export var produces_morale: int = 0

@export var training_xp_per_worker: int = 0
@export var recruit_base_cost: int = 100
@export var recruit_min_cost: int = 50
@export var recruit_cost_reduction_per_worker: int = 10
@export var recruit_stat_bonus_per_worker: int = 5
@export var soldier_capacity_bonus: int = 0

# --- Per-level production (index = level-1) ---
## food produced per worker at each level
@export var food_by_level: PackedInt32Array = []
## gold produced per worker at each level
@export var gold_by_level: PackedInt32Array = []
## wood produced per worker at each level
@export var wood_by_level: PackedInt32Array = []
## stone produced per worker at each level
@export var stone_by_level: PackedInt32Array = []
## iron produced per worker at each level (negative = consumed)
@export var iron_by_level: PackedInt32Array = []
## steel produced per worker at each level (negative = consumed)
@export var steel_by_level: PackedInt32Array = []
## flat morale added per turn (NOT per worker) at each level
@export var morale_flat_by_level: PackedInt32Array = []

# --- Upgrade costs (index 0 = L1→L2 cost, index 1 = L2→L3 cost) ---
@export var upgrade_cost_gold: PackedInt32Array = []
@export var upgrade_cost_wood: PackedInt32Array = []
@export var upgrade_cost_stone: PackedInt32Array = []
@export var upgrade_cost_iron: PackedInt32Array = []
@export var upgrade_cost_steel: PackedInt32Array = []

# --- Barracks regen ---
## Flat HP regen per idle soldier per turn at each level
@export var idle_hp_regen_by_level: PackedInt32Array = []
## Percent of max HP regen per idle soldier per turn at each level (used if > 0)
@export var idle_hp_regen_pct_by_level: PackedFloat32Array = []

# --- Training Grounds ---
## Base XP per trainer per turn at each level
@export var base_xp_by_level: PackedInt32Array = []

# --- Farm / Butchery bonus proc ---
## Chance (0.0–1.0) for a bonus harvest/batch proc
@export var harvest_bonus_chance: float = 0.0
## Multiplier for harvest bonus (Farm: 1.5 = ×1.5 food; Butchery: 0.0 = flat +5 gold handled in code)
@export var harvest_bonus_multiplier: float = 1.0

# --- Iron Mine bonus find ---
## Per-level chance to find bonus resources (index = level-1)
@export var bonus_find_chance_by_level: PackedFloat32Array = []

# --- Weapon Forge crafting tier (handled in GameState, not here) ---
@export var crafting_tier: int = 0

## Human-readable notes for what changes at each upgrade step.
## Index 0 = notes for L1→L2 upgrade, index 1 = notes for L2→L3 upgrade.
@export var upgrade_notes: PackedStringArray = []

# --- House/Barracks soldier capacity per level ---
@export var soldier_capacity_by_level: PackedInt32Array = []


func get_stat_at_level(array: PackedInt32Array, level: int, fallback: int) -> int:
	var idx := level - 1
	if idx >= 0 and idx < array.size():
		return array[idx]
	return fallback


static func get_texture_path(b_name: String) -> String:
	const PATHS: Dictionary = {
		"Tavern":           "res://assets/buildings/tavern_l1.png",
		"Market":           "res://assets/buildings/market.png",
		"House":            "res://assets/buildings/house.png",
		"Barracks":         "res://assets/buildings/barracks.png",
		"Training Grounds": "res://assets/buildings/training_grounds.png",
		"Blacksmith":     "res://assets/buildings/blacksmith.png",
		"Steel Forge":      "res://assets/buildings/steel_forge.png",
		"Butchery":         "res://assets/buildings/butchery.png",
		"Farm":             "res://assets/buildings/farm.png",
		"Forest":           "res://assets/buildings/forest.png",
		"Iron Mine":        "res://assets/buildings/iron_mine.png",
		"Quarry":           "res://assets/buildings/quarry.png",
	}
	var path: String = PATHS.get(b_name, "")
	if path != "" and not ResourceLoader.exists(path):
		const FALLBACK: Dictionary = {
			"Barracks":         "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/Stable or Storage.png",
			"Training Grounds": "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/Stable or Storage.png",
			"Blacksmith":     "res://Downloaded Game Assets/Constructions/Generic Exterior/Pixel Art Furnace and Sawmill.png",
			"Steel Forge":      "res://Downloaded Game Assets/Constructions/Generic Exterior/Pixel Art Furnace and Sawmill.png",
			"Butchery":         "res://Downloaded Game Assets/Constructions/Generic Exterior/Cooking area.png",
			"Farm":             "res://Downloaded Game Assets/Decor&WorldItems/Farming Tiles and Crops/GandalfHardcore Farming Tiles and Crops 32x32.png",
			"Forest":           "res://assets/buildings/forest.png",
			"Iron Mine":        "res://Downloaded Game Assets/Decor&WorldItems/Generic Decor/Ores.png",
			"Quarry":           "res://Downloaded Game Assets/Decor&WorldItems/Generic Decor/Ores.png",
		}
		return FALLBACK.get(b_name, "")
	return path


func get_float_stat_at_level(array: PackedFloat32Array, level: int, fallback: float) -> float:
	var idx := level - 1
	if idx >= 0 and idx < array.size():
		return array[idx]
	return fallback


func get_production_per_worker() -> Dictionary:
	return get_production_per_worker_at_level(1)


func get_production_per_worker_at_level(level: int) -> Dictionary:
	var production := {}

	var w := get_stat_at_level(wood_by_level, level, produces_wood)
	var s := get_stat_at_level(stone_by_level, level, produces_stone)
	var ir := get_stat_at_level(iron_by_level, level, produces_iron)
	var st := get_stat_at_level(steel_by_level, level, produces_steel)
	var f := get_stat_at_level(food_by_level, level, produces_food)
	var g := get_stat_at_level(gold_by_level, level, produces_gold)

	if w != 0: production["Wood"] = w
	if s != 0: production["Stone"] = s
	if ir != 0: production["Iron"] = ir
	if st != 0: production["Steel"] = st
	if f != 0: production["Food"] = f
	if g != 0: production["Gold"] = g

	return production


func get_production_for_workers(workers: int, level: int = 1) -> Dictionary:
	var totals := {}
	var production := get_production_per_worker_at_level(level)
	for resource in production:
		totals[resource] = production[resource] * workers
	return totals
