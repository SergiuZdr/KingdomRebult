# GameState.gd
extends Node

# --- CONSTANTE ---
const SOLDIER_FOOD_UPKEEP: int = 2
const MORALE_PENALTY_PER_UNFED_SOLDIER: int = 5
const HOUSE_RECRUIT_GOLD_COST: int = 25
const HOUSE_RECRUIT_FOOD_COST: int = 8
const HOUSE_MAX_RECRUITS_PER_TURN: int = 2
const BASE_WORKFORCE_CAP: int = 10

# --- RESURSE ---
var gold: int = 500
var wood: int = 0
var stone: int = 0
var iron: int = 0
var steel: int = 0
var food: int = 0
var morale: int = 100
var workforce_total: int = 10
var workforce_available: int = 10
var workforce_cap: int = BASE_WORKFORCE_CAP

# --- SOLDAȚI ---
var soldiers: Array[SoldierData] = []
var max_soldiers: int = 4

# --- UI STATE ---
var menu_open: bool = false
var in_city_view: bool = true

# --- RECAP ---
var turn_recap: Array[String] = []

# --- INVENTAR ---
var available_items: Array[ItemData] = []
var owned_items: Array[ItemData] = []
var building_definitions: Dictionary = {}
var building_workers: Dictionary = {}
var building_built_status: Dictionary = {}
var house_recruits_this_turn: int = 0

# --- PROGRES ---
var current_turn: int = 0
var combat_difficulty: int = 1
var turns_until_next_battle: int = 2
var base_battle_interval: int = 2
var pending_enemy_wave: Array[EnemyData] = []
var pending_battle_source: String = "Scheduled Wave"
var last_turn_resource_deltas: Dictionary = {}
var _pending_event_recap: Array[String] = []
var _pending_event_data: Dictionary = {}
var _pending_city_defense_result: Dictionary = {}
var _city_defense_replay_events: Array = []

func _ready() -> void:
	_load_building_definitions()
	_populate_shop()
	_schedule_next_battle(true)
	refresh_tavern_roster()

func _load_building_definitions() -> void:
	building_definitions.clear()
	var existing_workers = building_workers.duplicate()
	building_workers.clear()

	var dir = DirAccess.open("res://data/buildings")
	if dir == null:
		push_warning("Could not open res://data/buildings")
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

	for building_name in building_definitions.keys():
		building_workers[building_name] = existing_workers.get(building_name, 0)
		if not building_built_status.has(building_name):
			building_built_status[building_name] = building_definitions[building_name].starts_built

func _populate_shop() -> void:
	available_items = [
		ItemData.make_iron_sword(),
		ItemData.make_steel_axe(),
		ItemData.make_shortbow(),
		ItemData.make_dagger(),
		ItemData.make_leather_armor(),
		ItemData.make_chainmail(),
		ItemData.make_plate_armor(),
	]

func buy_market_item(item_template: ItemData) -> bool:
	if gold < item_template.gold_cost:
		print("Not enough gold!")
		return false

	var item_copy = item_template.duplicate(true)
	owned_items.append(item_copy)
	gold -= item_template.gold_cost
	emit_signal("resources_changed")
	emit_signal("soldiers_changed")
	print("Bought: %s" % item_copy.item_name)
	return true

func get_owned_items_for_slot(slot: String) -> Array[ItemData]:
	var valid_items: Array[ItemData] = []
	for item in owned_items:
		if slot == "armor" and item.item_type == ItemData.ItemType.ARMOR:
			valid_items.append(item)
		elif (slot == "weapon_1" or slot == "weapon_2") and item.item_type == ItemData.ItemType.WEAPON:
			valid_items.append(item)
	return valid_items

func unequip_item(soldier: SoldierData, slot: String) -> bool:
	var item = null
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

func get_item_owner_name(item: ItemData) -> String:
	if item == null:
		return ""

	for soldier in soldiers:
		if soldier.weapon_1 == item or soldier.weapon_2 == item or soldier.armor == item:
			return soldier.soldier_name
	return ""

func is_market_item_unlocked(item_template: ItemData) -> bool:
	return get_market_lock_reason(item_template) == ""

