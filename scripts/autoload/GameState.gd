# GameState.gd
extends Node

# --- CONSTANTS ---
const SOLDIER_FOOD_UPKEEP: int = 2
const HOUSE_RECRUIT_GOLD_COST: int = 25
const HOUSE_RECRUIT_FOOD_COST: int = 8
const BASE_WORKFORCE_CAP: int = 10

# Tavern recruit quality. Each innkeeper committed last turn grants a GUARANTEED
# stat floor to new recruits (plus a tiny 0-2 random spread per stat); tavern
# level adds a smaller guaranteed boost. A fully-staffed tavern (3 innkeepers)
# yields roughly +6-8 to each combat stat and ~+18 HP over an unstaffed one.
const INNKEEPER_COMBAT_BONUS: int = 2      # +power/+speed/+dexterity per innkeeper
const INNKEEPER_HP_BONUS: int = 6          # +HP per innkeeper
const TAVERN_LEVEL_COMBAT_BONUS: int = 2   # +combat stats per tavern level above 1
const TAVERN_LEVEL_HP_BONUS: int = 5       # +HP per tavern level above 1
const RECRUIT_STAT_SPREAD: int = 2         # extra rand(0..N) per stat for variety

# --- RESOURCES ---
var gold: int = 500
var wood: int = 0
var stone: int = 0
var iron: int = 0
var steel: int = 0
var food: int = 0
var workforce_total: int = 10
var workforce_available: int = 10
var workforce_cap: int = BASE_WORKFORCE_CAP

# --- SOLDIERS ---
var soldiers: Array[SoldierData] = []
var max_soldiers: int = 4

# --- UI STATE ---
var menu_open: bool = false
var in_city_view: bool = true

# --- ONBOARDING (per-save; set true once the intro/tutorial has played) ---
var intro_seen: bool = false
var tutorial_seen: bool = false

# --- RECAP ---
var turn_recap: Array[String] = []

# --- INVENTORY ---
var available_items: Array[ItemData] = []
var owned_items: Array[ItemData] = []
var building_definitions: Dictionary = {}
var building_workers: Dictionary = {}
var building_levels: Dictionary = {}  # building_name -> int (0=destroyed, 1-3=built levels)
var house_recruits_this_turn: int = 0

# --- WEAPON FORGE CRAFTING QUEUE ---
# Each entry: {item_name: String, quality: int, turns_remaining: int, result_item: ItemData}
var weapon_forge_queue: Array[Dictionary] = []

# --- TRAINING GROUNDS TRAINERS ---
var training_soldiers: Array[SoldierData] = []

# --- BARRACKS CITY DEFENSE BONUS ---
var barracks_city_defense_bonus: float = 0.0

# --- PROGRESS ---
var current_turn: int = 0
var combat_difficulty: int = 1
var total_waves_won: int = 0
## Threat meter: fills each turn, triggers a wave when it reaches threat_max.
var threat: int = 0
var threat_max: int = 100
var pending_enemy_wave: Array[EnemyData] = []
var pending_battle_source: String = "Scheduled Wave"
var pale_court_gift_death_pending: bool = false
var legion_garrison_active: bool = false
var legion_solo_fight_pending: bool = false
var next_wave_difficulty_bonus: int = 0
var last_turn_resource_deltas: Dictionary = {}
## A wave attacked while the dungeon expedition was active and the city has at
## least one defender. Resolution is deferred until the player exits the
## dungeon, where they choose to Watch (live spectator combat) or Auto-Resolve.
## {wave: Array[EnemyData], wave_names: Array[String], wave_source: String, defenders: Array[SoldierData]}
var _pending_city_defense_battle: Dictionary = {}
var pending_deserter_return: Array = []   # [{soldier: SoldierData, turns_remaining: int}]
var last_scout_combat_result: Dictionary = {}
var pending_iron_mine_worker_restore: bool = false

# --- WIN / LOSS STATE ---
var city_walls: int = 1           # Starts at 1. Losing a wave costs 1 wall. 0 = game over.
var max_city_walls: int = 4
var damaged_buildings: Dictionary = {}  # building_name -> repair_cost (int Gold)
var win_condition_triggered: bool = false
var _win_letter_turn: int = -1   # turn on which kings_return letter fires; -1 = not scheduled

## Set when the wave that is about to be fought is the final boss wave (win
## conditions already met and this wave's difficulty is a multiple of 5).
## Consumed by the resolution path (normal combat / auto-resolve / spectator)
## that determines whether that wave was actually WON.
var final_battle_pending: bool = false
## Set permanently once the final boss wave has been won. Survives even if the
## hub UI is rebuilt, so _ready() can show the victory screen if it was missed.
var game_won_achieved: bool = false

## Called immediately when the Pale Court vial is accepted. 99% chance of death.
func _trigger_veil_death() -> void:
	if randf() < 0.99:
		# Permadeath: delete the save the instant this loss state is entered
		# (and block any later autosave) — before prince_death_overlay shows.
		SaveManager.delete_save_on_game_over()
		emit_signal("prince_consumed_by_veil")

func apply_army_morale(delta: int) -> void:
	for s in soldiers:
		if s.is_alive():
			s.morale = clampi(s.morale + delta, 0, s.get_max_morale())

## Called by CombatState after a player defeat. Damages walls, drains resources,
## damages a random non-military building, and escalates threat.
func apply_wave_loss_consequences() -> void:
	city_walls -= 1
	SFX.play("wall_lost")
	# Resource losses
	gold  = int(gold  * 0.25)   # lose 75%
	food  = int(food  * 0.5)
	wood  = int(wood  * 0.5)
	stone = int(stone * 0.5)
	iron  = int(iron  * 0.5)
	# Building damage — pick 1 random non-military built building not already damaged
	var candidates: Array[String] = []
	var military := ["Barracks", "Training Grounds", "Tavern"]
	for b in building_levels.keys():
		if building_levels[b] >= 1 and b not in military and b not in damaged_buildings:
			candidates.append(b)
	if not candidates.is_empty():
		var target: String = candidates[randi() % candidates.size()]
		damaged_buildings[target] = 30   # costs 30 Gold to repair
	# Threat acceleration
	threat = mini(threat + 20, threat_max + 20)   # can spike above threshold
	threat_gain_rate = mini(threat_gain_rate + 5, 60)
	# Morale hit for all soldiers
	apply_army_morale(-20)
	emit_signal("resources_changed")
	emit_signal("soldiers_changed")
	if city_walls <= 0:
		emit_signal("city_fallen")

# --- Win condition targets (single source of truth for the objectives UI and codex) ---
const WIN_WAVES_REQUIRED: int = 10
const WIN_DUNGEON_LEVEL_REQUIRED: int = 3
const WIN_BUILDING_TARGETS: Dictionary = {
	"Farm": 2, "Forest": 2, "Quarry": 2, "Iron Mine": 2, "Market": 2,
	"Barracks": 1, "Steel Forge": 1, "Blacksmith": 1,
}

## Returns the player's progress toward victory as ordered rows.
## Each row: { label: String, current: int, target: int, done: bool }.
## Both check_win_condition() and the Objectives panel/codex read from this so they never drift.
func get_objectives_progress() -> Array:
	var rows: Array = []
	rows.append({
		"label": "Survive enemy waves",
		"current": mini(total_waves_won, WIN_WAVES_REQUIRED),
		"target": WIN_WAVES_REQUIRED,
		"done": total_waves_won >= WIN_WAVES_REQUIRED,
	})
	rows.append({
		"label": "Descend into the dungeon",
		"current": mini(DungeonState.dungeon_level, WIN_DUNGEON_LEVEL_REQUIRED),
		"target": WIN_DUNGEON_LEVEL_REQUIRED,
		"done": DungeonState.dungeon_level >= WIN_DUNGEON_LEVEL_REQUIRED,
	})
	for b in WIN_BUILDING_TARGETS.keys():
		var target: int = WIN_BUILDING_TARGETS[b]
		var lvl: int = get_building_level(b)
		rows.append({
			"label": "%s, Level %d" % [b, target],
			"current": mini(lvl, target),
			"target": target,
			"done": lvl >= target,
		})
	return rows

