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
@export var dodge_bonus: float = 0.0
## Faction identifier: "valuiti", "iron_legion", or "" for generic/dungeon enemies.
@export var faction: String = ""
## One-line lore flavour displayed in the combat log.
@export var description: String = ""

# Combat-only runtime status (not serialized — reset each battle)
var status_effects: Array = []   # [{type:String, potency:int, duration:int}]
var shield_hp: int = 0

func is_alive() -> bool:
	return hp_current > 0

# Outgoing power, reduced by "weaken".
func get_effective_power() -> int:
	return max(1, power - get_status_potency("weaken"))

# Speed for turn order, reduced by "slow".
func get_effective_speed() -> int:
	return max(1, speed - get_status_potency("slow"))

# ---------------------------------------------------------------------------
# Combat status effects (runtime only) — mirrors SoldierData
# ---------------------------------------------------------------------------

func add_status(type: String, potency: int, duration: int) -> void:
	if type == "":
		return
	if type == "shield":
		shield_hp += potency
		return
	status_effects.append({type = type, potency = potency, duration = duration})

func has_status(type: String) -> bool:
	for st in status_effects:
		if st.type == type:
			return true
	return false

func get_status_potency(type: String) -> int:
	var v := 0
	for st in status_effects:
		if st.type == type:
			v += st.potency
	return v

# Applies DoT at the start of the enemy's turn. Returns log lines.
func apply_status_dot() -> Array:
	var logs: Array = []
	var dot := 0
	for st in status_effects:
		if st.type == "bleed" or st.type == "poison" or st.type == "burn":
			dot += st.potency
	if dot > 0 and is_alive():
		hp_current = max(0, hp_current - dot)
		logs.append("%s suffers %d from afflictions" % [enemy_name, dot])
	return logs

func advance_statuses() -> void:
	for st in status_effects:
		st.duration -= 1
	status_effects = status_effects.filter(func(st): return st.duration > 0)

func clear_combat_status() -> void:
	status_effects.clear()
	shield_hp = 0

# Enemy factory — creates an enemy instance by type
static func make_enemy_soldier() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Enemy Soldier"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 70; e.hp_current = 70
	e.power = 12; e.speed = 5; e.dexterity = 5
	e.gold_reward = 18; e.xp_reward = 30
	e.dodge_bonus = 0.05
	return e

static func make_boss(difficulty: int) -> EnemyData:
	var e = EnemyData.new()
	var tier = int(float(difficulty) / 5.0)
	var boss_names = ["Dark Captain", "Warlord Groth", "Iron Colossus", "Void Stalker", "Shadow King"]
	e.enemy_name = boss_names[mini(tier, boss_names.size() - 1)]
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 150 + tier * 80
	e.hp_current = e.hp_max
	e.power = 20 + tier * 8
	e.speed = 5 + tier * 1
	e.dexterity = 6 + tier * 1
	e.gold_reward = 50 + tier * 20
	e.xp_reward = 80 + tier * 30
	return e

# ---------------------------------------------------------------------------
# The Veiled — ancient stone/rune creatures from the Sevet below
# ---------------------------------------------------------------------------

static func make_valusit_seeker() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "The Seeker"
	e.enemy_type = EnemyType.MONSTER
	e.hp_max = 25; e.hp_current = 25
	e.power = 7; e.speed = 9; e.dexterity = 7
	e.gold_reward = 8; e.xp_reward = 12
	e.dodge_bonus = 0.10
	e.faction = "valuiti"
	e.description = "A shard of the Sevet, dispatched to sense warmth."
	return e

static func make_valusit_sentinel() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "The Sentinel"
	e.enemy_type = EnemyType.MONSTER
	e.hp_max = 120; e.hp_current = 120
	e.power = 16; e.speed = 2; e.dexterity = 1
	e.gold_reward = 15; e.xp_reward = 35
	e.dodge_bonus = 0.0
	e.faction = "valuiti"
	e.description = "Stone memory of an old guardian, awakened by vibration."
	return e

