# GameState.gd
extends Node

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

# --- PROGRES ---
var current_turn: int = 0
var combat_difficulty: int = 1
var turns_until_next_battle: int = 2
var base_battle_interval: int = 2
var pending_enemy_wave: Array[EnemyData] = []
var pending_battle_source: String = "Scheduled Wave"
var last_turn_resource_deltas: Dictionary = {}

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
	var innkeepers = building_workers.get("Tavern", 0)
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
			var capacity_after = base_capacity
			if new_amount > 0:
				capacity_after = base_capacity + data.soldier_capacity_bonus
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
	return "Threat: %s in %d turn%s | Difficulty %d | Enemies %d" % [
		pending_battle_source,
		turns_until_next_battle,
		"" if turns_until_next_battle == 1 else "s",
		combat_difficulty,
		pending_enemy_wave.size()
	]

func _schedule_next_battle(initial_schedule: bool = false) -> void:
	if initial_schedule:
		combat_difficulty = 1
	else:
		combat_difficulty = max(1, int(current_turn / 2) + 1)

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

	var wave = pending_enemy_wave.duplicate()
	turn_recap.append("%s arrived! Difficulty %d, %d enemies." % [
		pending_battle_source,
		combat_difficulty,
		wave.size()
	])
	CombatState.start_combat(wave)
	pending_enemy_wave.clear()
	_schedule_next_battle()
	emit_signal("combat_started_from_turn")


var tavern_workers_last_turn: int = 0
func end_turn() -> void:
	tavern_workers_last_turn = building_workers.get("Tavern", 0)
	var resource_snapshot = _capture_resource_snapshot()
	turn_recap.clear()
	turn_recap.append("=== Turn %d Complete ===" % current_turn)
	turn_recap.append("Production:")
	_process_production()
	turn_recap.append("")
	turn_recap.append("Training:")
	_process_training()
	turn_recap.append("")
	_build_resource_delta_summary(resource_snapshot)
	turn_recap.append("")
	current_turn += 1

	var battle_starts_now = _advance_threat_schedule()
	if battle_starts_now:
		_start_pending_battle()
	else:
		turn_recap.append(get_threat_forecast_text())
		emit_signal("recap_ready")
		emit_signal("turn_ended", current_turn)
	tavern_workers_last_turn = building_workers.get("Tavern", 0)
	refresh_tavern_roster()
	emit_signal("resources_changed")
	emit_signal("threat_updated")

#var sign = ""
func _process_production() -> void:
	var anything_produced = false
	for b_name in building_workers:
		var workers = building_workers[b_name]
		if workers <= 0:
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
			wood += amount
		"Stone":
			stone += amount
		"Iron":
			iron += amount
		"Steel":
			steel += amount
		"Food":
			food += amount
		"Gold":
			gold += amount
		"Morale":
			morale += amount

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
