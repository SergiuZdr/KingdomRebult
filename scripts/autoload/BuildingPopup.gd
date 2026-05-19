# BuildingPopup.gd
extends CanvasLayer

var popup_panel: Panel
var title_label: Label
var desc_label: Label
var close_button: Button

var workers_label: Label
var production_label: Label
var btn_add: Button
var btn_remove: Button
var btn_remove5: Button
var btn_add5: Button

var tavern_section: VBoxContainer
var tavern_info_label: Label
var tavern_scroll: ScrollContainer
var tavern_roster_list: VBoxContainer

var market_section: VBoxContainer
var market_info_label: Label
var market_scroll: ScrollContainer
var market_list: VBoxContainer

var rebuild_section: VBoxContainer
var house_section: VBoxContainer

var current_building: String = ""
var reopen_menu_on_close: bool = false

func _ready() -> void:
	layer = 50
	_build_popup()
	hide()
	GameState.turn_ended.connect(func(_turn): _close_popup())

func _build_popup() -> void:
	popup_panel = Panel.new()
	popup_panel.size = Vector2(520, 420)
	popup_panel.position = Vector2(360, 150)
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
	)
	add_child(popup_panel)

	title_label = Label.new()
	title_label.position = Vector2(20, 15)
	title_label.size = Vector2(480, 35)
	title_label.add_theme_font_size_override("font_size", 20)
	popup_panel.add_child(title_label)

	desc_label = Label.new()
	desc_label.position = Vector2(20, 55)
	desc_label.size = Vector2(480, 50)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_panel.add_child(desc_label)

	workers_label = Label.new()
	workers_label.position = Vector2(20, 115)
	workers_label.size = Vector2(480, 30)
	popup_panel.add_child(workers_label)

	btn_remove5 = Button.new()
	btn_remove5.text = " -5 "
	btn_remove5.position = Vector2(20, 150)
	btn_remove5.size = Vector2(55, 34)
	btn_remove5.pressed.connect(func():
		for _i in 5:
			GameState.assign_worker(current_building, -1)
		_refresh()
	)
	popup_panel.add_child(btn_remove5)

	btn_remove = Button.new()
	btn_remove.text = "  -  "
	btn_remove.position = Vector2(85, 150)
	btn_remove.size = Vector2(55, 34)
	btn_remove.pressed.connect(_on_remove_worker)
	popup_panel.add_child(btn_remove)

	btn_add = Button.new()
	btn_add.text = "  +  "
	btn_add.position = Vector2(150, 150)
	btn_add.size = Vector2(55, 34)
	btn_add.pressed.connect(_on_add_worker)
	popup_panel.add_child(btn_add)

	btn_add5 = Button.new()
	btn_add5.text = " +5 "
	btn_add5.position = Vector2(215, 150)
	btn_add5.size = Vector2(55, 34)
	btn_add5.pressed.connect(func():
		for _i in 5:
			GameState.assign_worker(current_building, 1)
		_refresh()
	)
	popup_panel.add_child(btn_add5)

	production_label = Label.new()
	production_label.position = Vector2(20, 195)
	production_label.size = Vector2(480, 140)
	production_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	production_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_panel.add_child(production_label)

	tavern_section = VBoxContainer.new()
	tavern_section.position = Vector2(20, 115)
	tavern_section.size = Vector2(580, 500)
	popup_panel.add_child(tavern_section)

	tavern_info_label = Label.new()
	tavern_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tavern_info_label.custom_minimum_size = Vector2(580, 40)
	tavern_section.add_child(tavern_info_label)

	var worker_hbox = HBoxContainer.new()
	tavern_section.add_child(worker_hbox)

	var lbl = Label.new()
	lbl.text = "Innkeepers: "
	lbl.custom_minimum_size = Vector2(100, 0)
	worker_hbox.add_child(lbl)

	var t_remove5 = Button.new()
	t_remove5.text = " -5 "
	t_remove5.custom_minimum_size = Vector2(50, 0)
	t_remove5.pressed.connect(func():
		for _i in 5:
			GameState.assign_worker("Tavern", -1)
		_refresh_tavern()
	)
	worker_hbox.add_child(t_remove5)

	var t_remove = Button.new()
	t_remove.text = " - "
	t_remove.custom_minimum_size = Vector2(40, 0)
	t_remove.pressed.connect(func(): GameState.assign_worker("Tavern", -1); _refresh_tavern())
	worker_hbox.add_child(t_remove)

	var t_add = Button.new()
	t_add.text = " + "
	t_add.custom_minimum_size = Vector2(40, 0)
	t_add.pressed.connect(func(): GameState.assign_worker("Tavern", 1); _refresh_tavern())
	worker_hbox.add_child(t_add)

	var t_add5 = Button.new()
	t_add5.text = " +5 "
	t_add5.custom_minimum_size = Vector2(50, 0)
	t_add5.pressed.connect(func():
		for _i in 5:
			GameState.assign_worker("Tavern", 1)
		_refresh_tavern()
	)
	worker_hbox.add_child(t_add5)

	tavern_scroll = ScrollContainer.new()
	tavern_scroll.custom_minimum_size = Vector2(580, 440)
	tavern_section.add_child(tavern_scroll)

	tavern_roster_list = VBoxContainer.new()
	tavern_roster_list.custom_minimum_size = Vector2(560, 0)
	tavern_roster_list.add_theme_constant_override("separation", 8)
	tavern_scroll.add_child(tavern_roster_list)

	market_section = VBoxContainer.new()
	market_section.position = Vector2(20, 115)
	market_section.size = Vector2(480, 240)
	popup_panel.add_child(market_section)

	market_info_label = Label.new()
	market_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	market_info_label.custom_minimum_size = Vector2(480, 36)
	market_section.add_child(market_info_label)

	market_scroll = ScrollContainer.new()
	market_scroll.custom_minimum_size = Vector2(480, 190)
	market_section.add_child(market_scroll)

	market_list = VBoxContainer.new()
	market_list.custom_minimum_size = Vector2(460, 0)
	market_scroll.add_child(market_list)

	rebuild_section = VBoxContainer.new()
	rebuild_section.position = Vector2(20, 115)
	rebuild_section.size = Vector2(480, 220)
	rebuild_section.add_theme_constant_override("separation", 10)
	popup_panel.add_child(rebuild_section)

	house_section = VBoxContainer.new()
	house_section.position = Vector2(20, 115)
	house_section.size = Vector2(480, 220)
	house_section.add_theme_constant_override("separation", 10)
	popup_panel.add_child(house_section)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(210, 368)
	close_button.size = Vector2(100, 36)
	close_button.pressed.connect(_close_popup)
	popup_panel.add_child(close_button)

