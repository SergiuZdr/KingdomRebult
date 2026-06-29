# DungeonState.gd — autoload
extends Node

var active: bool = false           # expedition in progress
var dungeon_level: int = 1
var current_pos: Vector2i = Vector2i.ZERO

var map: DungeonMap = null
var soldiers_in_dungeon: Array[SoldierData] = []
var pending_soldiers: Array[SoldierData] = []

# Remains of soldiers who died in the dungeon, organised by level so they
# can appear as loot in future runs on the same dungeon level.
var soldier_remains: Dictionary = {}  # dungeon_level (int) -> Array of Dictionaries

var expedition_log: Array = []        # Array[Dictionary] {type, text, ...}
var warden_lockout_turns: int = 0
var legion_lockout_turns: int = 0

## Pale Court map gift: auto-reveals dungeon levels 4-5 for a limited number of
## expeditions rather than forever. A charge is spent at the start of each
## qualifying expedition (dungeon_level >= 4); `_active` flags the current run.
const MAP_REVEAL_EXPEDITIONS: int = 3
var dungeon_map_reveal_charges: int = 0
var dungeon_map_reveal_active: bool = false

## Items available to the party during this expedition: everything each soldier
## had equipped at departure + anything acquired mid-run (loot, market purchases).
## Cleared in recall_soldiers() / at the start of a new expedition.
var expedition_pool: Array[ItemData] = []

signal expedition_started
signal soldiers_retrieved

func start_expedition() -> void:
	if pending_soldiers.is_empty():
		return
	if warden_lockout_turns > 0:
		warden_lockout_turns = 0
		FactionState.change_wardens(-20)
	if legion_lockout_turns > 0:
		legion_lockout_turns = 0
		FactionState.change_iron_legion(-20)
	active = true
	soldiers_in_dungeon = pending_soldiers.duplicate()
	pending_soldiers.clear()

	# Spend a map-reveal charge if one is available and this depth qualifies.
	dungeon_map_reveal_active = false
	if dungeon_map_reveal_charges > 0 and dungeon_level >= 4:
		dungeon_map_reveal_active = true
		dungeon_map_reveal_charges -= 1

	# Seed the expedition pool with every item currently equipped on party soldiers.
	expedition_pool.clear()
	for sol in soldiers_in_dungeon:
		if sol.weapon_1 != null: expedition_pool.append(sol.weapon_1)
		if sol.weapon_2 != null: expedition_pool.append(sol.weapon_2)
		if sol.armor    != null: expedition_pool.append(sol.armor)

	# Resume the in-progress dungeon for this level if one was left behind by a
	# previous recall; otherwise generate a fresh map. The persisted map keeps all
	# cleared/seen progress and the position the last party left off at.
	if map != null and map.dungeon_level == dungeon_level:
		_log("expedition_start", "Expedition resumed — Dungeon Level %d" % dungeon_level)
	else:
		var remains: Array = soldier_remains.get(dungeon_level, [])
		map = DungeonMap.new()
		map.generate(dungeon_level, remains)
		current_pos = map._find_spawn_pos()
		expedition_log.clear()
		_log("expedition_start", "Expedition started — Dungeon Level %d" % dungeon_level)

	mark_seen_around(current_pos)
	emit_signal("expedition_started")

func recall_soldiers() -> void:
	if not active:
		return
	for s in soldiers_in_dungeon:
		if s.is_alive() and not GameState.soldiers.has(s):
			GameState.soldiers.append(s)
	soldiers_in_dungeon.clear()
	active = false
	expedition_pool.clear()
	# Keep the map so a future party resumes this in-progress dungeon where the
	# last one left off. Only drop it when it is stale — i.e. the boss was cleared
	# and dungeon_level advanced past the map's level — so the next dive regenerates.
	if map != null and map.dungeon_level != dungeon_level:
		map = null
		current_pos = Vector2i.ZERO
		expedition_log.clear()
	emit_signal("soldiers_retrieved")
	GameState.emit_signal("soldiers_changed")

func soldier_died_in_dungeon(soldier) -> void:
	# Store remains for future runs
	var items: Array = []
	if soldier.weapon_1 != null: items.append(soldier.weapon_1)
	if soldier.weapon_2 != null: items.append(soldier.weapon_2)
	if soldier.armor != null:    items.append(soldier.armor)
	var remains = {soldier_name = soldier.soldier_name, items = items}
	if not soldier_remains.has(dungeon_level):
		soldier_remains[dungeon_level] = []
	soldier_remains[dungeon_level].append(remains)
	soldiers_in_dungeon.erase(soldier)
	_log("soldier_died", "%s has fallen in the dungeon. Their remains may be found here again." % soldier.soldier_name)
	GameState.soldiers.erase(soldier)
	GameState.emit_signal("soldiers_changed")

