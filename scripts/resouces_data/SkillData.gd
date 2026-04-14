# SkillData.gd
class_name SkillData
extends Resource

enum SkillType { PASSIVE, ACTIVE }
enum UnlockCondition { LEVEL, STAT_POWER, STAT_SPEED, STAT_DEX, STAT_HP }

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var description: String = ""
@export var skill_type: SkillType = SkillType.PASSIVE
@export var soldier_class: String = ""  # "Warrior", "Archer", etc. sau "" pentru universal

# Unlock conditions
@export var required_level: int = 0
@export var required_stat: UnlockCondition = UnlockCondition.LEVEL
@export var required_stat_value: int = 0

# Passive effects
@export var power_bonus: int = 0
@export var speed_bonus: int = 0
@export var dexterity_bonus: int = 0
@export var defense_bonus: int = 0
@export var hp_bonus: int = 0
@export var hit_chance_bonus: float = 0.0
@export var dodge_bonus: float = 0.0

# Active effects (folosite in combat)
@export var damage_multiplier: float = 1.0
@export var cooldown_turns: int = 0

func get_unlock_description() -> String:
	match required_stat:
		UnlockCondition.LEVEL:
			return "Unlocks at Level %d" % required_level
		UnlockCondition.STAT_POWER:
			return "Unlocks when POW reaches %d" % required_stat_value
		UnlockCondition.STAT_SPEED:
			return "Unlocks when SPD reaches %d" % required_stat_value
		UnlockCondition.STAT_DEX:
			return "Unlocks when DEX reaches %d" % required_stat_value
		UnlockCondition.STAT_HP:
			return "Unlocks when HP reaches %d" % required_stat_value
	return ""

func get_stats_display() -> String:
	var parts = []
	if power_bonus != 0:      parts.append("POW %+d" % power_bonus)
	if speed_bonus != 0:      parts.append("SPD %+d" % speed_bonus)
	if dexterity_bonus != 0:  parts.append("DEX %+d" % dexterity_bonus)
	if defense_bonus != 0:    parts.append("DEF %+d" % defense_bonus)
	if hp_bonus != 0:         parts.append("HP %+d" % hp_bonus)
	if hit_chance_bonus != 0: parts.append("HIT %+d%%" % int(hit_chance_bonus * 100))
	if dodge_bonus != 0:      parts.append("DODGE %+d%%" % int(dodge_bonus * 100))
	if damage_multiplier != 1.0: parts.append("DMG x%.1f" % damage_multiplier)
	return ", ".join(parts) if not parts.is_empty() else "No bonuses"
