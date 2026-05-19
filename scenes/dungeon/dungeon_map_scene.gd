# dungeon_map_scene.gd — full-screen dungeon map, extends CanvasLayer
extends CanvasLayer

signal dungeon_scene_closed

const CELL_SIZE: int = 90
const CELL_PADDING: int = 10

@onready var _map_container: Control = $Root/MapContainer
@onready var _info_label: Label = $Root/RightPanel/InfoLabel
@onready var _log_container: VBoxContainer = $Root/RightPanel/LogScroll/LogList
@onready var _soldiers_label: Label = $Root/SoldiersLabel
@onready var _recall_btn: Button = $Root/RightPanel/RecallBtn
@onready var _title_label: Label = $Root/Title

var _room_buttons: Dictionary = {}  # Vector2i -> Button
var _map_content: Control = null

var _in_combat: bool = false
var _waiting_for_input: bool = true

func _ready() -> void:
	GameState.menu_open = true
	_title_label.text = "Dungeon — Level %d" % DungeonState.dungeon_level
	_recall_btn.pressed.connect(_on_recall_pressed)

	_connect_combat_signals()
	for entry in DungeonState.expedition_log:
		_add_log_entry(entry.text)
	_refresh_soldiers_label()
	_render_map()
	_refresh_info()
	_add_party_info_button()

func _render_map() -> void:
	for child in _map_container.get_children():
		child.queue_free()
	_room_buttons.clear()
	_map_content = null

	var map: DungeonMap = DungeonState.map

	# Create a sub-node to hold all map content; scale this instead of the container
	# so clip_contents on _map_container correctly clips at its original 740x640 rect.
	_map_content = Control.new()
	_map_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_container.add_child(_map_content)

	for pos in map.get_occupied_positions():
		var room: DungeonRoom = map.get_room_at(pos)
		_create_room_button(pos, room)

	_refresh_room_states()

	# Scale only _map_content to fit the MapContainer (740x640) without scrolling
	var map_width: float = DungeonMap.GRID_COLS * (CELL_SIZE + CELL_PADDING)
	var map_height: float = map.num_rows * (CELL_SIZE + CELL_PADDING)
	var scale_val: float = min(740.0 / map_width, 640.0 / map_height) * 0.95
	_map_content.scale = Vector2(scale_val, scale_val)

func _create_room_button(pos: Vector2i, room: DungeonRoom) -> void:
	# Draw connection lines to neighbors first (underneath buttons)
	var map: DungeonMap = DungeonState.map
	for neighbor_room in map.get_neighbors(pos):
		var np: Vector2i = neighbor_room.grid_pos
		# Only draw each edge once: prefer the room with smaller col, or smaller row on tie
		if np.x > pos.x or (np.x == pos.x and np.y > pos.y):
			_draw_connection_line(pos, np)

	var btn = Button.new()
	btn.text = room.get_display_label()
	btn.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	btn.position = _grid_to_screen(pos)
	btn.add_theme_font_size_override("font_size", 11)

	if room.cleared:
		btn.text = "✓"
		btn.modulate = Color(0.5, 0.5, 0.5)
	elif room.visited and not room.cleared:
		btn.modulate = room.get_display_color()
	else:
		btn.modulate = room.get_display_color() * 0.5

	btn.pressed.connect(func(): _on_room_clicked(pos))
	_map_content.add_child(btn)
	_room_buttons[pos] = btn

	# Current position indicator
	if pos == DungeonState.current_pos:
		var marker = Label.new()
		marker.text = "YOU"
		marker.add_theme_font_size_override("font_size", 9)
		marker.add_theme_color_override("font_color", Color(1, 1, 0))
		marker.position = _grid_to_screen(pos) + Vector2(int(float(CELL_SIZE) / 2.0) - 10, CELL_SIZE - 14)
		_map_content.add_child(marker)

