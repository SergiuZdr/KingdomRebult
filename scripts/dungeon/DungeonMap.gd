class_name DungeonMap
extends RefCounted

# Grid is 10×10. Spawn is in the CENTER cell.
# Boss is placed at the cell with maximum graph-distance from spawn.
const GRID_COLS: int = 10
const GRID_ROWS: int = 10

var rooms: Array = []        # Array[DungeonRoom], indexed by room_id
var grid: Dictionary = {}    # Vector2i(col, row) -> room_id (-1 = empty)
var dungeon_level: int = 1

## Kept for backward compat with dungeon_map_scene (uses map.num_rows for layout height)
var num_rows: int = GRID_ROWS

# Stored after generation for depth-based room typing
var _spawn_pos: Vector2i = Vector2i(-1, -1)
var _boss_pos: Vector2i  = Vector2i(-1, -1)

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
func generate(level: int, dead_remains: Array = []) -> void:
	dungeon_level = level
	rooms.clear()
	grid.clear()
	_spawn_pos = Vector2i(-1, -1)
	_boss_pos  = Vector2i(-1, -1)

	_init_grid()

	# Spawn sits in the center of the grid.
	_spawn_pos = Vector2i(GRID_COLS >> 1, GRID_ROWS >> 1)

	# Step 1 — grow a random spanning tree from spawn using Wilson's algorithm
	# variant (loop-erased random walk). Guarantees a proper spanning tree with
	# no cycles and every cell reachable, producing natural maze structure.
	#
	# Room count scales with depth: ~10 at level 1, ~16 at level 6+, ±1 variance.
	# Clamped to fit comfortably within the 10×10 grid (max 95 leaves ~15% margin).
	var base_rooms: int = clampi(13 + dungeon_level, 15, 25)
	var target_rooms: int = base_rooms + randi_range(0, 2)
	target_rooms = mini(target_rooms, GRID_COLS * GRID_ROWS - 5)
	_grow_maze_tree(_spawn_pos, target_rooms)

	# Step 2 — boss room = cell at maximum BFS distance from spawn (forces a long
	# critical path and prevents the boss being directly above spawn).
	_boss_pos = _find_farthest_cell(_spawn_pos)

	# Step 3 — ensure the boss cell is actually placed (it should already be,
	# but guard against edge cases).
	if grid.get(_boss_pos, -1) == -1:
		_place_room(_boss_pos)

	# Step 4 — assign room types, populate, place remains
	_assign_room_types()
	_populate_enemies()
	_place_remains(dead_remains)

# ---------------------------------------------------------------------------
# Maze generation — random spanning tree grown from a seed cell
# ---------------------------------------------------------------------------
func _grow_maze_tree(start_pos: Vector2i, target: int) -> void:
	_place_room(start_pos)
	var active: Array = [start_pos]
	var dirs: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

	while not active.is_empty() and count_rooms() < target:
		var pick_idx: int
		if randf() < 0.70:
			pick_idx = active.size() - 1
		else:
			pick_idx = randi_range(0, active.size() - 1)

		var pos: Vector2i = active[pick_idx]
		var shuffled_dirs: Array = dirs.duplicate()
		shuffled_dirs.shuffle()

		var extended := false
		for dir in shuffled_dirs:
			var neighbor: Vector2i = pos + dir
			if not grid.has(neighbor):
				continue
			if grid[neighbor] != -1:
				continue
			if _would_form_2x2(neighbor):
				continue

			_place_room(neighbor)
			active.append(neighbor)
			extended = true
			break

		if not extended:
			active.remove_at(pick_idx)

# ---------------------------------------------------------------------------
# Find the grid cell farthest from `origin` via BFS (for boss placement)
# ---------------------------------------------------------------------------
func _find_farthest_cell(origin: Vector2i) -> Vector2i:
	var visited: Dictionary = {}
	var queue: Array = [origin]
	visited[origin] = true
	var last: Vector2i = origin

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		last = pos
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = pos + dir
			if grid.get(n, -1) != -1 and not visited.has(n):
				visited[n] = true
				queue.append(n)

	return last