func show_building(b_name: String, _b_desc: String) -> void:
	if DungeonState.active:
		return
	if GameState.menu_open and not reopen_menu_on_close:
		return
	current_building = b_name
	var data = GameState.get_building_data(current_building)
	title_label.text = b_name
	desc_label.text = data.description if data != null else _b_desc

	var is_built = GameState.is_building_built(b_name)
	var is_tavern = b_name == "Tavern"
	var is_market = b_name == "Market"
	var is_house = b_name == "House"

	if is_tavern:
		popup_panel.size = Vector2(620, 620)
		popup_panel.position = Vector2(300, 80)
		close_button.position = Vector2(260, 570)
	else:
		popup_panel.size = Vector2(520, 420)
		popup_panel.position = Vector2(360, 150)
		close_button.position = Vector2(210, 368)

	rebuild_section.visible = not is_built
	tavern_section.visible = is_tavern and is_built
	market_section.visible = is_market and is_built
	house_section.visible = is_house and is_built
	workers_label.visible = not is_tavern and not is_market and not is_house and is_built
	btn_add.visible = not is_tavern and not is_market and not is_house and is_built
	btn_remove.visible = not is_tavern and not is_market and not is_house and is_built
	btn_add5.visible = not is_tavern and not is_market and not is_house and is_built
	btn_remove5.visible = not is_tavern and not is_market and not is_house and is_built
	production_label.visible = not is_tavern and not is_house and is_built

	# Curăță explicit house_section când nu e House, ca să nu rămână conținut vechi
	if not is_house:
		for child in house_section.get_children():
			child.queue_free()

	_refresh()
	GameState.menu_open = true
	show()

func _refresh() -> void:
	if current_building == "":
		return

	if not GameState.is_building_built(current_building):
		_refresh_rebuild()
		return

	if current_building == "Tavern":
		_refresh_tavern()
	elif current_building == "Market":
		_refresh_market()
	elif current_building == "Barracks":
		_refresh_barracks()
	elif current_building == "House":
		_refresh_house()
	else:
		_refresh_standard()

