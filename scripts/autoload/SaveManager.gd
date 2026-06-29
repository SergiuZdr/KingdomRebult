# SaveManager.gd
extends Node

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 3

var current_slot: int = 1

## Set to true the moment a loss game-over screen is shown (city fallen,
## prince consumed by veil, etc). Once set, save_game() becomes a permanent
## no-op for the rest of this session — permadeath: nothing can re-create the
## save slot we just deleted, regardless of which autosave call site fires
## next (recap continue, Main Menu buttons, tutorial save...).
var game_over: bool = false

signal save_completed(slot: int)
signal load_completed(slot: int)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func get_save_path(slot: int) -> String:
	return SAVE_DIR + "save_slot_%d.json" % slot

func save_game(slot: int) -> bool:
	if game_over:
		# Permadeath: the active save was deleted on loss — never write it
		# back, no matter which call site (autosave, main menu, etc) fires.
		return false
	var data = _collect_save_data()
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(get_save_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_string)
	file.close()
	emit_signal("save_completed", slot)
	return true

func load_game(slot: int) -> bool:
	var path = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		return false
	_apply_save_data(json.get_data())
	current_slot = slot
	# A successful load starts a live run — lift the permadeath save block.
	game_over = false
	emit_signal("load_completed", slot)
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

## Permadeath hook — call this the moment a loss game-over screen is entered
## (city fallen, prince consumed by veil, ...), BEFORE any "Continue" /
## "Return to Main Menu" button can be pressed. Deletes the active save slot
## (no-op if current_slot == 0, e.g. an unsaved fresh run), then permanently
## blocks save_game() for the rest of the session so nothing — autosave on
## recap continue, the hub/pause "Main Menu" autosave, the tutorial save —
## can resurrect the deleted save before the player quits.
func delete_save_on_game_over() -> void:
	if current_slot > 0:
		delete_save(current_slot)
	current_slot = 0
	game_over = true

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

	var building_levels_data := {}
	for b in GameState.building_levels:
		building_levels_data[b] = GameState.building_levels[b]

	# Serialize weapon forge queue
	var forge_queue_data: Array = []
	for entry in GameState.weapon_forge_queue:
		forge_queue_data.append({
			item_name = entry.item_name,
			quality = entry.quality,
			turns_remaining = entry.turns_remaining,
			result_item = _serialize_item(entry.result_item),
		})

	# Serialize training soldiers by name
	var training_soldiers_data: Array = []
	for trainer in GameState.training_soldiers:
		training_soldiers_data.append(trainer.soldier_name)

	return {
		timestamp = Time.get_datetime_string_from_system(),
		current_turn = GameState.current_turn,
		gold = GameState.gold,
		wood = GameState.wood,
		stone = GameState.stone,
		iron = GameState.iron,
		steel = GameState.steel,
		food = GameState.food,
		workforce_total = GameState.workforce_total,
		workforce_available = GameState.workforce_available,
		workforce_cap = GameState.workforce_cap,
		max_soldiers = GameState.max_soldiers,
		combat_difficulty = GameState.combat_difficulty,
		threat = GameState.threat,
		total_waves_won = GameState.total_waves_won,
		tavern_workers_last_turn = GameState.tavern_workers_last_turn,
		building_workers = building_workers_data,
		building_levels = building_levels_data,
		house_recruits_this_turn = GameState.house_recruits_this_turn,
		tavern_roster = tavern_roster_data,
		dungeon = dungeon_data,
		soldiers = soldiers_data,
		owned_items = owned_items_data,
		weapon_forge_queue = forge_queue_data,
		training_soldiers = training_soldiers_data,
		story_letters = StoryManager.get_letters_for_save(),
		story_morale_low_sent = StoryManager._morale_low_sent,
		faction_state = FactionState.get_data_for_save(),
		faction_events = FactionEvents.get_data_for_save(),
		pale_court_gift_death_pending = GameState.pale_court_gift_death_pending,
		legion_garrison_active = GameState.legion_garrison_active,
		legion_solo_fight_pending = GameState.legion_solo_fight_pending,
		next_wave_difficulty_bonus = GameState.next_wave_difficulty_bonus,
		warden_lockout_turns = DungeonState.warden_lockout_turns,
		legion_lockout_turns = DungeonState.legion_lockout_turns,
		dungeon_map_reveal_charges = DungeonState.dungeon_map_reveal_charges,
		dungeon_map_reveal_active = DungeonState.dungeon_map_reveal_active,
		pending_deserter_return = GameState.pending_deserter_return.map(func(e): return {
			soldier = _serialize_soldier_array([e.soldier])[0],
			turns_remaining = e.turns_remaining,
		}),
		pending_iron_mine_worker_restore = GameState.pending_iron_mine_worker_restore,
		city_walls = GameState.city_walls,
		max_city_walls = GameState.max_city_walls,
		damaged_buildings = GameState.damaged_buildings.duplicate(),
		win_condition_triggered = GameState.win_condition_triggered,
		win_letter_turn = GameState._win_letter_turn,
		threat_gain_rate = GameState.threat_gain_rate,
		final_battle_pending = GameState.final_battle_pending,
		game_won_achieved = GameState.game_won_achieved,
		intro_seen = GameState.intro_seen,
		tutorial_seen = GameState.tutorial_seen,
	}