func _draw_connection_line(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var line = Line2D.new()
	line.default_color = Color(0.4, 0.4, 0.5, 0.6)
	line.width = 2.0
	var fp = _grid_to_screen(from_pos) + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	var tp = _grid_to_screen(to_pos) + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)
	line.add_point(fp)
	line.add_point(tp)
	_map_content.add_child(line)

func _grid_to_screen(pos: Vector2i) -> Vector2:
	return Vector2(
		pos.x * (CELL_SIZE + CELL_PADDING),
		pos.y * (CELL_SIZE + CELL_PADDING)
	)

func _refresh_room_states() -> void:
	var accessible = DungeonState.get_accessible_positions()
	for pos in _room_buttons.keys():
		var btn: Button = _room_buttons[pos]
		var room: DungeonRoom = DungeonState.map.get_room_at(pos)
		if room == null:
			continue
		btn.disabled = false
		if pos == DungeonState.current_pos:
			btn.self_modulate = Color(1.2, 1.2, 0.4)
		elif accessible.has(pos) and not room.cleared:
			btn.self_modulate = Color(1.0, 1.0, 1.0)
			btn.disabled = false
		elif room.cleared:
			btn.self_modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = true
		else:
			btn.self_modulate = Color(0.4, 0.4, 0.4)
			btn.disabled = true

func _refresh_info() -> void:
	var room: DungeonRoom = DungeonState.map.get_room_at(DungeonState.current_pos)
	if room == null:
		_info_label.text = ""
		return
	_info_label.text = "Location: %s" % room.get_display_label()

func _refresh_soldiers_label() -> void:
	var names: Array[String] = []
	for s in DungeonState.soldiers_in_dungeon:
		var hp_pct = int(float(s.hp_current) / float(s.hp_max) * 100)
		names.append("%s (%d%%)" % [s.soldier_name, hp_pct])
	_soldiers_label.text = "Party: " + (", ".join(names) if not names.is_empty() else "(none)")

func _on_room_clicked(pos: Vector2i) -> void:
	if _in_combat or not _waiting_for_input:
		return
	if not DungeonState.is_pos_accessible(pos):
		return
	_enter_room(pos)

func _enter_room(pos: Vector2i) -> void:
	DungeonState.enter_room(pos)
	var room: DungeonRoom = DungeonState.map.get_room_at(pos)

	# Cleared non-combat rooms: just move without re-triggering effects
	if room.cleared and room.room_type not in [
		DungeonRoom.RoomType.MONSTER,
		DungeonRoom.RoomType.ELITE,
		DungeonRoom.RoomType.BOSS,
	]:
		_render_map()
		_refresh_info()
		_refresh_soldiers_label()
		return

	match room.room_type:
		DungeonRoom.RoomType.MONSTER, DungeonRoom.RoomType.ELITE, DungeonRoom.RoomType.BOSS:
			if not room.cleared:
				_start_dungeon_combat(room)
				return
		DungeonRoom.RoomType.FOUNTAIN:
			_handle_fountain(room)
		DungeonRoom.RoomType.EMPTY:
			_handle_empty_room(room)
		DungeonRoom.RoomType.MARKET_TRAIT:
			_open_market_trait(room)
			return  # overlay handles cleared + re-render via close button
		DungeonRoom.RoomType.MARKET_GEAR:
			_open_market_gear(room)
			return  # same

	room.cleared = true
	_render_map()
	_refresh_info()
	_refresh_soldiers_label()

func _start_dungeon_combat(room: DungeonRoom) -> void:
	_in_combat = true
	_waiting_for_input = false
	# Hide the recap screen if it is still visible from a previous city-battle turn
	var recap = get_tree().get_root().find_child("RecapScreen", true, false)
	if recap != null and recap.visible:
		recap.hide()
		GameState.menu_open = false
	CombatState.is_dungeon_combat = true
	CombatState.start_combat(room.enemies)
	CombatState.allies = DungeonState.soldiers_in_dungeon.filter(func(s): return s.is_alive())
	hide()
	CombatState.begin_after_selection()

