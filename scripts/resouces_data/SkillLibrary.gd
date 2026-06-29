# SkillLibrary.gd
class_name SkillLibrary

# Each class has 5 distinct skills: two Lv.1 "starters" (auto-learned on recruit,
# one passive + one active) and three higher skills gated by level and/or a base
# stat, learned at the dungeon Skill Trainer. A soldier equips up to 3 at a time.
static func get_all() -> Array[SkillData]:
	return [
		# =====================================================================
		# WARRIOR — frontline bruiser: cleaving, bleeding, rallying
		# =====================================================================
		_make("warrior_hardened", "Battle Hardened", SkillData.SkillType.PASSIVE, "Warrior",
			"Years of war have toughened body and resolve.",
			{defense_bonus = 3, hp_bonus = 20, required_level = 1}),

		_make("warrior_cleave", "Cleave", SkillData.SkillType.ACTIVE, "Warrior",
			"A wide swing that strikes every enemy at once.",
			{target_mode = SkillData.TargetMode.ENEMY_ALL, damage_multiplier = 0.8,
			 cooldown_turns = 3, required_level = 1}),

		_make("warrior_rend", "Rend", SkillData.SkillType.ACTIVE, "Warrior",
			"A brutal tearing blow that leaves the foe bleeding.",
			{damage_multiplier = 1.3, cooldown_turns = 2,
			 applies_status = "bleed", status_potency = 6, status_duration = 3,
			 req_power = 18}),

		_make("warrior_battlecry", "Battle Cry", SkillData.SkillType.ACTIVE, "Warrior",
			"A roar that sharpens every ally's aim.",
			{target_mode = SkillData.TargetMode.ALLY_ALL, cooldown_turns = 4,
			 applies_status = "rally", status_potency = 12, status_duration = 2,
			 required_level = 5}),

		_make("warrior_counter", "Counterattack", SkillData.SkillType.PASSIVE, "Warrior",
			"Punishes attackers with an immediate riposte.",
			{counter_chance = 0.40, req_power = 22}),

		# =====================================================================
		# KNIGHT — protector/tank: taunt, stun, party guard, last stand
		# =====================================================================
		_make("knight_wall", "Shield Wall", SkillData.SkillType.PASSIVE, "Knight",
			"A living fortress that shrugs off blows.",
			{defense_bonus = 8, hp_bonus = 30, speed_bonus = -2, damage_reduction = 3,
			 required_level = 1}),

		_make("knight_taunt", "Taunt", SkillData.SkillType.ACTIVE, "Knight",
			"Draws the enemy's fury and braces for impact.",
			{target_mode = SkillData.TargetMode.SELF, cooldown_turns = 3,
			 applies_status = "taunt", status_duration = 2, defense_bonus = 6,
			 required_level = 1}),

		_make("knight_bash", "Shield Bash", SkillData.SkillType.ACTIVE, "Knight",
			"Slams the shield forward, stunning the target.",
			{damage_multiplier = 1.2, cooldown_turns = 3,
			 applies_status = "stun", status_duration = 1,
			 req_power = 15}),

		_make("knight_guard", "Guard", SkillData.SkillType.ACTIVE, "Knight",
			"Raises shields across the whole party.",
			{target_mode = SkillData.TargetMode.ALLY_ALL, cooldown_turns = 5,
			 applies_status = "defense_up", status_potency = 5, status_duration = 2,
			 required_level = 5}),

		_make("knight_laststand", "Last Stand", SkillData.SkillType.PASSIVE, "Knight",
			"Refuses to fall — survives one killing blow each battle.",
			{last_stand = true, hp_bonus = 20, required_level = 10}),

		# =====================================================================
		# ARCHER — ranged precision: crits, crippling, volleys
		# =====================================================================
		_make("archer_eye", "Eagle Eye", SkillData.SkillType.PASSIVE, "Archer",
			"A hunter's gaze that finds the weak spot.",
			{hit_chance_bonus = 0.15, dexterity_bonus = 3, crit_chance = 0.10,
			 required_level = 1}),

		_make("archer_aimed", "Aimed Shot", SkillData.SkillType.ACTIVE, "Archer",
			"A patient shot that rarely misses and often crits.",
			{damage_multiplier = 1.6, hit_chance_bonus = 0.30, crit_chance = 0.25,
			 cooldown_turns = 3, required_level = 1}),

		_make("archer_cripple", "Crippling Shot", SkillData.SkillType.ACTIVE, "Archer",
			"An arrow to the leg that slows the target's movements.",
			{damage_multiplier = 1.0, cooldown_turns = 3,
			 applies_status = "slow", status_potency = 3, status_duration = 3,
			 req_dex = 18}),

		_make("archer_volley", "Volley", SkillData.SkillType.ACTIVE, "Archer",
			"A rain of arrows over the entire enemy line.",
			{target_mode = SkillData.TargetMode.ENEMY_ALL, damage_multiplier = 0.7,
			 cooldown_turns = 4, required_level = 7}),

		_make("archer_quickdraw", "Quick Draw", SkillData.SkillType.PASSIVE, "Archer",
			"Nocks and looses faster than the eye can follow.",
			{speed_bonus = 6, crit_chance = 0.05, req_speed = 25}),

		# =====================================================================
		# ROGUE — assassin: backstabs, poison, evasion
		# =====================================================================
		_make("rogue_shadow", "Shadow Step", SkillData.SkillType.PASSIVE, "Rogue",
			"Moves like smoke. Hard to pin down.",
			{dodge_bonus = 0.12, speed_bonus = 4, required_level = 1}),

		_make("rogue_backstab", "Backstab", SkillData.SkillType.ACTIVE, "Rogue",
			"A strike at the vitals — lethal against the wounded.",
			{damage_multiplier = 1.5, cooldown_turns = 3, crit_vs_wounded = true,
			 required_level = 1}),

		_make("rogue_poison", "Poison Blade", SkillData.SkillType.ACTIVE, "Rogue",
			"Coats the blade in venom that festers over time.",
			{damage_multiplier = 1.0, cooldown_turns = 2,
			 applies_status = "poison", status_potency = 5, status_duration = 3,
			 req_dex = 16}),

		_make("rogue_vanish", "Vanish", SkillData.SkillType.ACTIVE, "Rogue",
			"Slips into the shadows, near impossible to hit.",
			{target_mode = SkillData.TargetMode.SELF, cooldown_turns = 4,
			 applies_status = "dodge_up", status_potency = 40, status_duration = 2,
			 required_level = 5}),

		_make("rogue_opportunist", "Opportunist", SkillData.SkillType.PASSIVE, "Rogue",
			"Never lets a wounded foe escape.",
			{crit_vs_wounded = true, crit_chance = 0.10, req_dex = 22}),

		# =====================================================================
		# MAGE — caster: armor-piercing bolts, AoE control
		# =====================================================================
		_make("mage_focus", "Arcane Focus", SkillData.SkillType.PASSIVE, "Mage",
			"Channels arcane power into every strike.",
			{power_bonus = 8, hit_chance_bonus = 0.05, required_level = 1}),

		_make("mage_bolt", "Arcane Bolt", SkillData.SkillType.ACTIVE, "Mage",
			"Raw force that ignores armor entirely.",
			{damage_multiplier = 1.8, cooldown_turns = 3, ignores_defense = true,
			 required_level = 1}),

		_make("mage_firestorm", "Firestorm", SkillData.SkillType.ACTIVE, "Mage",
			"Engulfs all enemies in lingering flame.",
			{target_mode = SkillData.TargetMode.ENEMY_ALL, damage_multiplier = 0.9,
			 cooldown_turns = 5, applies_status = "burn", status_potency = 5, status_duration = 3,
			 req_power = 20}),

		_make("mage_frost", "Frost Nova", SkillData.SkillType.ACTIVE, "Mage",
			"A wave of cold that slows the whole enemy line.",
			{target_mode = SkillData.TargetMode.ENEMY_ALL, damage_multiplier = 0.5,
			 cooldown_turns = 5, applies_status = "slow", status_potency = 3, status_duration = 3,
			 required_level = 7}),

		_make("mage_ward", "Arcane Ward", SkillData.SkillType.PASSIVE, "Mage",
			"A protective weave that mends wounds each turn.",
			{regen_amount = 5, defense_bonus = 3, req_speed = 18}),
	]

