# CombatState.gd
extends Node

const CRIT_MULT := 1.75

var active: bool = false
var turn_number: int = 0
var current_unit_index: int = 0
var turn_order: Array = []

var allies: Array[SoldierData] = []
var enemies: Array[EnemyData] = []

var auto_battle: bool = false
var speed_multiplier: float = 1.0

var combat_log: Array[String] = []
var gold_earned: int = 0
var xp_earned: int = 0
var is_dungeon_combat: bool = false
var leveled_up_soldiers: Array = []

## Live "watch the city defend itself" battle: real defenders vs. the actual
## wave, fought through the normal combat loop, but with locked controls and
## bespoke (lighter) post-battle consequences mirroring the city-defense
## auto-resolve math instead of the normal city-combat or dungeon-combat paths.
var spectator_mode: bool = false

signal combat_started
signal turn_changed(entry: Dictionary)
signal unit_acted(log_line: String)
signal combat_ended(victory: bool)
signal dungeon_combat_ended(victory: bool)
signal spectator_combat_ended(victory: bool)
signal dungeon_result_dismissed

func notify_dungeon_result_dismissed() -> void:
	dungeon_result_dismissed.emit()

## Picks the background image for the current battle: city defense, a regular
## dungeon fight, or a dungeon boss fight (only inside the dungeon's BOSS room —
## the old hp_max heuristic misfired on beefy regular mobs at higher levels).
func get_battle_bg_path() -> String:
	if not is_dungeon_combat:
		return "res://assets/combat/bg_city.png"
	if DungeonState.active and DungeonState.map != null:
		var room: DungeonRoom = DungeonState.map.get_room_at(DungeonState.current_pos)
		if room != null and room.room_type == DungeonRoom.RoomType.BOSS:
			return "res://assets/combat/bg_boss.png"
	return "res://assets/combat/bg_dungeon.png"

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
		s.clear_combat_status()
	for e in enemies:
		e.clear_combat_status()
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
		all.append({unit = a, is_ally = true, speed_roll = a.get_total_speed() + randi_range(0, 3)})
	for e in enemies:
		all.append({unit = e, is_ally = false, speed_roll = e.get_effective_speed() + randi_range(0, 3)})
	all.sort_custom(func(a, b): return a.speed_roll > b.speed_roll)
	turn_order = all
	current_unit_index = 0

# Appends a line to the log AND notifies listeners. Use for any action that may
# produce several log lines in one turn (AoE skills, multi-hits, counters).
func _log(line: String) -> void:
	combat_log.append(line)
	emit_signal("unit_acted", line)

func _unit_name(unit) -> String:
	return unit.soldier_name if unit is SoldierData else unit.enemy_name

# Applies damage through shields and the Last Stand passive. Returns HP actually lost.
func _deal_damage(unit, dmg: int) -> int:
	var remaining := dmg
	if unit.shield_hp > 0:
		var absorbed = min(unit.shield_hp, remaining)
		unit.shield_hp -= absorbed
		remaining -= absorbed
	if remaining <= 0:
		return 0
	if unit is SoldierData and remaining >= unit.hp_current and unit.has_last_stand() and not unit.last_stand_used:
		unit.last_stand_used = true
		var dealt = max(0, unit.hp_current - 1)
		unit.hp_current = 1
		return dealt
	var before = unit.hp_current
	unit.hp_current = max(0, unit.hp_current - remaining)
	return before - unit.hp_current

func _apply_lifesteal(actor: SoldierData, dealt: int) -> void:
	var ls = actor.get_lifesteal()
	if ls > 0.0 and dealt > 0:
		actor.hp_current = min(actor.hp_max, actor.hp_current + int(dealt * ls))

func _rolls_crit(actor: SoldierData, skill, target) -> bool:
	var ratio = float(target.hp_current) / float(maxi(1, target.hp_max))
	var vs_wounded = actor.has_crit_vs_wounded() or (skill != null and skill.crit_vs_wounded)
	if vs_wounded and ratio < 0.5:
		return true
	var chance = actor.get_crit_chance() + (skill.crit_chance if skill != null else 0.0)
	return chance > 0.0 and randf() < chance

