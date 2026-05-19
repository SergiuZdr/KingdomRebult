extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var label_gold: Label = $UI/HUD/ResourceBar/TopRow/LabelGold
@onready var label_wood: Label = $UI/HUD/ResourceBar/TopRow/LabelWood
@onready var label_stone: Label = $UI/HUD/ResourceBar/TopRow/LabelStone
@onready var label_iron: Label = $UI/HUD/ResourceBar/TopRow/LabelIron
@onready var label_steel: Label = $UI/HUD/ResourceBar/TopRow/LabelSteel
@onready var label_food: Label = $UI/HUD/ResourceBar/TopRow/LabelFood
@onready var label_morale: Label = $UI/HUD/ResourceBar/TopRow/LabelMorale
@onready var label_pep: Label = $UI/HUD/ResourceBar/TopRow/LabelPep
@onready var label_turn: Label = $UI/HUD/ResourceBar/TopRow/LabelTurn
@onready var label_threat: Label = $UI/HUD/ResourceBar/LabelThreat
@onready var combat_scene = $CombatScene
@onready var soldier_menu: Control = null
@onready var combat_transition = $CombatTransition
@onready var pre_combat_screen = $PreCombatScreen

const CAMERA_SPEED: float = 400.0

var expedition_panel: Node = null

var dungeon_map_scene: Node = null
var retrieve_btn: Button = null

func _ready() -> void:
	GameState.in_city_view = true
	add_to_group("city_view")
	_update_resource_display()
	_update_threat_display()
	GameState.resources_changed.connect(_update_resource_display)
	GameState.threat_updated.connect(_update_threat_display)
	GameState.combat_started_from_turn.connect(_on_combat_started)
	GameState.dungeon_expedition_ready.connect(_open_dungeon_map)
	DungeonState.soldiers_retrieved.connect(_on_soldiers_retrieved)
	_add_buildings_button()
	_add_expeditions_button()
	_add_retrieve_button()

func _add_buildings_button() -> void:
	var btn = Button.new()
	btn.text = "Buildings"
	btn.position = Vector2(950, 690)
	btn.size = Vector2(100, 36)
	btn.pressed.connect(_on_btn_buildings_pressed)
	$UI/HUD.add_child(btn)

func _add_expeditions_button() -> void:
	var btn = Button.new()
	btn.text = "Expeditions"
	btn.position = Vector2(810, 690)
	btn.size = Vector2(130, 36)
	btn.pressed.connect(_on_btn_expeditions_pressed)
	$UI/HUD.add_child(btn)

func _add_retrieve_button() -> void:
	retrieve_btn = Button.new()
	retrieve_btn.text = "Retrieve from Dungeon"
	retrieve_btn.position = Vector2(1040, 10)
	retrieve_btn.size = Vector2(150, 36)
	retrieve_btn.visible = DungeonState.active
	retrieve_btn.pressed.connect(_on_retrieve_pressed)
	$UI/HUD.add_child(retrieve_btn)

func _on_retrieve_pressed() -> void:
	DungeonState.recall_soldiers()

func _on_soldiers_retrieved() -> void:
	if retrieve_btn:
		retrieve_btn.visible = false
	$UI.visible = true
	$UI/HUD.visible = true

const DUNGEON_TIPS: Array = [
	"Tip: Assign workers to the Farm to produce Food each turn.",
	"Tip: Barracks increase your maximum soldier count.",
	"Tip: Fountain rooms heal your entire party for 20%% HP.",
	"Tip: Goblins target your weakest soldier — protect them.",
	"Tip: Keep Morale high for better hit chance in battle.",
	"Tip: Elite rooms are harder but reward more Gold.",
	"Tip: Markets in the dungeon sell gear and permanent traits.",
	"Tip: Boss waves hit every 5th difficulty — prepare early.",
	"Tip: Soldiers gain XP from victories and Training Grounds.",
	"Tip: The Market building unlocks better weapons and armor.",
]