func _on_dungeon_combat_ended(victory: bool) -> void:
	_in_combat = false
	_waiting_for_input = true
	GameState.menu_open = true
	show()

	var room: DungeonRoom = DungeonState.map.get_room_at(DungeonState.current_pos)
	if victory:
		room.cleared = true
		# Distribute gold reward
		GameState.gold += room.loot_gold
		if room.loot_gold > 0:
			DungeonState.log_event("loot", "Found %d Gold!" % room.loot_gold)
			_add_log_entry("Victory! Found %d Gold." % room.loot_gold)
		else:
			_add_log_entry("Victory!")
		# Remove dead dungeon soldiers
		var dead = DungeonState.soldiers_in_dungeon.filter(func(s): return not s.is_alive())
		for s in dead:
			DungeonState.soldier_died_in_dungeon(s)
			_add_log_entry("%s has fallen permanently." % s.soldier_name)
		if room.room_type == DungeonRoom.RoomType.BOSS:
			_add_log_entry("BOSS CLEARED! Dungeon Level %d complete." % DungeonState.dungeon_level)
			_add_log_entry("Your soldiers are ready to return to the city.")
			_render_map()
			_refresh_info()
			_refresh_soldiers_label()
			DungeonState.on_boss_cleared()
			_show_boss_cleared_return_button()
			return
	else:
		_add_log_entry("Defeat! Soldiers retreat.")
		var dead = DungeonState.soldiers_in_dungeon.filter(func(s): return not s.is_alive())
		for s in dead:
			DungeonState.soldier_died_in_dungeon(s)
			_add_log_entry("%s has fallen permanently." % s.soldier_name)
		var survivors = DungeonState.soldiers_in_dungeon.filter(func(s): return s.is_alive())
		for s in survivors:
			s.hp_current = max(1, int(s.hp_max * 0.3))
		DungeonState.recall_soldiers()
		GameState.menu_open = false
		emit_signal("dungeon_scene_closed")
		queue_free()
		return

	_render_map()
	_refresh_info()
	_refresh_soldiers_label()

func _handle_fountain(_room: DungeonRoom) -> void:
	var heal_pct = 0.20
	for s in DungeonState.soldiers_in_dungeon:
		if s.is_alive():
			var healed = int(s.hp_max * heal_pct)
			s.hp_current = mini(s.hp_max, s.hp_current + healed)
	DungeonState.log_event("fountain", "Fountain healed all soldiers for 20% max HP.")
	_add_log_entry("Fountain: all soldiers healed 20% max HP.")

func _handle_empty_room(room: DungeonRoom) -> void:
	if room.has_remains:
		_show_remains_event(room)
		return
	# Random event
	var roll = randf()
	if roll < 0.30:
		# Trap
		var dmg_pct = randf_range(0.08, 0.18)
		for s in DungeonState.soldiers_in_dungeon:
			if s.is_alive():
				var dmg = int(s.hp_max * dmg_pct)
				s.hp_current = max(1, s.hp_current - dmg)
		var dmg_msg = "Trap! All soldiers lost ~%d%% HP." % int(dmg_pct * 100)
		DungeonState.log_event("trap", dmg_msg)
		_add_log_entry(dmg_msg)
	elif roll < 0.55:
		# Gold cache
		var gold = randi_range(10, 30) * DungeonState.dungeon_level
		GameState.gold += gold
		DungeonState.log_event("gold_cache", "Found a cache of %d Gold." % gold)
		_add_log_entry("Found %d Gold in the ruins." % gold)
	else:
		DungeonState.log_event("empty", "Nothing of note here.")
		_add_log_entry("Empty room — nothing here.")

func _show_remains_event(room: DungeonRoom) -> void:
	_add_log_entry("Found the remains of %s." % room.remains_soldier_name)
	for item in room.remains_items:
		GameState.owned_items.append(item)
		_add_log_entry("  Recovered: %s" % item.item_name)
	if room.remains_items.is_empty():
		_add_log_entry("  Nothing left to recover.")
	room.has_remains = false
	DungeonState.log_event("remains", "Found remains of %s." % room.remains_soldier_name)