# ---------------------------------------------------------------------------
# Enemy AI
# ---------------------------------------------------------------------------

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
		"Enemy":
			await _enemy_act_soldier(enemy, alive_allies)
		_:
			await _enemy_act_default(enemy, alive_allies)

func _has_taunter(alive_allies: Array) -> SoldierData:
	for a in alive_allies:
		if a.has_status("taunt"):
			return a
	return null

func _enemy_pick_target_random(alive_allies: Array) -> SoldierData:
	var t = _has_taunter(alive_allies)
	if t != null: return t
	return alive_allies[randi_range(0, alive_allies.size() - 1)]

func _enemy_pick_target_lowest_hp(alive_allies: Array) -> SoldierData:
	var taunter = _has_taunter(alive_allies)
	if taunter != null: return taunter
	var t: SoldierData = alive_allies[0]
	for a in alive_allies:
		if a.hp_current < t.hp_current:
			t = a
	return t

func _enemy_do_attack(enemy: EnemyData, target: SoldierData, dmg_multiplier: float = 1.0, ignores_defense: bool = false) -> void:
	var hit_chance = 0.7 + (enemy.dexterity - target.get_total_speed()) * 0.03
	hit_chance -= float(enemy.get_status_potency("blind")) / 100.0
	hit_chance = clamp(hit_chance, 0.15, 0.95)
	if not randf() < hit_chance:
		_log("%s attacks %s — MISS" % [enemy.enemy_name, target.soldier_name])
		return
	var dodge_chance = target.get_dodge_bonus()
	if dodge_chance > 0.0 and randf() < dodge_chance:
		_log("%s attacks %s — DODGE!" % [enemy.enemy_name, target.soldier_name])
		return
	var raw_dmg = int((enemy.get_effective_power() + randi_range(-3, 3)) * dmg_multiplier)
	var defense = 0 if ignores_defense else target.get_total_defense()
	var final_dmg = max(1, raw_dmg - defense - target.get_damage_reduction())
	var dealt = _deal_damage(target, final_dmg)
	target.combat_damage_taken += dealt
	if float(target.hp_current) / float(target.hp_max) < 0.15:
		target.combat_survived_near_death = true
	_log("%s attacks %s for %d dmg" % [enemy.enemy_name, target.soldier_name, dealt])
	# Counterattack passive
	if target.is_alive() and target.get_counter_chance() > 0.0 and randf() < target.get_counter_chance():
		var cdmg = max(1, target.get_total_power())
		var cdealt = _deal_damage(enemy, cdmg)
		target.combat_damage_dealt += cdealt
		if enemy.hp_current <= 0:
			target.combat_kills += 1
		_log("%s counters %s for %d dmg" % [target.soldier_name, enemy.enemy_name, cdealt])

func _enemy_act_soldier(enemy: EnemyData, alive_allies: Array) -> void:
	# 30% chance to use Precise Strike: ignores defense
	var target = _enemy_pick_target_random(alive_allies)
	if randf() < 0.30:
		_log("%s readies a Precise Strike!" % enemy.enemy_name)
		_enemy_do_attack(enemy, target, 1.0, true)
	else:
		_enemy_do_attack(enemy, target)
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_boss(enemy: EnemyData, alive_allies: Array) -> void:
	# Bosses: alternate between a powerful strike and hitting all allies
	var use_cleave = turn_number % 2 == 0
	if use_cleave:
		_log("%s unleashes a CLEAVE!" % enemy.enemy_name)
		for target in alive_allies.duplicate():
			_enemy_do_attack(enemy, target, 0.7)
	else:
		var target = _enemy_pick_target_lowest_hp(alive_allies)
		_enemy_do_attack(enemy, target, 1.4)
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _enemy_act_default(enemy: EnemyData, alive_allies: Array) -> void:
	var target = _enemy_pick_target_random(alive_allies)
	_enemy_do_attack(enemy, target)
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

# ---------------------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------------------