func _play_dungeon_transition(header_text: String, at_peak: Callable, on_complete: Callable = Callable(), start_black: bool = false) -> void:
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0
	if start_black:
		root.modulate.a = 1.0
	overlay.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(700, 120)
	vbox.position -= Vector2(350, 60)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	var header_lbl = Label.new()
	header_lbl.text = header_text
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 22)
	header_lbl.add_theme_color_override("font_color", Color(0.9, 0.82, 0.5))
	vbox.add_child(header_lbl)

	var tip_lbl = Label.new()
	tip_lbl.text = DUNGEON_TIPS[randi() % DUNGEON_TIPS.size()]
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.add_theme_font_size_override("font_size", 14)
	tip_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_lbl.custom_minimum_size = Vector2(700, 0)
	vbox.add_child(tip_lbl)

	var tween = create_tween()
	if not start_black:
		tween.tween_property(root, "modulate:a", 1.0, 0.35)
	tween.tween_callback(at_peak)
	tween.tween_interval(1.2)
	tween.tween_property(root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		overlay.queue_free()
		if on_complete.is_valid():
			on_complete.call()
	)

func _open_dungeon_map() -> void:
	$UI.visible = false
	$UI/HUD.visible = false
	if dungeon_map_scene != null:
		if not dungeon_map_scene.dungeon_scene_closed.is_connected(_on_dungeon_scene_closed):
			dungeon_map_scene.dungeon_scene_closed.connect(_on_dungeon_scene_closed, CONNECT_ONE_SHOT)
		dungeon_map_scene.show()
		return
	var header = "Entering Dungeon — Level %d" % DungeonState.dungeon_level
	_play_dungeon_transition(header, func():
		dungeon_map_scene = preload("res://scenes/dungeon/dungeon_map_scene.tscn").instantiate()
		dungeon_map_scene.dungeon_scene_closed.connect(_on_dungeon_scene_closed, CONNECT_ONE_SHOT)
		add_child(dungeon_map_scene)
		if retrieve_btn:
			retrieve_btn.visible = true
	)

func _on_dungeon_scene_closed() -> void:
	dungeon_map_scene = null
	if retrieve_btn:
		retrieve_btn.visible = false
	var at_peak := func():
		$UI.visible = true
		$UI/HUD.visible = true
	var on_complete := func():
		if not DungeonState.active:
			if not GameState._pending_city_defense_result.is_empty():
				var result = GameState._pending_city_defense_result.duplicate()
				GameState._pending_city_defense_result.clear()
				_on_city_defense_result(result)
			else:
				GameState.emit_signal("turn_ended", GameState.current_turn)
				GameState.emit_signal("recap_ready")
	_play_dungeon_transition("Returning to City…", at_peak, on_complete, true)

func _on_city_defense_result(result: Dictionary) -> void:
	GameState.menu_open = true
	var overlay = CanvasLayer.new()
	overlay.layer = 70
	add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel = PanelContainer.new()
	panel.position = Vector2(420, 180)
	panel.custom_minimum_size = Vector2(440, 300)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "City Attacked!"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var source_lbl = Label.new()
	source_lbl.text = result.get("wave_source", "Enemy Wave")
	source_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6))
	source_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(source_lbl)

	var outcome_lbl = Label.new()
	var victory: bool = result.get("victory", false)
	outcome_lbl.text = "VICTORY — City held!" if victory else "DEFEAT — City overwhelmed!"
	outcome_lbl.add_theme_font_size_override("font_size", 18)
	outcome_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4) if victory else Color(1.0, 0.3, 0.3))
	outcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(outcome_lbl)

	var soldiers_lost: int = result.get("soldiers_lost", 0)
	if soldiers_lost > 0:
		var loss_lbl = Label.new()
		loss_lbl.text = "%d soldier%s lost." % [soldiers_lost, "s" if soldiers_lost != 1 else ""]
		loss_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		loss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(loss_lbl)
	else:
		var no_loss_lbl = Label.new()
		no_loss_lbl.text = "No soldiers lost."
		no_loss_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
		no_loss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_loss_lbl)

	var watch_btn = Button.new()
	watch_btn.text = "Watch Last Battle"
	watch_btn.custom_minimum_size = Vector2(400, 44)
	watch_btn.add_theme_font_size_override("font_size", 16)
	watch_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	watch_btn.disabled = GameState._city_defense_replay_events.is_empty()
	watch_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
		_play_city_defense_replay()
	)
	vbox.add_child(watch_btn)

	var continue_btn = Button.new()
	continue_btn.text = "Skip"
	continue_btn.custom_minimum_size = Vector2(400, 44)
	continue_btn.add_theme_font_size_override("font_size", 16)
	continue_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
		GameState._city_defense_replay_events.clear()
		GameState.emit_signal("turn_ended", GameState.current_turn)
		GameState.emit_signal("recap_ready")
	)
	vbox.add_child(continue_btn)