func _refresh_rebuild() -> void:
	for child in rebuild_section.get_children():
		child.queue_free()

	var data = GameState.get_building_data(current_building)

	var status_label = Label.new()
	status_label.text = "This building lies in ruins."
	status_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.35))
	status_label.add_theme_font_size_override("font_size", 14)
	rebuild_section.add_child(status_label)

	var cost_label = Label.new()
	var cost_lines = "Rebuild cost:\n"
	if data != null:
		if data.cost_gold > 0:
			cost_lines += "  Gold: %d  (have %d)\n" % [data.cost_gold, GameState.gold]
		if data.cost_wood > 0:
			cost_lines += "  Wood: %d  (have %d)\n" % [data.cost_wood, GameState.wood]
		if data.cost_stone > 0:
			cost_lines += "  Stone: %d  (have %d)\n" % [data.cost_stone, GameState.stone]
		if data.cost_gold == 0 and data.cost_wood == 0 and data.cost_stone == 0:
			cost_lines += "  Free to rebuild!\n"
		if data.increases_population > 0:
			cost_lines += "\nReward: +%d Workforce (permanent)" % data.increases_population
	cost_label.text = cost_lines
	cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	cost_label.custom_minimum_size = Vector2(480, 80)
	rebuild_section.add_child(cost_label)

	var check = GameState.can_rebuild(current_building)
	var rebuild_btn = Button.new()
	rebuild_btn.custom_minimum_size = Vector2(480, 40)
	rebuild_btn.disabled = not check.can
	if check.can:
		rebuild_btn.text = "Rebuild"
	else:
		rebuild_btn.text = "Cannot rebuild — missing: %s" % check.missing
	rebuild_btn.pressed.connect(func():
		if GameState.rebuild_building(current_building):
			GameState.menu_open = false
			call_deferred("show_building", current_building, "")
	)
	rebuild_section.add_child(rebuild_btn)

func _refresh_house() -> void:
	for child in house_section.get_children():
		child.queue_free()

	var recruits = GameState.house_recruits_this_turn
	var max_r = GameState.HOUSE_MAX_RECRUITS_PER_TURN
	var gold_cost = GameState.HOUSE_RECRUIT_GOLD_COST
	var food_cost = GameState.HOUSE_RECRUIT_FOOD_COST

	var info_lbl = Label.new()
	info_lbl.text = "Workforce: %d / %d (cap)\nRecruits this turn: %d / %d\n\nEach new worker costs %d Gold + %d Food.\nBuild more Houses to raise the workforce cap." % [
		GameState.workforce_total, GameState.workforce_cap, recruits, max_r, gold_cost, food_cost,
	]
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_lbl.custom_minimum_size = Vector2(480, 80)
	house_section.add_child(info_lbl)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(460, 42)
	var check = GameState.can_recruit_worker()
	btn.disabled = not check.can
	if check.can:
		btn.text = "Recruit Worker  (%d/%d this turn)  -%d Gold  -%d Food" % [
			recruits, max_r, gold_cost, food_cost
		]
	else:
		btn.text = check.reason
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn.pressed.connect(func():
		if GameState.recruit_worker():
			_refresh_house()
	)
	house_section.add_child(btn)

func _refresh_standard() -> void:
	var data = GameState.get_building_data(current_building)
	var workers = GameState.building_workers.get(current_building, 0)
	workers_label.text = "Workers: %d  |  Available: %d / %d  (cap: %d)" % [
		workers,
		GameState.workforce_available,
		GameState.workforce_total,
		GameState.workforce_cap,
	]

	if data == null:
		production_label.text = "No building data configured."
		return

	if data.is_training_building():
		var xp = workers * data.training_xp_per_worker
		production_label.text = "XP per turn: +%d to all living soldiers\n(%d trainers × %d XP)" % [
			xp, workers, data.training_xp_per_worker
		]
		return

	var prod_text = "Production per turn:\n"
	var prod = data.get_production_for_workers(workers)
	if prod.is_empty():
		prod_text += "  — (special building)"
	else:
		for resource in prod:
			var amount = prod[resource]
			var sign_str = "+" if amount >= 0 else ""
			prod_text += "  %s%d %s\n" % [sign_str, amount, resource]
	if workers == 0:
		prod_text += "  (assign workers to produce)"
	production_label.text = prod_text

func _refresh_tavern() -> void:
	var innkeepers = GameState.building_workers.get("Tavern", 0)
	var committed_innkeepers = GameState.tavern_workers_last_turn
	var cost = GameState.get_recruit_cost()

	# Update the persistent info label at the top of tavern_section
	tavern_info_label.text = "Innkeepers: %d (committed last turn: %d) | Recruit cost: %d Gold | Slots: %d/%d" % [
		innkeepers, committed_innkeepers, cost,
		GameState.soldiers.size(),
		GameState.get_max_soldiers()
	]
	tavern_info_label.add_theme_font_size_override("font_size", 12)

	# Clear only the roster list inside the scroll container
	for child in tavern_roster_list.get_children():
		child.queue_free()

	# Lista de recruti disponibili
	if GameState.tavern_roster.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No recruits available. Wait for next turn."
		tavern_roster_list.add_child(empty_lbl)
		return

	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	tavern_roster_list.add_child(grid)
	for recruit in GameState.tavern_roster:
		var card = _make_recruit_card(recruit, committed_innkeepers)
		grid.add_child(card)