static func make_valusit_herald() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "The Herald"
	e.enemy_type = EnemyType.MONSTER
	e.hp_max = 60; e.hp_current = 60
	e.power = 11; e.speed = 5; e.dexterity = 4
	e.gold_reward = 25; e.xp_reward = 28
	e.dodge_bonus = 0.05
	e.faction = "valuiti"
	e.description = "A walker between the deep and the surface, older than the city above it."
	return e

static func make_valusit_boss(difficulty: int) -> EnemyData:
	var e = EnemyData.new()
	var tier = int(float(difficulty) / 5.0)
	e.enemy_name = "Veiled Shadow"
	e.enemy_type = EnemyType.MONSTER
	e.hp_max = 200 + tier * 100
	e.hp_current = e.hp_max
	e.power = 22 + tier * 10
	e.speed = 4 + tier
	e.dexterity = 5 + tier
	e.gold_reward = 60 + tier * 25
	e.xp_reward = 90 + tier * 35
	e.dodge_bonus = 0.0
	e.faction = "valuiti"
	e.description = "The deepest thing that can still be called awake."
	return e

# ---------------------------------------------------------------------------
# Iron Legion — disciplined human soldiers seeking the dungeon
# ---------------------------------------------------------------------------

static func make_legion_scout() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Legion Scout"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 35; e.hp_current = 35
	e.power = 8; e.speed = 8; e.dexterity = 6
	e.gold_reward = 10; e.xp_reward = 14
	e.dodge_bonus = 0.12
	e.faction = "iron_legion"
	e.description = "Sent ahead to mark the walls and count the windows."
	return e

static func make_legion_soldier() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Legion Soldier"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 75; e.hp_current = 75
	e.power = 13; e.speed = 5; e.dexterity = 4
	e.gold_reward = 18; e.xp_reward = 28
	e.dodge_bonus = 0.03
	e.faction = "iron_legion"
	e.description = "Trained since the age of twelve. Afraid of nothing he has been told to name."
	return e

static func make_legion_crossbowman() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Legion Crossbowman"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 45; e.hp_current = 45
	e.power = 10; e.speed = 6; e.dexterity = 8
	e.gold_reward = 14; e.xp_reward = 20
	e.dodge_bonus = 0.15
	e.faction = "iron_legion"
	e.description = "Does not close the gap. Makes the gap close you."
	return e

static func make_legion_captain() -> EnemyData:
	var e = EnemyData.new()
	e.enemy_name = "Legion Captain"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 90; e.hp_current = 90
	e.power = 17; e.speed = 6; e.dexterity = 6
	e.gold_reward = 30; e.xp_reward = 45
	e.dodge_bonus = 0.08
	e.faction = "iron_legion"
	e.description = "Every scar has a report filed to match it."
	return e

static func make_legion_boss(difficulty: int) -> EnemyData:
	var e = EnemyData.new()
	var tier = int(float(difficulty) / 5.0)
	e.enemy_name = "Colonel Hera" if difficulty <= 12 else "Legion Commander"
	e.enemy_type = EnemyType.SOLDIER
	e.hp_max = 180 + tier * 90
	e.hp_current = e.hp_max
	e.power = 20 + tier * 9
	e.speed = 5 + tier
	e.dexterity = 6 + tier
	e.gold_reward = 55 + tier * 22
	e.xp_reward = 85 + tier * 32
	e.dodge_bonus = 0.05
	e.faction = "iron_legion"
	e.description = "The Legion does not send its best. It sends enough."
	return e

# ---------------------------------------------------------------------------
# Display name helper
# ---------------------------------------------------------------------------

static func get_faction_display_name(faction_id: String) -> String:
	match faction_id:
		"valuiti":     return "The Veiled"
		"iron_legion": return "Iron Legion"
	return "Unknown"

# ---------------------------------------------------------------------------
# Scaling (applied to all non-boss enemy factories)
# ---------------------------------------------------------------------------

static func _scale_enemy(e: EnemyData, difficulty: int) -> EnemyData:
	var bonus = maxi(0, difficulty - 1)
	e.hp_max += bonus * 8
	e.hp_current = e.hp_max
	e.power += bonus * 2
	e.gold_reward += bonus * 2
	e.xp_reward += bonus * 3
	return e