func _play_city_defense_replay() -> void:
	var events = GameState._city_defense_replay_events.duplicate()
	GameState._city_defense_replay_events.clear()
	if events.is_empty():
		GameState.emit_signal("turn_ended", GameState.current_turn)
		GameState.emit_signal("recap_ready")
		return

	$UI.visible = false
	combat_scene.start_city_defense_replay(events, func():
		$UI.visible = true
		GameState.emit_signal("turn_ended", GameState.current_turn)
		GameState.emit_signal("recap_ready")
	)

func _on_btn_expeditions_pressed() -> void:
	if GameState.menu_open:
		return
	if expedition_panel == null:
		expedition_panel = preload("res://scenes/management/expedition_panel.tscn").instantiate()
		expedition_panel.panel_closed.connect(func():
			expedition_panel.queue_free()
			expedition_panel = null
			$UI.visible = true
		)
		add_child(expedition_panel)
	$UI.visible = false
	expedition_panel.open()

func _on_combat_started() -> void:
	$UI.visible = false
	print("Combat started, enemies: ", CombatState.enemies.size())
	print("PreCombatScreen visible: ", pre_combat_screen.visible)
	if not pre_combat_screen.selection_confirmed.is_connected(_on_soldiers_selected):
		pre_combat_screen.selection_confirmed.connect(_on_soldiers_selected, CONNECT_ONE_SHOT)
	pre_combat_screen.open(CombatState.enemies)
	print("After open, PreCombatScreen visible: ", pre_combat_screen.visible)


func _on_soldiers_selected(soldiers: Array) -> void:
	CombatState.allies = soldiers
	combat_transition.play(CombatState.enemies)
	combat_transition.transition_finished.connect(
		func(): CombatState.begin_after_selection()
		, CONNECT_ONE_SHOT
	)
	
func _process(delta: float) -> void:
	_handle_camera(delta)

func _handle_camera(delta: float) -> void:
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	camera.position += direction * CAMERA_SPEED * delta

func _update_resource_display() -> void:
	label_gold.text = "Gold: %d" % GameState.gold
	label_wood.text = "Wood: %d" % GameState.wood
	label_stone.text = "Stone: %d" % GameState.stone
	label_iron.text = "Iron: %d" % GameState.iron
	label_steel.text = "Steel: %d" % GameState.steel
	label_turn.text = "Turn: %d" % GameState.current_turn
	label_food.text = "Food: %d" % GameState.food
	label_morale.text = "Morale: %d" % GameState.morale
	label_pep.text = "People: %d" % GameState.workforce_total

func _update_threat_display() -> void:
	label_threat.text = GameState.get_threat_forecast_text()

func _on_btn_end_turn_pressed() -> void:
	if GameState.menu_open:
		return
	GameState.end_turn()

func _on_scene_exit() -> void:
	GameState.in_city_view = false
	$UI.visible = false

func _on_btn_soldiers_pressed() -> void:
	if GameState.menu_open:
		return
	if soldier_menu == null:
		soldier_menu = preload("res://scenes/management/soldier_menu.tscn").instantiate()
		add_child(soldier_menu)
	$UI.visible = false
	soldier_menu.open()

