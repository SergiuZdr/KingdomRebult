# expedition_panel.gd — shown when player clicks "Expeditions"
extends CanvasLayer

signal panel_closed

@onready var _content: VBoxContainer = $Root/ContentScroll/Content
@onready var _close_btn: Button = $Root/CloseBtn

func _ready() -> void:
	_close_btn.pressed.connect(_on_close)

func open() -> void:
	BuildingPopup.hide()
	GameState.menu_open = true
	show()
	_rebuild_content()

func _rebuild_content() -> void:
	for child in _content.get_children():
		child.queue_free()

	if DungeonState.active:
		_build_active_expedition_ui()
	else:
		_build_start_expedition_ui()

func _build_active_expedition_ui() -> void:
	var status_lbl = Label.new()
	status_lbl.text = "Active Expedition — Dungeon Level %d" % DungeonState.dungeon_level
	status_lbl.add_theme_font_size_override("font_size", 18)
	status_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	_content.add_child(status_lbl)

	# Soldier status
	var sol_panel = _make_section("Party Status")
	for s in DungeonState.soldiers_in_dungeon:
		var row = HBoxContainer.new()
		sol_panel.add_child(row)
		var name_lbl = Label.new()
		name_lbl.text = "%s [%s]" % [s.soldier_name, s.soldier_class]
		name_lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_lbl)
		var hp_lbl = Label.new()
		hp_lbl.text = "HP: %d / %d" % [s.hp_current, s.hp_max]
		hp_lbl.add_theme_color_override("font_color", _hp_color(s))
		row.add_child(hp_lbl)
	_content.add_child(sol_panel)

	# Enter dungeon button
	var enter_btn = Button.new()
	enter_btn.text = "Enter Dungeon Map"
	enter_btn.custom_minimum_size = Vector2(400, 50)
	enter_btn.add_theme_font_size_override("font_size", 16)
	enter_btn.pressed.connect(_on_enter_dungeon_pressed)
	_content.add_child(enter_btn)

	# Recall button
	var recall_btn = Button.new()
	recall_btn.text = "Recall All Soldiers to City"
	recall_btn.custom_minimum_size = Vector2(400, 44)
	recall_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	recall_btn.pressed.connect(func():
		DungeonState.recall_soldiers()
		_rebuild_content()
	)
	_content.add_child(recall_btn)

func _build_start_expedition_ui() -> void:
	# Level info
	var level_lbl = Label.new()
	level_lbl.text = "Dungeon Level %d  |  Recommended soldier level: %d+" % [
		DungeonState.dungeon_level,
		_recommended_level()
	]
	level_lbl.add_theme_font_size_override("font_size", 16)
	_content.add_child(level_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = ("Assign soldiers to explore the dungeon. They will enter on your next End Turn.\n"
		+ "Soldiers in the dungeon CANNOT defend the city — choose carefully.\n"
		+ "Soldiers who die in the dungeon are lost permanently.")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(1100, 50)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	_content.add_child(desc_lbl)

	var sep = HSeparator.new()
	_content.add_child(sep)

	# Soldier assignment
	var assign_section = _make_section("Assign Soldiers to Expedition")
	_content.add_child(assign_section)

	if GameState.soldiers.is_empty():
		var no_sol = Label.new()
		no_sol.text = "No soldiers available."
		assign_section.add_child(no_sol)
	else:
		for s in GameState.soldiers:
			if not s.is_alive():
				continue
			var row = _make_soldier_row(s)
			assign_section.add_child(row)

	# Pending list
	var pending_section = _make_section("Staged for Expedition (%d)" % DungeonState.pending_soldiers.size())
	_content.add_child(pending_section)

	if DungeonState.pending_soldiers.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No soldiers staged yet."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		pending_section.add_child(empty_lbl)
	else:
		for s in DungeonState.pending_soldiers:
			var row = _make_staged_soldier_row(s)
			pending_section.add_child(row)

	# Start button
	var start_btn = Button.new()
	start_btn.text = "Confirm — Soldiers will enter dungeon on End Turn  (%d staged)" % DungeonState.pending_soldiers.size()
	start_btn.disabled = DungeonState.pending_soldiers.is_empty()
	start_btn.custom_minimum_size = Vector2(600, 50)
	start_btn.add_theme_font_size_override("font_size", 15)
	start_btn.pressed.connect(_on_confirm_pressed)
	_content.add_child(start_btn)

func _make_soldier_row(s) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl = Label.new()
	name_lbl.text = "%s [%s Lv.%d]" % [s.soldier_name, s.soldier_class, s.level]
	name_lbl.custom_minimum_size = Vector2(280, 0)
	row.add_child(name_lbl)

	var hp_lbl = Label.new()
	hp_lbl.text = "HP %d/%d  POW %d  SPD %d" % [s.hp_current, s.hp_max, s.power, s.speed]
	hp_lbl.add_theme_color_override("font_color", _hp_color(s))
	hp_lbl.custom_minimum_size = Vector2(260, 0)
	row.add_child(hp_lbl)

	var is_staged = DungeonState.pending_soldiers.has(s)
	var assign_btn = Button.new()
	assign_btn.text = "Remove" if is_staged else "Stage"
	assign_btn.custom_minimum_size = Vector2(90, 32)
	assign_btn.pressed.connect(func():
		if DungeonState.pending_soldiers.has(s):
			DungeonState.pending_soldiers.erase(s)
		else:
			DungeonState.pending_soldiers.append(s)
		_rebuild_content()
	)
	row.add_child(assign_btn)
	return row

func _make_staged_soldier_row(s) -> HBoxContainer:
	var row = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "  → %s [%s Lv.%d]" % [s.soldier_name, s.soldier_class, s.level]
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	row.add_child(lbl)
	return row

func _make_section(title: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	vbox.add_child(lbl)
	return vbox

func _on_confirm_pressed() -> void:
	for s in DungeonState.pending_soldiers:
		if GameState.soldiers.has(s):
			GameState.soldiers.erase(s)
	GameState.emit_signal("soldiers_changed")
	_rebuild_content()

func _on_enter_dungeon_pressed() -> void:
	_on_close()
	# City_view will show the dungeon scene directly
	# We emit a signal that City_view listens to
	get_tree().call_group("city_view", "_open_dungeon_map")

func _on_close() -> void:
	GameState.menu_open = false
	hide()
	emit_signal("panel_closed")

func _hp_color(s) -> Color:
	var pct = float(s.hp_current) / float(s.hp_max)
	if pct > 0.6: return Color(0.4, 0.9, 0.4)
	elif pct > 0.3: return Color(0.9, 0.7, 0.2)
	return Color(0.9, 0.3, 0.3)

func _recommended_level() -> int:
	return 1 + (DungeonState.dungeon_level - 1) * 2
