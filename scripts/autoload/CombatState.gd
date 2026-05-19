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
var auto_battle: bool = false
var speed_multiplier: float = 1.0

var combat_log: Array[String] = []
var gold_earned: int = 0
var xp_earned: int = 0
var is_dungeon_combat: bool = false
var leveled_up_soldiers: Array = []

signal combat_started
signal turn_changed(entry: Dictionary)
signal unit_acted(log_line: String)
signal combat_ended(victory: bool)
signal dungeon_combat_ended(victory: bool)
signal game_over

func cancel_combat() -> void:
	active = false
	allies.clear()
	turn_order.clear()
	current_unit_index = 0

func start_combat(enemy_wave: Array[EnemyData]) -> void:
	active = true
	turn_number = 1
	combat_log.clear()
	gold_earned = 0
	xp_earned = 0
	allies = []  # gol pana la selectie
	enemies = enemy_wave
	speed_multiplier = 1.0
	auto_battle = false
	leveled_up_soldiers = []

func begin_after_selection() -> void:
	if enemies.is_empty():
		return
	for s in allies:
		s.active_skill_cooldowns.clear()
	emit_signal("combat_started")
	await get_tree().process_frame
	_build_turn_order()
	await _next_turn()

func _build_turn_order() -> void:
	turn_order.clear()
	for s in allies:
		for skill_id in s.active_skill_cooldowns:
			s.active_skill_cooldowns[skill_id] = max(0, s.active_skill_cooldowns[skill_id] - 1)
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

	# Boss detection: hp_max > 100 catches all boss variants regardless of name
	if enemy.hp_max > 100:
		await _enemy_act_boss(enemy, alive_allies)
		return

	var base_name = enemy.enemy_name.split(" ")[0]
	match base_name:
		"Goblin":
			await _enemy_act_goblin(enemy, alive_allies)
		"Orc":
			await _enemy_act_orc(enemy, alive_allies)
		"Wolf":
			await _enemy_act_wolf(enemy, alive_allies)
		"Enemy":
			await _enemy_act_soldier(enemy, alive_allies)
		_:
			await _enemy_act_default(enemy, alive_allies)

func _enemy_pick_target_random(alive_allies: Array) -> SoldierData:
	return alive_allies[randi_range(0, alive_allies.size() - 1)]

func _enemy_pick_target_lowest_hp(alive_allies: Array) -> SoldierData:
	var t: SoldierData = alive_allies[0]
	for a in alive_allies:
		if a.hp_current < t.hp_current:
			t = a
	return t

func _enemy_pick_target_most_damaged(alive_allies: Array) -> SoldierData:
	var t: SoldierData = alive_allies[0]
	for a in alive_allies:
		if (a.hp_max - a.hp_current) > (t.hp_max - t.hp_current):
			t = a
	return t

func _enemy_do_attack(enemy: EnemyData, target: SoldierData, dmg_multiplier: float = 1.0, ignores_defense: bool = false) -> void:
	var hit_chance = 0.7 + (enemy.dexterity - target.get_total_speed()) * 0.03
	hit_chance = clamp(hit_chance, 0.15, 0.95)
	if not randf() < hit_chance:
		combat_log.append("%s attacks %s — MISS" % [enemy.enemy_name, target.soldier_name])
		return
	var dodge_chance = target.get_dodge_bonus()
	if dodge_chance > 0.0 and randf() < dodge_chance:
		combat_log.append("%s attacks %s — DODGE!" % [enemy.enemy_name, target.soldier_name])
		return
	var raw_dmg = int((enemy.power + randi_range(-3, 3)) * dmg_multiplier)
	var defense = 0 if ignores_defense else target.get_total_defense()
	var final_dmg = max(1, raw_dmg - defense)
	target.hp_current = max(0, target.hp_current - final_dmg)
	target.combat_damage_taken += final_dmg
	if float(target.hp_current) / float(target.hp_max) < 0.15:
		target.combat_survived_near_death = true
	combat_log.append("%s attacks %s for %d dmg" % [enemy.enemy_name, target.soldier_name, final_dmg])