func _open_market_trait(room: DungeonRoom) -> void:
	# Show trait market overlay
	var overlay: Control = _make_market_overlay("Trait Market — exchange stats for traits/skills", room, true)
	add_child(overlay)

func _open_market_gear(room: DungeonRoom) -> void:
	var overlay: Control = _make_market_overlay("Gear Market — buy equipment and potions", room, false)
	add_child(overlay)

func _make_market_overlay(title: String, room: DungeonRoom, is_trait_market: bool) -> Control:
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel = PanelContainer.new()
	panel.position = Vector2(300, 130)
	panel.size = Vector2(600, 460)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	vbox.add_child(title_lbl)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 340)
	vbox.add_child(scroll)
	var items_vbox = VBoxContainer.new()
	items_vbox.custom_minimum_size = Vector2(560, 0)
	scroll.add_child(items_vbox)

	if is_trait_market:
		# Pre-shuffle once so the market stays stable across rebuilds
		var market_traits = TraitLibrary.get_all().duplicate()
		market_traits.shuffle()
		market_traits = market_traits.slice(0, 4)
		var market_skills = SkillLibrary.get_universal_skills().duplicate()
		market_skills.shuffle()
		market_skills = market_skills.slice(0, 2)
		var selected_idx = [0]
		_populate_trait_market(items_vbox, room, selected_idx, market_traits, market_skills)
	else:
		_populate_gear_market(items_vbox, room)

	var close_btn = Button.new()
	close_btn.text = "Leave Market"
	close_btn.custom_minimum_size = Vector2(580, 40)
	close_btn.pressed.connect(func():
		room.cleared = true
		overlay.queue_free()
		_render_map()
		_refresh_info()
	)
	vbox.add_child(close_btn)
	return overlay

func _calc_trait_cost(t: TraitData) -> int:
	var v = 0
	v += abs(t.power_bonus)
	v += abs(t.speed_bonus)
	v += abs(t.dexterity_bonus)
	v += int(float(abs(t.hp_bonus)) / 8.0)
	v += abs(t.defense_bonus)
	v += int(t.hit_chance_bonus * 15.0)
	v += int(t.dodge_bonus * 15.0)
	return clampi(v, 2, 12)

func _calc_skill_cost(sk: SkillData) -> int:
	var v = 4
	if sk.damage_multiplier > 1.0:
		v += int((sk.damage_multiplier - 1.0) * 6.0)
	v += int(sk.hit_chance_bonus * 10.0)
	if sk.cooldown_turns <= 1:
		v += 2
	elif sk.cooldown_turns <= 2:
		v += 1
	return clampi(v, 3, 10)