func _serialize_soldier_array(soldier_array: Array) -> Array:
	var result = []
	for s in soldier_array:
		result.append({
			soldier_name = s.soldier_name,
			soldier_class = s.soldier_class,
			sprite_variant = s.sprite_variant,
			level = s.level,
			experience = s.experience,
			xp_to_next_level = s.xp_to_next_level,
			unspent_stat_points = s.unspent_stat_points,
			hp_max = s.hp_max,
			hp_current = s.hp_current,
			power = s.power,
			speed = s.speed,
			dexterity = s.dexterity,
			morale = s.morale,
			unavailable_turns = s.unavailable_turns,
			temp_soldier_turns = s.temp_soldier_turns,
			weapon_1 = _serialize_item(s.weapon_1),
			weapon_2 = _serialize_item(s.weapon_2),
			armor = _serialize_item(s.armor),
			traits = _serialize_traits(s.traits),
			unlocked_skills = s.unlocked_skills.map(func(sk): return sk.skill_id),
			equipped_skills = s.equipped_skills.map(func(sk): return sk.skill_id),
		})
	return result

func _deserialize_soldier_array(data_array: Array) -> Array[SoldierData]:
	var result: Array[SoldierData] = []
	for s_data in data_array:
		var s = SoldierData.new()
		s.soldier_name = s_data.get("soldier_name", "Unknown")
		s.soldier_class = s_data.get("soldier_class", "")
		s.sprite_variant = s_data.get("sprite_variant", 1)
		s.level = s_data.get("level", 1)
		s.experience = s_data.get("experience", 0)
		s.xp_to_next_level = s_data.get("xp_to_next_level", 100)
		s.unspent_stat_points = s_data.get("unspent_stat_points", 0)
		s.hp_max = s_data.get("hp_max", 100)
		s.hp_current = s_data.get("hp_current", 100)
		s.power = s_data.get("power", 10)
		s.speed = s_data.get("speed", 5)
		s.dexterity = s_data.get("dexterity", 5)
		s.morale = s_data.get("morale", 60)
		s.unavailable_turns = s_data.get("unavailable_turns", 0)
		s.temp_soldier_turns = s_data.get("temp_soldier_turns", 0)
		s.traits = _deserialize_traits(s_data.get("traits", []))
		# Learned pool — resolve ids against the current library, skip ids that no
		# longer exist (the skill kits were reworked). Append directly so equipped
		# HP bonuses aren't double-applied (saved hp_max already includes them).
		var skill_ids: Array = s_data.get("unlocked_skills", [])
		for skill_id in skill_ids:
			var sk: SkillData = SkillLibrary.get_skill_by_id(skill_id)
			if sk != null and not s.has_skill(sk.skill_id):
				s.unlocked_skills.append(sk)
		# Equipped loadout
		if s_data.has("equipped_skills"):
			for eid in s_data.get("equipped_skills", []):
				var esk: SkillData = SkillLibrary.get_skill_by_id(eid)
				if esk == null or s.is_equipped(esk.skill_id):
					continue
				if not s.has_skill(esk.skill_id):
					s.unlocked_skills.append(esk)
				s.equipped_skills.append(esk)  # saved hp_max already accounts for this
		else:
			# Pre-revamp save: auto-equip the first slots from the learned pool.
			for usk in s.unlocked_skills:
				if s.equipped_skills.size() >= s.max_skill_slots():
					break
				s.equip_skill(usk)
		# Legacy saves whose skill ids no longer resolve: grant class starters.
		if s.unlocked_skills.is_empty():
			s.check_skill_unlocks()
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
	# Persist the map whenever one exists — including after a recall (active=false),
	# so an in-progress dungeon survives quitting the game and can be resumed.
	if DungeonState.map == null:
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
			seen = room.seen,
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
	DungeonState.active = d.get("active", false)

	var map_data: Dictionary = d.get("map", {})
	if map_data.is_empty():
		# No persisted map — make sure nothing stale lingers.
		DungeonState.active = false
		DungeonState.map = null
		return

	var pos_arr: Array = d.get("current_pos", [DungeonMap.GRID_COLS >> 1, DungeonMap.GRID_ROWS >> 1])
	DungeonState.current_pos = Vector2i(pos_arr[0], pos_arr[1])
	DungeonState.expedition_log = d.get("expedition_log", [])
	DungeonState.soldiers_in_dungeon = _deserialize_soldier_array(d.get("soldiers_in_dungeon", []))

	var map = DungeonMap.new()
	map.dungeon_level = map_data.get("dungeon_level", 1)
	map.num_rows = map_data.get("num_rows", DungeonMap.GRID_ROWS)
	map.rooms.clear()
	map.grid.clear()
	# Always size the grid to the full board so rooms on any row resolve correctly.
	for row in DungeonMap.GRID_ROWS:
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
		room.seen = r_data.get("seen", false)
		room.loot_gold = r_data.get("loot_gold", 0)
		map.rooms.append(room)
		map.grid[pos] = room.room_id

	# Recover spawn/boss anchors from room types so neighbour reveal and
	# fast-travel behave correctly after a load.
	for room in map.rooms:
		if room.room_type == DungeonRoom.RoomType.SPAWN:
			map._spawn_pos = room.grid_pos
		elif room.room_type == DungeonRoom.RoomType.BOSS:
			map._boss_pos = room.grid_pos

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

