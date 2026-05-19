class_name DungeonMap
extends RefCounted

const GRID_COLS: int = 5
const BASE_ROWS: int = 6

var rooms: Array = []        # Array[DungeonRoom], indexed by room_id
var grid: Dictionary = {}    # Vector2i(col, row) -> room_id (-1 if empty)
var dungeon_level: int = 1
var num_rows: int = BASE_ROWS

func generate(level: int, dead_remains: Array = []) -> void:
	dungeon_level = level
	num_rows = randi_range(BASE_ROWS, BASE_ROWS + level * 2)
	rooms.clear()
	grid.clear()

	_init_grid()

	# Step 1: Place spawn
	_place_room(_find_spawn_pos())

	# Step 2: BFS-expand from spawn
	var frontier: Array = [_find_spawn_pos()]
	var target_rooms = 12 + level * 3 + randi_range(0, 5)
	while not frontier.is_empty() and count_rooms() < target_rooms:
		frontier.shuffle()
		var pos = frontier.pop_front()
		var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
		dirs.shuffle()
		var expand_count = randi_range(1, 4)
		var expanded = 0
		for dir in dirs:
			if expanded >= expand_count:
				break
			var neighbor = pos + dir
			if not grid.has(neighbor):
				continue
			if grid[neighbor] != -1:
				continue
			if _would_form_2x2(neighbor):
				continue
			_place_room(neighbor)
			frontier.append(neighbor)
			expanded += 1

	# Step 3: Ensure boss is placed and reachable
	_ensure_boss_connected()

	# Step 4: Remove cycles, then prune rooms unreachable from spawn
	_remove_all_cycles()
	_ensure_connectivity()

	# Step 5: Assign types, populate, place remains
	_assign_room_types()
	_populate_enemies()
	_place_remains(dead_remains)

func _place_room(pos: Vector2i) -> void:
	if not grid.has(pos):
		return
	if grid[pos] != -1:
		return  # already placed
	var room = DungeonRoom.new()
	room.room_id = rooms.size()
	room.grid_pos = pos
	rooms.append(room)
	grid[pos] = room.room_id

func _init_grid() -> void:
	for row in num_rows:
		for col in GRID_COLS:
			grid[Vector2i(col, row)] = -1

func _would_form_2x2(pos: Vector2i) -> bool:
	# A room at `pos` completes a 2x2 if any of the 4 squares containing pos are all filled
	var offsets = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]
	for off in offsets:
		var tl = pos + off
		var t_item = tl + Vector2i(1, 0)
		var bl = tl + Vector2i(0, 1)
		var br = tl + Vector2i(1, 1)
		var corners = [tl, t_item, bl, br]
		var filled_count = 0
		for c in corners:
			if c == pos:
				filled_count += 1  # this is the one we're about to place
			elif grid.get(c, -2) != -2 and grid.get(c, -1) != -1:
				filled_count += 1
		if filled_count >= 4:
			return true
	return false

func _ensure_boss_connected() -> void:
	var boss_pos = _find_boss_pos()
	var spawn_pos = _find_spawn_pos()

	# Re-add boss if not yet placed
	if grid.get(boss_pos, -1) == -1:
		var room = DungeonRoom.new()
		room.room_id = rooms.size()
		room.grid_pos = boss_pos
		rooms.append(room)
		grid[boss_pos] = room.room_id

	# BFS from spawn to check boss reachability
	var visited: Dictionary = {}
	var queue: Array = [spawn_pos]
	visited[spawn_pos] = true
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for n in _get_neighbors(pos):
			if not visited.has(n):
				visited[n] = true
				queue.append(n)

	# If boss unreachable, carve a direct column from row 1 down to nearest reachable row
	if not visited.has(boss_pos):
		for r in range(1, num_rows):
			var bridge = Vector2i(boss_pos.x, r)
			if visited.has(bridge):
				break  # connected; rooms above already exist
			if grid.get(bridge, -1) == -1:
				var room = DungeonRoom.new()
				room.room_id = rooms.size()
				room.grid_pos = bridge
				rooms.append(room)
				grid[bridge] = room.room_id

	# Ensure boss is not adjacent to spawn (shouldn't happen with BASE_ROWS>=6, extra guard)
	for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if boss_pos + dir == spawn_pos and num_rows < 3:
			push_warning("DungeonMap: boss is adjacent to spawn — map is too small.")

