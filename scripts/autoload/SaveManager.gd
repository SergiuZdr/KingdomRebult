# SaveManager.gd
extends Node

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 3

signal save_completed(slot: int)
signal load_completed(slot: int)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_%d.json" % slot

func save_game(slot: int) -> bool:
	var data = _collect_save_data()
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for slot %d" % slot)
		return false
	file.store_string(json_string)
	file.close()
	emit_signal("save_completed", slot)
	print("Game saved to slot %d" % slot)
	return true

func load_game(slot: int) -> bool:
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_error("No save file found for slot %d" % slot)
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		push_error("Failed to parse save file: %s" % json.get_error_message())
		return false
	_apply_save_data(json.get_data())
	emit_signal("load_completed", slot)
	print("Game loaded from slot %d" % slot)
	return true

func get_slot_info(slot: int) -> Dictionary:
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {empty = true, slot = slot}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {empty = true, slot = slot}
	var json = JSON.new()
	var raw_text = file.get_as_text()
	file.close()
	if json.parse(raw_text) != OK:
		return {empty = true, slot = slot}
	var data = json.get_data()
	return {
		empty = false,
		slot = slot,
		turn = data.get("current_turn", 0),
		gold = data.get("gold", 0),
		soldiers = data.get("soldiers", []).size(),
		timestamp = data.get("timestamp", "Unknown")
	}

func delete_save(slot: int) -> void:
	var path = get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _collect_save_data() -> Dictionary:
	var soldiers_data = _serialize_soldier_array(GameState.soldiers)

	var owned_items_data = []
	for item in GameState.owned_items:
		owned_items_data.append(_serialize_item(item))

	var building_workers_data = {}
	for b in GameState.building_workers:
		building_workers_data[b] = GameState.building_workers[b]

	var tavern_roster_data = _serialize_soldier_array(GameState.tavern_roster)

	var dungeon_data = _serialize_dungeon_state()

	return {
		timestamp = Time.get_datetime_string_from_system(),
		current_turn = GameState.current_turn,
		gold = GameState.gold,
		wood = GameState.wood,
		stone = GameState.stone,
		iron = GameState.iron,
		steel = GameState.steel,
		food = GameState.food,
		morale = GameState.morale,
		workforce_total = GameState.workforce_total,
		workforce_available = GameState.workforce_available,
		workforce_cap = GameState.workforce_cap,
		max_soldiers = GameState.max_soldiers,
		combat_difficulty = GameState.combat_difficulty,
		turns_until_next_battle = GameState.turns_until_next_battle,
		tavern_workers_last_turn = GameState.tavern_workers_last_turn,
		building_workers = building_workers_data,
		building_built_status = GameState.building_built_status.duplicate(),
		house_recruits_this_turn = GameState.house_recruits_this_turn,
		tavern_roster = tavern_roster_data,
		dungeon = dungeon_data,
		soldiers = soldiers_data,
		owned_items = owned_items_data,
	}

func _serialize_soldier_array(soldier_array: Array) -> Array:
	var result = []
	for s in soldier_array:
		result.append({
			soldier_name = s.soldier_name,
			soldier_class = s.soldier_class,
			level = s.level,
			experience = s.experience,
			xp_to_next_level = s.xp_to_next_level,
			hp_max = s.hp_max,
			hp_current = s.hp_current,
			power = s.power,
			speed = s.speed,
			dexterity = s.dexterity,
			weapon_1 = _serialize_item(s.weapon_1),
			weapon_2 = _serialize_item(s.weapon_2),
			armor = _serialize_item(s.armor),
			traits = _serialize_traits(s.traits),
			unlocked_skills = s.unlocked_skills.map(func(sk): return sk.skill_id),
		})
	return result

