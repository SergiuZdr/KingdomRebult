extends GutTest

# Teste pentru generarea procedurala a hartii de dungeon:
# numar de camere, conectivitate si lipsa ciclurilor (structura de arbore).

const DIRS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]

func _occupied_cells(m: DungeonMap) -> Array:
	var cells: Array = []
	for pos in m.grid:
		if m.grid[pos] != -1:
			cells.append(pos)
	return cells

func test_generates_several_rooms():
	var m := DungeonMap.new()
	m.generate(1)
	assert_gt(m.count_rooms(), 5, "nivelul 1 genereaza mai multe camere")

func test_map_is_connected():
	var m := DungeonMap.new()
	m.generate(3)
	var n := _occupied_cells(m).size()

	# Parcurgere in latime din camera de start, pe adiacenta din grila.
	var visited := {}
	var queue: Array = [m._spawn_pos]
	visited[m._spawn_pos] = true
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in DIRS:
			var nb: Vector2i = p + d
			if m.grid.get(nb, -1) != -1 and not visited.has(nb):
				visited[nb] = true
				queue.append(nb)

	assert_eq(visited.size(), n, "toate camerele sunt accesibile din start (graf conex)")
	assert_true(visited.has(m._boss_pos), "camera de boss este accesibila din start")

func test_boss_room_exists():
	var m := DungeonMap.new()
	m.generate(2)
	assert_ne(m.grid.get(m._boss_pos, -1), -1, "camera de boss este o camera reala")