# ---------------------------------------------------------------------------
# Room placement helpers
# ---------------------------------------------------------------------------
func _place_room(pos: Vector2i) -> void:
	if not grid.has(pos):
		return
	if grid[pos] != -1:
		return
	var room := DungeonRoom.new()
	room.room_id = rooms.size()
	room.grid_pos = pos
	rooms.append(room)
	grid[pos] = room.room_id

func _init_grid() -> void:
	for row in GRID_ROWS:
		for col in GRID_COLS:
			grid[Vector2i(col, row)] = -1

func _would_form_2x2(pos: Vector2i) -> bool:
	var offsets: Array = [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]
	for off in offsets:
		var tl: Vector2i = pos + off
		var corners: Array = [tl, tl + Vector2i(1, 0), tl + Vector2i(0, 1), tl + Vector2i(1, 1)]
		var filled := 0
		for c in corners:
			if c == pos:
				filled += 1
			elif grid.get(c, -2) != -2 and grid.get(c, -1) != -1:
				filled += 1
		if filled >= 4:
			return true
	return false

# ---------------------------------------------------------------------------
# Room type assignment
# ---------------------------------------------------------------------------
func _assign_room_types() -> void:
	# BFS from spawn to get graph-distance for every occupied cell.
	var dist: Dictionary = _bfs_distances(_spawn_pos)
	var boss_dist: int = dist.get(_boss_pos, 0)

	# Separate dead-ends from corridor rooms — dead-ends are ideal for special rooms.
	var dead_ends: Array = []
	var regulars: Array = []
	for pos in grid.keys():
		if grid[pos] == -1:
			continue
		if pos == _spawn_pos or pos == _boss_pos:
			continue
		if _get_neighbors(pos).size() == 1:
			dead_ends.append(pos)
		else:
			regulars.append(pos)

	# Prefer dead-ends for fountain / market rooms so they are off the critical path.
	dead_ends.shuffle()
	regulars.shuffle()
	var pool: Array = dead_ends + regulars

	var reserved: Dictionary = {}
	var assigned_special := 0
	for pos in pool:
		match assigned_special:
			0: reserved[pos] = DungeonRoom.RoomType.FOUNTAIN
			1: reserved[pos] = DungeonRoom.RoomType.MARKET_GEAR
			2: reserved[pos] = DungeonRoom.RoomType.MARKET_TRAIT
		assigned_special += 1
		if assigned_special >= 3:
			break

	# Assign types to every occupied cell.
	for pos in grid.keys():
		if grid[pos] == -1:
			continue
		var room: DungeonRoom = rooms[grid[pos]]
		if pos == _spawn_pos:
			room.room_type = DungeonRoom.RoomType.SPAWN
			room.cleared = true
			room.visited = true
		elif pos == _boss_pos:
			room.room_type = DungeonRoom.RoomType.BOSS
		elif reserved.has(pos):
			room.room_type = reserved[pos]
		else:
			# Depth from 0.0 (spawn) to 1.0 (boss).
			var depth_pct := float(dist.get(pos, 0)) / float(maxi(boss_dist, 1))
			room.room_type = _random_room_type(depth_pct)

	# Lore rooms: only in EMPTY rooms directly adjacent to the boss (pre-boss corridor).
	var lore_candidates: Array = []
	for neighbor_pos in _get_neighbors(_boss_pos):
		var r_id: int = grid.get(neighbor_pos, -1)
		if r_id != -1:
			var candidate: DungeonRoom = rooms[r_id]
			if candidate.room_type == DungeonRoom.RoomType.EMPTY:
				lore_candidates.append(candidate)
	lore_candidates.shuffle()
	var lore_count: int = mini(2, lore_candidates.size())
	# Guarantee at least one lore room per expedition. If no boss-adjacent EMPTY
	# room exists, fall back to any EMPTY room; if there are none (common on small
	# early maps), convert a Monster/Elite room instead. Never steal the spawn,
	# boss, fountain or shops.
	if lore_count == 0:
		var empties: Array = []
		var combats: Array = []
		for r in rooms:
			if r.grid_pos == _spawn_pos or r.room_type == DungeonRoom.RoomType.BOSS:
				continue
			if r.room_type == DungeonRoom.RoomType.EMPTY:
				empties.append(r)
			elif r.room_type == DungeonRoom.RoomType.MONSTER or r.room_type == DungeonRoom.RoomType.ELITE:
				combats.append(r)
		var lore_pool: Array = empties if not empties.is_empty() else combats
		lore_pool.shuffle()
		if not lore_pool.is_empty():
			lore_candidates = [lore_pool[0]]
			lore_count = 1
	for i in lore_count:
		var lore_room: DungeonRoom = lore_candidates[i]
		lore_room.room_type = DungeonRoom.RoomType.LORE
		_populate_lore_room(lore_room, dungeon_level)

	# Assign flavor text to every remaining EMPTY room.
	for room in rooms:
		if room.room_type == DungeonRoom.RoomType.EMPTY:
			room.flavor_text = _get_empty_flavor(dungeon_level)