func get_market_lock_reason(item_template: ItemData) -> String:
	match item_template.item_name:
		"Iron Sword":
			if building_workers.get("Weapon Forge", 0) <= 0:
				return "Assign at least 1 worker to Weapon Forge to unlock forged weapons."
		"Steel Axe":
			if building_workers.get("Weapon Forge", 0) <= 0:
				return "Assign at least 1 worker to Weapon Forge to unlock heavy weapons."
			if building_workers.get("Steel Forge", 0) <= 0:
				return "Assign at least 1 worker to Steel Forge to unlock steel weapons."
		"Chainmail":
			if building_workers.get("Steel Forge", 0) <= 0:
				return "Assign at least 1 worker to Steel Forge to unlock medium armor."
		"Plate Armor":
			if building_workers.get("Steel Forge", 0) <= 0:
				return "Assign at least 1 worker to Steel Forge to unlock heavy armor."
			if building_workers.get("Weapon Forge", 0) <= 0:
				return "Assign at least 1 worker to Weapon Forge to finish advanced armor."
	return ""

func equip_owned_item(soldier: SoldierData, item: ItemData, slot: String) -> bool:
	if not owned_items.has(item):
		print("Item is not in inventory!")
		return false
	if slot == "armor" and item.item_type != ItemData.ItemType.ARMOR:
		return false
	if (slot == "weapon_1" or slot == "weapon_2") and item.item_type != ItemData.ItemType.WEAPON:
		return false

	var previous_item = null
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

	emit_signal("soldiers_changed")
	return true

func can_recruit_worker() -> Dictionary:
	if not is_building_built("House"):
		return {can = false, reason = "House not built."}
	if workforce_total >= workforce_cap:
		return {can = false, reason = "Workforce cap reached (%d/%d). Build more Houses to expand." % [workforce_total, workforce_cap]}
	if house_recruits_this_turn >= HOUSE_MAX_RECRUITS_PER_TURN:
		return {can = false, reason = "Recruit limit reached (%d/%d this turn)." % [house_recruits_this_turn, HOUSE_MAX_RECRUITS_PER_TURN]}
	if gold < HOUSE_RECRUIT_GOLD_COST:
		return {can = false, reason = "Need %d Gold (have %d)." % [HOUSE_RECRUIT_GOLD_COST, gold]}
	if food < HOUSE_RECRUIT_FOOD_COST:
		return {can = false, reason = "Need %d Food (have %d)." % [HOUSE_RECRUIT_FOOD_COST, food]}
	return {can = true, reason = ""}

func recruit_worker() -> bool:
	var check = can_recruit_worker()
	if not check.can:
		return false
	gold -= HOUSE_RECRUIT_GOLD_COST
	food -= HOUSE_RECRUIT_FOOD_COST
	workforce_total += 1
	workforce_available += 1
	house_recruits_this_turn += 1
	emit_signal("resources_changed")
	return true

func is_building_built(building_name: String) -> bool:
	return building_built_status.get(building_name, false)

func can_rebuild(building_name: String) -> Dictionary:
	var data = get_building_data(building_name)
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
	var data = get_building_data(building_name)
	if data == null:
		return false
	var check = can_rebuild(building_name)
	if not check.can:
		return false
	gold -= data.cost_gold
	wood -= data.cost_wood
	stone -= data.cost_stone
	building_built_status[building_name] = true
	if data.increases_population > 0:
		workforce_cap += data.increases_population
	emit_signal("resources_changed")
	return true

func get_building_data(building_name: String) -> BuildingData:
	return building_definitions.get(building_name) as BuildingData

func get_building_production(building_name: String, workers: int) -> Dictionary:
	var data = get_building_data(building_name)
	if data == null or workers <= 0:
		return {}
	return data.get_production_for_workers(workers)

var tavern_roster: Array[SoldierData] = []

func refresh_tavern_roster() -> void:
	tavern_roster.clear()
	var count = randi_range(3, 5)
	var classes = ["Warrior", "Archer", "Rogue", "Mage", "Knight"]
	var stat_bonus = tavern_workers_last_turn * 5

	for i in count:
		var soldier_class = classes[randi_range(0, classes.size() - 1)]
		var s = _generate_recruit(soldier_class, stat_bonus)
		tavern_roster.append(s)