## Returns true when all win conditions are satisfied and the game has not already been won.
func check_win_condition() -> bool:
	if win_condition_triggered:
		return false
	for row in get_objectives_progress():
		if not row["done"]:
			return false
	return true

## Returns the faction ending key based on current standing, or "" for a neutral ending.
func get_win_ending() -> String:
	var best_faction := ""
	var best_standing := 75   # Allied threshold
	if FactionState.iron_legion_standing > best_standing:
		best_standing = FactionState.iron_legion_standing
		best_faction = "iron_legion"
	if FactionState.wardens_standing > best_standing:
		best_standing = FactionState.wardens_standing
		best_faction = "wardens"
	if FactionState.pale_court_standing > best_standing:
		best_standing = FactionState.pale_court_standing
		best_faction = "pale_court"
	return best_faction

## Adds wall charges up to max_city_walls and notifies listeners.
func reinforce_walls(amount: int = 1) -> void:
	city_walls = mini(city_walls + amount, max_city_walls)
	emit_signal("resources_changed")

## Spends 30 Gold to remove a building from the damaged list. Returns false if insufficient gold or building is not damaged.
func repair_building_damage(building_name: String) -> bool:
	if not damaged_buildings.has(building_name):
		return false
	var cost: int = damaged_buildings[building_name]
	if gold < cost:
		return false
	gold -= cost
	damaged_buildings.erase(building_name)
	emit_signal("resources_changed")
	return true

func _ready() -> void:
	_load_building_definitions()
	_populate_shop()
	_schedule_next_battle(true)
	refresh_tavern_roster()
	# Normal (non-dungeon, non-spectator) combat resolution — used to detect
	# whether a final boss wave was actually won. See _arm_final_battle_check()
	# / _consume_final_battle_result().
	CombatState.combat_ended.connect(_consume_final_battle_result)

func _load_building_definitions() -> void:
	building_definitions.clear()
	var existing_workers = building_workers.duplicate()
	building_workers.clear()

	var dir = DirAccess.open("res://data/buildings")
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path = "res://data/buildings/%s" % file_name
			var data = load(path)
			if data is BuildingData and data.building_name != "":
				building_definitions[data.building_name] = data
		file_name = dir.get_next()
	dir.list_dir_end()

	for b_name in building_definitions.keys():
		# Training Grounds uses dedicated trainer slots — no worker assignment
		if b_name == "Training Grounds":
			continue
		building_workers[b_name] = existing_workers.get(b_name, 0)
		if not building_levels.has(b_name):
			var data: BuildingData = building_definitions[b_name]
			building_levels[b_name] = 1 if data.starts_built else 0

	# Training Grounds still needs a level entry even though it has no workers entry
	if building_definitions.has("Training Grounds") and not building_levels.has("Training Grounds"):
		var tg_data: BuildingData = building_definitions["Training Grounds"]
		building_levels["Training Grounds"] = 1 if tg_data.starts_built else 0

# --- BACKWARD COMPAT PROPERTY ---
var building_built_status: Dictionary:
	get:
		var result := {}
		for b in building_levels:
			result[b] = building_levels[b] >= 1
		return result

func _populate_shop() -> void:
	refresh_market_stock()

func refresh_market_stock() -> void:
	var level := get_building_level("Market")
	if level <= 0:
		available_items = []
		return

	# Build full catalog
	var pool: Array[ItemData] = []
	for d in ItemData.get_all_craftable_weapons():
		pool.append(ItemData.make_from_dict(d))
	for d in ItemData.get_all_craftable_armors():
		pool.append(ItemData.make_from_dict(d))
	pool.shuffle()

	# L1: 5 items, Common only, prices ×1.30
	# L2: 8 items, Common/Uncommon, normal prices
	# L3: 10 items, Uncommon/Rare, normal prices, guaranteed 1 Rare
	var counts: Array[int] = [5, 8, 10]
	var count: int = counts[clamp(level - 1, 0, 2)]
	available_items = []

	for i in min(count, pool.size()):
		var item := pool[i]
		var q := 0
		match level:
			1:
				q = 0
				item.gold_cost = roundi(item.gold_cost * 1.30)
			2:
				q = randi_range(0, 1)
			3:
				q = 1 if i > 0 else 2  # first slot is Rare, rest Uncommon
		ItemData.apply_quality(item, q)
		available_items.append(item)

func get_market_item_cost(item_template: ItemData) -> int:
	var discount := FactionState.iron_legion_trade_discount
	return ceili(item_template.gold_cost * (1.0 - discount))

func buy_market_item(item_template: ItemData) -> bool:
	var final_cost := get_market_item_cost(item_template)
	if gold < final_cost:
		SFX.play("denied")
		return false

	var item_copy = item_template.duplicate(true)
	owned_items.append(item_copy)
	gold -= final_cost
	emit_signal("resources_changed")
	emit_signal("soldiers_changed")
	SFX.play("coin")
	return true

func get_owned_items_for_slot(slot: String) -> Array[ItemData]:
	var valid_items: Array[ItemData] = []
	for item in owned_items:
		match slot:
			"armor":
				if item.item_type == ItemData.ItemType.ARMOR:
					valid_items.append(item)
			"weapon_1":
				# weapon_1 accepts one-hand weapons only (shields go in weapon_2)
				if item.item_type == ItemData.ItemType.WEAPON:
					valid_items.append(item)
			"weapon_2":
				# weapon_2 accepts one-hand weapons and shields (not two-handers)
				if item.item_type == ItemData.ItemType.SHIELD:
					valid_items.append(item)
				elif item.item_type == ItemData.ItemType.WEAPON and item.hand_type == ItemData.HandType.ONE_HAND:
					valid_items.append(item)
	return valid_items

func unequip_item(soldier: SoldierData, slot: String) -> bool:
	var item: ItemData = null
	match slot:
		"weapon_1":
			item = soldier.weapon_1
			soldier.weapon_1 = null
		"weapon_2":
			item = soldier.weapon_2
			soldier.weapon_2 = null
		"armor":
			item = soldier.armor
			soldier.armor = null
		_:
			return false

	if item == null:
		return false

	owned_items.append(item)
	emit_signal("soldiers_changed")
	return true

func get_market_lock_reason(_item_template: ItemData) -> String:
	# Market items are independent — availability is controlled by market level and
	# the item rotation system. No forge or worker dependencies.
	return ""

# ---------------------------------------------------------------------------
# WEAPON FORGE — crafting queue
# ---------------------------------------------------------------------------

## Quality names for display
const QUALITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare"]
## Base turns to craft by quality tier
const CRAFT_BASE_TURNS: Array[int] = [1, 2, 3]
## Stat multipliers by quality: 0=1.0x, 1=1.15x, 2=1.35x
const QUALITY_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.35]

func start_crafting(item_name: String, quality: int) -> Dictionary:
	quality = clampi(quality, 0, 2)
	if not is_building_built("Blacksmith"):
		return {ok = false, reason = "Weapon Forge is not built."}

	var forge_level := get_building_level("Blacksmith")
	var forge_workers: int = building_workers.get("Blacksmith", 0)
	if forge_workers <= 0:
		return {ok = false, reason = "Assign at least 1 worker to the Weapon Forge."}

	# Quality tier check per forge level
	if quality >= 2 and forge_level < 2:
		return {ok = false, reason = "Rare items require Weapon Forge L2."}

	# Find the matching craftable item template
	var template: ItemData = _find_craftable_template(item_name)
	if template == null:
		return {ok = false, reason = "Item '%s' is not available for crafting." % item_name}

	if template.craft_available_at_forge_level > forge_level:
		return {ok = false, reason = "This item requires Weapon Forge L%d." % template.craft_available_at_forge_level}

	# Check and deduct resources
	for resource in template.craft_resource_cost:
		var needed: int = template.craft_resource_cost[resource]
		var have := _get_resource_value(resource)
		if have < needed:
			return {ok = false, reason = "Need %d %s (have %d)." % [needed, resource, have]}

	for resource in template.craft_resource_cost:
		var needed: int = template.craft_resource_cost[resource]
		_apply_resource_delta(resource, -needed)

	# Calculate turns with worker reduction (each worker beyond first reduces by 1, min 1)
	var base_turns: int = CRAFT_BASE_TURNS[quality]
	var turns: int = maxi(1, base_turns - (forge_workers - 1))

	# Build result item (clone template and apply quality stats)
	var result_item := template.duplicate(true) as ItemData
	result_item.quality = quality
	result_item = _apply_quality_to_item(result_item, quality)

	weapon_forge_queue.append({
		item_name = item_name,
		quality = quality,
		turns_remaining = turns,
		result_item = result_item,
	})

	emit_signal("resources_changed")
	return {ok = true, reason = ""}