func enter_room(pos: Vector2i) -> void:
	current_pos = pos
	var room: DungeonRoom = map.get_room_at(pos)
	if room == null:
		return
	room.visited = true
	# Passing into a room permanently reveals it and its neighbours, so their type
	# stays shown on the map for planning even after the party moves on.
	mark_seen_around(pos)
	_log("move", "Moved to %s" % room.get_display_label())

## Permanently reveal the room at `pos` and every adjacent room. `seen` rooms
## render their type icon (dimmed, non-interactive) instead of a locked medallion.
func mark_seen_around(pos: Vector2i) -> void:
	if map == null:
		return
	var here: DungeonRoom = map.get_room_at(pos)
	if here != null:
		here.seen = true
	for room in map.get_neighbors(pos):
		room.seen = true

func log_event(event_type: String, text: String, data: Dictionary = {}) -> void:
	_log(event_type, text, data)

func _log(event_type: String, text: String, data: Dictionary = {}) -> void:
	var entry = {type = event_type, text = text}
	entry.merge(data)
	expedition_log.append(entry)

func get_accessible_positions() -> Array:
	if map == null:
		return []
	return map.get_neighbors(current_pos).map(func(r): return r.grid_pos)

func is_pos_accessible(pos: Vector2i) -> bool:
	return get_accessible_positions().has(pos)

# --- Auto-combat for city defense while soldiers are in dungeon ---
# Returns {victory, soldiers_lost, log_lines}
func auto_resolve_city_defense(defenders: Array, enemies: Array, hit_bonus: float = 0.0) -> Dictionary:
	var log_lines: Array[String] = []
	var alive_defenders = defenders.filter(func(s): return s.is_alive())
	var alive_enemies = enemies.duplicate()

	if alive_defenders.is_empty():
		return {victory = false, soldiers_lost = 0, log_lines = ["No defenders — city fell!"]}

	var rounds = 0
	while not alive_defenders.is_empty() and not alive_enemies.is_empty() and rounds < 30:
		rounds += 1
		for sol in alive_defenders.duplicate():
			if alive_enemies.is_empty(): break

			# Pick lowest-HP alive enemy (mirrors CombatState._enemy_pick_target_lowest_hp)
			var target = alive_enemies[0]
			for e in alive_enemies:
				if e.hp_current < target.hp_current:
					target = e

			# Use best available active skill (highest damage_multiplier, off cooldown)
			var best_skill: SkillData = null
			for skill in sol.get_active_skills():
				if not skill.is_offensive():
					continue
				if sol.active_skill_cooldowns.get(skill.skill_id, 0) > 0:
					continue
				if best_skill == null or skill.damage_multiplier > best_skill.damage_multiplier:
					best_skill = skill

			var dmg: int
			if best_skill != null:
				dmg = max(1, int((sol.power + randi_range(-3, 3)) * best_skill.damage_multiplier * (1.0 + hit_bonus)))
				sol.active_skill_cooldowns[best_skill.skill_id] = best_skill.cooldown_turns
			else:
				dmg = max(1, int((sol.power + randi_range(-3, 3)) * (1.0 + hit_bonus)))

			target.hp_current -= dmg
			if not target.is_alive():
				alive_enemies.erase(target)
		for enemy in alive_enemies.duplicate():
			if alive_defenders.is_empty(): break
			var target = alive_defenders[randi_range(0, alive_defenders.size() - 1)]
			var dmg = max(1, enemy.power + randi_range(-3, 3))
			target.hp_current -= dmg
			if not target.is_alive():
				alive_defenders.erase(target)

	var victory = alive_enemies.is_empty()
	var dead_soldiers = defenders.filter(func(s): return not s.is_alive())
	var soldiers_lost = dead_soldiers.size()

	for s in dead_soldiers:
		log_lines.append("  %s fell defending the city." % s.soldier_name)
		GameState.soldiers.erase(s)

	if victory:
		log_lines.append("City defenders held the line! (%d round%s)" % [rounds, "s" if rounds > 1 else ""])
	else:
		log_lines.append("The city's defenses were overwhelmed!")

	return {victory = victory, soldiers_lost = soldiers_lost, log_lines = log_lines}
