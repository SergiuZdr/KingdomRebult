# CombatState.gd
extends Node

var active: bool = false
var turn_number: int = 0
var current_unit_index: int = 0
var turn_order: Array = []

var allies: Array[SoldierData] = []
var enemies: Array[EnemyData] = []

var selected_action: String = "Attack"
var selected_target = null  # EnemyData sau SoldierData

var combat_log: Array[String] = []
var gold_earned: int = 0
var xp_earned: int = 0

signal combat_started
signal turn_changed(unit)
signal unit_acted(log_line: String)
signal combat_ended(victory: bool)

func start_combat(enemy_wave: Array[EnemyData]) -> void:
	active = true
	turn_number = 1
	combat_log.clear()
	gold_earned = 0
	xp_earned = 0
	allies = GameState.soldiers.filter(func(s): return s.is_alive())
	enemies = enemy_wave
	_build_turn_order()
	combat_log.append("— Combat started —")
	emit_signal("combat_started")
	_next_turn()

func _build_turn_order() -> void:
	turn_order.clear()
	var all = []
	for a in allies:
		all.append({unit = a, is_ally = true, speed_roll = a.speed + randi_range(0, 3)})
	for e in enemies:
		all.append({unit = e, is_ally = false, speed_roll = e.speed + randi_range(0, 3)})
	all.sort_custom(func(a, b): return a.speed_roll > b.speed_roll)
	turn_order = all
	current_unit_index = 0


func _enemy_act(enemy: EnemyData) -> void:
	var alive_allies = allies.filter(func(a): return a.is_alive())
	if alive_allies.is_empty():
		_check_combat_end()
		return

	var target: SoldierData = alive_allies[randi_range(0, alive_allies.size() - 1)]
	
	var hit_chance = 0.7 + (enemy.dexterity - target.get_total_speed()) * 0.03
	hit_chance = clamp(hit_chance, 0.15, 0.95)
	var hit = randf() < hit_chance

	if hit:
		var raw_dmg = enemy.power + randi_range(-3, 3)
		var final_dmg = max(1, raw_dmg - target.get_total_defense())
		target.hp_current = max(0, target.hp_current - final_dmg)
		combat_log.append("%s attacks %s for %d dmg" % [enemy.enemy_name, target.soldier_name, final_dmg])
	else:
		combat_log.append("%s attacks %s — MISS" % [enemy.enemy_name, target.soldier_name])

	emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()
func player_act(action: String, target) -> void:
	if current_unit_index >= turn_order.size():
		return
	var current_entry = turn_order[current_unit_index]
	if not current_entry.is_ally:
		return

	var actor: SoldierData = current_entry.unit

	match action:
		"Attack":
			if target == null or not target is EnemyData:
				return
			# Foloseste damage range din arma
			var dmg_range = actor.get_damage_range()
			var base_dmg = randi_range(dmg_range.min, dmg_range.max)
			var result = _calculate_hit_soldier(actor, target)
			if result.hit:
				# Scade defense-ul armurii
				var final_dmg = max(1, base_dmg)
				target.hp_current = max(0, target.hp_current - final_dmg)
				combat_log.append("%s attacks %s for %d dmg" % [
					actor.soldier_name, target.enemy_name, final_dmg
					])
			else:
				combat_log.append("%s attacks %s — MISS" % [
					actor.soldier_name, target.enemy_name
				])
		"Defend":
			combat_log.append("%s takes a defensive stance (+3 DEF this round)" % actor.soldier_name)

	emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _calculate_hit_soldier(actor: SoldierData, target) -> Dictionary:
	var hit_chance = 0.7
	hit_chance += (actor.get_total_speed() - target.dexterity) * 0.03
	hit_chance += actor.get_hit_chance_bonus()
	hit_chance = clamp(hit_chance, 0.15, 0.95)
	return {hit = randf() < hit_chance}
	
	
func _next_turn() -> void:
	# Sari peste unitatile moarte
	while current_unit_index < turn_order.size():
		var entry = turn_order[current_unit_index]
		if entry.unit.is_alive():
			break
		current_unit_index += 1

# Runda noua
	if current_unit_index >= turn_order.size():
		turn_number += 1
		combat_log.append("— Round %d —" % turn_number)
		emit_signal("unit_acted", combat_log.back())
		_build_turn_order()
		await _next_turn()
		return

	var current = turn_order[current_unit_index]
	emit_signal("turn_changed", current)

# Daca e inamic — actioneaza automat
	if not current.is_ally:
		await Engine.get_main_loop().create_timer(1).timeout
		if active:
			_enemy_act(current.unit)


func _advance_turn() -> void:
	_check_combat_end()
	if active:
		current_unit_index += 1
		_next_turn()

func _check_combat_end() -> void:
	var allies_alive = allies.any(func(a): return a.is_alive())
	var enemies_alive = enemies.any(func(e): return e.is_alive())

	if not enemies_alive:
		_end_combat(true)
	elif not allies_alive:
		_end_combat(false)

func _end_combat(victory: bool) -> void:
	active = false
	if victory:
		for e in enemies:
			gold_earned += e.gold_reward
			xp_earned += e.xp_reward
		GameState.gold += gold_earned
		for s in allies:
			s.add_xp(xp_earned)
		combat_log.append("— Victory! +%d Gold, +%d XP —" % [gold_earned, xp_earned])
	else:
		combat_log.append("— Defeat... —")
	emit_signal("combat_ended", victory)