func _generate_recruit(soldier_class: String, stat_bonus: int) -> SoldierData:
	var s = SoldierData.new()
	s.soldier_class = soldier_class
	s.soldier_name = _generate_name()
	s.level = 1
	s.hp_max = 80 + randi_range(0, 40 + stat_bonus)
	s.hp_current = s.hp_max
	s.power = 8 + randi_range(0, 6 + stat_bonus)
	s.speed = 4 + randi_range(0, 4 + stat_bonus)
	s.dexterity = 4 + randi_range(0, 4 + stat_bonus)

	# Boost stats bazat pe clasa
	match soldier_class:
		"Warrior":  s.power += 5;     s.hp_max += 20; s.hp_current = s.hp_max
		"Archer":   s.dexterity += 5; s.speed += 3
		"Rogue":    s.speed += 6;     s.dexterity += 4
		"Mage":     s.power += 8;     s.speed -= 1
		"Knight":   s.hp_max += 40;   s.hp_current = s.hp_max; s.speed -= 2

	# Unlock skill de baza al clasei imediat
	var class_skills = SkillLibrary.get_class_skills(soldier_class)
	for skill in class_skills:
		if skill.required_level <= 1:
			s.unlock_skill(skill)

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
		print("No room for more soldiers!")
		return false
	var cost = get_recruit_cost()
	if gold < cost:
		print("Not enough gold! Need %d" % cost)
		return false
	soldiers.append(soldier)
	tavern_roster.erase(soldier)
	gold -= cost
	emit_signal("soldiers_changed")
	emit_signal("resources_changed")
	return true

func get_recruit_cost() -> int:
	# Foloseste workers din tura trecuta, nu cei curenti
	var committed_innkeepers = tavern_workers_last_turn
	var tavern_data = get_building_data("Tavern")
	if tavern_data == null:
		return max(50, 100 - committed_innkeepers * 10)
	return max(
		tavern_data.recruit_min_cost,
		tavern_data.recruit_base_cost - committed_innkeepers * tavern_data.recruit_cost_reduction_per_worker
	)

func get_recruit_stat_bonus() -> int:
	# Bonus de stat foloseste de asemenea workers din tura trecuta
	var committed_innkeepers = tavern_workers_last_turn
	var tavern_data = get_building_data("Tavern")
	if tavern_data == null:
		return committed_innkeepers * 5
	return committed_innkeepers * tavern_data.recruit_stat_bonus_per_worker

func recruit_soldier(s_name: String) -> bool:
	if soldiers.size() >= get_max_soldiers():
		print("No room for more soldiers!")
		return false

	var cost = get_recruit_cost()
	if gold < cost:
		print("Not enough gold! Need %d" % cost)
		return false

	var stat_bonus = get_recruit_stat_bonus()  # ← foloseste committed workers

	var soldier = SoldierData.new()
	soldier.soldier_name = s_name
	soldier.hp_max = 80 + randi_range(0, 40 + stat_bonus)
	soldier.hp_current = soldier.hp_max
	soldier.power = 8 + randi_range(0, 6 + stat_bonus)
	soldier.speed = 4 + randi_range(0, 4 + stat_bonus)
	soldier.dexterity = 4 + randi_range(0, 4 + stat_bonus)

	soldiers.append(soldier)
	gold -= cost
	emit_signal("soldiers_changed")
	emit_signal("resources_changed")
	return true
	
func get_max_soldiers() -> int:
	var base = max_soldiers
	var barracks_data = get_building_data("Barracks")
	if barracks_data == null:
		return base
	var workers = building_workers.get("Barracks", 0)
	if workers > 0:
		base += barracks_data.soldier_capacity_bonus * workers
	return base

# --- SEMNALE ---
signal resources_changed
signal turn_ended(turn_number: int)
signal soldiers_changed
signal recap_ready
signal combat_started_from_turn
signal threat_updated


func assign_worker(building_name: String, amount: int) -> bool:
	if not building_workers.has(building_name):
		return false
	if not is_building_built(building_name):
		return false

	var current = building_workers.get(building_name, 0)
	var new_amount = current + amount

	if amount > 0 and workforce_available < amount:
		return false
	if new_amount < 0:
		return false
	if building_name == "Barracks" and amount < 0:
		var data = get_building_data("Barracks")
		if data != null:
			var base_capacity = max_soldiers
			var capacity_after = base_capacity + data.soldier_capacity_bonus * new_amount
			if soldiers.size() > capacity_after:
				return false

	building_workers[building_name] = new_amount
	workforce_available -= amount
	emit_signal("resources_changed")
	
	return true
	