func player_act(action: String, target) -> void:
	if current_unit_index >= turn_order.size():
		return
	var current_entry = turn_order[current_unit_index]
	if not current_entry.is_ally:
		return
	var actor: SoldierData = current_entry.unit
	var emit_final := true

	match action:
		"Attack":
			if target == null or not target is EnemyData:
				return
			var dmg_range = actor.get_damage_range()
			var base_dmg = randi_range(dmg_range.min, dmg_range.max)
			var result = _calculate_hit_soldier(actor, target)
			if result.hit:
				var final_dmg = max(1, base_dmg + actor.get_total_power())
				var crit = _rolls_crit(actor, null, target)
				if crit:
					final_dmg = int(final_dmg * CRIT_MULT)
				var dealt = _deal_damage(target, final_dmg)
				actor.combat_damage_dealt += dealt
				_apply_lifesteal(actor, dealt)
				var tag = " (crit)" if crit else ""
				if target.hp_current > 0:
					combat_log.append("%s attacks %s for %d dmg%s" % [
						actor.soldier_name, target.enemy_name, dealt, tag])
				else:
					actor.combat_kills += 1
					combat_log.append("%s attacks %s for %d dmg%s (lethal)" % [
						actor.soldier_name, target.enemy_name, dealt, tag])
			elif result.dodged:
				combat_log.append("%s attacks %s — DODGE!" % [actor.soldier_name, target.enemy_name])
			else:
				combat_log.append("%s attacks %s — MISS" % [actor.soldier_name, target.enemy_name])

		"Defend":
			actor.add_status("defense_up", 5, 1)
			combat_log.append("%s takes a defensive stance" % actor.soldier_name)

		"Skill":
			# target e un Dictionary {skill, enemy_target}
			if target == null:
				return
			var skill: SkillData = target.get("skill")
			var enemy_target: Variant = target.get("enemy_target")
			if skill == null:
				return
			if skill.target_mode == SkillData.TargetMode.ENEMY_SINGLE and (enemy_target == null or not enemy_target is EnemyData):
				combat_log.append("%s — no target for %s" % [actor.soldier_name, skill.skill_name])
				emit_signal("unit_acted", combat_log.back())
				return
			_use_active_skill(actor, skill, enemy_target)
			emit_final = false

	if emit_final:
		emit_signal("unit_acted", combat_log.back())
	_check_combat_end()
	if active:
		current_unit_index += 1
		await _next_turn()

func _use_active_skill(actor: SoldierData, skill: SkillData, target) -> void:
	if actor.active_skill_cooldowns.get(skill.skill_id, 0) > 0:
		_log("%s — %s is on cooldown!" % [actor.soldier_name, skill.skill_name])
		return
	actor.active_skill_cooldowns[skill.skill_id] = skill.cooldown_turns

	match skill.target_mode:
		SkillData.TargetMode.SELF:
			_apply_support(actor, actor, skill)
			_log("%s uses %s" % [actor.soldier_name, skill.skill_name])
		SkillData.TargetMode.ALLY_ALL:
			for a in allies:
				if a.is_alive():
					_apply_support(actor, a, skill)
			_log("%s uses %s — allies are bolstered!" % [actor.soldier_name, skill.skill_name])
		SkillData.TargetMode.ENEMY_ALL:
			_log("%s unleashes %s!" % [actor.soldier_name, skill.skill_name])
			for e in enemies:
				if e.is_alive():
					_skill_hit_enemy(actor, skill, e)
		_:  # ENEMY_SINGLE
			if target == null or not (target is EnemyData):
				return
			_skill_hit_enemy(actor, skill, target)