func _ensure_connectivity() -> void:
	# BFS from spawn to find reachable rooms; remove unreachable ones
	var spawn_id = _find_spawn_id()
	if spawn_id == -1:
		return
	var spawn_room: DungeonRoom = rooms[spawn_id]
	var reachable: Dictionary = {}
	var queue: Array = [spawn_room.grid_pos]
	reachable[spawn_room.grid_pos] = true

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for neighbor in _get_neighbors(pos):
			if not reachable.has(neighbor):
				reachable[neighbor] = true
				queue.append(neighbor)

	var boss_pos = _find_boss_pos()
	for pos in grid.keys():
		if grid[pos] != -1 and not reachable.has(pos) and pos != boss_pos:
			grid[pos] = -1

func _assign_room_types() -> void:
	var boss_pos = _find_boss_pos()
	var spawn_pos = _find_spawn_pos()

	for pos in grid.keys():
		if grid[pos] == -1:
			continue
		var room: DungeonRoom = rooms[grid[pos]]
		if pos == spawn_pos:
			room.room_type = DungeonRoom.RoomType.SPAWN
			room.cleared = true
			room.visited = true
		elif pos == boss_pos:
			room.room_type = DungeonRoom.RoomType.BOSS
		else:
			room.room_type = _random_room_type(pos.y)

func _random_room_type(row: int) -> DungeonRoom.RoomType:
	# row 0 = top (near boss), row num_rows-1 = bottom (near spawn)
	var depth_pct = float(num_rows - 1 - row) / float(num_rows - 1)  # 0 near boss, 1 near spawn

	var roll = randf()
	if depth_pct > 0.7:
		# Early rooms (near spawn) — easier mix
		if roll < 0.50: return DungeonRoom.RoomType.MONSTER
		elif roll < 0.70: return DungeonRoom.RoomType.EMPTY
		elif roll < 0.85: return DungeonRoom.RoomType.FOUNTAIN
		elif roll < 0.93: return DungeonRoom.RoomType.MARKET_GEAR
		else: return DungeonRoom.RoomType.MARKET_TRAIT
	elif depth_pct > 0.3:
		# Mid rooms
		if roll < 0.40: return DungeonRoom.RoomType.MONSTER
		elif roll < 0.60: return DungeonRoom.RoomType.ELITE
		elif roll < 0.72: return DungeonRoom.RoomType.EMPTY
		elif roll < 0.82: return DungeonRoom.RoomType.FOUNTAIN
		elif roll < 0.91: return DungeonRoom.RoomType.MARKET_GEAR
		else: return DungeonRoom.RoomType.MARKET_TRAIT
	else:
		# Deep rooms (near boss) — harder
		if roll < 0.30: return DungeonRoom.RoomType.MONSTER
		elif roll < 0.65: return DungeonRoom.RoomType.ELITE
		elif roll < 0.75: return DungeonRoom.RoomType.EMPTY
		elif roll < 0.84: return DungeonRoom.RoomType.FOUNTAIN
		elif roll < 0.92: return DungeonRoom.RoomType.MARKET_GEAR
		else: return DungeonRoom.RoomType.MARKET_TRAIT