var buildings_panel: Node = null

func _on_btn_buildings_pressed() -> void:
	if buildings_panel != null:
		BuildingPopup.reopen_menu_on_close = false
		buildings_panel.queue_free()
		buildings_panel = null
		GameState.menu_open = false
		$UI.visible = true
		return
	if GameState.menu_open:
		return
	_show_buildings_panel()

func _show_buildings_panel() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	buildings_panel = layer

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.10, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20; scroll.offset_top = 50; scroll.offset_right = -20; scroll.offset_bottom = -20
	layer.add_child(scroll)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(root_vbox)

	var header = Label.new()
	header.text = "Buildings — All Categories"
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	root_vbox.add_child(header)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.pressed.connect(func():
		BuildingPopup.reopen_menu_on_close = false
		buildings_panel.queue_free()
		buildings_panel = null
		GameState.menu_open = false
		$UI.visible = true
	)
	root_vbox.add_child(close_btn)

	var category_names = {
		BuildingData.BuildingCategory.RESOURCE_OBTAINING: "Resource Obtaining",
		BuildingData.BuildingCategory.RESOURCE_PROCESSING: "Resource Processing",
		BuildingData.BuildingCategory.INTERMEDIARY: "Intermediary",
		BuildingData.BuildingCategory.MILITARY: "Military",
		BuildingData.BuildingCategory.CONSTRUCTION: "Construction",
		BuildingData.BuildingCategory.SPECIAL: "Special",
	}

	# Group buildings by category
	var groups: Dictionary = {}
	for cat in category_names.keys():
		groups[cat] = []
	for b_name in GameState.building_definitions.keys():
		var data: BuildingData = GameState.get_building_data(b_name)
		var cat = data.category
		if groups.has(cat):
			groups[cat].append(b_name)

	for cat in [
		BuildingData.BuildingCategory.RESOURCE_OBTAINING,
		BuildingData.BuildingCategory.RESOURCE_PROCESSING,
		BuildingData.BuildingCategory.INTERMEDIARY,
		BuildingData.BuildingCategory.MILITARY,
		BuildingData.BuildingCategory.CONSTRUCTION,
		BuildingData.BuildingCategory.SPECIAL,
	]:
		var b_list: Array = groups[cat]
		if b_list.is_empty():
			continue

		var cat_label = Label.new()
		cat_label.text = "— %s —" % category_names[cat]
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
		root_vbox.add_child(cat_label)

		for b_name in b_list:
			var row = _make_building_row(b_name)
			root_vbox.add_child(row)

	$UI.visible = false
	GameState.menu_open = true

func _make_building_row(b_name: String) -> PanelContainer:
	var data: BuildingData = GameState.get_building_data(b_name)
	var is_built = GameState.is_building_built(b_name)
	var workers = GameState.building_workers.get(b_name, 0)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 52)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# Building image icon
	var bld_texture = _get_building_texture_for_overview(b_name)
	if bld_texture != null:
		var img = TextureRect.new()
		img.texture = bld_texture
		img.custom_minimum_size = Vector2(48, 48)
		img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(img)

	# Status icon
	var status_lbl = Label.new()
	status_lbl.text = "[OK]" if is_built else "[RUINS]"
	status_lbl.add_theme_font_size_override("font_size", 11)
	status_lbl.add_theme_color_override("font_color",
		Color(0.3, 0.9, 0.4) if is_built else Color(0.85, 0.45, 0.2))
	status_lbl.custom_minimum_size = Vector2(62, 0)
	hbox.add_child(status_lbl)

	# Name + info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = b_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_lbl)

	var detail_lbl = Label.new()
	detail_lbl.add_theme_font_size_override("font_size", 11)
	detail_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	if is_built:
		var prod = data.get_production_per_worker()
		if not prod.is_empty():
			var parts: Array[String] = []
			for r in prod:
				var amt = prod[r]
				parts.append("%s%d %s/worker" % ["+" if amt > 0 else "", amt, r])
			detail_lbl.text = "Workers: %d  |  %s" % [workers, "  ".join(parts)]
		elif data.is_training_building():
			detail_lbl.text = "Workers: %d  |  %d XP/worker/turn" % [workers, data.training_xp_per_worker]
		else:
			detail_lbl.text = "Workers: %d  |  %s" % [workers, data.description.substr(0, 50)]
	else:
		var cost_parts: Array[String] = []
		if data.cost_gold > 0: cost_parts.append("%d Gold" % data.cost_gold)
		if data.cost_wood > 0: cost_parts.append("%d Wood" % data.cost_wood)
		if data.cost_stone > 0: cost_parts.append("%d Stone" % data.cost_stone)
		detail_lbl.text = "Rebuild: %s" % ("  ".join(cost_parts) if not cost_parts.is_empty() else "Free")
	info_vbox.add_child(detail_lbl)

	# Manage button
	var btn = Button.new()
	btn.text = "Manage"
	btn.custom_minimum_size = Vector2(90, 40)
	btn.pressed.connect(func():
		BuildingPopup.reopen_menu_on_close = true
		BuildingPopup.show_building(b_name, data.description if data else "")
	)
	hbox.add_child(btn)

	return panel

