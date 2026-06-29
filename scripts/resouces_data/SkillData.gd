# SkillData.gd
class_name SkillData
extends Resource

enum SkillType { PASSIVE, ACTIVE }
enum TargetMode { ENEMY_SINGLE, ENEMY_ALL, SELF, ALLY_SINGLE, ALLY_ALL }

@export var skill_id: String = ""
@export var skill_name: String = ""
@export var description: String = ""
@export var skill_type: SkillType = SkillType.PASSIVE
@export var soldier_class: String = ""  # "Warrior", "Archer", etc. sau "" pentru universal

# Unlock conditions — all must be met (0 = no requirement)
@export var required_level: int = 0
@export var req_power: int = 0
@export var req_speed: int = 0
@export var req_dex: int = 0
@export var req_hp: int = 0

# Passive stat effects (apply while the skill is EQUIPPED)
@export var power_bonus: int = 0
@export var speed_bonus: int = 0
@export var dexterity_bonus: int = 0
@export var defense_bonus: int = 0
@export var hp_bonus: int = 0
@export var hit_chance_bonus: float = 0.0
@export var dodge_bonus: float = 0.0

# Passive combat triggers (equipped passives)
@export var damage_reduction: int = 0   # flat reduction to incoming damage
@export var regen_amount: int = 0        # heal at start of each of the soldier's turns
@export var counter_chance: float = 0.0  # chance to retaliate when struck
@export var lifesteal_pct: float = 0.0   # heal for this fraction of damage dealt
@export var crit_chance: float = 0.0     # added crit chance
@export var crit_vs_wounded: bool = false  # auto-crit vs targets below 50% HP
@export var last_stand: bool = false     # survive one lethal hit per battle at 1 HP

# Active effects (used in combat)
@export var target_mode: TargetMode = TargetMode.ENEMY_SINGLE
@export var damage_multiplier: float = 1.0
@export var cooldown_turns: int = 0
@export var ignores_defense: bool = false
@export var hits: int = 1                 # number of strikes per use
@export var heal_amount: int = 0          # flat heal applied to ally target(s)
# Status applied on use. One of:
#   bleed, poison, burn (DoT), stun, weaken, slow, blind, armor_break,
#   taunt, defense_up, rally, dodge_up, shield
@export var applies_status: String = ""
@export var status_potency: int = 0
@export var status_duration: int = 0

func is_offensive() -> bool:
	return target_mode == TargetMode.ENEMY_SINGLE or target_mode == TargetMode.ENEMY_ALL

func get_unlock_description() -> String:
	var parts: Array[String] = []
	if required_level > 0: parts.append("Lv.%d" % required_level)
	if req_power > 0: parts.append("STR %d" % req_power)
	if req_speed > 0: parts.append("INIT %d" % req_speed)
	if req_dex > 0:   parts.append("CUN %d" % req_dex)
	if req_hp > 0:    parts.append("HP %d" % req_hp)
	if parts.is_empty():
		return "No requirements"
	return "Requires " + ", ".join(parts)

func get_stats_display() -> String:
	var parts: Array[String] = []
	if power_bonus != 0:      parts.append("STR %+d" % power_bonus)
	if speed_bonus != 0:      parts.append("INIT %+d" % speed_bonus)
	if dexterity_bonus != 0:  parts.append("CUN %+d" % dexterity_bonus)
	if defense_bonus != 0:    parts.append("DEF %+d" % defense_bonus)
	if hp_bonus != 0:         parts.append("HP %+d" % hp_bonus)
	if hit_chance_bonus != 0: parts.append("HIT %+d%%" % int(hit_chance_bonus * 100))
	if dodge_bonus != 0:      parts.append("DODGE %+d%%" % int(dodge_bonus * 100))
	if damage_reduction != 0: parts.append("-%d dmg taken" % damage_reduction)
	if regen_amount != 0:     parts.append("regen %d/turn" % regen_amount)
	if counter_chance != 0:   parts.append("%d%% counter" % int(counter_chance * 100))
	if lifesteal_pct != 0:    parts.append("%d%% lifesteal" % int(lifesteal_pct * 100))
	if crit_chance != 0:      parts.append("%d%% crit" % int(crit_chance * 100))
	if crit_vs_wounded:       parts.append("crits the wounded")
	if last_stand:            parts.append("survives a killing blow")
	if damage_multiplier != 1.0: parts.append("DMG x%.1f" % damage_multiplier)
	if hits > 1:              parts.append("%d hits" % hits)
	if ignores_defense:       parts.append("ignores armor")
	if heal_amount > 0:       parts.append("heal %d" % heal_amount)
	if applies_status != "":
		var s := applies_status
		if status_potency > 0 and status_duration > 0:
			s += " %d/%dt" % [status_potency, status_duration]
		elif status_duration > 0:
			s += " %dt" % status_duration
		parts.append(s)
	return ", ".join(parts) if not parts.is_empty() else "No bonuses"
