# SoldierData.gd
class_name SoldierData
extends Resource

@export var soldier_name: String = "Unknown"
@export var level: int = 1
@export var experience: int = 0
@export var xp_to_next_level: int = 100

# Core stats
@export var hp_max: int = 100
@export var hp_current: int = 100
@export var power: int = 10
@export var speed: int = 5
@export var dexterity: int = 5

# Equipment slots
@export var weapon_1: String = ""
@export var weapon_2: String = ""
@export var armor: String = ""

# Skills
@export var skill_passive: String = ""
@export var skill_active: String = ""

# Traits
@export var traits: Array[String] = []

# Limb system
@export var hp_head: int = 30
@export var hp_left_arm: int = 25
@export var hp_right_arm: int = 25
@export var hp_legs: int = 40
var head_disabled: bool = false
var left_arm_disabled: bool = false
var right_arm_disabled: bool = false
var legs_disabled: bool = false

func is_alive() -> bool:
	return hp_current > 0 and not head_disabled

func get_display_name() -> String:
	return "%s (Lv.%d)" % [soldier_name, level]

func add_xp(amount: int) -> bool:
	# Returneaza true daca a dat level up
	experience += amount
	if experience >= xp_to_next_level:
		_level_up()
		return true
	return false

func _level_up() -> void:
	experience -= xp_to_next_level
	level += 1
	xp_to_next_level = 100 + (level - 1) * 50

	# Creste stats
	hp_max      += randi_range(8, 15)
	hp_current  = hp_max
	power       += randi_range(1, 3)
	speed       += randi_range(1, 2)
	dexterity   += randi_range(1, 2)

	# Creste si limb HP
	hp_head      += 5
	hp_left_arm  += 4
	hp_right_arm += 4
	hp_legs      += 6

	print("%s reached Level %d!" % [soldier_name, level])
	print("  HP:%d POW:%d SPD:%d DEX:%d" % [hp_max, power, speed, dexterity])