func _random_room_type(depth_pct: float) -> DungeonRoom.RoomType:
	# depth_pct 0.0 = near spawn (easy), 1.0 = near boss (hard)
	var roll := randf()
	if depth_pct < 0.35:
		if roll < 0.55: return DungeonRoom.RoomType.MONSTER
		elif roll < 0.82: return DungeonRoom.RoomType.EMPTY
		else: return DungeonRoom.RoomType.MONSTER
	elif depth_pct < 0.70:
		if roll < 0.50: return DungeonRoom.RoomType.MONSTER
		elif roll < 0.75: return DungeonRoom.RoomType.ELITE
		else: return DungeonRoom.RoomType.EMPTY
	else:
		if roll < 0.30: return DungeonRoom.RoomType.MONSTER
		elif roll < 0.75: return DungeonRoom.RoomType.ELITE
		else: return DungeonRoom.RoomType.EMPTY

# ---------------------------------------------------------------------------
# Enemy population
# ---------------------------------------------------------------------------
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
			var boss := EnemyData.make_boss(dungeon_level)
			var escort: Array[EnemyData] = []
			escort.assign(EnemyData.make_random_wave(dungeon_level).slice(0, 2))
			room.enemies.append(boss)
			room.enemies.append_array(escort)
			room.loot_gold = dungeon_level * 20 + randi_range(8, 20)

# ---------------------------------------------------------------------------
# Remains placement
# ---------------------------------------------------------------------------
func _place_remains(dead_remains: Array) -> void:
	if dead_remains.is_empty():
		return
	var empty_rooms: Array = rooms.filter(func(r): return r.room_type == DungeonRoom.RoomType.EMPTY)
	for remains in dead_remains:
		if empty_rooms.is_empty():
			break
		var idx := randi_range(0, empty_rooms.size() - 1)
		var room: DungeonRoom = empty_rooms[idx]
		room.has_remains = true
		room.remains_soldier_name = remains.get("soldier_name", "Unknown")
		room.remains_items = remains.get("items", [])
		empty_rooms.remove_at(idx)

# ---------------------------------------------------------------------------
# BFS distance map from a given origin cell (only traverses placed rooms)
# ---------------------------------------------------------------------------
func _bfs_distances(origin: Vector2i) -> Dictionary:
	var dist: Dictionary = {}
	var queue: Array = [origin]
	dist[origin] = 0
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for n in _get_neighbors(pos):
			if not dist.has(n):
				dist[n] = dist[pos] + 1
				queue.append(n)
	return dist

# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------
func get_room_at(pos: Vector2i) -> DungeonRoom:
	var rid: int = grid.get(pos, -1)
	if rid == -1:
		return null
	return rooms[rid]

func get_neighbors(pos: Vector2i) -> Array:
	var neighbors: Array = []
	for neighbor in _get_neighbors(pos):
		var room := get_room_at(neighbor)
		if room != null:
			neighbors.append(room)
	return neighbors

func _get_neighbors(pos: Vector2i) -> Array:
	var result: Array = []
	for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = pos + dir
		if grid.has(n) and grid[n] != -1:
			result.append(n)
	return result

func _find_spawn_pos() -> Vector2i:
	return _spawn_pos

func get_occupied_positions() -> Array:
	var result: Array = []
	for pos in grid.keys():
		if grid[pos] != -1:
			result.append(pos)
	return result

func count_rooms() -> int:
	var count := 0
	for pos in grid.keys():
		if grid[pos] != -1:
			count += 1
	return count

## BFS path from `from` to `to` that only steps through visited/cleared rooms
## (plus the target itself regardless of its state, so the party can reach it).
## Returns the full path [from, ..., to] or an empty array if unreachable.
func find_cleared_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return [from] as Array[Vector2i]
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = pos + dir
			if visited.has(n):
				continue
			if grid.get(n, -1) == -1:
				continue
			# Allow stepping through visited/cleared rooms; allow the target unconditionally.
			var room: DungeonRoom = rooms[grid[n]]
			if n != to and not room.visited and not room.cleared:
				continue
			visited[n] = true
			parent[n] = pos
			if n == to:
				# Reconstruct path.
				var path: Array[Vector2i] = []
				var cur: Vector2i = to
				while cur != from:
					path.push_front(cur)
					cur = parent[cur]
				path.push_front(from)
				return path
			queue.append(n)

	return [] as Array[Vector2i]

# ---------------------------------------------------------------------------
# Lore room population — called during generation after type assignment
# ---------------------------------------------------------------------------
static func _populate_lore_room(room: DungeonRoom, level: int) -> void:
	var pool: Array[Dictionary] = _get_level_lore_pool(level)
	if pool.is_empty():
		return
	var entry: Dictionary = pool[randi() % pool.size()]
	room.lore_title = entry.title
	room.lore_text  = entry.text
	# Flavor text = opening sentence (up to the first period, or the full text if none).
	var dot_idx: int = entry.text.find(".")
	room.flavor_text = entry.text.substr(0, dot_idx + 1) if dot_idx != -1 else entry.text

