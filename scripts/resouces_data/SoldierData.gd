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
@export var weapon_1: ItemData = null
@export var weapon_2: ItemData = null
@export var armor: ItemData = null

func get_total_power() -> int:
	var total = power
	if weapon_1: total += weapon_1.power_bonus
	if weapon_2: total += weapon_2.power_bonus
	for t in traits: total += t.power_bonus
	for skill in get_passive_skills(): total += skill.power_bonus
	return total

func get_total_defense() -> int:
	var total = 0
	if armor: total += armor.defense
	for t in traits: total += t.defense_bonus
	for skill in get_passive_skills(): total += skill.defense_bonus
	return total

func get_total_speed() -> int:
	var total = speed
	if weapon_1: total += weapon_1.speed_bonus
	if weapon_2: total += weapon_2.speed_bonus
	if armor:    total += armor.speed_bonus
	for t in traits: total += t.speed_bonus
	for skill in get_passive_skills(): total += skill.speed_bonus
	return max(1, total)

func get_hit_chance_bonus() -> float:
	var bonus = 0.0
	if weapon_1: bonus += weapon_1.hit_chance_bonus
	if weapon_2: bonus += weapon_2.hit_chance_bonus
	for t in traits: bonus += t.hit_chance_bonus
	for skill in get_passive_skills(): bonus += skill.hit_chance_bonus
	return bonus

func get_dodge_bonus() -> float:
	var bonus = 0.0
	for t in traits: bonus += t.dodge_bonus
	for skill in get_passive_skills(): bonus += skill.dodge_bonus
	return bonus

func get_damage_range() -> Dictionary:
	if weapon_1:
		return {min = weapon_1.damage_min, max = weapon_1.damage_max}
	return {min = 3, max = 8}  # unarmed

# Skills
@export var soldier_class: String = ""
@export var unlocked_skills: Array[SkillData] = []
var active_skill_cooldowns: Dictionary = {}

func has_skill(skill_id: String) -> bool:
	for skill in unlocked_skills:
		if skill.skill_id == skill_id:
			return true
	return false

func unlock_skill(skill: SkillData) -> void:
	if has_skill(skill.skill_id):
		return
	unlocked_skills.append(skill)
	if skill.hp_bonus > 0:
		hp_max += skill.hp_bonus
		hp_current += skill.hp_bonus
	print("%s unlocked skill: %s" % [soldier_name, skill.skill_name])

func check_skill_unlocks() -> void:
	var all_skills = SkillLibrary.get_class_skills(soldier_class)
	all_skills.append_array(SkillLibrary.get_universal_skills())
	for skill in all_skills:
		if has_skill(skill.skill_id):
			continue
		if _meets_skill_conditions(skill):
			unlock_skill(skill)

func _meets_skill_conditions(skill: SkillData) -> bool:
	if skill.required_level > 0 and level < skill.required_level:
		return false
	match skill.required_stat:
		SkillData.UnlockCondition.STAT_POWER:
			if get_total_power() < skill.required_stat_value:
				return false
		SkillData.UnlockCondition.STAT_SPEED:
			if get_total_speed() < skill.required_stat_value:
				return false
		SkillData.UnlockCondition.STAT_DEX:
			if dexterity < skill.required_stat_value:
				return false
		SkillData.UnlockCondition.STAT_HP:
			if hp_max < skill.required_stat_value:
				return false
	return true

func get_passive_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in unlocked_skills:
		if skill.skill_type == SkillData.SkillType.PASSIVE:
			result.append(skill)
	return result

func get_active_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in unlocked_skills:
		if skill.skill_type == SkillData.SkillType.ACTIVE:
			result.append(skill)
	return result

# Traits
@export var traits: Array[TraitData] = []

var combat_kills: int = 0
var combat_damage_dealt: int = 0
var combat_damage_taken: int = 0
var combat_survived_near_death: bool = false

func reset_combat_stats() -> void:
	combat_kills = 0
	combat_damage_dealt = 0
	combat_damage_taken = 0
	combat_survived_near_death = false

func has_trait(trait_id: String) -> bool:
	for soldier_trait in traits:
		if soldier_trait.trait_id == trait_id:
			return true
	return false

# Limb system
#@export var hp_head: int = 30
#@export var hp_left_arm: int = 25
#@export var hp_right_arm: int = 25
#@export var hp_legs: int = 40
#
#var head_disabled: bool = false
#var left_arm_disabled: bool = false
#var right_arm_disabled: bool = false
#var legs_disabled: bool = false

func is_alive() -> bool:
	return hp_current > 0 #and not head_disabled

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
	hp_max      += randi_range(5, 10)
	hp_current  = hp_max
	power       += randi_range(1, 3)
	speed       += randi_range(1, 2)
	dexterity   += randi_range(1, 2)
	
	# Creste si limb HP
	#hp_head      += 5
	#hp_left_arm  += 4
	#hp_right_arm += 4
	#hp_legs      += 6

	print("%s reached Level %d!" % [soldier_name, level])
	print("  HP:%d POW:%d SPD:%d DEX:%d" % [hp_max, power, speed, dexterity])
	TraitChecker.check_level_traits(self)  
	TraitChecker.check_level_traits(self)
	check_skill_unlocks()