func sell_item(item: ItemData) -> bool:
	if not owned_items.has(item):
		return false
	var sell_price := ceili(item.gold_cost * 0.5)
	owned_items.erase(item)
	gold += sell_price
	emit_signal("resources_changed")
	emit_signal("soldiers_changed")
	return true

func _find_craftable_template(item_name: String) -> ItemData:
	# Search the full catalogs so crafting works independently of market stock
	for d in ItemData.get_all_craftable_weapons():
		if d.get("name", "") == item_name:
			return ItemData.make_from_dict(d)
	for d in ItemData.get_all_craftable_armors():
		if d.get("name", "") == item_name:
			return ItemData.make_from_dict(d)
	for d in ItemData.get_all_craftable_shields():
		if d.get("name", "") == item_name:
			return ItemData.make_from_dict(d)
	return null

func _apply_quality_to_item(item: ItemData, quality: int) -> ItemData:
	if quality <= 0:
		return item
	var mult := QUALITY_MULTIPLIERS[clampi(quality, 0, 2)]
	# Apply multiplier to all numeric combat stats; round to nearest int
	item.damage_min  = roundi(float(item.damage_min)  * mult)
	item.damage_max  = roundi(float(item.damage_max)  * mult)
	item.defense     = roundi(float(item.defense)     * mult)
	item.hp_bonus    = roundi(float(item.hp_bonus)    * mult)
	item.speed_bonus = roundi(float(item.speed_bonus) * mult)
	item.dexterity_bonus = roundi(float(item.dexterity_bonus) * mult)
	# Fractional stat: keep float precision
	item.hit_chance_bonus = item.hit_chance_bonus * mult
	item.dodge_bonus      = item.dodge_bonus      * mult
	return item

# ---------------------------------------------------------------------------
# TRAINING GROUNDS — trainer soldier management
# ---------------------------------------------------------------------------

func get_training_slots() -> int:
	if not is_building_built("Training Grounds"):
		return 0
	var slots_by_level := [1, 2, 3]
	return slots_by_level[clampi(get_building_level("Training Grounds") - 1, 0, 2)]

func can_assign_trainer(soldier: SoldierData) -> bool:
	if not is_building_built("Training Grounds"):
		return false
	if training_soldiers.has(soldier):
		return false
	if training_soldiers.size() >= get_training_slots():
		return false
	if not soldier.is_alive():
		return false
	# Reject soldiers currently in dungeon expedition
	if DungeonState.soldiers_in_dungeon.has(soldier):
		return false
	if DungeonState.pending_soldiers.has(soldier):
		return false
	return true

func assign_trainer(soldier: SoldierData) -> bool:
	if not can_assign_trainer(soldier):
		return false
	training_soldiers.append(soldier)
	emit_signal("soldiers_changed")
	return true

func unassign_trainer(soldier: SoldierData) -> void:
	training_soldiers.erase(soldier)
	emit_signal("soldiers_changed")

func equip_owned_item(soldier: SoldierData, item: ItemData, slot: String) -> bool:
	if not owned_items.has(item):
		return false

	# Armor slot: only accept armor
	if slot == "armor" and item.item_type != ItemData.ItemType.ARMOR:
		return false

	# weapon_1: accepts weapons and shields — but shields belong in weapon_2
	if slot == "weapon_1" and item.item_type == ItemData.ItemType.SHIELD:
		return false

	# weapon_2: only weapons or shields; two-handed weapons cannot go here
	if slot == "weapon_2":
		if item.item_type == ItemData.ItemType.ARMOR:
			return false
		if item.item_type == ItemData.ItemType.WEAPON and item.hand_type == ItemData.HandType.TWO_HAND:
			return false

	# weapon_1: if equipping a two-handed weapon, clear weapon_2
	var displaced_from_w2: ItemData = null
	if slot == "weapon_1" and item.item_type == ItemData.ItemType.WEAPON and item.hand_type == ItemData.HandType.TWO_HAND:
		if soldier.weapon_2 != null:
			displaced_from_w2 = soldier.weapon_2
			soldier.weapon_2 = null

	var previous_item: ItemData = null
	match slot:
		"weapon_1":
			previous_item = soldier.weapon_1
			soldier.weapon_1 = item
		"weapon_2":
			previous_item = soldier.weapon_2
			soldier.weapon_2 = item
		"armor":
			previous_item = soldier.armor
			soldier.armor = item
		_:
			return false

	owned_items.erase(item)
	if previous_item != null:
		owned_items.append(previous_item)
	if displaced_from_w2 != null:
		owned_items.append(displaced_from_w2)

	emit_signal("soldiers_changed")
	return true

func can_recruit_worker() -> Dictionary:
	if not is_building_built("House"):
		return {can = false, reason = "House not built."}
	if workforce_total >= workforce_cap:
		return {can = false, reason = "Workforce cap reached (%d/%d). Build more Houses to expand." % [workforce_total, workforce_cap]}
	var max_r := _get_house_max_recruits()
	if house_recruits_this_turn >= max_r:
		return {can = false, reason = "Recruit limit reached (%d/%d this turn)." % [house_recruits_this_turn, max_r]}
	if gold < HOUSE_RECRUIT_GOLD_COST:
		return {can = false, reason = "Need %d Gold (have %d)." % [HOUSE_RECRUIT_GOLD_COST, gold]}
	if food < HOUSE_RECRUIT_FOOD_COST:
		return {can = false, reason = "Need %d Food (have %d)." % [HOUSE_RECRUIT_FOOD_COST, food]}
	return {can = true, reason = ""}

func _get_house_max_recruits() -> int:
	var level := get_building_level("House")
	var recruits_by_level := [1, 2, 3]
	return recruits_by_level[clampi(level - 1, 0, 2)]

func recruit_worker() -> bool:
	var check = can_recruit_worker()
	if not check.can:
		SFX.play("denied")
		return false
	gold -= HOUSE_RECRUIT_GOLD_COST
	food -= HOUSE_RECRUIT_FOOD_COST
	workforce_total += 1
	workforce_available += 1
	house_recruits_this_turn += 1
	emit_signal("resources_changed")
	SFX.play("coin")
	return true

func is_building_built(building_name: String) -> bool:
	return building_levels.get(building_name, 0) >= 1

func get_building_level(building_name: String) -> int:
	return building_levels.get(building_name, 0)

func get_max_allowed_upgrade_level() -> int:
	var sf_level := get_building_level("Steel Forge")
	if sf_level >= 3: return 3
	if sf_level >= 2: return 2
	return 1

