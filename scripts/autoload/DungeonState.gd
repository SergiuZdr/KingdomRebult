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

signal expedition_started
signal soldiers_retrieved

func start_expedition() -> void:
	if pending_soldiers.is_empty():
		return
	active = true
	soldiers_in_dungeon = pending_soldiers.duplicate()
	pending_soldiers.clear()
	expedition_log.clear()

	var remains = soldier_remains.get(dungeon_level, [])
	map = DungeonMap.new()
	map.generate(dungeon_level, remains)

	current_pos = map._find_spawn_pos()
	_log("expedition_start", "Expedition started — Dungeon Level %d" % dungeon_level)
	emit_signal("expedition_started")

func recall_soldiers() -> void:
	if not active:
		return
	for s in soldiers_in_dungeon:
		if s.is_alive() and not GameState.soldiers.has(s):
			GameState.soldiers.append(s)
	soldiers_in_dungeon.clear()
	active = false
	map = null
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

func on_boss_cleared() -> void:
	dungeon_level += 1
	_log("boss_cleared", "Boss defeated! The next dungeon level is now unlocked.")
	# Auto-recall after beating boss
	recall_soldiers()

func enter_room(pos: Vector2i) -> void:
	current_pos = pos
	var room: DungeonRoom = map.get_room_at(pos)
	if room == null:
		return
	room.visited = true
	_log("move", "Moved to %s" % room.get_display_label())

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
# Returns {victory, soldiers_lost, log_lines, replay_events}
func auto_resolve_city_defense(defenders: Array, enemies: Array) -> Dictionary:
	var log_lines: Array[String] = []
	var replay_events: Array = []
	var alive_defenders = defenders.filter(func(s): return s.is_alive())
	var alive_enemies = enemies.duplicate()

	if alive_defenders.is_empty():
		return {victory = false, soldiers_lost = 0, log_lines = ["No defenders — city fell!"], replay_events = []}

	var rounds = 0
	while not alive_defenders.is_empty() and not alive_enemies.is_empty() and rounds < 30:
		rounds += 1
		for sol in alive_defenders.duplicate():
			if alive_enemies.is_empty(): break
			var target = alive_enemies[randi_range(0, alive_enemies.size() - 1)]
			var dmg = max(1, sol.power + randi_range(-3, 3))
			target.hp_current -= dmg
			replay_events.append({
				type = "attack",
				attacker_name = sol.soldier_name,
				attacker_is_ally = true,
				target_name = target.enemy_name,
				target_is_ally = false,
				damage = dmg,
				target_hp_after = maxi(0, target.hp_current),
				target_hp_max = target.hp_max,
			})
			if not target.is_alive():
				alive_enemies.erase(target)
				replay_events.append({type = "death", unit_name = target.enemy_name, is_ally = false})
		for enemy in alive_enemies.duplicate():
			if alive_defenders.is_empty(): break
			var target = alive_defenders[randi_range(0, alive_defenders.size() - 1)]
			var dmg = max(1, enemy.power + randi_range(-3, 3))
			target.hp_current -= dmg
			replay_events.append({
				type = "attack",
				attacker_name = enemy.enemy_name,
				attacker_is_ally = false,
				target_name = target.soldier_name,
				target_is_ally = true,
				damage = dmg,
				target_hp_after = maxi(0, target.hp_current),
				target_hp_max = target.hp_max,
			})
			if not target.is_alive():
				alive_defenders.erase(target)
				replay_events.append({type = "death", unit_name = target.soldier_name, is_ally = true})

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

	return {victory = victory, soldiers_lost = soldiers_lost, log_lines = log_lines, replay_events = replay_events}