func _populate_trait_market(container: VBoxContainer, room: DungeonRoom, selected_idx: Array, market_traits: Array, market_skills: Array) -> void:
	# Clear any previous content
	for child in container.get_children():
		child.queue_free()

	var alive = DungeonState.soldiers_in_dungeon.filter(func(s): return s.is_alive())
	if alive.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No living soldiers to receive traits or skills."
		container.add_child(empty_lbl)
		return

	# Clamp selected_idx in case a soldier died
	if selected_idx[0] >= alive.size():
		selected_idx[0] = 0

	# Soldier selector
	var sel_lbl = Label.new()
	sel_lbl.text = "Select which soldier receives the trait or skill:"
	sel_lbl.add_theme_font_size_override("font_size", 13)
	sel_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	container.add_child(sel_lbl)

	var sel_btns: Array[Button] = []
	var sel_hbox = HBoxContainer.new()
	sel_hbox.add_theme_constant_override("separation", 6)
	container.add_child(sel_hbox)
	for i in alive.size():
		var s = alive[i]
		var sbtn = Button.new()
		sbtn.text = "%s\n[%s Lv.%d]\nPOW:%d SPD:%d" % [s.soldier_name, s.soldier_class, s.level, s.power, s.speed]
		sbtn.custom_minimum_size = Vector2(130, 60)
		sbtn.toggle_mode = true
		sbtn.button_pressed = (i == selected_idx[0])
		var capture_i = i
		sbtn.pressed.connect(func():
			selected_idx[0] = capture_i
			for ob in sel_btns:
				ob.button_pressed = false
			sbtn.button_pressed = true
			# Rebuild to update Owned/disabled states for newly selected soldier
			_populate_trait_market(container, room, selected_idx, market_traits, market_skills)
		)
		sel_hbox.add_child(sbtn)
		sel_btns.append(sbtn)

	var sep1 = HSeparator.new()
	container.add_child(sep1)

	# Traits (cost Power)
	var t_header = Label.new()
	t_header.text = "Traits  (cost Power permanently):"
	t_header.add_theme_font_size_override("font_size", 12)
	container.add_child(t_header)

	var sol_for_check = alive[selected_idx[0]]

	for t in market_traits:
		var cost = _calc_trait_cost(t)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)

		var info = Label.new()
		info.text = "%s — %s" % [t.trait_name, t.description.substr(0, 55)]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.custom_minimum_size = Vector2(360, 0)
		row.add_child(info)

		var already_has = sol_for_check.traits.any(func(t2): return t2.trait_id == t.trait_id)
		if already_has:
			var owned_lbl = Label.new()
			owned_lbl.text = "[Owned]"
			owned_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			owned_lbl.custom_minimum_size = Vector2(90, 50)
			owned_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(owned_lbl)
		else:
			var buy_btn = Button.new()
			buy_btn.text = "Give  (%d POW)" % cost
			buy_btn.custom_minimum_size = Vector2(120, 50)
			buy_btn.disabled = sol_for_check.power < cost + 2
			buy_btn.pressed.connect(func():
				var sol = alive[selected_idx[0]]
				if sol.power < cost + 2:
					return
				var already = sol.traits.any(func(t2): return t2.trait_id == t.trait_id)
				if already:
					return
				sol.power -= cost
				sol.traits.append(t)
				DungeonState.log_event("market_trait", "%s acquired %s (-POW %d)." % [sol.soldier_name, t.trait_name, cost])
				_populate_trait_market(container, room, selected_idx, market_traits, market_skills)
			)
			row.add_child(buy_btn)

	var sep2 = HSeparator.new()
	container.add_child(sep2)

	# Skills (cost Speed)
	var sk_header = Label.new()
	sk_header.text = "Skills  (cost Speed permanently):"
	sk_header.add_theme_font_size_override("font_size", 12)
	container.add_child(sk_header)

	for sk in market_skills:
		var cost = _calc_skill_cost(sk)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)

		var info = Label.new()
		info.text = "%s — %s" % [sk.skill_name, sk.description.substr(0, 55)]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.custom_minimum_size = Vector2(360, 0)
		row.add_child(info)

		var already_has_sk = sol_for_check.unlocked_skills.any(func(e): return e.skill_id == sk.skill_id)
		if already_has_sk:
			var owned_lbl = Label.new()
			owned_lbl.text = "[Owned]"
			owned_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			owned_lbl.custom_minimum_size = Vector2(90, 50)
			owned_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			owned_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(owned_lbl)
		else:
			var buy_btn = Button.new()
			buy_btn.text = "Give  (%d SPD)" % cost
			buy_btn.custom_minimum_size = Vector2(120, 50)
			buy_btn.disabled = sol_for_check.speed < cost + 2
			buy_btn.pressed.connect(func():
				var sol = alive[selected_idx[0]]
				if sol.speed < cost + 2:
					return
				var already = sol.unlocked_skills.any(func(e): return e.skill_id == sk.skill_id)
				if already:
					return
				sol.speed -= cost
				sol.unlock_skill(sk)
				DungeonState.log_event("market_skill", "%s learned %s (-SPD %d)." % [sol.soldier_name, sk.skill_name, cost])
				_populate_trait_market(container, room, selected_idx, market_traits, market_skills)
			)
			row.add_child(buy_btn)