## Items that exist in the catalog (or as hardcoded starter items) are saved
## in a compact form -- just name + quality -- and rebuilt from the catalog
## on load via ItemData.make_by_name(). Custom/unknown items (not present in
## any catalog) fall back to the old verbose dict so no data is lost.
func _serialize_item(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	if ItemData.make_by_name(item.item_name, item.quality) != null:
		return {
			name = item.item_name,
			quality = item.quality,
		}
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
		quality = item.quality,
		craft_resource_cost = item.craft_resource_cost.duplicate(),
		craft_available_at_forge_level = item.craft_available_at_forge_level,
	}

func _deserialize_item(data: Dictionary) -> ItemData:
	if data.is_empty():
		return null

	# New compact form (and back-compat upgrade path for old verbose saves):
	# rebuild deterministically from the catalog by name + quality. Old saves
	# stored item_name/quality too, so this also auto-upgrades them as long
	# as the item still exists in the catalog/starter makers.
	var lookup_name: String = data.get("name", data.get("item_name", ""))
	var lookup_quality: int = int(data.get("quality", 0))
	var rebuilt := ItemData.make_by_name(lookup_name, lookup_quality)
	if rebuilt != null:
		return rebuilt

	# Fallback: legacy verbose reconstruction for custom/unknown items that
	# no longer exist in the catalog.
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
	item.quality = data.get("quality", 0)
	item.craft_available_at_forge_level = data.get("craft_available_at_forge_level", 1)
	var crc: Dictionary = data.get("craft_resource_cost", {})
	item.craft_resource_cost = {}
	for k in crc:
		item.craft_resource_cost[k] = int(crc[k])
	return item