func _enemy_act_goblin(enemy: EnemyData, alive_allies: Array) -> void:
	# Targets the weakest soldier to finish them off
	var target = _enemy_pick_target_lowest_hp(alive_allies)
	_enemy_do_attack(enemy, target)
	emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_orc(enemy: EnemyData, alive_allies: Array) -> void:
	# Slow but hits hard; 25% chance of Rage: 1.5x damage
	var target = _enemy_pick_target_random(alive_allies)
	var raging = randf() < 0.25
	if raging:
		combat_log.append("%s enters a RAGE!" % enemy.enemy_name)
		emit_signal("unit_acted", combat_log.back())
	_enemy_do_attack(enemy, target, 1.5 if raging else 1.0)
	emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_wolf(enemy: EnemyData, alive_allies: Array) -> void:
	# Targets the most wounded soldier; attacks twice at 60% damage each
	var target = _enemy_pick_target_most_damaged(alive_allies)
	_enemy_do_attack(enemy, target, 0.6)
	emit_signal("unit_acted", combat_log.back())
	if target.is_alive():
		_enemy_do_attack(enemy, target, 0.6)
		emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_soldier(enemy: EnemyData, alive_allies: Array) -> void:
	# 30% chance to use Precise Strike: ignores defense
	var target = _enemy_pick_target_random(alive_allies)
	if randf() < 0.30:
		combat_log.append("%s readies a Precise Strike!" % enemy.enemy_name)
		emit_signal("unit_acted", combat_log.back())
		_enemy_do_attack(enemy, target, 1.0, true)
	else:
		_enemy_do_attack(enemy, target)
	emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_boss(enemy: EnemyData, alive_allies: Array) -> void:
	# Bosses: alternate between a powerful strike and hitting all allies
	var use_cleave = turn_number % 2 == 0
	if use_cleave:
		combat_log.append("%s unleashes a CLEAVE!" % enemy.enemy_name)
		emit_signal("unit_acted", combat_log.back())
		for target in alive_allies.duplicate():
			_enemy_do_attack(enemy, target, 0.7)
			emit_signal("unit_acted", combat_log.back())
	else:
		var target = _enemy_pick_target_lowest_hp(alive_allies)
		_enemy_do_attack(enemy, target, 1.4)
		emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_default(enemy: EnemyData, alive_allies: Array) -> void:
	var target = _enemy_pick_target_random(alive_allies)
	_enemy_do_attack(enemy, target)
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
			var dmg_range = actor.get_damage_range()
			var base_dmg = randi_range(dmg_range.min, dmg_range.max)
			var result = _calculate_hit_soldier(actor, target)
			if result.hit:
				var final_dmg = max(1, base_dmg + actor.get_total_power())
				target.hp_current = max(0, target.hp_current - final_dmg)
				actor.combat_damage_dealt += final_dmg
				if target.hp_current > 0:
					combat_log.append("%s attacks %s for %d dmg" % [
						actor.soldier_name, target.enemy_name, final_dmg
					])
				else:
					actor.combat_kills += 1
					combat_log.append("%s killed %s dealing %d dmg" % [
						actor.soldier_name, target.enemy_name, final_dmg
				])
			elif result.dodged:
				combat_log.append("%s attacks %s — DODGE!" % [
					actor.soldier_name, target.enemy_name
				])
			else:
				combat_log.append("%s attacks %s — MISS" % [
					actor.soldier_name, target.enemy_name
				])

		"Defend":
			combat_log.append("%s takes a defensive stance" % actor.soldier_name)

		"Skill":
			# target e un Dictionary {skill, enemy_target}
			if target == null:
				return
			var skill: SkillData = target.get("skill")
			var enemy_target = target.get("enemy_target")
			if skill == null or enemy_target == null:
				return
			_use_active_skill(actor, skill, enemy_target)

	emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _use_active_skill(actor: SoldierData, skill: SkillData, target: EnemyData) -> void:
	# Verifica cooldown
	if actor.active_skill_cooldowns.get(skill.skill_id, 0) > 0:
		combat_log.append("%s — %s is on cooldown!" % [actor.soldier_name, skill.skill_name])
		return

	var dmg_range = actor.get_damage_range()
	var base_dmg = randi_range(dmg_range.min, dmg_range.max)
	var final_dmg = max(1, int(base_dmg * skill.damage_multiplier) + actor.get_total_power())

	var hit_chance = 0.7 + actor.get_hit_chance_bonus() + skill.hit_chance_bonus + _get_morale_hit_modifier()
	hit_chance = clamp(hit_chance, 0.15, 0.99)

	if not randf() < hit_chance:
		combat_log.append("%s uses %s — MISS!" % [actor.soldier_name, skill.skill_name])
	elif target.dodge_bonus > 0.0 and randf() < target.dodge_bonus:
		combat_log.append("%s uses %s on %s — DODGE!" % [actor.soldier_name, skill.skill_name, target.enemy_name])
	else:
		target.hp_current = max(0, target.hp_current - final_dmg)
		actor.combat_damage_dealt += final_dmg
		if target.hp_current <= 0:
			actor.combat_kills += 1
		combat_log.append("%s uses %s on %s for %d dmg!" % [
			actor.soldier_name, skill.skill_name, target.enemy_name, final_dmg
		])

	# Seteaza cooldown
	actor.active_skill_cooldowns[skill.skill_id] = skill.cooldown_turns