func _deserialize_soldier_array(data_array: Array) -> Array[SoldierData]:
	var result: Array[SoldierData] = []
	for s_data in data_array:
		var s = SoldierData.new()
		s.soldier_name = s_data.get("soldier_name", "Unknown")
		s.soldier_class = s_data.get("soldier_class", "")
		s.level = s_data.get("level", 1)
		s.experience = s_data.get("experience", 0)
		s.xp_to_next_level = s_data.get("xp_to_next_level", 100)
		s.hp_max = s_data.get("hp_max", 100)
		s.hp_current = s_data.get("hp_current", 100)
		s.power = s_data.get("power", 10)
		s.speed = s_data.get("speed", 5)
		s.dexterity = s_data.get("dexterity", 5)
		s.traits = _deserialize_traits(s_data.get("traits", []))
		var skill_ids: Array = s_data.get("unlocked_skills", [])
		for skill_id in skill_ids:
			var all_skills: Array = SkillLibrary.get_class_skills(s.soldier_class).duplicate()
			all_skills.append_array(SkillLibrary.get_universal_skills())
			for sk in all_skills:
				if sk.skill_id == skill_id:
					s.unlock_skill(sk)
					break
		s.weapon_1 = _deserialize_item(s_data.get("weapon_1", {}))
		s.weapon_2 = _deserialize_item(s_data.get("weapon_2", {}))
		s.armor = _deserialize_item(s_data.get("armor", {}))
		result.append(s)
	return result

func _serialize_dungeon_state() -> Dictionary:
	var d = {
		dungeon_level = DungeonState.dungeon_level,
		active = DungeonState.active,
	}
	if not DungeonState.active or DungeonState.map == null:
		return d
	d["current_pos"] = [DungeonState.current_pos.x, DungeonState.current_pos.y]
	d["soldiers_in_dungeon"] = _serialize_soldier_array(DungeonState.soldiers_in_dungeon)
	d["expedition_log"] = DungeonState.expedition_log.duplicate()
	var rooms_data = []
	for pos in DungeonState.map.grid.keys():
		var rid = DungeonState.map.grid[pos]
		if rid == -1:
			continue
		var room: DungeonRoom = DungeonState.map.rooms[rid]
		rooms_data.append({
			pos_x = pos.x,
			pos_y = pos.y,
			room_type = room.room_type,
			cleared = room.cleared,
			visited = room.visited,
			loot_gold = room.loot_gold,
		})
	d["map"] = {
		num_rows = DungeonState.map.num_rows,
		dungeon_level = DungeonState.map.dungeon_level,
		rooms = rooms_data,
	}
	return d

func _restore_dungeon_state(d: Dictionary) -> void:
	DungeonState.dungeon_level = d.get("dungeon_level", 1)
	if not d.get("active", false):
		return

	DungeonState.active = true
	var pos_arr = d.get("current_pos", [2, 5])
	DungeonState.current_pos = Vector2i(pos_arr[0], pos_arr[1])
	DungeonState.expedition_log = d.get("expedition_log", [])
	DungeonState.soldiers_in_dungeon = _deserialize_soldier_array(d.get("soldiers_in_dungeon", []))

	var map_data = d.get("map", {})
	if map_data.is_empty():
		DungeonState.active = false
		return

	var map = DungeonMap.new()
	map.dungeon_level = map_data.get("dungeon_level", 1)
	map.num_rows = map_data.get("num_rows", 6)
	map.rooms.clear()
	map.grid.clear()
	for row in map.num_rows:
		for col in DungeonMap.GRID_COLS:
			map.grid[Vector2i(col, row)] = -1

	for r_data in map_data.get("rooms", []):
		var pos = Vector2i(r_data.get("pos_x", 0), r_data.get("pos_y", 0))
		var room = DungeonRoom.new()
		room.room_id = map.rooms.size()
		room.grid_pos = pos
		room.room_type = r_data.get("room_type", DungeonRoom.RoomType.EMPTY) as DungeonRoom.RoomType
		room.cleared = r_data.get("cleared", false)
		room.visited = r_data.get("visited", false)
		room.loot_gold = r_data.get("loot_gold", 0)
		map.rooms.append(room)
		map.grid[pos] = room.room_id

	# Re-populate enemies for uncleared combat rooms
	map._populate_enemies()
	DungeonState.map = map

func _serialize_traits(traits: Array) -> Array:
	var result = []
	for t in traits:
		result.append(t.trait_id)
	return result