func _get_building_texture_for_overview(b_name: String) -> Texture2D:
	const PATHS: Dictionary = {
		"Tavern": "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/Tavern.png",
		"Market": "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/market stall1.png",
		"House": "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/House.png",
		"Barracks": "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/Stable or Storage.png",
		"Training Grounds": "res://Downloaded Game Assets/Constructions/Medieval House Exteriors/Stable or Storage.png",
		"Weapon Forge": "res://Downloaded Game Assets/Constructions/Generic Exterior/Pixel Art Furnace and Sawmill.png",
		"Steel Forge": "res://Downloaded Game Assets/Constructions/Generic Exterior/Pixel Art Furnace and Sawmill.png",
		"Butchery": "res://Downloaded Game Assets/Constructions/Generic Exterior/Cooking area.png",
		"Farm": "res://Downloaded Game Assets/Decor&WorldItems/Farming Tiles and Crops/GandalfHardcore Farming Tiles and Crops 32x32.png",
		"Forest": "res://Downloaded Game Assets/Decor&WorldItems/Generic Decor/Pine forest sheet.png",
		"Iron Mine": "res://Downloaded Game Assets/Decor&WorldItems/Generic Decor/Ores.png",
		"Mine": "res://Downloaded Game Assets/Decor&WorldItems/Generic Decor/Ores.png",
		"Quarry": "res://Downloaded Game Assets/Decor&WorldItems/Generic Decor/Ores.png",
	}
	var path = PATHS.get(b_name, "")
	if path == "":
		return null
	return load(path) as Texture2D

func _on_btn_save_pressed() -> void:
	_show_save_panel()

var save_panel: Control = null

func _show_save_panel() -> void:
	if save_panel != null:
		save_panel.queue_free()

	save_panel = PanelContainer.new()
	save_panel.position = Vector2(440, 200)
	save_panel.custom_minimum_size = Vector2(400, 280)
	$UI.add_child(save_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	save_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Save Game"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var info = SaveManager.get_slot_info(i)
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if info.get("empty", true):
			info_lbl.text = "Slot %d — Empty" % i
		else:
			info_lbl.text = "Slot %d — Turn %d | %s" % [
				i, info.get("turn", 0), info.get("timestamp", "")
			]
		hbox.add_child(info_lbl)

		var save_btn = Button.new()
		save_btn.text = "Save"
		save_btn.custom_minimum_size = Vector2(80, 34)
		save_btn.pressed.connect(func():
			SaveManager.save_game(i)
			save_panel.queue_free()
			save_panel = null
		)
		hbox.add_child(save_btn)

	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(func():
		save_panel.queue_free()
		save_panel = null
	)
	vbox.add_child(close_btn)

	GameState.menu_open = true
	save_panel.tree_exited.connect(func(): GameState.menu_open = false)
func _on_btn_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