func _populate_enemies() -> void:
	for pos in grid.keys():
		if grid[pos] == -1:
			continue
		var room: DungeonRoom = rooms[grid[pos]]
		if room.room_type == DungeonRoom.RoomType.MONSTER:
			var wave: Array[EnemyData] = []
			wave.assign(EnemyData.make_random_wave(dungeon_level).slice(0, randi_range(2, 3)))
			room.enemies = wave
		elif room.room_type == DungeonRoom.RoomType.ELITE:
			var wave: Array[EnemyData] = []
			wave.assign(EnemyData.make_random_wave(dungeon_level + 2).slice(0, randi_range(2, 4)))
			room.enemies = wave
			room.loot_gold = dungeon_level * 8 + randi_range(0, 10)
		elif room.room_type == DungeonRoom.RoomType.BOSS:
			var boss = EnemyData.make_boss(dungeon_level)
			var escort: Array[EnemyData] = []
			escort.assign(EnemyData.make_random_wave(dungeon_level).slice(0, 2))
			room.enemies.append(boss)
			room.enemies.append_array(escort)
			room.loot_gold = dungeon_level * 20 + randi_range(8, 20)

func _place_remains(dead_remains: Array) -> void:
	if dead_remains.is_empty():
		return
	# Place remains in random EMPTY rooms
	var empty_rooms: Array = rooms.filter(func(r): return r.room_type == DungeonRoom.RoomType.EMPTY)
	for remains in dead_remains:
		if empty_rooms.is_empty():
			break
		var idx = randi_range(0, empty_rooms.size() - 1)
		var room: DungeonRoom = empty_rooms[idx]
		room.has_remains = true
		room.remains_soldier_name = remains.get("soldier_name", "Unknown")
		room.remains_items = remains.get("items", [])
		empty_rooms.remove_at(idx)

func _remove_all_cycles() -> void:
	var spawn_pos = _find_spawn_pos()
	var boss_pos = _find_boss_pos()

	var changed = true
	while changed:
		changed = false
		var visited: Dictionary = {}
		var tree_parent: Dictionary = {}
		var queue: Array = [spawn_pos]
		visited[spawn_pos] = true
		tree_parent[spawn_pos] = Vector2i(-1, -1)

		var found_cycle = false
		while not queue.is_empty() and not found_cycle:
			var pos: Vector2i = queue.pop_front()
			for n in _get_neighbors(pos):
				if not visited.has(n):
					visited[n] = true
					tree_parent[n] = pos
					queue.append(n)
				elif tree_parent.get(pos, Vector2i(-1, -1)) != n:
					# Back edge found — cycle detected
					# Remove the non-critical room
					if pos != spawn_pos and pos != boss_pos:
						grid[pos] = -1
						changed = true
						found_cycle = true
						break
					elif n != spawn_pos and n != boss_pos:
						grid[n] = -1
						changed = true
						found_cycle = true
						break

# --- Helpers ---

func get_room_at(pos: Vector2i) -> DungeonRoom:
	var rid = grid.get(pos, -1)
	if rid == -1:
		return null
	return rooms[rid]

func get_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []
	for neighbor in _get_neighbors(pos):
		var room = get_room_at(neighbor)
		if room != null:
			neighbors.append(room)
	return neighbors

func _get_neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n = pos + dir
		if grid.has(n) and grid[n] != -1:
			result.append(n)
	return result

func _has_orthogonal_neighbor(pos: Vector2i) -> bool:
	return not _get_neighbors(pos).is_empty()

func _find_spawn_pos() -> Vector2i:
	return Vector2i(int(float(GRID_COLS) / 2.0), num_rows - 1)

func _find_boss_pos() -> Vector2i:
	return Vector2i(int(float(GRID_COLS) / 2.0), 0)

func _find_spawn_id() -> int:
	var pos = _find_spawn_pos()
	return grid.get(pos, -1)

func get_occupied_positions() -> Array:
	var result: Array = []
	for pos in grid.keys():
		if grid[pos] != -1:
			result.append(pos)
	return result

func count_rooms() -> int:
	var count = 0
	for pos in grid.keys():
		if grid[pos] != -1:
			count += 1
	return count

func level_extras() -> int:
	return dungeon_level
