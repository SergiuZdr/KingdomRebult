# TraitData.gd
class_name TraitData
extends Resource

enum TraitTrigger { COMBAT, LEVEL_UP }

@export var trait_id: String = ""
@export var trait_name: String = ""
@export var description: String = ""
@export var trigger: TraitTrigger = TraitTrigger.COMBAT

# Stat bonuses
@export var power_bonus: int = 0
@export var speed_bonus: int = 0
@export var dexterity_bonus: int = 0
@export var hp_bonus: int = 0
@export var defense_bonus: int = 0
@export var hit_chance_bonus: float = 0.0
@export var dodge_bonus: float = 0.0

# Conditii de obtinere entru combat traits
@export var required_kills: int = 0           # ucide X inamici intr-o lupta
@export var required_damage_dealt: int = 0    # da X damage intr-o lupta
@export var required_damage_taken: int = 0    # primeste X damage intr-o lupta
@export var required_level: int = 0           # level minim pentru level up traits
@export var survive_near_death: bool = false  # supravietuieste cu < 20% HP

func get_stats_display() -> String:
	var parts = []
	if power_bonus != 0:       parts.append("POW %+d" % power_bonus)
	if speed_bonus != 0:       parts.append("SPD %+d" % speed_bonus)
	if dexterity_bonus != 0:   parts.append("DEX %+d" % dexterity_bonus)
	if hp_bonus != 0:          parts.append("HP %+d" % hp_bonus)
	if defense_bonus != 0:     parts.append("DEF %+d" % defense_bonus)
	if hit_chance_bonus != 0:  parts.append("HIT %+d%%" % int(hit_chance_bonus * 100))
	if dodge_bonus != 0:       parts.append("DODGE %+d%%" % int(dodge_bonus * 100))
	return ", ".join(parts) if not parts.is_empty() else "No bonuses"