func _populate_gear_market(container: VBoxContainer, _room: DungeonRoom) -> void:
	var all_btns: Array[Button] = []
	var gold_lbl = Label.new()
	gold_lbl.text = "Gold: %d" % GameState.gold
	gold_lbl.add_theme_font_size_override("font_size", 14)
	gold_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.3))
	container.add_child(gold_lbl)

	var refresh_btns = func():
		gold_lbl.text = "Gold: %d" % GameState.gold
		for b in all_btns:
			if is_instance_valid(b):
				b.disabled = GameState.gold < int(b.get_meta("cost", 0))

	for item in GameState.available_items.slice(0, 5):
		var row = HBoxContainer.new()
		container.add_child(row)
		var info = Label.new()
		info.text = "%s — %d Gold" % [item.item_name, item.gold_cost]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.set_meta("cost", item.gold_cost)
		buy_btn.disabled = GameState.gold < item.gold_cost
		buy_btn.pressed.connect(func():
			if GameState.buy_market_item(item):
				DungeonState.log_event("market_gear", "Purchased %s." % item.item_name)
				refresh_btns.call()
		)
		row.add_child(buy_btn)
		all_btns.append(buy_btn)

	# Healing potion
	var potion_row = HBoxContainer.new()
	container.add_child(potion_row)
	var potion_cost = 30 * DungeonState.dungeon_level
	var potion_info = Label.new()
	potion_info.text = "Healing Potion (15-25%% HP) — %d Gold" % potion_cost
	potion_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(potion_info)
	var potion_btn = Button.new()
	potion_btn.text = "Buy"
	potion_btn.set_meta("cost", potion_cost)
	potion_btn.disabled = GameState.gold < potion_cost
	potion_btn.pressed.connect(func():
		if GameState.gold >= potion_cost:
			GameState.gold -= potion_cost
			for s in DungeonState.soldiers_in_dungeon:
				if s.is_alive():
					var heal = int(s.hp_max * randf_range(0.15, 0.25))
					s.hp_current = mini(s.hp_max, s.hp_current + heal)
			DungeonState.log_event("market_potion", "Used healing potion.")
			GameState.emit_signal("resources_changed")
			refresh_btns.call()
	)
	potion_row.add_child(potion_btn)
	all_btns.append(potion_btn)

func _show_boss_cleared_return_button() -> void:
	# Remove existing recall button and replace with a prominent "Return to City" button
	var return_btn = Button.new()
	return_btn.text = "Return to City"
	return_btn.custom_minimum_size = Vector2(200, 56)
	return_btn.add_theme_font_size_override("font_size", 18)
	return_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	return_btn.pressed.connect(func():
		GameState.menu_open = false
		emit_signal("dungeon_scene_closed")
		queue_free()
	)
	$Root/RightPanel.add_child(return_btn)
	# Hide the normal recall button since soldiers are already recalled
	_recall_btn.visible = false

func _on_recall_pressed() -> void:
	DungeonState.recall_soldiers()
	_add_log_entry("Soldiers recalled to the city.")
	GameState.menu_open = false
	emit_signal("dungeon_scene_closed")
	queue_free()

