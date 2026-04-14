# TraitChecker.gd
extends Node

signal trait_earned(soldier: SoldierData, soldier_trait: TraitData)

# Apelat dupa fiecare lupta
func check_combat_traits(soldier: SoldierData) -> void:
	if not soldier.is_alive():
		return
	for soldier_trait in TraitLibrary.get_all():
		if soldier_trait.trigger != TraitData.TraitTrigger.COMBAT:
			continue
		if soldier.has_trait(soldier_trait.trait_id):
			continue
		if _meets_combat_conditions(soldier, soldier_trait):
			_award_trait(soldier, soldier_trait)

# Apelat dupa fiecare level up
func check_level_traits(soldier: SoldierData) -> void:
	for lvl_trait in TraitLibrary.get_all():
		if lvl_trait.trigger != TraitData.TraitTrigger.LEVEL_UP:
			continue
		if soldier.has_trait(lvl_trait.trait_id):
			continue
		if _meets_level_conditions(soldier, lvl_trait):
			_award_trait(soldier, lvl_trait)

func _meets_combat_conditions(s: SoldierData, t: TraitData) -> bool:
	if t.required_kills > 0 and s.combat_kills < t.required_kills:
		return false
	if t.required_damage_dealt > 0 and s.combat_damage_dealt < t.required_damage_dealt:
		return false
	if t.required_damage_taken > 0 and s.combat_damage_taken < t.required_damage_taken:
		return false
	if t.survive_near_death and not s.combat_survived_near_death:
		return false
	return true

func _meets_level_conditions(s: SoldierData, t: TraitData) -> bool:
	if t.required_level > 0 and s.level < t.required_level:
		return false
	return true

func _award_trait(soldier: SoldierData, g_trait: TraitData) -> void:
	soldier.traits.append(g_trait)
	# Aplica HP bonus imediat
	if g_trait.hp_bonus > 0:
		soldier.hp_max += g_trait.hp_bonus
		soldier.hp_current += g_trait.hp_bonus
	GameState.turn_recap.append(
		"  %s earned trait: %s (%s)" % [
			soldier.soldier_name, g_trait.trait_name, g_trait.get_stats_display()
		]
	)
	emit_signal("trait_earned", soldier, g_trait)
	print("%s earned trait: %s" % [soldier.soldier_name, g_trait.trait_name])