func can_upgrade_building(building_name: String) -> Dictionary:
	var data := get_building_data(building_name)
	if data == null:
		return {can = false, missing = "No building data"}
	var level := get_building_level(building_name)
	if level <= 0:
		return {can = false, missing = "Build it first"}
	if level >= data.max_level:
		return {can = false, missing = "Already max level"}

	var max_allowed := get_max_allowed_upgrade_level()
	if level + 1 > max_allowed and building_name != "Steel Forge":
		return {can = false, missing = "Requires Steel Forge L%d" % (level + 1)}

	var idx := level - 1
	var missing: Array[String] = []
	if idx < data.upgrade_cost_gold.size() and gold < data.upgrade_cost_gold[idx]:
		missing.append("%d Gold" % data.upgrade_cost_gold[idx])
	if idx < data.upgrade_cost_wood.size() and wood < data.upgrade_cost_wood[idx]:
		missing.append("%d Wood" % data.upgrade_cost_wood[idx])
	if idx < data.upgrade_cost_stone.size() and stone < data.upgrade_cost_stone[idx]:
		missing.append("%d Stone" % data.upgrade_cost_stone[idx])
	if idx < data.upgrade_cost_iron.size() and iron < data.upgrade_cost_iron[idx]:
		missing.append("%d Iron" % data.upgrade_cost_iron[idx])
	if idx < data.upgrade_cost_steel.size() and steel < data.upgrade_cost_steel[idx]:
		missing.append("%d Steel" % data.upgrade_cost_steel[idx])
	return {can = missing.is_empty(), missing = ", ".join(missing)}

func upgrade_building(building_name: String) -> bool:
	var check := can_upgrade_building(building_name)
	if not check.can:
		SFX.play("denied")
		return false
	var data := get_building_data(building_name)
	var level := get_building_level(building_name)
	var idx := level - 1

	if idx < data.upgrade_cost_gold.size(): gold -= data.upgrade_cost_gold[idx]
	if idx < data.upgrade_cost_wood.size(): wood -= data.upgrade_cost_wood[idx]
	if idx < data.upgrade_cost_stone.size(): stone -= data.upgrade_cost_stone[idx]
	if idx < data.upgrade_cost_iron.size(): iron -= data.upgrade_cost_iron[idx]
	if idx < data.upgrade_cost_steel.size(): steel -= data.upgrade_cost_steel[idx]

	building_levels[building_name] = level + 1
	SFX.play("build")

	if building_name == "House":
		var new_level := level + 1
		var cap_now := data.get_stat_at_level(data.soldier_capacity_by_level, new_level, 0)
		var cap_prev := data.get_stat_at_level(data.soldier_capacity_by_level, level, 0)
		workforce_cap += cap_now - cap_prev

	if building_name == "Barracks":
		var new_level := level + 1
		var cap_now := data.get_stat_at_level(data.soldier_capacity_by_level, new_level, 0)
		var cap_prev := data.get_stat_at_level(data.soldier_capacity_by_level, level, 0)
		max_soldiers += cap_now - cap_prev
		_refresh_barracks_defense_bonus()

	emit_signal("resources_changed")
	return true

func _refresh_barracks_defense_bonus() -> void:
	barracks_city_defense_bonus = 0.05 if get_building_level("Barracks") >= 3 else 0.0

func can_rebuild(building_name: String) -> Dictionary:
	var data := get_building_data(building_name)
	if data == null:
		return {can = false, missing = "No building data"}
	var missing: Array[String] = []
	if gold < data.cost_gold:
		missing.append("%d Gold (have %d)" % [data.cost_gold, gold])
	if wood < data.cost_wood:
		missing.append("%d Wood (have %d)" % [data.cost_wood, wood])
	if stone < data.cost_stone:
		missing.append("%d Stone (have %d)" % [data.cost_stone, stone])
	return {can = missing.is_empty(), missing = ", ".join(missing)}

func rebuild_building(building_name: String) -> bool:
	if is_building_built(building_name):
		return false
	var data := get_building_data(building_name)
	if data == null:
		return false
	var check := can_rebuild(building_name)
	if not check.can:
		SFX.play("denied")
		return false
	gold -= data.cost_gold
	wood -= data.cost_wood
	stone -= data.cost_stone
	building_levels[building_name] = 1
	SFX.play("build")
	StoryManager.check_first_building_rebuilt()
	if building_name == "House":
		workforce_cap += data.get_stat_at_level(data.soldier_capacity_by_level, 1, 5)
	if building_name == "Barracks":
		max_soldiers += data.get_stat_at_level(data.soldier_capacity_by_level, 1, 2)
		_refresh_barracks_defense_bonus()
	if building_name == "Market":
		refresh_market_stock()
	emit_signal("resources_changed")
	return true

func get_building_data(building_name: String) -> BuildingData:
	return building_definitions.get(building_name) as BuildingData

func get_building_production(building_name: String, workers: int) -> Dictionary:
	var data := get_building_data(building_name)
	if data == null or workers <= 0:
		return {}
	var level := get_building_level(building_name)
	return data.get_production_for_workers(workers, level)

var tavern_roster: Array[SoldierData] = []

func refresh_tavern_roster() -> void:
	tavern_roster.clear()
	var level := get_building_level("Tavern")
	var roster_counts := [2, 3, 4]
	var count: int = roster_counts[clampi(level - 1, 0, 2)] if level >= 1 else 2
	var classes: Array[String]
	if level <= 1:
		classes = ["Warrior", "Archer", "Rogue"]
	else:
		classes = ["Warrior", "Archer", "Rogue", "Mage", "Knight"]

	# Guaranteed quality floor from innkeepers + tavern level (see consts above).
	var ik := tavern_workers_last_turn
	var lvl_steps := maxi(level, 1) - 1
	var combat_floor := ik * INNKEEPER_COMBAT_BONUS + lvl_steps * TAVERN_LEVEL_COMBAT_BONUS
	var hp_floor := ik * INNKEEPER_HP_BONUS + lvl_steps * TAVERN_LEVEL_HP_BONUS

	for i in count:
		var soldier_class := classes[randi_range(0, classes.size() - 1)]
		var s := _generate_recruit(soldier_class)
		s.power     += combat_floor + randi_range(0, RECRUIT_STAT_SPREAD)
		s.speed     += combat_floor + randi_range(0, RECRUIT_STAT_SPREAD)
		s.dexterity += combat_floor + randi_range(0, RECRUIT_STAT_SPREAD)
		s.hp_max    += hp_floor + randi_range(0, RECRUIT_STAT_SPREAD)
		s.hp_current = s.hp_max
		tavern_roster.append(s)

func _generate_recruit(soldier_class: String) -> SoldierData:
	var s := SoldierData.new()
	s.soldier_class = soldier_class
	s.sprite_variant = randi_range(1, 3)
	s.soldier_name = _generate_name()
	s.level = 1
	s.hp_max = 80 + randi_range(0, 40)
	s.hp_current = s.hp_max
	s.power = 8 + randi_range(0, 6)
	s.speed = 4 + randi_range(0, 4)
	s.dexterity = 4 + randi_range(0, 4)

	match soldier_class:
		"Warrior":  s.power += 5;     s.hp_max += 20; s.hp_current = s.hp_max
		"Archer":   s.dexterity += 5; s.speed += 3
		"Rogue":    s.speed += 6;     s.dexterity += 4
		"Mage":     s.power += 8;     s.speed -= 1
		"Knight":   s.hp_max += 40;   s.hp_current = s.hp_max; s.speed -= 2

	# Auto-learn the class's Lv.1 starter skills (first one auto-equips into slot 1).
	s.check_skill_unlocks()

	return s

func _generate_name() -> String:
	var first = ["Aldric", "Brynn", "Cael", "Dara", "Eron", "Fynn",
				 "Gara", "Holt", "Isen", "Jora", "Kael", "Lyra",
				 "Morn", "Nira", "Orin", "Pael", "Roan", "Sera",
				 "Thorn", "Urik", "Vara", "Wren", "Xara", "Yorn"]
	var last = ["Stone", "Iron", "Ash", "Frost", "Blade", "Storm",
				"Wolf", "Hawk", "Bear", "Fox", "Crow", "Drake",
				"Vale", "Ridge", "Crest", "Ford", "Moor", "Glen"]
	return "%s %s" % [first[randi_range(0, first.size()-1)],
					  last[randi_range(0, last.size()-1)]]

func recruit_from_roster(soldier: SoldierData) -> bool:
	if soldiers.size() >= get_max_soldiers():
		SFX.play("denied")
		return false
	var cost := get_recruit_cost()
	if gold < cost:
		SFX.play("denied")
		return false
	soldiers.append(soldier)
	tavern_roster.erase(soldier)
	gold -= cost
	emit_signal("soldiers_changed")
	emit_signal("resources_changed")
	SFX.play("coin")
	return true

