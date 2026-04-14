# EnemyData.gd
class_name EnemyData
extends Resource

enum EnemyType { MONSTER, ANIMAL, SOLDIER }

@export var enemy_name: String = "Enemy"
@export var enemy_type: EnemyType = EnemyType.MONSTER
@export var hp_max: int = 50
@export var hp_current: int = 50
@export var power: int = 8
@export var speed: int = 4
@export var dexterity: int = 3
@export var gold_reward: int = 20
@export var xp_reward: int = 15

func is_alive() -> bool:
	return hp_current > 0

func take_damage(amount: int) -> int:
	var actual = min(amount, hp_current)
	hp_current -= actual
	return actual

# Fabrica de inamici — genereaza un inamic dupa tip
static func make_goblin() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Goblin"
	e.enemy_type = EnemyType.MONSTER
	e.hp_max = 30; e.hp_current = 30
	e.power = 6; e.speed = 6; e.dexterity = 5
	e.gold_reward = 15; e.xp_reward = 10
	return e

static func make_orc() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Orc"
	e.enemy_type = EnemyType.MONSTER
	e.hp_max = 80; e.hp_current = 80
	e.power = 14; e.speed = 3; e.dexterity = 2
	e.gold_reward = 30; e.xp_reward = 25
	return e

static func make_wolf() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Wolf"
	e.enemy_type = EnemyType.ANIMAL
	e.hp_max = 50; e.hp_current = 50
	e.power = 10; e.speed = 8; e.dexterity = 6
	e.gold_reward = 10; e.xp_reward = 15
	return e

static func make_enemy_soldier() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Enemy Soldier"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 70; e.hp_current = 70
	e.power = 12; e.speed = 5; e.dexterity = 5
	e.gold_reward = 40; e.xp_reward = 30
	return e

static func make_random_wave(difficulty: int) -> Array[EnemyData]:
	var wave: Array[EnemyData] = []
	var pool = ["goblin", "goblin", "wolf", "orc", "soldier"]
	if difficulty <= 1:
		pool = ["goblin", "goblin", "goblin", "wolf", "goblin"]
	elif difficulty <= 3:
		pool = ["goblin", "wolf", "orc", "goblin", "wolf"]
	else:
		pool = ["orc", "soldier", "wolf", "orc", "soldier"]

	# Numara aparitiile fiecarui tip
	var type_counts: Dictionary = {}
	for type in pool:
		type_counts[type] = type_counts.get(type, 0) + 1

	# Genereaza cu nume unice doar pentru tipurile care apar de mai multe ori
	var type_index: Dictionary = {}
	for type in pool:
		var enemy: EnemyData
		match type:
			"goblin":  enemy = make_goblin()
			"orc":     enemy = make_orc()
			"wolf":    enemy = make_wolf()
			"soldier": enemy = make_enemy_soldier()
			_:         enemy = make_goblin()

		if type_counts[type] > 1:
			type_index[type] = type_index.get(type, 0) + 1
			enemy.enemy_name = "%s #%d" % [enemy.enemy_name, type_index[type]]

		wave.append(enemy)

	return wave