static func get_class_skills(soldier_class: String) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in get_all():
		if skill.soldier_class == soldier_class:
			result.append(skill)
	return result

# Kept for compatibility; the revamp is fully class-based, so there are no
# generic universal skills.
static func get_universal_skills() -> Array[SkillData]:
	return []

static func get_skill_by_id(skill_id: String) -> SkillData:
	for skill in get_all():
		if skill.skill_id == skill_id:
			return skill
	return null

static func _make(id: String, sname: String, type: SkillData.SkillType,
				  sclass: String, desc: String, stats: Dictionary) -> SkillData:
	var s = SkillData.new()
	s.skill_id = id
	s.skill_name = sname
	s.skill_type = type
	s.soldier_class = sclass
	s.description = desc
	# Unlock requirements
	s.required_level = stats.get("required_level", 0)
	s.req_power      = stats.get("req_power", 0)
	s.req_speed      = stats.get("req_speed", 0)
	s.req_dex        = stats.get("req_dex", 0)
	s.req_hp         = stats.get("req_hp", 0)
	# Passive stat bonuses
	s.power_bonus       = stats.get("power_bonus", 0)
	s.speed_bonus       = stats.get("speed_bonus", 0)
	s.dexterity_bonus   = stats.get("dexterity_bonus", 0)
	s.defense_bonus     = stats.get("defense_bonus", 0)
	s.hp_bonus          = stats.get("hp_bonus", 0)
	s.hit_chance_bonus  = stats.get("hit_chance_bonus", 0.0)
	s.dodge_bonus       = stats.get("dodge_bonus", 0.0)
	# Passive triggers
	s.damage_reduction  = stats.get("damage_reduction", 0)
	s.regen_amount      = stats.get("regen_amount", 0)
	s.counter_chance    = stats.get("counter_chance", 0.0)
	s.lifesteal_pct     = stats.get("lifesteal_pct", 0.0)
	s.crit_chance       = stats.get("crit_chance", 0.0)
	s.crit_vs_wounded   = stats.get("crit_vs_wounded", false)
	s.last_stand        = stats.get("last_stand", false)
	# Active effects
	s.target_mode       = stats.get("target_mode", SkillData.TargetMode.ENEMY_SINGLE)
	s.damage_multiplier = stats.get("damage_multiplier", 1.0)
	s.cooldown_turns    = stats.get("cooldown_turns", 0)
	s.ignores_defense   = stats.get("ignores_defense", false)
	s.hits              = stats.get("hits", 1)
	s.heal_amount       = stats.get("heal_amount", 0)
	s.applies_status    = stats.get("applies_status", "")
	s.status_potency    = stats.get("status_potency", 0)
	s.status_duration   = stats.get("status_duration", 0)
	return s
