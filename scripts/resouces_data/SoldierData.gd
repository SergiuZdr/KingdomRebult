# SoldierData.gd
class_name SoldierData
extends Resource

@export var soldier_name: String = "Unknown"
@export var sprite_variant: int = 1  # 1, 2, or 3
@export var level: int = 1
@export var experience: int = 0
@export var xp_to_next_level: int = 100
@export var unspent_stat_points: int = 0
@export var morale: int = 60
@export var unavailable_turns: int = 0
@export var temp_soldier_turns: int = 0  # 0 = permanent; >0 = leaves after N turns

# Core stats (player-allocated). UI labels: STRENGTH/INITIATIVE/CUNNING/HEALTH
@export var hp_max: int = 100
@export var hp_current: int = 100
@export var power: int = 10
@export var speed: int = 5
@export var dexterity: int = 5

# Equipment slots
@export var weapon_1: ItemData = null
@export var weapon_2: ItemData = null
@export var armor: ItemData = null

# Skills
@export var soldier_class: String = ""
@export var unlocked_skills: Array[SkillData] = []   # everything the soldier has learned
@export var equipped_skills: Array[SkillData] = []   # the (max 3) active loadout used in combat
var active_skill_cooldowns: Dictionary = {}

# Traits
@export var traits: Array[TraitData] = []

# Combat-only runtime state (NOT serialized — reset each battle)
var status_effects: Array = []   # [{type:String, potency:int, duration:int}]
var shield_hp: int = 0
var last_stand_used: bool = false

var combat_kills: int = 0
var combat_damage_dealt: int = 0
var combat_damage_taken: int = 0
var combat_survived_near_death: bool = false

# Each class favours two stats: points spent there are worth more.
const FAVORED := {
	"Warrior": ["power", "hp"],
	"Knight":  ["hp", "dexterity"],
	"Archer":  ["dexterity", "speed"],
	"Rogue":   ["speed", "dexterity"],
	"Mage":    ["power", "speed"],
}
# Skill slots unlock as the soldier reaches these levels.
const SLOT_LEVELS := [1, 5, 10]
const POINTS_PER_LEVEL := 3

# ---------------------------------------------------------------------------
# Derived stats (equipment + traits + equipped passives + combat statuses)
# ---------------------------------------------------------------------------

func get_total_power() -> int:
	var total = power
	for t in traits: total += t.power_bonus
	for skill in get_passive_skills(): total += skill.power_bonus
	total -= get_status_potency("weaken")
	return max(1, total)

func get_total_defense() -> int:
	var total = 0
	if armor: total += armor.defense
	for t in traits: total += t.defense_bonus
	for skill in get_passive_skills(): total += skill.defense_bonus
	total += get_status_potency("defense_up")
	total -= get_status_potency("armor_break")
	return max(0, total)

func get_total_speed() -> int:
	var total = speed
	if weapon_1: total += weapon_1.speed_bonus
	if weapon_2: total += weapon_2.speed_bonus
	if armor:    total += armor.speed_bonus
	for t in traits: total += t.speed_bonus
	for skill in get_passive_skills(): total += skill.speed_bonus
	total -= get_status_potency("slow")
	return max(1, total)

func get_total_dexterity() -> int:
	var total = dexterity
	if weapon_1: total += weapon_1.dexterity_bonus
	if weapon_2: total += weapon_2.dexterity_bonus
	if armor:    total += armor.dexterity_bonus
	for t in traits: total += t.dexterity_bonus
	for skill in get_passive_skills(): total += skill.dexterity_bonus
	return max(0, total)

func get_hit_chance_bonus() -> float:
	var bonus = 0.0
	if weapon_1: bonus += weapon_1.hit_chance_bonus
	if weapon_2: bonus += weapon_2.hit_chance_bonus
	for t in traits: bonus += t.hit_chance_bonus
	for skill in get_passive_skills(): bonus += skill.hit_chance_bonus
	bonus += float(get_status_potency("rally")) / 100.0
	bonus -= float(get_status_potency("blind")) / 100.0
	return bonus

func get_dodge_bonus() -> float:
	var bonus = 0.0
	for t in traits: bonus += t.dodge_bonus
	for skill in get_passive_skills(): bonus += skill.dodge_bonus
	bonus += float(get_status_potency("dodge_up")) / 100.0
	return bonus

func get_morale_hit_modifier() -> float:
	if morale >= 75: return 0.05
	if morale >= 50: return 0.0
	if morale >= 25: return -0.05
	return -0.10

func get_damage_range() -> Dictionary:
	if weapon_1:
		return {min = weapon_1.damage_min, max = weapon_1.damage_max}
	return {min = 3, max = 8}  # unarmed

# Passive combat-trigger aggregates (equipped passives only)
func get_crit_chance() -> float:
	var c := 0.0
	for s in get_passive_skills(): c += s.crit_chance
	return c

func has_crit_vs_wounded() -> bool:
	for s in get_passive_skills():
		if s.crit_vs_wounded: return true
	return false

func get_lifesteal() -> float:
	var v := 0.0
	for s in get_passive_skills(): v += s.lifesteal_pct
	return v

func get_counter_chance() -> float:
	var v := 0.0
	for s in get_passive_skills(): v = maxf(v, s.counter_chance)
	return v

func get_damage_reduction() -> int:
	var v := 0
	for s in get_passive_skills(): v += s.damage_reduction
	return v

func get_regen() -> int:
	var v := 0
	for s in get_passive_skills(): v += s.regen_amount
	return v

func has_last_stand() -> bool:
	for s in get_passive_skills():
		if s.last_stand: return true
	return false

# ---------------------------------------------------------------------------
# Stat allocation
# ---------------------------------------------------------------------------