func _add_log_entry(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(310, 0)
	_log_container.add_child(lbl)

func _connect_combat_signals() -> void:
	if not CombatState.dungeon_combat_ended.is_connected(_on_dungeon_combat_ended):
		CombatState.dungeon_combat_ended.connect(_on_dungeon_combat_ended)

func _input(event: InputEvent) -> void:
	if _in_combat or not _waiting_for_input:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var dir: Vector2i = Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:    dir = Vector2i(0, -1)
		KEY_S, KEY_DOWN:  dir = Vector2i(0,  1)
		KEY_A, KEY_LEFT:  dir = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT: dir = Vector2i( 1, 0)
		_: return
	var target = DungeonState.current_pos + dir
	if DungeonState.is_pos_accessible(target):
		_enter_room(target)

# ─── Party Info Button & Overlay ──────────────────────────────────────────────

func _add_party_info_button() -> void:
	var btn = Button.new()
	btn.name = "PartyInfoBtn"
	btn.text = "Party"
	btn.custom_minimum_size = Vector2(200, 40)
	btn.pressed.connect(_open_party_info_overlay)
	$Root/RightPanel.add_child(btn)

func _open_party_info_overlay(scroll_y: float = 0.0) -> void:
	_waiting_for_input = false

	var overlay = CanvasLayer.new()
	overlay.layer = 55
	overlay.name = "PartyInfoOverlay"
	add_child(overlay)

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	# Centered panel
	var panel = PanelContainer.new()
	panel.position = Vector2(180, 60)
	panel.size = Vector2(820, 640)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.11, 0.15, 0.98)
	panel_style.border_color = Color(0.45, 0.52, 0.68, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	bg.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(outer_vbox)

	# Header row
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "Party — Dungeon Level %d" % DungeonState.dungeon_level
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.4))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 32)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_waiting_for_input = true
	)
	header.add_child(close_btn)

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 560)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(760, 0)
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var soldiers = DungeonState.soldiers_in_dungeon
	if soldiers.is_empty():
		var none_lbl = Label.new()
		none_lbl.text = "No soldiers in dungeon."
		content.add_child(none_lbl)
	else:
		for sol in soldiers:
			content.add_child(_make_party_soldier_card(sol, overlay, scroll))

	# Restore scroll position after the layout settles
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll_y)