func get_turns_until_next_battle() -> int:
	return turns_until_next_battle

func get_threat_forecast_text() -> String:
	if pending_enemy_wave.is_empty():
		return "Threat: None scheduled"
	var is_boss = combat_difficulty > 0 and combat_difficulty % 5 == 0
	var threat_type = " [BOSS WAVE!]" if is_boss else ""
	return "Threat: %s in %d turn%s | Difficulty %d | Enemies %d%s" % [
		pending_battle_source,
		turns_until_next_battle,
		"" if turns_until_next_battle == 1 else "s",
		combat_difficulty,
		pending_enemy_wave.size(),
		threat_type
	]

func _schedule_next_battle(initial_schedule: bool = false) -> void:
	if initial_schedule:
		combat_difficulty = 1
	else:
		combat_difficulty = max(1, int(float(current_turn) / 2.0) + 1)

	turns_until_next_battle = base_battle_interval
	pending_enemy_wave = EnemyData.make_random_wave(combat_difficulty)
	pending_battle_source = "Scheduled Wave"
	emit_signal("threat_updated")

func _advance_threat_schedule() -> bool:
	if pending_enemy_wave.is_empty():
		_schedule_next_battle()
		return false

	turns_until_next_battle -= 1
	if turns_until_next_battle <= 0:
		return true

	emit_signal("threat_updated")
	return false

func _start_pending_battle() -> void:
	if pending_enemy_wave.is_empty():
		_schedule_next_battle()

	var wave: Array[EnemyData] = []
	wave.assign(pending_enemy_wave)
	turn_recap.append("%s arrived! Difficulty %d, %d enemies." % [
		pending_battle_source,
		combat_difficulty,
		wave.size()
	])
	CombatState.start_combat(wave)
	pending_enemy_wave.clear()
	_schedule_next_battle()
	emit_signal("combat_started_from_turn")


# --- DUNGEON INTEGRATION ---
signal dungeon_expedition_ready  # emitted after end_turn phases so City_view can open dungeon

var tavern_workers_last_turn: int = 0
func end_turn() -> void:
	# Start dungeon expedition if soldiers were staged
	if not DungeonState.pending_soldiers.is_empty():
		DungeonState.start_expedition()

	tavern_workers_last_turn = building_workers.get("Tavern", 0)
	var resource_snapshot = _capture_resource_snapshot()
	turn_recap.clear()
	turn_recap.append("=== Turn %d Complete ===" % current_turn)

	# Show events deferred from previous turn
	if not _pending_event_recap.is_empty():
		for line in _pending_event_recap:
			turn_recap.append(line)
		_pending_event_recap.clear()

	_phase_production()
	_phase_training()
	_phase_upkeep()
	_phase_events()

	_build_resource_delta_summary(resource_snapshot)
	current_turn += 1

	var battle_starts_now = _advance_threat_schedule()
	if battle_starts_now:
		if DungeonState.active:
			_auto_resolve_city_defense()
		else:
			_start_pending_battle()
	else:
		turn_recap.append("")
		turn_recap.append(get_threat_forecast_text())
		emit_signal("turn_ended", current_turn)
		if not DungeonState.active:
			emit_signal("recap_ready")
		else:
			# Dungeon is active and no recap shown — clear pending event data so it
			# does not fire a stale popup on the next recap.
			_pending_event_data.clear()
	house_recruits_this_turn = 0
	refresh_tavern_roster()
	emit_signal("resources_changed")
	emit_signal("threat_updated")

	# Always open dungeon if active (city defense result shown after exit)
	if DungeonState.active:
		emit_signal("dungeon_expedition_ready")