func is_favored(stat: String) -> bool:
	return FAVORED.get(soldier_class, []).has(stat)

func point_value(stat: String) -> int:
	var fav := is_favored(stat)
	if stat == "hp":
		return 7 if fav else 5
	return 2 if fav else 1

func spend_stat_point(stat: String) -> bool:
	if unspent_stat_points <= 0:
		return false
	var v := point_value(stat)
	match stat:
		"power": power += v
		"speed": speed += v
		"dexterity": dexterity += v
		"hp":
			hp_max += v
			hp_current += v
		_:
			return false
	unspent_stat_points -= 1
	return true

# ---------------------------------------------------------------------------
# Skills — learn into the pool, equip up to 3 (slots unlock by level)
# ---------------------------------------------------------------------------

func max_skill_slots() -> int:
	var n := 0
	for lv in SLOT_LEVELS:
		if level >= lv:
			n += 1
	return n

func has_skill(skill_id: String) -> bool:
	for skill in unlocked_skills:
		if skill.skill_id == skill_id:
			return true
	return false

func is_equipped(skill_id: String) -> bool:
	for skill in equipped_skills:
		if skill.skill_id == skill_id:
			return true
	return false

func equip_skill(skill: SkillData) -> bool:
	if is_equipped(skill.skill_id):
		return false
	if equipped_skills.size() >= max_skill_slots():
		return false
	equipped_skills.append(skill)
	# Passive HP bonuses apply only while equipped.
	if skill.skill_type == SkillData.SkillType.PASSIVE and skill.hp_bonus > 0:
		hp_max += skill.hp_bonus
		hp_current += skill.hp_bonus
	return true

func unequip_skill(skill: SkillData) -> bool:
	var idx := -1
	for i in equipped_skills.size():
		if equipped_skills[i].skill_id == skill.skill_id:
			idx = i
			break
	if idx == -1:
		return false
	var s: SkillData = equipped_skills[idx]
	equipped_skills.remove_at(idx)
	if s.skill_type == SkillData.SkillType.PASSIVE and s.hp_bonus > 0:
		hp_max = max(1, hp_max - s.hp_bonus)
		hp_current = min(hp_current, hp_max)
	return true

func learn_skill(skill: SkillData) -> void:
	if has_skill(skill.skill_id):
		return
	unlocked_skills.append(skill)
	# Auto-equip into a free slot for convenience; player can re-arrange later.
	if equipped_skills.size() < max_skill_slots():
		equip_skill(skill)

# Auto-learns only the class starter skills (Lv.1, no stat gate). All other
# skills must be learned at the dungeon Skill Trainer once requirements are met.
func check_skill_unlocks() -> void:
	for skill in SkillLibrary.get_class_skills(soldier_class):
		if _is_starter(skill) and not has_skill(skill.skill_id):
			learn_skill(skill)

func _is_starter(skill: SkillData) -> bool:
	return skill.required_level <= 1 \
		and skill.req_power == 0 and skill.req_speed == 0 \
		and skill.req_dex == 0 and skill.req_hp == 0

# Checks unlock requirements against BASE allocated stats (what the player sees).
func meets_skill_conditions(skill: SkillData) -> bool:
	if skill.required_level > 0 and level < skill.required_level: return false
	if skill.req_power > 0 and power < skill.req_power: return false
	if skill.req_speed > 0 and speed < skill.req_speed: return false
	if skill.req_dex > 0 and dexterity < skill.req_dex: return false
	if skill.req_hp > 0 and hp_max < skill.req_hp: return false
	return true

func get_passive_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in equipped_skills:
		if skill.skill_type == SkillData.SkillType.PASSIVE:
			result.append(skill)
	return result

func get_active_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in equipped_skills:
		if skill.skill_type == SkillData.SkillType.ACTIVE:
			result.append(skill)
	return result

# ---------------------------------------------------------------------------
# Combat status effects (runtime only)
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

# Applies DoT and regen at the start of the soldier's turn. Returns log lines.
func apply_status_dot() -> Array:
	var logs: Array = []
	var dot := 0
	for st in status_effects:
		if st.type == "bleed" or st.type == "poison" or st.type == "burn":
			dot += st.potency
	if dot > 0 and is_alive():
		hp_current = max(0, hp_current - dot)
		combat_damage_taken += dot
		logs.append("%s suffers %d from afflictions" % [soldier_name, dot])
	var rg := get_regen()
	if rg > 0 and is_alive() and hp_current < hp_max:
		var healed = min(rg, hp_max - hp_current)
		hp_current += healed
		logs.append("%s recovers %d HP" % [soldier_name, healed])
	return logs

func advance_statuses() -> void:
	for st in status_effects:
		st.duration -= 1
	status_effects = status_effects.filter(func(st): return st.duration > 0)

func clear_combat_status() -> void:
	status_effects.clear()
	shield_hp = 0
	last_stand_used = false

# ---------------------------------------------------------------------------
# Traits
# ---------------------------------------------------------------------------

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

func get_max_morale() -> int:
	var cap := 100
	for t in traits:
		if t.max_morale_cap < cap:
			cap = t.max_morale_cap
	return cap

func is_alive() -> bool:
	return hp_current > 0

func get_display_name() -> String:
	return "%s (Lv.%d)" % [soldier_name, level]

func add_xp(amount: int) -> bool:
	# Returns true if the soldier leveled up.
	experience += amount
	if experience >= xp_to_next_level:
		_level_up()
		return true
	return false

func _level_up() -> void:
	experience -= xp_to_next_level
	level += 1
	xp_to_next_level = 100 + (level - 1) * 50
	# No automatic stat gains — the player allocates points manually.
	unspent_stat_points += POINTS_PER_LEVEL
	TraitChecker.check_level_traits(self)
	check_skill_unlocks()
