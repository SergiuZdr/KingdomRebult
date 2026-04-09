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

func _ready() -> void:
	_populate_shop()

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
	
func recruit_soldier(s_name: String, innkeeper_bonus: int = 0) -> bool:
	if soldiers.size() >= max_soldiers:
		print("No room for more soldiers!")
		return false
	var cost = max(50, 100 - innkeeper_bonus * 10)
	if gold < cost:
		print("Not enough gold! Need %d" % cost)
		return false

	var bonus = innkeeper_bonus * 2
	var s = SoldierData.new()
	s.soldier_name = s_name
	s.hp_max    = 80 + randi_range(0 + bonus, 40 + bonus)
	s.hp_current = s.hp_max
	s.power     = 8  + randi_range(0 + bonus, 6  + bonus)
	s.speed     = 4  + randi_range(0 + bonus , 4  + bonus)
	s.dexterity = 4  + randi_range(0 + bonus, 4  + bonus)

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

# --- CLĂDIRI ACTIVE ---
# Cheia e numele clădirii, valoarea e câți muncitori sunt asignați
var building_workers: Dictionary = {
	"Forest":          0,
	"Quarry":          0,
	"Iron Mine":       0,
	"Farm":            0,
	"Steel Forge":     0,
	"Market":          0,
	"Butchery":        0,
	"Weapon Forge":    0,
	"Tavern":          0,
	"Training Grounds":0,
	"Barracks":        0,
}

const PRODUCTION: Dictionary = {
	"Forest":        {"Wood": 10},
	"Quarry":        {"Stone": 8},
	"Iron Mine":     {"Iron": 6},
	"Farm":          {"Food": 12},
	"Steel Forge":   {"Steel": 3, "Iron":-9},
	"Market":        {"Gold": 25},
	"Butchery":      {"Food": -5, "Gold": 15},
	"Weapon Forge":  {"Gold": -10, "Steel": -2},
	"Tavern":        {"Gold": 30},
	"Training Grounds": {},
	"Barracks":      {},
}

# --- SEMNALE ---
signal resources_changed
signal turn_ended(turn_number: int)
#signal scene_changed
signal soldiers_changed
signal recap_ready

func assign_worker(building_name: String, amount: int) -> void:
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
		if not PRODUCTION.has(b_name):
			continue
		var prod = PRODUCTION[b_name]
		if prod.is_empty():
			continue
			
		var line = "%s (%d workers): " % [b_name, workers]
		var parts = []
		for resource in prod:
			var amount = prod[resource] * workers
			if resource == "Wood":   wood  += amount
			if resource == "Stone":  stone += amount
			if resource == "Iron":   iron  += amount
			if resource == "Steel":  steel += amount
			if resource == "Food":   food  += amount
			if resource == "Gold":   gold  += amount
			
			if amount != 0:
				var sign = "+" if amount >= 0 else ""
				parts.append("%s%d %s" % [sign, amount, resource])
			
		if not parts.is_empty():
			turn_recap.append(line + ", ".join(parts))
			anything_produced = true
	if not anything_produced:
		turn_recap.append("No production this turn — assign workers to buildings.")


func _process_training() -> void:
	var trainers = building_workers.get("Training Grounds", 0)
	if trainers <= 0 or soldiers.is_empty():
		return

	var xp_per_soldier = trainers * 10
	turn_recap.append("Training Ground: +%d XP to all soldiers" % xp_per_soldier)
	for soldier in soldiers:
		if not soldier.is_alive():
			continue
		var leveled_up = soldier.add_xp(xp_per_soldier)
		if leveled_up:
			turn_recap.append("  %s reached Level %d!" % [soldier.soldier_name, soldier.level])
			emit_signal("soldiers_changed")