func _get_morale_hit_modifier() -> float:
	# Morale 100 = +0.10 bonus, Morale 50 = 0, Morale 0 = -0.10 penalty
	return (GameState.morale - 50) * 0.002

func _calculate_hit_soldier(actor: SoldierData, target) -> Dictionary:
	var hit_chance = 0.7
	hit_chance += (actor.get_total_speed() - target.dexterity) * 0.03
	hit_chance += actor.get_hit_chance_bonus()
	hit_chance += _get_morale_hit_modifier()
	hit_chance = clamp(hit_chance, 0.15, 0.95)
	if not randf() < hit_chance:
		return {hit = false, dodged = false}
	if target is EnemyData and target.dodge_bonus > 0.0 and randf() < target.dodge_bonus:
		return {hit = false, dodged = true}
	return {hit = true, dodged = false}


func _next_turn() -> void:
	# Skip dead units. If everyone in the order is done, start a new round.
	# Use a loop instead of recursion so the stack does not grow per round.
	while true:
		if not active:
			return
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
			# Loop back to the top — do NOT recurse (stack-overflow risk)
			continue

		break  # found a live unit, proceed

	var current = turn_order[current_unit_index]
	emit_signal("turn_changed", current)

	# Daca e inamic — actioneaza automat
	if not current.is_ally:
		await Engine.get_main_loop().create_timer(1.0 / speed_multiplier).timeout
		if active:
			await _enemy_act(current.unit)

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
		for s in allies:
			TraitChecker.check_combat_traits(s)
			s.reset_combat_stats()
			if s.is_alive():
				var level_before = s.level
				s.add_xp(xp_earned)
				if s.level > level_before:
					leveled_up_soldiers.append(s.soldier_name)
		if not is_dungeon_combat:
			var dead: Array[SoldierData] = []
			for s in allies:
				if not s.is_alive():
					dead.append(s)
			for s in dead:
				GameState.soldiers.erase(s)
		if not is_dungeon_combat:
			GameState.add_post_turn_resource_delta("Gold", gold_earned)
			GameState.turn_recap.append("")
			GameState.turn_recap.append("Phase: Battle")
			GameState.turn_recap.append("Victory: +%d Gold | +%d XP" % [gold_earned, xp_earned])
		else:
			GameState.gold += gold_earned
		combat_log.append("— Victory! +%d Gold, +%d XP —" % [gold_earned, xp_earned])
		GameState.emit_signal("resources_changed")
		GameState.emit_signal("soldiers_changed")
	else:
		if not is_dungeon_combat:
			# Remove dead soldiers from roster (dungeon handles its own deaths)
			var dead_soldiers: Array[SoldierData] = []
			for s in allies:
				if not s.is_alive():
					dead_soldiers.append(s)
			for s in dead_soldiers:
				GameState.soldiers.erase(s)
			GameState.emit_signal("soldiers_changed")
			GameState.turn_recap.append("")
			GameState.turn_recap.append("Phase: Battle")
			var casualties = dead_soldiers.size()
			GameState.turn_recap.append("Defeat! %d soldier%s lost." % [casualties, "s" if casualties != 1 else ""])
			combat_log.append("— Defeat! %d soldier%s lost. —" % [casualties, "s" if casualties != 1 else ""])

		# Game over if no soldiers remain AND this is not a dungeon combat
		if GameState.soldiers.is_empty() and not is_dungeon_combat:
			emit_signal("game_over")
			is_dungeon_combat = false
			return

	if is_dungeon_combat:
		is_dungeon_combat = false
		emit_signal("dungeon_combat_ended", victory)
	else:
		emit_signal("combat_ended", victory)
