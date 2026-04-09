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
var max_soldiers: int = 5

# --- UI STATE ---
var menu_open: bool = false
var in_city_view: bool = true


# --- RECAP ---
var turn_recap: Array[String] = []

# --- INVENTAR ---
var available_items: Array[ItemData] = []
var building_definitions: Dictionary = {}
var building_workers: Dictionary = {}

func _ready() -> void:
	_load_building_definitions()
	_populate_shop()

func _load_building_definitions() -> void:
	building_definitions.clear()
	var existing_workers := building_workers.duplicate()
	building_workers.clear()

	var dir := DirAccess.open("res://data/buildings")
	if dir == null:
		push_warning("Could not open res://data/buildings")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://data/buildings/%s" % file_name
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

func buy_item(item: ItemData, soldier: SoldierData, slot: String) -> bool:
	if gold < item.gold_cost:
		print("Not enough gold!")
		return false
	match slot:
		"weapon_1": soldier.weapon_1 = item
		"weapon_2": soldier.weapon_2 = item
		"armor":    soldier.armor = item
	gold -= item.gold_cost
	emit_signal("resources_changed")
	emit_signal("soldiers_changed")
	print("%s equipped %s" % [soldier.soldier_name, item.item_name])
	return true
	
func get_building_data(building_name: String) -> BuildingData:
	return building_definitions.get(building_name) as BuildingData

func get_building_production(building_name: String, workers: int) -> Dictionary:
	var data := get_building_data(building_name)
	if data == null or workers <= 0:
		return {}
	return data.get_production_for_workers(workers)

func get_recruit_cost() -> int:
	var tavern_data := get_building_data("Tavern")
	var innkeepers := building_workers.get("Tavern", 0)
	if tavern_data == null:
		return max(50, 100 - innkeepers * 10)
	return max(
		tavern_data.recruit_min_cost,
		tavern_data.recruit_base_cost - innkeepers * tavern_data.recruit_cost_reduction_per_worker
	)

func recruit_soldier(s_name: String) -> bool:
	if soldiers.size() >= max_soldiers:
		print("No room for more soldiers!")
		return false

	var tavern_data := get_building_data("Tavern")
	var innkeepers := building_workers.get("Tavern", 0)
	var cost := get_recruit_cost()
	if gold < cost:
		print("Not enough gold! Need %d" % cost)
		return false

	var stat_bonus := innkeepers * 5
	if tavern_data != null:
		stat_bonus = innkeepers * tavern_data.recruit_stat_bonus_per_worker

	var s = SoldierData.new()
	s.soldier_name = s_name
	s.hp_max    = 80 + randi_range(0, 40) + stat_bonus
	s.hp_current = s.hp_max
	s.power     = 8  + randi_range(0, 6) + stat_bonus
	s.speed     = 4  + randi_range(0, 4) + stat_bonus
	s.dexterity = 4  + randi_range(0, 4) + stat_bonus

	soldiers.append(s)
	gold -= cost
	emit_signal("soldiers_changed")
	emit_signal("resources_changed")
	print("Recruited: %s | HP:%d POW:%d SPD:%d DEX:%d" % [
		s.soldier_name, s.hp_max, s.power, s.speed, s.dexterity
	])
	return true
	
# --- PROGRES ---
var current_turn: int = 0

# --- SEMNALE ---
signal resources_changed
signal turn_ended(turn_number: int)
#signal scene_changed
signal soldiers_changed
signal recap_ready

func assign_worker(building_name: String, amount: int) -> void:
	if not building_workers.has(building_name):
		return

	var current = building_workers.get(building_name, 0)
	var new_amount = current + amount

	# Nu putem asigna mai mult decât avem disponibil
	if amount > 0 and workforce_available < amount:
		return
	# Nu putem scoate mai mult decât e asignat
	if new_amount < 0:
		return

	building_workers[building_name] = new_amount
	workforce_available -= amount
	emit_signal("resources_changed")
	
var turns_since_combat: int = 0
var combat_difficulty: int = 1

func end_turn() -> void:
	turn_recap.clear()
	turn_recap.append("=== Turn %d Complete ===" % current_turn)
	_process_production()
	_process_training()
	current_turn += 1
	turns_since_combat += 1
	print("turns_since_combat: ", turns_since_combat)
	emit_signal("resources_changed")
	
	if turns_since_combat >= 2:
		turns_since_combat = 0
		combat_difficulty = current_turn / 2 + 1
		print("Generating wave, difficulty: ", combat_difficulty)  # ← adaugă
		var wave = EnemyData.make_random_wave(combat_difficulty)
		print("Wave size: ", wave.size())  # ← adaugă
		turn_recap.append("Enemies approach the city!")
		print("Starting combat...")  # ← adaugă
		CombatState.start_combat(wave)
		emit_signal("combat_started_from_turn")
		print("Signal emitted")  # ← adaugă
	else:
		emit_signal("recap_ready")
		emit_signal("turn_ended", current_turn)

signal combat_started_from_turn



func _process_production() -> void:
	var anything_produced = false
	for b_name in building_workers:
		var workers = building_workers[b_name]
		if workers <= 0:
			continue

		var prod := get_building_production(b_name, workers)
		if prod.is_empty():
			continue
			
		var line = "%s (%d workers): " % [b_name, workers]
		var parts = []
		for resource in prod:
			var amount = prod[resource]
			if resource == "Wood":   wood  += amount
			if resource == "Stone":  stone += amount
			if resource == "Iron":   iron  += amount
			if resource == "Steel":  steel += amount
			if resource == "Food":   food  += amount
			if resource == "Gold":   gold  += amount
			if resource == "Morale": morale += amount
			
			if amount != 0:
				var sign = "+" if amount >= 0 else ""
				parts.append("%s%d %s" % [sign, amount, resource])
			
		if not parts.is_empty():
			turn_recap.append(line + ", ".join(parts))
			anything_produced = true
	if not anything_produced:
		turn_recap.append("No production this turn — assign workers to buildings.")


func _process_training() -> void:
	var training_data := get_building_data("Training Grounds")
	if training_data == null or soldiers.is_empty():
		return

	var trainers = building_workers.get("Training Grounds", 0)
	if trainers <= 0 or training_data.training_xp_per_worker <= 0:
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