func _skill_hit_enemy(actor: SoldierData, skill: SkillData, target: EnemyData) -> void:
	if not target.is_alive():
		return
	var total := 0
	for _i in maxi(1, skill.hits):
		if not target.is_alive():
			break
		var hit_chance = 0.7 + actor.get_hit_chance_bonus() + skill.hit_chance_bonus + _get_morale_hit_modifier(actor)
		hit_chance = clamp(hit_chance, 0.15, 0.99)
		if not randf() < hit_chance:
			_log("%s uses %s on %s — MISS!" % [actor.soldier_name, skill.skill_name, target.enemy_name])
			continue
		if target.dodge_bonus > 0.0 and randf() < target.dodge_bonus:
			_log("%s uses %s on %s — DODGE!" % [actor.soldier_name, skill.skill_name, target.enemy_name])
			continue
		var dmg_range = actor.get_damage_range()
		var base_dmg = randi_range(dmg_range.min, dmg_range.max)
		var dmg = max(1, int(base_dmg * skill.damage_multiplier) + actor.get_total_power())
		var crit = _rolls_crit(actor, skill, target)
		if crit:
			dmg = int(dmg * CRIT_MULT)
		var dealt = _deal_damage(target, dmg)
		total += dealt
		if skill.applies_status != "" and target.is_alive():
			target.add_status(skill.applies_status, skill.status_potency, skill.status_duration)
		var tag = " (crit)" if crit else ""
		if target.hp_current <= 0:
			actor.combat_kills += 1
			_log("%s uses %s on %s for %d dmg%s (lethal)" % [
				actor.soldier_name, skill.skill_name, target.enemy_name, dealt, tag])
		else:
			_log("%s uses %s on %s for %d dmg%s" % [
				actor.soldier_name, skill.skill_name, target.enemy_name, dealt, tag])
	actor.combat_damage_dealt += total
	_apply_lifesteal(actor, total)

# Applies heals / buffs / protective statuses to an ally (or self).
func _apply_support(_actor: SoldierData, ally: SoldierData, skill: SkillData) -> void:
	if skill.heal_amount > 0 and ally.is_alive():
		ally.hp_current = min(ally.hp_max, ally.hp_current + skill.heal_amount)
	if skill.defense_bonus > 0:
		ally.add_status("defense_up", skill.defense_bonus, maxi(2, skill.status_duration))
	if skill.applies_status != "":
		ally.add_status(skill.applies_status, skill.status_potency, maxi(1, skill.status_duration))

func _get_morale_hit_modifier(actor: SoldierData) -> float:
	return actor.get_morale_hit_modifier()

func _calculate_hit_soldier(actor: SoldierData, target) -> Dictionary:
	var hit_chance = 0.7
	hit_chance += (actor.get_total_speed() - target.dexterity) * 0.03
	hit_chance += actor.get_hit_chance_bonus()
	hit_chance += _get_morale_hit_modifier(actor)
	hit_chance = clamp(hit_chance, 0.15, 0.95)
	if not randf() < hit_chance:
		return {hit = false, dodged = false}
	if target is EnemyData and target.dodge_bonus > 0.0 and randf() < target.dodge_bonus:
		return {hit = false, dodged = true}
	return {hit = true, dodged = false}

# ---------------------------------------------------------------------------
# Turn loop
# ---------------------------------------------------------------------------