func get_recruit_cost() -> int:
	var committed_innkeepers := tavern_workers_last_turn
	var tavern_data := get_building_data("Tavern")
	if tavern_data == null:
		return max(50, 100 - committed_innkeepers * 10)
	return max(
		tavern_data.recruit_min_cost,
		tavern_data.recruit_base_cost - committed_innkeepers * tavern_data.recruit_cost_reduction_per_worker
	)

# Guaranteed combat-stat floor recruits currently get from committed innkeepers
# + tavern level (matches refresh_tavern_roster). Used for the tavern UI hint.
func get_recruit_combat_bonus() -> int:
	var level := get_building_level("Tavern")
	return tavern_workers_last_turn * INNKEEPER_COMBAT_BONUS \
		+ (maxi(level, 1) - 1) * TAVERN_LEVEL_COMBAT_BONUS

func get_recruit_hp_bonus() -> int:
	var level := get_building_level("Tavern")
	return tavern_workers_last_turn * INNKEEPER_HP_BONUS \
		+ (maxi(level, 1) - 1) * TAVERN_LEVEL_HP_BONUS

func get_max_soldiers() -> int:
	return max_soldiers

# --- SIGNALS ---
signal resources_changed
signal turn_ended(turn_number: int)
signal soldiers_changed
signal recap_ready
signal combat_started_from_turn
signal threat_updated
@warning_ignore("unused_signal")
signal game_event_popup_ready(event: Dictionary)
@warning_ignore("unused_signal")
signal raid_pursuit_triggered
signal prince_consumed_by_veil
@warning_ignore("unused_signal")
signal scout_combat_result_ready(result: Dictionary)
signal city_fallen
signal game_won


func assign_worker(building_name: String, amount: int) -> bool:
	if not building_workers.has(building_name):
		return false
	if not is_building_built(building_name):
		return false

	var current: int = building_workers.get(building_name, 0)
	var new_amount: int = current + amount

	if amount > 0 and workforce_available < amount:
		return false
	if new_amount < 0:
		return false
	if building_name == "Barracks" and amount < 0:
		if soldiers.size() > get_max_soldiers():
			return false

	building_workers[building_name] = new_amount
	workforce_available -= amount
	emit_signal("resources_changed")

	return true

func get_threat_forecast_text() -> String:
	var wave_num: int = _get_next_wave_difficulty()
	var is_boss := wave_num > 0 and wave_num % 5 == 0
	var boss_tag := " [BOSS WAVE!]" if is_boss else ""
	return "Threat %d%% | Difficulty %d | +%d/turn%s" % [
		threat,
		combat_difficulty,
		_get_threat_gain(),
		boss_tag,
	]

func _get_threat_gain() -> int:
	return threat_gain_rate

var threat_gain_rate: int = 25

func _get_next_wave_difficulty() -> int:
	# Wave difficulty grows roughly every 2–3 threat cycles, not every turn.
	return max(1, int(float(combat_difficulty + 1) / 2.5) + 1)

## Schedules the kings_return letter to arrive 3 turns before the next boss wave.
## Called once when all win conditions are first satisfied.
func _schedule_win_letter() -> void:
	var turns_per_wave: int = ceili(float(threat_max) / float(maxi(1, threat_gain_rate)))
	var turns_to_next: int = ceili(float(maxi(0, threat_max - threat)) / float(maxi(1, threat_gain_rate)))
	# Project forward through upcoming wave turns until we land on a boss difficulty.
	var proj_turn: int = current_turn + turns_to_next
	for _i in 15:
		var proj_diff: int = maxi(1, int(float(proj_turn) / 3.0) + 1)
		if proj_diff % 5 == 0:
			break
		proj_turn += turns_per_wave
	_win_letter_turn = maxi(current_turn, proj_turn - 3)

func _schedule_next_battle(initial_schedule: bool = false) -> void:
	if initial_schedule:
		combat_difficulty = 1
	else:
		total_waves_won += 1
		# Wave difficulty advances every ~2–3 threat thresholds, not 1:1 with turns.
		combat_difficulty = max(1, int(float(current_turn) / 3.0) + 1)
		if total_waves_won == 3:
			StoryManager.check_wave_3_survived()
		FactionState.on_wave_survived(combat_difficulty)
		# Win: letter scheduled when conditions first met. The actual game_won
		# signal is fired only once the resulting final boss wave is WON — see
		# _arm_final_battle_check() (called from _start_pending_battle /
		# _stage_city_defense_battle) and _consume_final_battle_result().
		if not win_condition_triggered and check_win_condition():
			win_condition_triggered = true
			_schedule_win_letter()

	var effective_difficulty: int = combat_difficulty + next_wave_difficulty_bonus
	next_wave_difficulty_bonus = 0
	@warning_ignore("INTEGER_DIVISION")
	var _is_boss_wave: bool = effective_difficulty > 0 and effective_difficulty % 5 == 0
	pending_enemy_wave = EnemyData.make_random_wave(effective_difficulty)
	if legion_garrison_active:
		if _is_boss_wave:
			legion_garrison_active = false
		elif pending_enemy_wave.size() > 1:
			pending_enemy_wave.pop_back()
	pending_battle_source = "Scheduled Wave"
	emit_signal("threat_updated")

## Called immediately before a wave is actually fought (normal combat or
## staged city-defense). If win conditions are already met and this wave is
## a boss wave (combat_difficulty % 5 == 0), arms final_battle_pending so the
## resolution path can fire game_won if — and only if — this wave is WON.
func _arm_final_battle_check() -> void:
	@warning_ignore("INTEGER_DIVISION")
	final_battle_pending = win_condition_triggered and combat_difficulty > 0 and combat_difficulty % 5 == 0

## Called by every wave-resolution path (normal combat victory/defeat,
## city-defense auto-resolve, city-defense spectator battle) once the
## outcome of the wave is known. If final_battle_pending was armed for this
## wave:
##   - victory  -> the kingdom is saved; fire game_won (once).
##   - defeat   -> the city survives this attempt (assuming walls > 0); the
##                 next boss wave becomes the new "final" chance, so the flag
##                 is simply cleared and re-armed naturally next time.
## Always clears final_battle_pending so unrelated combats (raid pursuits,
## non-boss waves) can never trigger this.
func _consume_final_battle_result(victory: bool) -> void:
	if not final_battle_pending:
		return
	final_battle_pending = false
	if victory and not game_won_achieved:
		game_won_achieved = true

## Called once the player has dismissed the battle-result UI for a wave that
## was just won. If the kingdom-saving final wave was won (game_won_achieved),
## fires game_won now so the victory screen appears AFTER the result popup
## instead of racing it. Safe to call even when nothing is pending — and safe
## to call more than once, since hub_screen._on_game_won is idempotent via its
## is_victory_overlay meta guard. Returns true if game_won was (re-)announced.
func announce_game_won_if_pending() -> bool:
	if not game_won_achieved:
		return false
	emit_signal("game_won")
	return true

func _start_pending_battle() -> void:
	if pending_enemy_wave.is_empty():
		_schedule_next_battle()

	var wave: Array[EnemyData] = []
	wave.assign(pending_enemy_wave)

	@warning_ignore("INTEGER_DIVISION")
	var _is_boss: bool = combat_difficulty > 0 and combat_difficulty % 5 == 0
	if legion_solo_fight_pending and not _is_boss:
		legion_solo_fight_pending = false
		turn_recap.append("")
		turn_recap.append("--- City Defense ---")
		turn_recap.append("%s arrived! The garrison forces held the line. Your soldiers were not needed." % pending_battle_source)
		pending_enemy_wave.clear()
		_schedule_next_battle()
		emit_signal("turn_ended", current_turn)
		if not DungeonState.active:
			emit_signal("recap_ready")
		return
	legion_solo_fight_pending = false

	turn_recap.append("%s arrived! Difficulty %d, %d enemies." % [
		pending_battle_source,
		combat_difficulty,
		wave.size()
	])
	_arm_final_battle_check()
	CombatState.start_combat(wave)
	pending_enemy_wave.clear()
	_schedule_next_battle()
	emit_signal("combat_started_from_turn")