func _make_recruit_card(recruit: SoldierData, innkeepers: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = recruit.soldier_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.clip_contents = true
	vbox.add_child(name_lbl)

	# Class (revealed by innkeepers)
	var class_lbl = Label.new()
	if innkeepers >= 1:
		class_lbl.text = recruit.soldier_class
		class_lbl.add_theme_color_override("font_color", _get_class_color(recruit.soldier_class))
	else:
		class_lbl.text = "???"
		class_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	class_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(class_lbl)

	# Recruit button
	var recruit_btn = Button.new()
	recruit_btn.text = "%d G" % GameState.get_recruit_cost()
	recruit_btn.add_theme_font_size_override("font_size", 11)
	recruit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recruit_btn.disabled = (
		GameState.gold < GameState.get_recruit_cost() or
		GameState.soldiers.size() >= GameState.get_max_soldiers()
	)
	recruit_btn.pressed.connect(func():
		if GameState.recruit_from_roster(recruit):
			_refresh_tavern()
	)
	vbox.add_child(recruit_btn)

	return panel

func _get_class_color(soldier_class: String) -> Color:
	match soldier_class:
		"Warrior": return Color(0.9, 0.4, 0.3)
		"Archer":  return Color(0.3, 0.9, 0.4)
		"Rogue":   return Color(0.6, 0.3, 0.9)
		"Mage":    return Color(0.3, 0.6, 0.9)
		"Knight":  return Color(0.9, 0.8, 0.3)
	return Color(0.8, 0.8, 0.8)
	
func _refresh_barracks() -> void:
	var workers = GameState.building_workers.get("Barracks", 0)
	var data = GameState.get_building_data("Barracks")
	var staffed = workers > 0
	workers_label.text = "Workers: %d  |  Available: %d / %d  (cap: %d)" % [
		workers,
		GameState.workforce_available,
		GameState.workforce_total,
		GameState.workforce_cap,
	]

	if data == null:
		production_label.text = "No building data configured."
		return

	production_label.text = (
		"Soldier capacity: %d / %d\n" +
		"Morale: %d per turn \n" +
		"Food consumed: -%d per turn\n" +
		"%s"
	) % [
		GameState.soldiers.size(),
		GameState.get_max_soldiers(),
		data.produces_morale if staffed else 0,
		abs(data.consumes_food) if staffed else 0,
		"Assign workers to activate capacity bonus." if not staffed else "Barracks active."
	]
	return

func _refresh_market() -> void:
	market_info_label.text = "Gold: %d | Inventory: %d unequipped item(s)\nBuy gear here, then equip it from the soldier detail window." % [GameState.gold, GameState.owned_items.size()]
	for child in market_list.get_children():
		child.queue_free()

	for item in GameState.available_items:
		var wrapper = VBoxContainer.new()
		wrapper.add_theme_constant_override("separation", 4)
		market_list.add_child(wrapper)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		wrapper.add_child(row)

		var info = Label.new()
		info.text = "%s [%dg] — %s" % [item.item_name, item.gold_cost, item.get_stats_display()]
		info.custom_minimum_size = Vector2(320, 0)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(info)

		var buy_btn = Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(100, 30)
		var lock_reason = GameState.get_market_lock_reason(item)
		var unlocked = lock_reason == ""
		buy_btn.disabled = not unlocked or GameState.gold < item.gold_cost
		buy_btn.pressed.connect(_on_market_buy_pressed.bind(item))
		row.add_child(buy_btn)

		if not unlocked:
			var lock_label = Label.new()
			lock_label.text = lock_reason
			lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			lock_label.custom_minimum_size = Vector2(430, 0)
			lock_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.45, 1.0))
			wrapper.add_child(lock_label)

func _get_recruit_cost() -> int:
	return GameState.get_recruit_cost()

func _on_add_worker() -> void:
	GameState.assign_worker(current_building, 1)
	_refresh()

func _on_remove_worker() -> void:
	var success = GameState.assign_worker(current_building, -1)
	if not success and current_building == "Barracks":
		production_label.text = "Cannot reduce staff — too many soldiers!\nDismiss soldiers first."
		production_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		await get_tree().create_timer(2.0).timeout
		production_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_refresh()

func _on_market_buy_pressed(item: ItemData) -> void:
	if GameState.buy_market_item(item):
		_refresh_market()

func _close_popup() -> void:
	GameState.menu_open = reopen_menu_on_close
	hide()

func blocks_screen_position(screen_position: Vector2) -> bool:
	if not visible or popup_panel == null:
		return false
	return popup_panel.get_global_rect().has_point(screen_position)