func _auto_resolve_city_defense() -> void:
	var wave: Array[EnemyData] = []
	wave.assign(pending_enemy_wave)
	var wave_names: Array[String] = []
	for e in wave:
		wave_names.append(e.enemy_name)
	var defenders = soldiers.filter(func(s): return s.is_alive())

	turn_recap.append("")
	turn_recap.append("--- City Defense ---")
	turn_recap.append("%s attacked while soldiers were in the dungeon!" % pending_battle_source)

	var result = DungeonState.auto_resolve_city_defense(defenders, wave)
	result["wave_names"] = wave_names
	result["wave_source"] = pending_battle_source

	for line in result.log_lines:
		turn_recap.append(line)

	pending_enemy_wave.clear()
	_schedule_next_battle()

	if not result.victory:
		morale = max(0, morale - 15)
		turn_recap.append("City morale dropped! -15 Morale")

	emit_signal("soldiers_changed")
	_pending_city_defense_result = result
	_city_defense_replay_events = result.get("replay_events", [])

func continue_after_city_defense() -> void:
	emit_signal("turn_ended", current_turn)
	if DungeonState.active:
		emit_signal("dungeon_expedition_ready")
	else:
		emit_signal("recap_ready")

func _phase_upkeep() -> void:
	turn_recap.append("")
	turn_recap.append("--- Upkeep ---")
	_upkeep_soldiers_food()
	_upkeep_barracks()
	_phase_morale_combat_note()

func _upkeep_soldiers_food() -> void:
	if soldiers.is_empty():
		turn_recap.append("No soldiers to feed.")
		return
	var food_needed = soldiers.size() * SOLDIER_FOOD_UPKEEP
	if food >= food_needed:
		food -= food_needed
		turn_recap.append("Soldiers fed: -%d Food  (%d × %d)" % [food_needed, soldiers.size(), SOLDIER_FOOD_UPKEEP])
	else:
		var fed_count = int(float(food) / float(SOLDIER_FOOD_UPKEEP))
		var unfed_count = soldiers.size() - fed_count
		var morale_loss = unfed_count * MORALE_PENALTY_PER_UNFED_SOLDIER
		food = 0
		morale = max(0, morale - morale_loss)
		turn_recap.append("Food shortage! %d/%d soldiers unfed. Morale -%d." % [unfed_count, soldiers.size(), morale_loss])

func _upkeep_barracks() -> void:
	if not is_building_built("Barracks"):
		return
	var workers = building_workers.get("Barracks", 0)
	if workers <= 0:
		return
	var data = get_building_data("Barracks")
	if data == null or data.consumes_food <= 0:
		return
	var food_cost = data.consumes_food * workers
	if food >= food_cost:
		food -= food_cost
		turn_recap.append("Barracks upkeep: -%d Food" % food_cost)
	else:
		var shortage = food_cost - food
		food = 0
		morale = max(0, morale - 3)
		turn_recap.append("Barracks underfed (need %d Food, short %d). Morale -3." % [food_cost, shortage])

func _phase_production() -> void:
	turn_recap.append("")
	turn_recap.append("--- Production ---")
	_process_production()

func _phase_training() -> void:
	turn_recap.append("")
	turn_recap.append("--- Training ---")
	_process_training()

const EVENT_CHANCE: float = 0.40  # 40% sansa de eveniment per tura