static func _get_level_lore_pool(level: int) -> Array[Dictionary]:
	match level:
		1:
			return [
				{title = "A Child's Shoe", text = "It sits in the corner of what was once a doorway. The leather has hardened but the shape is still a child's shape. There is no other sign of who left it, or why they left it here instead of taking it with them."},
				{title = "Merchant's Ledger", text = "The ink has run but the columns are still visible. Wheat, salt, iron nails. The last entry is dated three years before the fall and trails off mid-row, as though the hand that held the pen simply stopped."},
				{title = "A Sealed Door", text = "The door is wood, banded with iron, and someone wedged a beam across it from this side. Whatever is on the other side, they wanted it to stay there. The beam is still in place."},
				{title = "Carved Names", text = "Seven names carved into the stone of a wall at shoulder height, with a date beneath them. The carving is careful, deliberate. Someone wanted these names to last longer than the people who wore them."},
				{title = "Collapsed Forge", text = "The bellows are burst and the anvil has been thrown from its stand. Not by time: the marks on the floor show it was dragged and shoved. Someone was very angry, or very frightened, when they left this room."},
			] as Array[Dictionary]
		2:
			return [
				{title = "The Watch Post", text = "The garrison log ends on a night of the third moon. The last entry reads: 'No movement since midday. Oren says he heard something in the lower ward. I did not hear it. I do not want to hear it.' There are no entries after that."},
				{title = "The Warden's Armory", text = "The weapons were not taken in a rout. They were stacked carefully against the far wall, each one cleaned and wrapped in oilcloth. Soldiers who expected to come back for them. They did not come back."},
				{title = "A Letter, Unsent", text = "The parchment has yellowed but the words are clear enough: 'I know you said not to write, but the thing in the lower crypts has been louder this past week and I think you should know. I think the Seal is...' It ends there, mid-sentence."},
				{title = "The Commander's Table", text = "The map is still pinned to the table. Defensive lines drawn in charcoal, a few positions circled, one crossed out. In the margin, in a different hand: 'They are not coming from outside.'"},
				{title = "Broken Oath-Stone", text = "Oath-stones were placed at garrison thresholds, and soldiers touched them on the way out and on the way back. This one is split cleanly in two. Half is still fixed to the wall. The other half is gone."},
			] as Array[Dictionary]
		_:  # level 3+
			return [
				{title = "The Seal Chamber", text = "The room is circular, the walls covered in script too old to read quickly. In the center, a raised stone platform with seven iron brackets, four of which still hold something that glows faintly and does not respond to torchlight. The other three brackets are empty. They have been empty a long time."},
				{title = "The Warden's Last Record", text = "Cut into the floor, not written. Cut, with something sharp and clearly in a hurry: 'THE SEVET IS AWARE. IT HAS BEEN AWARE SINCE THE THIRD EXPEDITION. DO NOT BRING LIVING FIRE BELOW THIS LEVEL. DO NOT SPEAK NAMES. DO NOT STAY.' Below it, smaller: 'I stayed.'"},
				{title = "A Child's Drawing", text = "Scratched into the soft stone, clearly old, clearly the work of small hands: a city with tall walls, a sun overhead, people in the streets. At the bottom of the picture, below the city, a single shape that is not a person. It is very large. It has many eyes. The child drew it smiling."},
				{title = "The Pale Court's Mark", text = "A circle of seven dots, incised into the stone at eye height. Beside it, in a different hand and a different era: 'They were here before us. They will be here after.' Beside that, in fresh charcoal: 'Not if we seal it properly this time.'"},
				{title = "The Prince Who Did Not Leave", text = "The remains are royal, by the ring on the finger and the crest on the breastplate. The armor is old, at least two generations. He is sitting against the wall with his back to the sealed door, as though he decided that if it was going to come through, he would be the last thing it saw."},
			] as Array[Dictionary]

# ---------------------------------------------------------------------------
# Flavor text for EMPTY rooms — atmospheric one-liners by dungeon level
# ---------------------------------------------------------------------------
static func _get_empty_flavor(level: int) -> String:
	match level:
		1:
			var options: Array[String] = [
				"A doorway with no door. The threshold is worn smooth by years of feet that no longer walk here.",
				"Someone swept this room before they left. The broom is still in the corner.",
				"The window openings face east. Whatever morning they last caught is three years gone.",
				"Ash on the floor, cold and scattered. A fire was here. It was not put out carefully.",
			]
			return options[randi() % options.size()]
		2:
			var options: Array[String] = [
				"A garrison bed, still made. Soldiers make their beds before a fight. Old habit.",
				"The door has been locked from the outside. From this side, someone scratched marks into the wood counting days. The scratches stop at eleven.",
				"Two chairs facing each other. A cup on the floor between them, still upright.",
				"Training dummies along one wall, hacked to pieces. Not by training, but by someone who needed to put the fear somewhere.",
			]
			return options[randi() % options.size()]
		_:
			var options: Array[String] = [
				"The stone here is warm. Not warm the way stone gets from torches. Warm the way stone gets from something underneath it.",
				"A sound at the edge of hearing. Not movement. More like the room is paying attention.",
				"The dust moves against the draft, not with it.",
				"Your torchlight does not reach the far wall. The far wall is not that far away.",
			]
			return options[randi() % options.size()]