func _make_party_soldier_card(sol: SoldierData, overlay: CanvasLayer, scroll: ScrollContainer) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(740, 0)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.13, 0.15, 0.21, 1.0)
	card_style.border_color = Color(0.38, 0.45, 0.60, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card.add_theme_stylebox_override("panel", card_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Name / class / level / alive status
	var name_hbox = HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(name_hbox)

	var name_lbl = Label.new()
	name_lbl.text = sol.get_display_name()
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_lbl)

	var status_lbl = Label.new()
	if sol.is_alive():
		status_lbl.text = "Alive"
		status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		status_lbl.text = "Dead"
		status_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	name_hbox.add_child(status_lbl)

	# HP bar
	var hp_pct = float(sol.hp_current) / float(sol.hp_max) if sol.hp_max > 0 else 0.0
	var hp_bar_hbox = HBoxContainer.new()
	hp_bar_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_bar_hbox)

	var hp_bar_lbl = Label.new()
	hp_bar_lbl.text = "HP:"
	hp_bar_lbl.add_theme_font_size_override("font_size", 12)
	hp_bar_hbox.add_child(hp_bar_lbl)

	var hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = sol.hp_max
	hp_bar.value = sol.hp_current
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(200, 18)
	if hp_pct > 0.6:
		hp_bar.modulate = Color(0.3, 0.9, 0.3)
	elif hp_pct > 0.3:
		hp_bar.modulate = Color(0.95, 0.85, 0.2)
	else:
		hp_bar.modulate = Color(0.9, 0.25, 0.25)
	hp_bar_hbox.add_child(hp_bar)

	var hp_num_lbl = Label.new()
	hp_num_lbl.text = "%d / %d" % [sol.hp_current, sol.hp_max]
	hp_num_lbl.add_theme_font_size_override("font_size", 12)
	hp_bar_hbox.add_child(hp_num_lbl)

	# Stats row
	var stats_lbl = Label.new()
	stats_lbl.text = "POW: %d   SPD: %d   DEX: %d   DEF: %d" % [
		sol.get_total_power(),
		sol.get_total_speed(),
		sol.dexterity,
		sol.get_total_defense()
	]
	stats_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(stats_lbl)

	# Equipment slots
	var equip_hdr = Label.new()
	equip_hdr.text = "Equipment:"
	equip_hdr.add_theme_font_size_override("font_size", 12)
	equip_hdr.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95))
	vbox.add_child(equip_hdr)

	for slot_info in [["weapon_1", "Weapon 1"], ["weapon_2", "Weapon 2"], ["armor", "Armor"]]:
		var slot = slot_info[0]
		var slot_title = slot_info[1]
		var equipped = sol.get(slot) as ItemData

		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(slot_hbox)

		var slot_lbl = Label.new()
		slot_lbl.text = "%s: %s" % [slot_title, equipped.item_name if equipped else "Empty"]
		slot_lbl.custom_minimum_size = Vector2(320, 0)
		slot_lbl.add_theme_color_override("font_color", Color(0.75, 0.79, 0.88))
		slot_lbl.add_theme_font_size_override("font_size", 12)
		slot_hbox.add_child(slot_lbl)

		if equipped != null:
			var unequip_btn = Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(90, 28)
			unequip_btn.pressed.connect(func():
				var saved_scroll = scroll.scroll_vertical
				GameState.unequip_item(sol, slot)
				overlay.queue_free()
				call_deferred("_open_party_info_overlay", float(saved_scroll))
			)
			slot_hbox.add_child(unequip_btn)

		var owned = GameState.get_owned_items_for_slot(slot)
		for item in owned:
			var item_row = HBoxContainer.new()
			item_row.add_theme_constant_override("separation", 8)
			vbox.add_child(item_row)

			var item_lbl = Label.new()
			item_lbl.text = "  → %s — %s" % [item.item_name, item.get_stats_display()]
			item_lbl.custom_minimum_size = Vector2(340, 0)
			item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			item_lbl.add_theme_font_size_override("font_size", 11)
			item_row.add_child(item_lbl)

			var equip_btn = Button.new()
			equip_btn.text = "Equip"
			equip_btn.custom_minimum_size = Vector2(80, 28)
			equip_btn.pressed.connect(func():
				var saved_scroll = scroll.scroll_vertical
				GameState.equip_owned_item(sol, item, slot)
				overlay.queue_free()
				call_deferred("_open_party_info_overlay", float(saved_scroll))
			)
			item_row.add_child(equip_btn)

	# Skills
	if not sol.unlocked_skills.is_empty():
		var skills_hdr = Label.new()
		skills_hdr.text = "Skills:"
		skills_hdr.add_theme_font_size_override("font_size", 12)
		skills_hdr.add_theme_color_override("font_color", Color(0.5, 0.85, 0.95))
		vbox.add_child(skills_hdr)
		for sk in sol.unlocked_skills:
			var cd_info = ""
			if sk.skill_type != SkillData.SkillType.PASSIVE:
				var cur_cd = sol.active_skill_cooldowns.get(sk.skill_id, 0)
				cd_info = " [CD: %d/%d]" % [cur_cd, sk.cooldown_turns]
			var sk_lbl = Label.new()
			sk_lbl.text = "  • %s%s — %s" % [sk.skill_name, cd_info, sk.description.substr(0, 60)]
			sk_lbl.add_theme_font_size_override("font_size", 11)
			sk_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
			sk_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			sk_lbl.custom_minimum_size = Vector2(700, 0)
			vbox.add_child(sk_lbl)

	# Traits
	if not sol.traits.is_empty():
		var traits_hdr = Label.new()
		traits_hdr.text = "Traits:"
		traits_hdr.add_theme_font_size_override("font_size", 12)
		traits_hdr.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		vbox.add_child(traits_hdr)
		for trait_item in sol.traits:
			var tr_lbl = Label.new()
			tr_lbl.text = "  • %s — %s" % [trait_item.trait_name, trait_item.description.substr(0, 60)]
			tr_lbl.add_theme_font_size_override("font_size", 11)
			tr_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			tr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			tr_lbl.custom_minimum_size = Vector2(700, 0)
			vbox.add_child(tr_lbl)

	return card