func _next_turn() -> void:
	# Skip dead units, process start-of-turn statuses, and start new rounds.
	# Uses a loop instead of recursion so the stack does not grow per round.
	while true:
		if not active:
			return
		# Skip dead units
		while current_unit_index < turn_order.size() and not turn_order[current_unit_index].unit.is_alive():
			current_unit_index += 1

		# New round
		if current_unit_index >= turn_order.size():
			turn_number += 1
			_log("— Round %d —" % turn_number)
			_build_turn_order()
			continue

		# Live unit found — resolve start-of-turn status effects
		var unit = turn_order[current_unit_index].unit
		for line in unit.apply_status_dot():
			_log(line)
		if not unit.is_alive():
			_check_combat_end()
			if not active:
				return
			current_unit_index += 1
			continue
		var stunned = unit.has_status("stun")
		unit.advance_statuses()
		if stunned:
			_log("%s is stunned and cannot act!" % _unit_name(unit))
			current_unit_index += 1
			continue

		break  # found a live, non-stunned unit — proceed

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
	for s in allies:
		s.clear_combat_status()
	for e in enemies:
		e.clear_combat_status()

	if spectator_mode:
		_end_spectator_combat(victory)
		return

	if victory:
		for e in enemies:
			gold_earned += e.gold_reward
			xp_earned += e.xp_reward
		# Apply Wardens dungeon XP bonus for dungeon combat
		var final_xp: int = xp_earned
		if is_dungeon_combat and FactionState.wardens_dungeon_xp_bonus > 0.0:
			final_xp = int(float(xp_earned) * (1.0 + FactionState.wardens_dungeon_xp_bonus))
		for s in allies:
			TraitChecker.check_combat_traits(s)
			s.reset_combat_stats()
			if s.is_alive():
				var level_before = s.level
				s.add_xp(final_xp)
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
			StoryManager.check_first_combat_victory()
			GameState.add_post_turn_resource_delta("Gold", gold_earned)
			GameState.turn_recap.append("")
			GameState.turn_recap.append("Phase: Battle")
			GameState.turn_recap.append("Victory: +%d Gold | +%d XP" % [gold_earned, xp_earned])
		else:
			GameState.gold += gold_earned
		combat_log.append("— Victory! +%d Gold, +%d XP —" % [gold_earned, final_xp])
		GameState.emit_signal("resources_changed")
		GameState.emit_signal("soldiers_changed")
	else:
		if not is_dungeon_combat:
			# 60/40 fate split for every soldier in this battle
			var permanently_dead: Array[SoldierData] = []
			var injured_soldiers: Array[SoldierData] = []
			for s in allies:
				if randf() < 0.6:
					permanently_dead.append(s)
				else:
					injured_soldiers.append(s)
			# Remove permanently dead from roster
			for s in permanently_dead:
				GameState.soldiers.erase(s)
			# Mark injured — they stay in roster but unavailable
			for s in injured_soldiers:
				s.unavailable_turns = 2
			GameState.emit_signal("soldiers_changed")
			# Apply wave loss consequences (resource drain, wall loss, building damage, threat, army morale -20)
			GameState.apply_wave_loss_consequences()
			# Extra morale penalty for injured soldiers specifically
			for s in injured_soldiers:
				s.morale = clampi(s.morale - 20, 0, s.get_max_morale())
			# Recap
			GameState.turn_recap.append("")
			GameState.turn_recap.append("Phase: Battle")
			GameState.turn_recap.append("Defeat! %d killed, %d injured. City walls: %d remaining." % [
				permanently_dead.size(), injured_soldiers.size(), GameState.city_walls
			])
			combat_log.append("— Defeat! %d killed, %d injured. —" % [permanently_dead.size(), injured_soldiers.size()])
			# Note: if GameState.city_walls <= 0 here, the city has fallen.
			# combat_ended is still emitted below so the normal "DEFEAT!"
			# battle-end screen shows first; its Continue handler checks
			# city_walls and routes to the city-fallen game-over screen.

	if victory:
		for s in allies:
			if not s.is_alive():
				continue
			var morale_delta: int = 8
			if s.combat_kills > 0:
				morale_delta += s.combat_kills * 3
			if s.combat_survived_near_death:
				morale_delta -= 5
			s.morale = clampi(s.morale + morale_delta, 0, s.get_max_morale())

	if is_dungeon_combat:
		is_dungeon_combat = false
		emit_signal("dungeon_combat_ended", victory)
	else:
		emit_signal("combat_ended", victory)

## Mirrors GameState.resolve_city_defense_auto's consequences: no gold/XP
## reward, fallen defenders are removed from the roster, and on defeat the
## same wave-loss consequences as a normal city-combat defeat apply (wall
## lost, resource drain, building damage, threat spike, -20 morale). Resets
## per-fight stat tracking on survivors so it doesn't leak into the next battle.
func _end_spectator_combat(victory: bool) -> void:
	spectator_mode = false
	for s in allies:
		s.reset_combat_stats()
	var dead: Array[SoldierData] = []
	for s in allies:
		if not s.is_alive():
			dead.append(s)
	for s in dead:
		GameState.soldiers.erase(s)
	if not victory:
		GameState.apply_wave_loss_consequences()
	GameState.emit_signal("soldiers_changed")
	emit_signal("spectator_combat_ended", victory)