# --- DUNGEON INTEGRATION ---
signal dungeon_expedition_ready

var tavern_workers_last_turn: int = 0
func end_turn() -> void:
	SFX.play("end_turn")
	if not DungeonState.pending_soldiers.is_empty():
		DungeonState.start_expedition()

	tavern_workers_last_turn = building_workers.get("Tavern", 0)
	FactionState.begin_turn_tracking()
	var resource_snapshot := _capture_resource_snapshot()
	turn_recap.clear()
	turn_recap.append("=== Turn %d Complete ===" % current_turn)

	_phase_production()
	# Restore Iron Mine worker after Warden burial rite (taken away last turn)
	if pending_iron_mine_worker_restore:
		pending_iron_mine_worker_restore = false
		if building_workers.has("Iron Mine"):
			building_workers["Iron Mine"] += 1
		emit_signal("resources_changed")
	_phase_training()
	_phase_upkeep()
	GameEvents._phase_events()

	# pale_court_gift_death_pending is now triggered immediately from FactionEvents;
	# this fallback handles any saves that had the flag set before the fix.
	if pale_court_gift_death_pending:
		pale_court_gift_death_pending = false
		_trigger_veil_death()

	# --- Lockout countdowns ---
	if DungeonState.warden_lockout_turns > 0:
		DungeonState.warden_lockout_turns -= 1
	if DungeonState.legion_lockout_turns > 0:
		DungeonState.legion_lockout_turns -= 1

	# --- Deserter returns ---
	var _returned: Array = []
	for _entry in pending_deserter_return:
		_entry.turns_remaining -= 1
		if _entry.turns_remaining <= 0:
			var _s: SoldierData = _entry.soldier
			if not _s.has_trait("deserter"):
				for _t in TraitLibrary.get_all():
					if _t.trait_id == "deserter":
						_s.traits.append(_t)
						break
			_s.morale = mini(_s.morale, 80)
			soldiers.append(_s)
			_returned.append(_entry)
			turn_recap.append("  %s returned, marked as Deserter by the Iron Legion." % _s.soldier_name)
	for _entry in _returned:
		pending_deserter_return.erase(_entry)
	if not _returned.is_empty():
		emit_signal("soldiers_changed")

	_build_resource_delta_summary(resource_snapshot)
	current_turn += 1
	StoryManager.check_milestones()
	FactionEvents.check_and_queue()

	# --- Threat accumulation ---
	var threat_gain: int = _get_threat_gain()
	threat += threat_gain

	var barracks_workers: int = building_workers.get("Barracks", 0)
	threat -= barracks_workers * 3

	# Wardens disrupt Veiled seepage when standing is Friendly or Allied
	if FactionState.wardens_reduces_valuiti_threat:
		var warden_reduction: int = 8 if FactionState.wardens_standing >= 81 else 5
		threat = maxi(0, threat - warden_reduction)
		turn_recap.append("The Wardens disrupt the Veiled's advance: -%d Threat" % warden_reduction)

	threat = clamp(threat, 0, 150)
	emit_signal("threat_updated")

	# --- Pale Court resource drain ---
	var drain: int = FactionState.pale_court_resource_drain
	if drain > 0:
		gold = maxi(0, gold - drain)
		turn_recap.append("Pale Court agents steal %d Gold from the city coffers." % drain)

	var battle_starts_now: bool = threat >= threat_max
	if battle_starts_now:
		# Carry overflow into the next cycle
		threat = max(0, threat - threat_max)
		emit_signal("threat_updated")
		if DungeonState.active:
			_stage_city_defense_battle()
		else:
			_start_pending_battle()
	else:
		turn_recap.append("")
		turn_recap.append(get_threat_forecast_text())
		# Warn when the threat will trigger a wave next turn.
		if threat + threat_gain_rate >= threat_max:
			SFX.play("wave_alarm")
		emit_signal("turn_ended", current_turn)
		if not DungeonState.active:
			emit_signal("recap_ready")
	house_recruits_this_turn = 0
	refresh_tavern_roster()
	refresh_market_stock()
	emit_signal("resources_changed")
	emit_signal("threat_updated")

	if DungeonState.active:
		emit_signal("dungeon_expedition_ready")

## Records the wave + remaining city defenders for resolution after the player
## exits the dungeon (see hub_screen._on_dungeon_scene_closed). Does NOT
## resolve the battle yet — the player chooses Watch Battle or Auto-Resolve.
func _stage_city_defense_battle() -> void:
	var wave: Array[EnemyData] = []
	wave.assign(pending_enemy_wave)
	var wave_names: Array[String] = []
	for e in wave:
		wave_names.append(e.enemy_name)
	# Defenders = alive soldiers who are actually in the city right now.
	# Trainers are occupied at the Training Grounds, and the dungeon party (and
	# any soldiers queued to depart) are away — none of them can defend, so the
	# replay must not show them fighting.
	var defenders: Array[SoldierData] = []
	defenders.assign(soldiers.filter(func(s):
		return s.is_alive() \
			and not training_soldiers.has(s) \
			and not DungeonState.soldiers_in_dungeon.has(s) \
			and not DungeonState.pending_soldiers.has(s)
	))
	# Combat fields at most 4 units (pre_combat_screen.MAX_COMBAT_SLOTS). The
	# strongest 4 hold the line so the replay never shows the whole roster.
	defenders.sort_custom(func(a, b): return a.get_total_power() > b.get_total_power())
	if defenders.size() > 4:
		defenders = defenders.slice(0, 4)

	turn_recap.append("")
	turn_recap.append("--- City Defense ---")
	turn_recap.append("%s attacked while soldiers were in the dungeon!" % pending_battle_source)

	_arm_final_battle_check()
	pending_enemy_wave.clear()
	_schedule_next_battle()

	_pending_city_defense_battle = {
		wave = wave,
		wave_names = wave_names,
		wave_source = pending_battle_source,
		defenders = defenders,
	}

## Auto-Resolve path — instant outcome via DungeonState's combat math. Appends
## the outcome to turn_recap (read by RecapScreen on recap_ready) and applies
## the same wave-loss consequences as a normal city-combat defeat (wall lost,
## resource drain, building damage, threat spike, -20 morale). Returns the
## result dict for the "City Attacked!" summary dialog.
func resolve_city_defense_auto() -> Dictionary:
	var battle: Dictionary = _pending_city_defense_battle
	_pending_city_defense_battle = {}
	var wave: Array[EnemyData] = []
	wave.assign(battle.get("wave", []))
	var defenders: Array[SoldierData] = []
	defenders.assign(battle.get("defenders", []))
	var wave_source: String = battle.get("wave_source", "Enemy Wave")

	var result := DungeonState.auto_resolve_city_defense(defenders, wave, barracks_city_defense_bonus)
	result["wave_names"] = battle.get("wave_names", [])
	result["wave_source"] = wave_source

	for line in result.log_lines:
		turn_recap.append(line)

	if not result.victory:
		apply_wave_loss_consequences()
		turn_recap.append("City walls weakened: %d remaining." % city_walls)

	_consume_final_battle_result(result.victory)

	emit_signal("soldiers_changed")
	return result

## Watch Battle path — sets up CombatState for a live spectator fight using the
## actual remaining city defenders vs. the actual wave. Returns the defenders
## list (for soldiers_lost bookkeeping after the fight ends) or an empty array
## if there is nothing to fight (handled by the zero-defenders edge case).
func start_city_defense_spectator_battle() -> Array[SoldierData]:
	var battle: Dictionary = _pending_city_defense_battle
	_pending_city_defense_battle = {}
	var wave: Array[EnemyData] = []
	wave.assign(battle.get("wave", []))
	var defenders: Array[SoldierData] = []
	defenders.assign(battle.get("defenders", []))
	if defenders.is_empty() or wave.is_empty():
		return []

	CombatState.start_combat(wave)
	CombatState.allies = defenders
	CombatState.spectator_mode = true
	CombatState.is_dungeon_combat = false
	CombatState.begin_after_selection()
	return defenders

