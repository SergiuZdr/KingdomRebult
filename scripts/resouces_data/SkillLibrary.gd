# SkillLibrary.gd
class_name SkillLibrary

static func get_all() -> Array[SkillData]:
	return [
		# =====================
		# WARRIOR — tanky, high damage
		# =====================
		_make("warrior_passive", "Battle Hardened", SkillData.SkillType.PASSIVE, "Warrior",
			"Years of combat have toughened this warrior.",
			{defense_bonus = 3, hp_bonus = 20,
			 required_level = 1}),

		_make("warrior_active", "Cleave", SkillData.SkillType.ACTIVE, "Warrior",
			"A powerful swing that hits harder than normal.",
			{damage_multiplier = 1.8, cooldown_turns = 3,
			 required_level = 1}),

		# =====================
		# ARCHER — high dex, ranged precision
		# =====================
		_make("archer_passive", "Eagle Eye", SkillData.SkillType.PASSIVE, "Archer",
			"Years of training have sharpened their aim.",
			{hit_chance_bonus = 0.15, dexterity_bonus = 3,
			 required_level = 1}),

		_make("archer_active", "Precise Shot", SkillData.SkillType.ACTIVE, "Archer",
			"A carefully aimed shot that never misses.",
			{damage_multiplier = 1.5, hit_chance_bonus = 0.3, cooldown_turns = 4,
			 required_level = 1}),

		# =====================
		# ROGUE — fast, dodge-focused
		# =====================
		_make("rogue_passive", "Shadow Step", SkillData.SkillType.PASSIVE, "Rogue",
			"Moves like a ghost. Hard to hit.",
			{dodge_bonus = 0.12, speed_bonus = 4,
			 required_level = 1}),

		_make("rogue_active", "Backstab", SkillData.SkillType.ACTIVE, "Rogue",
			"A swift strike from the shadows. Deadly.",
			{damage_multiplier = 2.2, cooldown_turns = 4,
			 required_level = 1}),

		# =====================
		# MAGE — glass cannon
		# =====================
		_make("mage_passive", "Arcane Focus", SkillData.SkillType.PASSIVE, "Mage",
			"Channels arcane energy into every strike.",
			{power_bonus = 8, hit_chance_bonus = 0.05,
			 required_level = 1}),

		_make("mage_active", "Arcane Burst", SkillData.SkillType.ACTIVE, "Mage",
			"Unleashes a burst of arcane power.",
			{damage_multiplier = 2.5, cooldown_turns = 5,
			 required_level = 1}),

		# =====================
		# KNIGHT — heavy armor, protector
		# =====================
		_make("knight_passive", "Shield Wall", SkillData.SkillType.PASSIVE, "Knight",
			"A living fortress. Takes hits others cannot.",
			{defense_bonus = 8, hp_bonus = 30, speed_bonus = -2,
			 required_level = 1}),

		_make("knight_active", "Shield Bash", SkillData.SkillType.ACTIVE, "Knight",
			"A powerful shield strike that stuns.",
			{damage_multiplier = 1.4, defense_bonus = 5, cooldown_turns = 3,
			 required_level = 1}),

		# =====================
		# UNIVERSAL — sblockable da orice clasa prin level/stats
		# =====================
		_make("power_strike", "Power Strike", SkillData.SkillType.ACTIVE, "",
			"A focused strike with maximum force.",
			{damage_multiplier = 1.6, cooldown_turns = 3,
			 required_level = 5}),

		_make("iron_will", "Iron Will", SkillData.SkillType.PASSIVE, "",
			"Refuses to fall. Survives against all odds.",
			{hp_bonus = 40, defense_bonus = 4,
			 required_stat = SkillData.UnlockCondition.STAT_HP,
			 required_stat_value = 150}),

		_make("swift_reflexes", "Swift Reflexes", SkillData.SkillType.PASSIVE, "",
			"Reacts faster than the eye can follow.",
			{speed_bonus = 6, dodge_bonus = 0.08,
			 required_stat = SkillData.UnlockCondition.STAT_SPEED,
			 required_stat_value = 20}),

		_make("killing_machine", "Killing Machine", SkillData.SkillType.PASSIVE, "",
			"Born to deal damage. Nothing else matters.",
			{power_bonus = 10, hit_chance_bonus = 0.08,
			 required_stat = SkillData.UnlockCondition.STAT_POWER,
			 required_stat_value = 35}),

		_make("phantom", "Phantom", SkillData.SkillType.PASSIVE, "",
			"Impossible to hit. A ghost on the battlefield.",
			{dodge_bonus = 0.18, speed_bonus = 5,
			 required_stat = SkillData.UnlockCondition.STAT_DEX,
			 required_stat_value = 25}),

		_make("warlord", "Warlord", SkillData.SkillType.ACTIVE, "",
			"A devastating attack only the most seasoned warriors can perform.",
			{damage_multiplier = 3.0, cooldown_turns = 6,
			 required_level = 10}),

		_make("fortitude", "Fortitude", SkillData.SkillType.PASSIVE, "",
			"Unbreakable will. Stat bonuses across the board.",
			{power_bonus = 4, defense_bonus = 4, hp_bonus = 30,
			 required_level = 8}),

		_make("death_blow", "Death Blow", SkillData.SkillType.ACTIVE, "",
			"One strike. Maximum damage. High risk.",
			{damage_multiplier = 2.8, hit_chance_bonus = -0.1, cooldown_turns = 5,
			 required_stat = SkillData.UnlockCondition.STAT_POWER,
			 required_stat_value = 40}),

		_make("evasion_master", "Evasion Master", SkillData.SkillType.PASSIVE, "",
			"Has mastered the art of not being hit.",
			{dodge_bonus = 0.20, dexterity_bonus = 5,
			 required_level = 7}),

		_make("berserker_rage", "Berserker Rage", SkillData.SkillType.ACTIVE, "",
			"Pure unbridled fury channeled into one attack.",
			{damage_multiplier = 2.0, cooldown_turns = 4,
			 required_stat = SkillData.UnlockCondition.STAT_POWER,
			 required_stat_value = 30}),
	]

static func get_class_skills(soldier_class: String) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in get_all():
		if skill.soldier_class == soldier_class:
			result.append(skill)
	return result

static func get_universal_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	for skill in get_all():
		if skill.soldier_class == "":
			result.append(skill)
	return result

static func _make(id: String, sname: String, type: SkillData.SkillType,
				  sclass: String, desc: String, stats: Dictionary) -> SkillData:
	var s = SkillData.new()
	s.skill_id = id
	s.skill_name = sname
	s.skill_type = type
	s.soldier_class = sclass
	s.description = desc
	s.power_bonus       = stats.get("power_bonus", 0)
	s.speed_bonus       = stats.get("speed_bonus", 0)
	s.dexterity_bonus   = stats.get("dexterity_bonus", 0)
	s.defense_bonus     = stats.get("defense_bonus", 0)
	s.hp_bonus          = stats.get("hp_bonus", 0)
	s.hit_chance_bonus  = stats.get("hit_chance_bonus", 0.0)
	s.dodge_bonus       = stats.get("dodge_bonus", 0.0)
	s.damage_multiplier = stats.get("damage_multiplier", 1.0)
	s.cooldown_turns    = stats.get("cooldown_turns", 0)
	s.required_level    = stats.get("required_level", 0)
	s.required_stat     = stats.get("required_stat", SkillData.UnlockCondition.LEVEL)
	s.required_stat_value = stats.get("required_stat_value", 0)
	return s