# ---------------------------------------------------------------------------
# Wave generation — faction pools shift with difficulty
# ---------------------------------------------------------------------------

static func make_random_wave(difficulty: int) -> Array[EnemyData]:
	var wave: Array[EnemyData] = []
	var pool: Array[String] = []

	# Boss waves fire on every 5th difficulty; the faction alternates:
	#   5, 15, 25 … → Veiled boss
	#   10, 20, 30 … → Iron Legion boss
	var is_boss_wave: bool = difficulty > 0 and difficulty % 5 == 0

	if not is_boss_wave:
		if difficulty <= 2:
			# Early game: Sevet seeps to the surface
			pool = ["v_seeker", "v_seeker", "v_seeker", "v_sentinel"]
		elif difficulty <= 4:
			# Dungeon pressure + first Legion scouts
			pool = ["v_seeker", "v_seeker", "v_sentinel", "v_herald", "l_scout"]
		elif difficulty <= 8:
			# Both factions contest the city
			pool = ["v_sentinel", "v_herald", "l_soldier", "l_soldier", "l_crossbow"]
		elif difficulty <= 11:
			# Iron Legion dominant
			pool = ["l_soldier", "l_soldier", "l_captain", "l_crossbow", "v_herald"]
		else:
			# Heavy Legion + Veiled remnants
			pool = ["l_captain", "l_soldier", "l_soldier", "v_sentinel", "l_crossbow"]

	# Count occurrences of each type for unique numbering
	var type_counts: Dictionary = {}
	for entry in pool:
		type_counts[entry] = type_counts.get(entry, 0) + 1

	var type_index: Dictionary = {}
	for entry in pool:
		var enemy: EnemyData
		match entry:
			"v_seeker":   enemy = make_valusit_seeker()
			"v_sentinel": enemy = make_valusit_sentinel()
			"v_herald":   enemy = make_valusit_herald()
			"l_scout":    enemy = make_legion_scout()
			"l_soldier":  enemy = make_legion_soldier()
			"l_crossbow": enemy = make_legion_crossbowman()
			"l_captain":  enemy = make_legion_captain()
			"soldier":    enemy = make_enemy_soldier()
			_:            enemy = make_valusit_seeker()

		_scale_enemy(enemy, difficulty)

		if type_counts[entry] > 1:
			type_index[entry] = type_index.get(entry, 0) + 1
			enemy.enemy_name = "%s #%d" % [enemy.enemy_name, type_index[entry]]

		wave.append(enemy)

	if is_boss_wave:
		# Trim to 3 regular enemies then add the boss
		while wave.size() > 3:
			wave.pop_back()
		# Alternate faction boss: 5,15,25 → Veiled; 10,20,30 → Legion
		@warning_ignore("INTEGER_DIVISION")
		var boss_cycle: int = difficulty / 5
		if boss_cycle % 2 == 1:
			wave.append(make_valusit_boss(difficulty))
		else:
			wave.append(make_legion_boss(difficulty))
	else:
		while wave.size() > 4:
			wave.pop_back()

	# When Iron Legion standing is neutral or better (>20), replace any Legion units
	# that ended up in the pool with Valusit equivalents — the Legion is not attacking.
	if not is_boss_wave and FactionState.iron_legion_standing > 20:
		for i in pool.size():
			match pool[i]:
				"l_scout":   pool[i] = "v_seeker"
				"l_soldier": pool[i] = "v_sentinel"
				"l_crossbow": pool[i] = "v_herald"
				"l_captain":  pool[i] = "v_herald"

	# Iron Legion hostile effect: inject 1-2 Legion soldiers into every non-boss wave
	# when standing is Hostile (≤20). They supplement rather than replace the normal pool.
	if not is_boss_wave and FactionState.iron_legion_joins_waves:
		var legion_count: int = randi_range(1, 2)
		for i in legion_count:
			var interloper: EnemyData
			if difficulty <= 4:
				interloper = make_legion_scout()
			else:
				interloper = make_legion_soldier() if i == 0 else make_legion_crossbowman()
			_scale_enemy(interloper, difficulty)
			interloper.enemy_name = "[Legion] %s" % interloper.enemy_name
			wave.append(interloper)

	return wave