func _deserialize_traits(trait_ids: Array) -> Array[TraitData]:
	var result: Array[TraitData] = []
	var all_traits = TraitLibrary.get_all()
	for id in trait_ids:
		for t in all_traits:
			if t.trait_id == id:
				result.append(t)
				break
	return result

func _serialize_item(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	return {
		item_name = item.item_name,
		item_type = item.item_type,
		weapon_type = item.weapon_type,
		description = item.description,
		gold_cost = item.gold_cost,
		speed_bonus = item.speed_bonus,
		dexterity_bonus = item.dexterity_bonus,
		hp_bonus = item.hp_bonus,
		damage_min = item.damage_min,
		damage_max = item.damage_max,
		hit_chance_bonus = item.hit_chance_bonus,
		defense = item.defense,
		dodge_bonus = item.dodge_bonus,
	}

func _deserialize_item(data: Dictionary) -> ItemData:
	if data.is_empty():
		return null
	var item = ItemData.new()
	item.item_name = data.get("item_name", "")
	item.item_type = data.get("item_type", 0)
	item.weapon_type = data.get("weapon_type", 0)
	item.description = data.get("description", "")
	item.gold_cost = data.get("gold_cost", 0)
	item.speed_bonus = data.get("speed_bonus", 0)
	item.dexterity_bonus = data.get("dexterity_bonus", 0)
	item.hp_bonus = data.get("hp_bonus", 0)
	item.damage_min = data.get("damage_min", 5)
	item.damage_max = data.get("damage_max", 10)
	item.hit_chance_bonus = data.get("hit_chance_bonus", 0.0)
	item.defense = data.get("defense", 0)
	item.dodge_bonus = data.get("dodge_bonus", 0.0)
	return item

func _apply_save_data(data: Dictionary) -> void:
	GameState.current_turn = data.get("current_turn", 0)
	GameState.gold = data.get("gold", 500)
	GameState.wood = data.get("wood", 0)
	GameState.stone = data.get("stone", 0)
	GameState.iron = data.get("iron", 0)
	GameState.steel = data.get("steel", 0)
	GameState.food = data.get("food", 0)
	GameState.morale = data.get("morale", 100)
	GameState.workforce_total = data.get("workforce_total", 10)
	GameState.workforce_available = data.get("workforce_available", 10)
	GameState.workforce_cap = data.get("workforce_cap", GameState.BASE_WORKFORCE_CAP)
	GameState.max_soldiers = data.get("max_soldiers", 4)
	GameState.combat_difficulty = data.get("combat_difficulty", 1)
	GameState.turns_until_next_battle = data.get("turns_until_next_battle", 2)
	GameState.tavern_workers_last_turn = data.get("tavern_workers_last_turn", 0)

	var bw = data.get("building_workers", {})
	for b in bw:
		if GameState.building_workers.has(b):
			GameState.building_workers[b] = bw[b]

	var built = data.get("building_built_status", {})
	for b in built:
		GameState.building_built_status[b] = built[b]
	GameState.house_recruits_this_turn = data.get("house_recruits_this_turn", 0)

	GameState.soldiers = _deserialize_soldier_array(data.get("soldiers", []))

	GameState.owned_items.clear()
	for i_data in data.get("owned_items", []):
		var item = _deserialize_item(i_data)
		if item != null:
			GameState.owned_items.append(item)

	# Tavern roster
	var roster_data = data.get("tavern_roster", [])
	if roster_data.is_empty():
		GameState.refresh_tavern_roster()
	else:
		GameState.tavern_roster = _deserialize_soldier_array(roster_data)

	# Dungeon state (new format) — fall back gracefully for old saves
	var dungeon_data = data.get("dungeon", {})
	if dungeon_data.is_empty():
		# Old save format: just restore level, no expedition
		DungeonState.dungeon_level = data.get("dungeon_level", 1)
		DungeonState.active = false
	else:
		_restore_dungeon_state(dungeon_data)

	GameState.emit_signal("resources_changed")
	GameState.emit_signal("soldiers_changed")