const EVENTS: Array = [
	# --- BUNE ---
	{
		id = "wandering_merchant",
		title = "Wandering Merchant",
		description = "A traveling merchant stops in the city and trades at fair prices.",
		effects = [{"resource": "Gold", "amount": 60}],
		category = "good",
	},
	{
		id = "good_harvest",
		title = "Good Harvest",
		description = "Favorable weather blessed the fields this season.",
		effects = [{"resource": "Food", "amount": 25}],
		category = "good",
	},
	{
		id = "found_supplies",
		title = "Found Supplies",
		description = "Workers uncovered a cache of materials buried in the ruins.",
		effects = [{"resource": "Wood", "amount": 30}, {"resource": "Stone", "amount": 15}],
		category = "good",
	},
	{
		id = "morale_boost",
		title = "Inspiring Victory",
		description = "News of the prince's resolve spreads — the people's spirits rise.",
		effects = [{"resource": "Morale", "amount": 15}],
		category = "good",
	},
	{
		id = "king_gift",
		title = "Royal Dispatch",
		description = "The king sends a small supply caravan to aid the reconstruction.",
		effects = [{"resource": "Gold", "amount": 40}, {"resource": "Wood", "amount": 20}],
		category = "good",
	},
	# --- RELE ---
	{
		id = "bandit_raid",
		title = "Bandit Raid",
		description = "Bandits struck the city outskirts overnight and looted supplies.",
		effects = [{"resource": "Gold", "amount": -50}],
		category = "bad",
	},
	{
		id = "crop_blight",
		title = "Crop Blight",
		description = "A fungal blight swept through the fields, rotting the stores.",
		effects = [{"resource": "Food", "amount": -30}],
		category = "bad",
	},
	{
		id = "fire",
		title = "Workshop Fire",
		description = "A fire broke out in the lumber yard, destroying stockpiled wood.",
		effects = [{"resource": "Wood", "amount": -25}],
		category = "bad",
	},
	{
		id = "desertion",
		title = "Desertion",
		description = "Fear spreads through the ranks — two men slipped away in the night.",
		effects = [{"resource": "Morale", "amount": -10}],
		category = "bad",
	},
	{
		id = "monster_scout",
		title = "Monster Scouts Spotted",
		description = "Enemy scouts have been seen near the walls. The attack is coming sooner.",
		effects = [],
		category = "bad",
		force_early_combat = true,
	},
	# --- NEUTRE / STORYLINE ---
	{
		id = "refugees",
		title = "Refugees Arrive",
		description = "A group of survivors from a nearby village seeks shelter in the city.",
		effects = [{"resource": "Morale", "amount": 5}],
		category = "neutral",
	},
	{
		id = "king_message",
		title = "Message from the King",
		description = "\"Hold the city, my son. The kingdom watches. Do not fail us.\"",
		effects = [],
		category = "neutral",
	},
	{
		id = "strange_traveler",
		title = "Strange Traveler",
		description = "A hooded figure passes through, leaving a small pouch of gold coins behind.",
		effects = [{"resource": "Gold", "amount": 30}],
		category = "neutral",
	},
]

func _phase_morale_combat_note() -> void:
	if morale < 50:
		var penalty = int((50 - morale) * 0.2)
		turn_recap.append("Low Morale (%d) — soldiers suffer -%d%% hit chance in battle." % [morale, penalty])
	elif morale >= 75:
		turn_recap.append("High Morale (%d) — soldiers get +%d%% hit chance in battle." % [morale, int((morale - 50) * 0.2)])

func _phase_events() -> void:
	if randf() > EVENT_CHANCE:
		return

	var pool = EVENTS.duplicate()
	var event = pool[randi_range(0, pool.size() - 1)]

	# Apply effects immediately
	for effect in event.get("effects", []):
		var amount: int = effect.amount
		_apply_resource_delta(effect.resource, amount)

	if event.get("force_early_combat", false):
		turns_until_next_battle = max(1, turns_until_next_battle - 1)

	# Defer display to next turn's recap
	_pending_event_recap.append("")
	_pending_event_recap.append("--- Event (from previous turn) ---")

	var category_prefix = ""
	match event.get("category", "neutral"):
		"good":    category_prefix = "[+] "
		"bad":     category_prefix = "[!] "
		"neutral": category_prefix = "[~] "

	_pending_event_recap.append("%s%s" % [category_prefix, event.title])
	_pending_event_recap.append(event.description)

	for effect in event.get("effects", []):
		var amount: int = effect.amount
		var sign_str = "+" if amount >= 0 else ""
		_pending_event_recap.append("  %s%d %s" % [sign_str, amount, effect.resource])

	if event.get("force_early_combat", false):
		_pending_event_recap.append("  The enemy wave arrived 1 turn sooner!")

	_pending_event_data = event.duplicate()

#var sign = ""
func _process_production() -> void:
	var anything_produced = false
	for b_name in building_workers:
		var workers = building_workers[b_name]
		if workers <= 0:
			continue
		if not is_building_built(b_name):
			continue

		var prod = get_building_production(b_name, workers)
		if prod.is_empty():
			continue
		if not _can_apply_production(prod):
			var shortage = _get_production_shortage(prod)
			turn_recap.append("%s (%d workers): skipped, need %d %s but only have %d." % [
				b_name,
				workers,
				shortage.required,
				shortage.resource.to_lower(),
				shortage.current,
			])
			continue

		var line = "%s (%d workers): " % [b_name, workers]
		var parts: Array[String] = []
		for resource in prod:
			var amount = prod[resource]
			_apply_resource_delta(resource, amount)

			if amount != 0:
				var sign_p = "+" if amount >= 0 else ""
				parts.append("%s%d %s" % [sign_p, amount, resource])

		if not parts.is_empty():
			turn_recap.append(line + ", ".join(parts))
			anything_produced = true

	if not anything_produced:
		turn_recap.append("No production this turn — assign workers to buildings.")