## Builds the "City Attacked!" summary dict after a live spectator battle ends.
## `defenders` is the list returned by start_city_defense_spectator_battle();
## CombatState._end_spectator_combat has already applied consequences
## (removed the dead from `soldiers`, applied wave-loss consequences on
## defeat) — this just reports on the outcome.
func build_city_defense_spectator_result(defenders: Array[SoldierData], wave_names: Array[String], wave_source: String, victory: bool) -> Dictionary:
	var dead_soldiers := defenders.filter(func(s): return not s.is_alive())
	var log_lines: Array[String] = []
	for s in dead_soldiers:
		log_lines.append("  %s fell defending the city." % s.soldier_name)
	if victory:
		log_lines.append("City defenders held the line!")
	else:
		log_lines.append("The city's defenses were overwhelmed!")
		log_lines.append("City walls weakened: %d remaining." % city_walls)

	for line in log_lines:
		turn_recap.append(line)

	_consume_final_battle_result(victory)

	return {
		victory = victory,
		soldiers_lost = dead_soldiers.size(),
		wave_names = wave_names,
		wave_source = wave_source,
		log_lines = log_lines,
	}

func _phase_upkeep() -> void:
	turn_recap.append("")
	turn_recap.append("--- Upkeep ---")
	# Expire temporary soldiers (mercenaries hired for a season)
	var expired: Array[SoldierData] = []
	for s in soldiers:
		if s.temp_soldier_turns > 0:
			s.temp_soldier_turns -= 1
			if s.temp_soldier_turns <= 0:
				expired.append(s)
	for s in expired:
		soldiers.erase(s)
		turn_recap.append("  %s's contract ended. They have moved on." % s.soldier_name)
	if not expired.is_empty():
		emit_signal("soldiers_changed")
	_upkeep_soldiers_food()
	_upkeep_barracks_and_regen()
	_phase_morale_combat_note()

func _upkeep_soldiers_food() -> void:
	if soldiers.is_empty():
		turn_recap.append("No soldiers to feed.")
		return
	var food_needed := soldiers.size() * SOLDIER_FOOD_UPKEEP
	if food >= food_needed:
		food -= food_needed
		turn_recap.append("Soldiers fed: -%d Food  (%d × %d)" % [food_needed, soldiers.size(), SOLDIER_FOOD_UPKEEP])
	else:
		var fed_count := int(float(food) / float(SOLDIER_FOOD_UPKEEP))
		var unfed_count := soldiers.size() - fed_count
		food = 0
		apply_army_morale(-unfed_count * 5)
		turn_recap.append("Food shortage! %d/%d soldiers unfed. Morale -5 each." % [unfed_count, soldiers.size()])

func _upkeep_barracks_and_regen() -> void:
	if not is_building_built("Barracks"):
		return
	var workers: int = building_workers.get("Barracks", 0)
	if workers <= 0:
		return
	var data := get_building_data("Barracks")
	if data == null:
		return

	# Food upkeep
	if data.consumes_food > 0:
		var food_cost: int = data.consumes_food * workers
		if food >= food_cost:
			food -= food_cost
			turn_recap.append("Barracks upkeep: -%d Food" % food_cost)
		else:
			var shortage: int = food_cost - food
			food = 0
			apply_army_morale(-3)
			turn_recap.append("Barracks underfed (need %d Food, short %d). Morale -3 each." % [food_cost, shortage])

	# HP regen for idle soldiers (not in dungeon), scaled by barracks workers.
	# Each assigned worker contributes one base regen increment per soldier per turn.
	var level := get_building_level("Barracks")
	var regen_flat := data.get_stat_at_level(data.idle_hp_regen_by_level, level, 0)
	var regen_pct := data.get_float_stat_at_level(data.idle_hp_regen_pct_by_level, level, 0.0)
	if regen_flat <= 0 and regen_pct <= 0.0:
		return

	# No workers → no regen
	if workers <= 0:
		return

	var regen_lines: Array[String] = []
	for soldier in soldiers:
		if not soldier.is_alive():
			continue
		if soldier.hp_current >= soldier.hp_max:
			continue
		var base_regen := regen_flat
		if regen_pct > 0.0:
			base_regen = int(soldier.hp_max * regen_pct)
		# Scale regen by the number of workers assigned to the Barracks
		var regen := base_regen * workers
		soldier.hp_current = mini(soldier.hp_max, soldier.hp_current + regen)
		regen_lines.append("  %s +%d HP" % [soldier.soldier_name, regen])

	if not regen_lines.is_empty():
		turn_recap.append("Barracks HP regen (%d worker%s):" % [workers, "s" if workers != 1 else ""])
		for line in regen_lines:
			turn_recap.append(line)

func _phase_production() -> void:
	turn_recap.append("")
	turn_recap.append("--- Production ---")
	_process_production()
	_tick_forge_queue()

func _phase_training() -> void:
	turn_recap.append("")
	turn_recap.append("--- Training ---")
	_process_training()

## Backward-compat accessor — hub_screen.gd iterates GameState.EVENTS to identify event ids.
var EVENTS: Array:
	get:
		return GameEvents.EVENTS

func _phase_morale_combat_note() -> void:
	if soldiers.is_empty():
		return
	var low_morale_count: int = soldiers.filter(func(s): return s.is_alive() and s.morale < 40).size()
	if low_morale_count > 0:
		turn_recap.append("Low morale: %d soldier%s suffer reduced hit chance." % [low_morale_count, "s" if low_morale_count != 1 else ""])

func _process_production() -> void:
	var anything_produced := false
	for b_name in building_workers:
		var workers: int = building_workers[b_name]
		if workers <= 0:
			continue
		if not is_building_built(b_name):
			continue
		if damaged_buildings.has(b_name):
			turn_recap.append("%s: damaged: no production this turn. Repair costs %d Gold." % [b_name, damaged_buildings[b_name]])
			continue

		var level := get_building_level(b_name)
		var prod := get_building_production(b_name, workers)
		if prod.is_empty():
			# Apply flat morale from morale_flat_by_level (if any) even with no worker production
			var bdata_morale := get_building_data(b_name)
			if bdata_morale != null:
				var flat_morale := bdata_morale.get_stat_at_level(bdata_morale.morale_flat_by_level, level, 0)
				if flat_morale != 0:
					_apply_resource_delta("Morale", flat_morale)
					var sign_fm := "+" if flat_morale >= 0 else ""
					turn_recap.append("%s: %s%d Morale (passive)" % [b_name, sign_fm, flat_morale])
					anything_produced = true
			continue
		if not _can_apply_production(prod):
			var shortage := _get_production_shortage(prod)
			turn_recap.append("%s (%d workers): skipped, need %d %s but only have %d." % [
				b_name,
				workers,
				shortage.required,
				shortage.resource.to_lower(),
				shortage.current,
			])
			continue

		var line := "%s (%d workers): " % [b_name, workers]
		var parts: Array[String] = []
		for resource in prod:
			var amount: int = prod[resource]
			_apply_resource_delta(resource, amount)
			if amount != 0:
				var sign_p := "+" if amount >= 0 else ""
				parts.append("%s%d %s" % [sign_p, amount, resource])

		# Flat morale bonus (stacks on top of worker production)
		var bdata := get_building_data(b_name)
		if bdata != null:
			var flat_morale := bdata.get_stat_at_level(bdata.morale_flat_by_level, level, 0)
			if flat_morale != 0:
				_apply_resource_delta("Morale", flat_morale)
				var sign_m := "+" if flat_morale >= 0 else ""
				parts.append("%s%d Morale" % [sign_m, flat_morale])

		# Farm L3 harvest bonus: 20% chance × 1.5 food
		if b_name == "Farm" and level >= 3 and bdata != null:
			if randf() < bdata.harvest_bonus_chance:
				var bonus_food := int(prod.get("Food", 0) * (bdata.harvest_bonus_multiplier - 1.0))
				if bonus_food > 0:
					_apply_resource_delta("Food", bonus_food)
					parts.append("+%d Food (harvest bonus)" % bonus_food)

		# Butchery L3 bonus batch: 15% chance → +5 flat gold
		if b_name == "Butchery" and level >= 3 and bdata != null:
			if randf() < bdata.harvest_bonus_chance:
				_apply_resource_delta("Gold", 5)
				parts.append("+5 Gold (bonus batch)")

		# Iron Mine L2/L3 bonus find: chance per level to find +3 Stone +2 Gold
		if b_name == "Iron Mine" and level >= 2 and bdata != null:
			var chance := bdata.get_float_stat_at_level(bdata.bonus_find_chance_by_level, level, 0.0)
			if chance > 0.0 and randf() < chance:
				_apply_resource_delta("Stone", 3)
				_apply_resource_delta("Gold", 2)
				parts.append("+3 Stone +2 Gold (vein find)")

		if not parts.is_empty():
			turn_recap.append(line + ", ".join(parts))
			anything_produced = true

	if not anything_produced:
		turn_recap.append("No production this turn. Assign workers to buildings.")

