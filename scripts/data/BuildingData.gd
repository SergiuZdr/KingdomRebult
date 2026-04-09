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
@export var increases_population: int = 0
@export var consumes_food: int = 0

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

func get_production_per_worker() -> Dictionary:
	var production := {}

	if produces_wood != 0:
		production["Wood"] = produces_wood
	if produces_stone != 0:
		production["Stone"] = produces_stone
	if produces_iron != 0:
		production["Iron"] = produces_iron
	if produces_steel != 0:
		production["Steel"] = produces_steel
	if produces_food != 0:
		production["Food"] = produces_food
	if produces_gold != 0:
		production["Gold"] = produces_gold
	if produces_morale != 0:
		production["Morale"] = produces_morale

	return production

func get_production_for_workers(workers: int) -> Dictionary:
	var totals := {}
	var production := get_production_per_worker()
	for resource in production:
		totals[resource] = production[resource] * workers
	return totals

func is_recruitment_building() -> bool:
	return recruit_cost_reduction_per_worker > 0 or recruit_stat_bonus_per_worker > 0

func is_training_building() -> bool:
	return training_xp_per_worker > 0