func _can_apply_production(prod: Dictionary) -> bool:
	for resource in prod:
		var amount = prod[resource]
		if amount >= 0:
			continue
		var current_value = _get_resource_value(resource)
		if current_value + amount < 0:
			return false
	return true

func _get_production_shortage(prod: Dictionary) -> Dictionary:
	for resource in prod:
		var amount = prod[resource]
		if amount >= 0:
			continue
		var current_value = _get_resource_value(resource)
		var required_value = abs(amount)
		if current_value + amount < 0:
			return {resource = resource, current = current_value, required = required_value}
	return {resource = "resources", current = 0, required = 0}

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
			morale = clampi(morale + amount, 0, 100)

func _process_training() -> void:
	var training_data = get_building_data("Training Grounds")
	if training_data == null or soldiers.is_empty():
		turn_recap.append("No training this turn.")
		return

	var trainers = building_workers.get("Training Grounds", 0)
	if trainers <= 0 or training_data.training_xp_per_worker <= 0:
		turn_recap.append("No training this turn.")
		return

	var xp_per_soldier = trainers * training_data.training_xp_per_worker
	turn_recap.append("%s: +%d XP to all soldiers" % [training_data.building_name, xp_per_soldier])
	for soldier in soldiers:
		if not soldier.is_alive():
			continue
		var leveled_up = soldier.add_xp(xp_per_soldier)
		if leveled_up:
			turn_recap.append("  %s reached Level %d!" % [soldier.soldier_name, soldier.level])
			emit_signal("soldiers_changed")


func _capture_resource_snapshot() -> Dictionary:
	return {
		"Gold": gold,
		"Wood": wood,
		"Stone": stone,
		"Iron": iron,
		"Steel": steel,
		"Food": food,
		"Morale": morale,
	}

func _build_resource_delta_summary(start_snapshot: Dictionary) -> void:
	last_turn_resource_deltas.clear()
	var ordered_resources: Array[String] = ["Gold", "Wood", "Stone", "Iron", "Steel", "Food", "Morale"]

	for resource_name in ordered_resources:
		var start_value = start_snapshot.get(resource_name, 0)
		var end_value = _get_resource_value(resource_name)
		var delta = end_value - start_value
		last_turn_resource_deltas[resource_name] = delta

	_refresh_resource_delta_summary_line()

func add_post_turn_resource_delta(resource_name: String, amount: int) -> void:
	if amount == 0:
		return

	_apply_resource_delta(resource_name, amount)
	var current_delta = int(last_turn_resource_deltas.get(resource_name, 0))
	last_turn_resource_deltas[resource_name] = current_delta + amount
	_refresh_resource_delta_summary_line()

func _refresh_resource_delta_summary_line() -> void:
	var ordered_resources: Array[String] = ["Gold", "Wood", "Stone", "Iron", "Steel", "Food", "Morale"]
	var parts: Array[String] = []
	for resource_name in ordered_resources:
		var delta = int(last_turn_resource_deltas.get(resource_name, 0))
		if delta != 0:
			var sign_d = "+" if delta > 0 else ""
			parts.append("%s %s%d" % [resource_name, sign_d, delta])

	var summary_line = "Net resources gain: No net change"
	if not parts.is_empty():
		summary_line = "Net resources gain: " + " | ".join(parts)

	for i in range(turn_recap.size()):
		if turn_recap[i].begins_with("Resources:") or turn_recap[i].begins_with("Net resources gain:"):
			turn_recap[i] = summary_line
			return

	turn_recap.append(summary_line)

func _get_resource_value(resource_name: String) -> int:
	match resource_name:
		"Gold":
			return gold
		"Wood":
			return wood
		"Stone":
			return stone
		"Iron":
			return iron
		"Steel":
			return steel
		"Food":
			return food
		"Morale":
			return morale
		_:
			return 0