func _tick_forge_queue() -> void:
	if weapon_forge_queue.is_empty():
		return
	var forge_level := get_building_level("Blacksmith")
	# Iterate backwards so remove_at does not shift unprocessed indices
	for i in range(weapon_forge_queue.size() - 1, -1, -1):
		weapon_forge_queue[i].turns_remaining -= 1
		if weapon_forge_queue[i].turns_remaining <= 0:
			var entry: Dictionary = weapon_forge_queue[i]
			# L3 quality upgrade chance (15%, only if below max quality)
			if forge_level >= 3 and randf() < 0.15 and entry.quality < 2:
				entry.quality += 1
				entry.result_item = _apply_quality_to_item(entry.result_item, entry.quality)
				turn_recap.append("Weapon Forge: '%s' quality upgraded to %s!" % [
					entry.item_name, QUALITY_NAMES[entry.quality]
				])
			owned_items.append(entry.result_item)
			weapon_forge_queue.remove_at(i)
			turn_recap.append("Weapon Forge: '%s' (%s) crafting complete!" % [
				entry.item_name, QUALITY_NAMES[entry.quality]
			])

func _can_apply_production(prod: Dictionary) -> bool:
	for resource in prod:
		var amount: int = prod[resource]
		if amount >= 0:
			continue
		var current_value := _get_resource_value(resource)
		if current_value + amount < 0:
			return false
	return true

func _get_production_shortage(prod: Dictionary) -> Dictionary:
	for resource in prod:
		var amount: int = prod[resource]
		if amount >= 0:
			continue
		var current_value := _get_resource_value(resource)
		var required_value: int = absi(amount)
		if current_value + amount < 0:
			return {resource = resource, current = current_value, required = required_value}
	return {resource = "resources", current = 0, required = 0}

## Current amount of a named resource ("Gold"/"Wood"/... case-insensitive).
func get_resource_amount(resource: String) -> int:
	match resource.capitalize():
		"Wood":  return wood
		"Stone": return stone
		"Iron":  return iron
		"Steel": return steel
		"Food":  return food
		"Gold":  return gold
	return 0

func _apply_resource_delta(resource: String, amount: int) -> void:
	match resource:
		"Wood":
			wood = max(0, wood + amount)
		"Stone":
			stone = max(0, stone + amount)
		"Iron":
			iron = max(0, iron + amount)
		"Steel":
			steel = max(0, steel + amount)
		"Food":
			food = max(0, food + amount)
		"Gold":
			gold = max(0, gold + amount)
		"Morale":
			apply_army_morale(amount)

func _process_training() -> void:
	if not is_building_built("Training Grounds"):
		turn_recap.append("No training this turn.")
		return

	# Remove any trainers who are no longer alive or are in the dungeon
	for i in range(training_soldiers.size() - 1, -1, -1):
		var t := training_soldiers[i]
		if not t.is_alive() or DungeonState.soldiers_in_dungeon.has(t):
			training_soldiers.remove_at(i)

	if training_soldiers.is_empty():
		turn_recap.append("No training this turn. Assign trainers at the Training Grounds.")
		return

	var training_data := get_building_data("Training Grounds")
	if training_data == null:
		turn_recap.append("No training this turn.")
		return

	var level := get_building_level("Training Grounds")
	var base_xp := training_data.get_stat_at_level(training_data.base_xp_by_level, level, training_data.training_xp_per_worker)

	# Sum XP contribution from each trainer
	var total_xp_per_trainee: int = 0
	for trainer in training_soldiers:
		total_xp_per_trainee += base_xp + trainer.dexterity * 2 + trainer.level * 3

	turn_recap.append("Training Grounds: +%d XP to each soldier this turn" % total_xp_per_trainee)

	var trainee_count: int = 0
	for soldier in soldiers:
		if not soldier.is_alive():
			continue
		if training_soldiers.has(soldier):
			continue
		trainee_count += 1
		var leveled_up := soldier.add_xp(total_xp_per_trainee)
		turn_recap.append("  %s +%d XP" % [soldier.soldier_name, total_xp_per_trainee])
		if leveled_up:
			turn_recap.append("  %s reached Level %d!" % [soldier.soldier_name, soldier.level])
			emit_signal("soldiers_changed")

	# Trainers gain XP from training (no explanatory recap line)
	var xp_for_trainer := int(0.3 * trainee_count)
	if xp_for_trainer > 0:
		for trainer in training_soldiers:
			var trainer_leveled := trainer.add_xp(xp_for_trainer)
			turn_recap.append("  %s (trainer) +%d XP" % [trainer.soldier_name, xp_for_trainer])
			if trainer_leveled:
				turn_recap.append("  %s (trainer) reached Level %d!" % [trainer.soldier_name, trainer.level])
				emit_signal("soldiers_changed")


func _capture_resource_snapshot() -> Dictionary:
	return {
		"Gold": gold,
		"Wood": wood,
		"Stone": stone,
		"Iron": iron,
		"Steel": steel,
		"Food": food,
	}

func _build_resource_delta_summary(start_snapshot: Dictionary) -> void:
	last_turn_resource_deltas.clear()
	var ordered_resources: Array[String] = ["Gold", "Wood", "Stone", "Iron", "Steel", "Food"]

	for resource_name in ordered_resources:
		var start_value: int = start_snapshot.get(resource_name, 0)
		var end_value := _get_resource_value(resource_name)
		var delta := end_value - start_value
		last_turn_resource_deltas[resource_name] = delta

	_refresh_resource_delta_summary_line()

func add_post_turn_resource_delta(resource_name: String, amount: int) -> void:
	if amount == 0:
		return

	_apply_resource_delta(resource_name, amount)
	var current_delta := int(last_turn_resource_deltas.get(resource_name, 0))
	last_turn_resource_deltas[resource_name] = current_delta + amount
	_refresh_resource_delta_summary_line()

func _refresh_resource_delta_summary_line() -> void:
	var ordered_resources: Array[String] = ["Gold", "Wood", "Stone", "Iron", "Steel", "Food"]
	var parts: Array[String] = []
	for resource_name in ordered_resources:
		var delta := int(last_turn_resource_deltas.get(resource_name, 0))
		if delta != 0:
			var sign_d := "+" if delta > 0 else ""
			parts.append("%s %s%d" % [resource_name, sign_d, delta])

	var summary_line := "Net resources gain: No net change"
	if not parts.is_empty():
		summary_line = "Net resources gain: " + " | ".join(parts)

	for i in range(turn_recap.size()):
		if turn_recap[i].begins_with("Resources:") or turn_recap[i].begins_with("Net resources gain:"):
			turn_recap[i] = summary_line
			return

	turn_recap.append(summary_line)

func _get_resource_value(resource_name: String) -> int:
	match resource_name:
		"Gold": return gold
		"Wood": return wood
		"Stone": return stone
		"Iron": return iron
		"Steel": return steel
		"Food": return food
		_: return 0