func _apply_save_data(data: Dictionary) -> void:
	GameState.current_turn = data.get("current_turn", 0)
	# Onboarding flags. Older saves lack these keys — default to true so a game
	# already in progress never replays the intro cinematic or the tutorial.
	GameState.intro_seen = data.get("intro_seen", true)
	GameState.tutorial_seen = data.get("tutorial_seen", true)
	GameState.gold = data.get("gold", 500)
	GameState.wood = data.get("wood", 0)
	GameState.stone = data.get("stone", 0)
	GameState.iron = data.get("iron", 0)
	GameState.steel = data.get("steel", 0)
	GameState.food = data.get("food", 0)
	GameState.workforce_total = data.get("workforce_total", 10)
	GameState.workforce_available = data.get("workforce_available", 10)
	GameState.workforce_cap = data.get("workforce_cap", GameState.BASE_WORKFORCE_CAP)
	GameState.max_soldiers = data.get("max_soldiers", 4)
	GameState.combat_difficulty = data.get("combat_difficulty", 1)
	GameState.threat = data.get("threat", 0)
	GameState.total_waves_won = data.get("total_waves_won", 0)
	GameState.tavern_workers_last_turn = data.get("tavern_workers_last_turn", 0)

	var bw: Dictionary = data.get("building_workers", {})
	for b in bw:
		if GameState.building_workers.has(b):
			GameState.building_workers[b] = bw[b]

	# Load building_levels (new format). Fall back to building_built_status from old saves.
	if data.has("building_levels"):
		var levels: Dictionary = data.get("building_levels", {})
		for b in levels:
			GameState.building_levels[b] = int(levels[b])
	elif data.has("building_built_status"):
		var built: Dictionary = data.get("building_built_status", {})
		for b in built:
			GameState.building_levels[b] = 1 if built[b] else 0

	GameState.house_recruits_this_turn = data.get("house_recruits_this_turn", 0)

	GameState.soldiers = _deserialize_soldier_array(data.get("soldiers", []))

	GameState.owned_items.clear()
	for i_data in data.get("owned_items", []):
		var item = _deserialize_item(i_data)
		if item != null:
			GameState.owned_items.append(item)

	# Tavern roster
	var roster_data: Array = data.get("tavern_roster", [])
	if roster_data.is_empty():
		GameState.refresh_tavern_roster()
	else:
		GameState.tavern_roster = _deserialize_soldier_array(roster_data)

	# Dungeon state (new format) — fall back gracefully for old saves
	var dungeon_data: Dictionary = data.get("dungeon", {})
	if dungeon_data.is_empty():
		# Old save format: just restore level, no expedition
		DungeonState.dungeon_level = data.get("dungeon_level", 1)
		DungeonState.active = false
	else:
		_restore_dungeon_state(dungeon_data)

	# Restore weapon forge queue
	GameState.weapon_forge_queue.clear()
	for entry_data in data.get("weapon_forge_queue", []):
		var result_item := _deserialize_item(entry_data.get("result_item", {}))
		if result_item == null:
			continue
		GameState.weapon_forge_queue.append({
			item_name = entry_data.get("item_name", ""),
			quality = int(entry_data.get("quality", 0)),
			turns_remaining = int(entry_data.get("turns_remaining", 1)),
			result_item = result_item,
		})

	# Restore training soldiers by matching names against loaded soldiers
	GameState.training_soldiers.clear()
	var trainer_names: Array = data.get("training_soldiers", [])
	for t_name in trainer_names:
		for s in GameState.soldiers:
			if s.soldier_name == t_name:
				GameState.training_soldiers.append(s)
				break

	StoryManager.restore_from_save(
		data.get("story_letters", []),
		data.get("story_morale_low_sent", false)
	)

	FactionState.restore_from_save(data.get("faction_state", {}))
	FactionEvents.restore_from_save(data.get("faction_events", {}))

	GameState.pale_court_gift_death_pending = data.get("pale_court_gift_death_pending", false)
	GameState.legion_garrison_active = data.get("legion_garrison_active", false)
	GameState.legion_solo_fight_pending = data.get("legion_solo_fight_pending", false)
	GameState.next_wave_difficulty_bonus = data.get("next_wave_difficulty_bonus", 0)
	DungeonState.warden_lockout_turns = data.get("warden_lockout_turns", 0)
	DungeonState.legion_lockout_turns = data.get("legion_lockout_turns", 0)
	DungeonState.dungeon_map_reveal_charges = data.get("dungeon_map_reveal_charges", 0)
	DungeonState.dungeon_map_reveal_active = data.get("dungeon_map_reveal_active", false)
	# Back-compat: old saves stored a permanent bool instead of a charge count.
	if data.get("dungeon_map_reveal_deep", false) and DungeonState.dungeon_map_reveal_charges == 0:
		DungeonState.dungeon_map_reveal_charges = DungeonState.MAP_REVEAL_EXPEDITIONS
	GameState.pending_deserter_return.clear()
	for _e in data.get("pending_deserter_return", []):
		var _soldiers := _deserialize_soldier_array([_e.get("soldier", {})])
		if not _soldiers.is_empty():
			GameState.pending_deserter_return.append({
				soldier = _soldiers[0],
				turns_remaining = _e.get("turns_remaining", 1),
			})
	GameState.pending_iron_mine_worker_restore = data.get("pending_iron_mine_worker_restore", false)
	GameState.city_walls = data.get("city_walls", 1)
	GameState.max_city_walls = data.get("max_city_walls", 4)
	GameState.damaged_buildings = data.get("damaged_buildings", {})
	GameState.win_condition_triggered = data.get("win_condition_triggered", false)
	GameState._win_letter_turn = data.get("win_letter_turn", -1)
	GameState.threat_gain_rate = data.get("threat_gain_rate", 25)
	GameState.final_battle_pending = data.get("final_battle_pending", false)
	GameState.game_won_achieved = data.get("game_won_achieved", false)

	GameState._refresh_barracks_defense_bonus()
	GameState.emit_signal("resources_changed")
	GameState.emit_signal("soldiers_changed")
