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

var tavern_section: VBoxContainer
var tavern_info_label: Label
var recruit_name_input: LineEdit
var recruit_button: Button

var market_section: VBoxContainer
var market_info_label: Label
var market_scroll: ScrollContainer
var market_list: VBoxContainer

var current_building: String = ""

func _ready() -> void:
	layer = 50
	_build_popup()
	hide()

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

	btn_remove = Button.new()
	btn_remove.text = "  -  "
	btn_remove.position = Vector2(20, 150)
	btn_remove.size = Vector2(55, 34)
	btn_remove.pressed.connect(_on_remove_worker)
	popup_panel.add_child(btn_remove)

	btn_add = Button.new()
	btn_add.text = "  +  "
	btn_add.position = Vector2(85, 150)
	btn_add.size = Vector2(55, 34)
	btn_add.pressed.connect(_on_add_worker)
	popup_panel.add_child(btn_add)

	production_label = Label.new()
	production_label.position = Vector2(20, 195)
	production_label.size = Vector2(480, 140)
	production_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	production_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_panel.add_child(production_label)

	tavern_section = VBoxContainer.new()
	tavern_section.position = Vector2(20, 115)
	tavern_section.size = Vector2(480, 220)
	popup_panel.add_child(tavern_section)

	tavern_info_label = Label.new()
	tavern_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tavern_info_label.custom_minimum_size = Vector2(480, 60)
	tavern_section.add_child(tavern_info_label)

	var worker_hbox = HBoxContainer.new()
	tavern_section.add_child(worker_hbox)

	var lbl = Label.new()
	lbl.text = "Innkeepers: "
	lbl.custom_minimum_size = Vector2(100, 0)
	worker_hbox.add_child(lbl)

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

	recruit_name_input = LineEdit.new()
	recruit_name_input.placeholder_text = "Enter soldier name..."
	recruit_name_input.custom_minimum_size = Vector2(480, 36)
	tavern_section.add_child(recruit_name_input)

	recruit_button = Button.new()
	recruit_button.custom_minimum_size = Vector2(480, 36)
	recruit_button.pressed.connect(_on_recruit)
	tavern_section.add_child(recruit_button)

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

	close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(210, 368)
	close_button.size = Vector2(100, 36)
	close_button.pressed.connect(_close_popup)
	popup_panel.add_child(close_button)

func show_building(b_name: String, _b_desc: String) -> void:
	current_building = b_name
	var data = GameState.get_building_data(current_building)
	title_label.text = b_name
	desc_label.text = data.description if data != null else _b_desc

	var is_tavern = b_name == "Tavern"
	var is_market = b_name == "Market"

	tavern_section.visible = is_tavern
	market_section.visible = is_market
	workers_label.visible = not is_tavern and not is_market
	btn_add.visible = not is_tavern and not is_market
	btn_remove.visible = not is_tavern and not is_market
	production_label.visible = not is_tavern and not is_market

	_refresh()
	show()

func _refresh() -> void:
	if current_building == "":
		return

	if current_building == "Tavern":
		_refresh_tavern()
	elif current_building == "Market":
		_refresh_market()
	elif current_building == "Barracks":
		_refresh_barracks()
	else:
		_refresh_standard()

func _refresh_standard() -> void:
	var data = GameState.get_building_data(current_building)
	var workers = GameState.building_workers.get(current_building, 0)
	workers_label.text = "Workers: %d  |  Available: %d / %d" % [
		workers,
		GameState.workforce_available,
		GameState.workforce_total
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

	var prod_text = "Production per turn:
"
	var prod = data.get_production_for_workers(workers)
	if prod.is_empty():
		prod_text += "  — (special building)"
	else:
		for resource in prod:
			var amount = prod[resource]
			prod_text += "  %d %s
" % [amount, resource]
	if workers == 0:
		prod_text += "  (assign workers to produce)"
	production_label.text = prod_text

func _refresh_tavern() -> void:
	for child in tavern_section.get_children():
		child.queue_free()

	var innkeepers = GameState.building_workers.get("Tavern", 0)
	var cost = GameState.get_recruit_cost()

	# Header info
	var header = Label.new()
	header.text = "Innkeepers: %d | Recruit cost: %d Gold | Slots: %d/%d" % [
		innkeepers, cost,
		GameState.soldiers.size(),
		GameState.get_max_soldiers()
	]
	header.add_theme_font_size_override("font_size", 12)
	tavern_section.add_child(header)

	# Butoane +/- innkeepers
	var worker_hbox = HBoxContainer.new()
	tavern_section.add_child(worker_hbox)
	var lbl = Label.new()
	lbl.text = "Innkeepers: "
	lbl.custom_minimum_size = Vector2(100, 0)
	worker_hbox.add_child(lbl)
	var t_remove = Button.new()
	t_remove.text = " - "
	t_remove.pressed.connect(func():
		GameState.assign_worker("Tavern", -1)
		_refresh_tavern()
	)
	worker_hbox.add_child(t_remove)
	var t_add = Button.new()
	t_add.text = " + "
	t_add.pressed.connect(func():
		GameState.assign_worker("Tavern", 1)
		_refresh_tavern()
	)
	worker_hbox.add_child(t_add)

	var separator = HSeparator.new()
	tavern_section.add_child(separator)

	# Lista de recruti disponibili
	if GameState.tavern_roster.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No recruits available. Wait for next turn."
		tavern_section.add_child(empty_lbl)
		return

	for recruit in GameState.tavern_roster:
		var card = _make_recruit_card(recruit, innkeepers)
		tavern_section.add_child(card)

func _make_recruit_card(recruit: SoldierData, innkeepers: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 70)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Linia 1 — nume mereu vizibil
	var name_lbl = Label.new()
	name_lbl.text = recruit.soldier_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_lbl)

	# Linia 2 — clasa (vizibila cu 1+ innkeeper)
	var class_lbl = Label.new()
	if innkeepers >= 1:
		class_lbl.text = "[%s]" % recruit.soldier_class
		class_lbl.add_theme_color_override("font_color", _get_class_color(recruit.soldier_class))
	else:
		class_lbl.text = "[??? — assign innkeepers to reveal]"
		class_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	info_vbox.add_child(class_lbl)

	# Linia 3+ — stats (1 stat per 2 innkeepers suplimentari)
	var stats_revealed = (innkeepers - 1) / 2 
	var all_stats = [
		"HP: %d" % recruit.hp_max,
		"POW: %d" % recruit.power,
		"SPD: %d" % recruit.speed,
		"DEX: %d" % recruit.dexterity,
	]
	var stats_text = ""
	for i in min(stats_revealed, all_stats.size()):
		stats_text += all_stats[i] + "  "
	if stats_revealed < all_stats.size() and innkeepers >= 1:
		stats_text += "..."

	if stats_text != "":
		var stats_lbl = Label.new()
		stats_lbl.text = stats_text.strip_edges()
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		info_vbox.add_child(stats_lbl)

	# Skill di baza vizibil cu 1+ innkeeper
	if innkeepers >= 1 and not recruit.unlocked_skills.is_empty():
		var skill_lbl = Label.new()
		skill_lbl.text = "Skill: %s (%s)" % [
			recruit.unlocked_skills[0].skill_name,
			"Passive" if recruit.unlocked_skills[0].skill_type == SkillData.SkillType.PASSIVE else "Active"
		]
		skill_lbl.add_theme_font_size_override("font_size", 11)
		skill_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		info_vbox.add_child(skill_lbl)

	# Buton recruit
	var recruit_btn = Button.new()
	recruit_btn.text = "Recruit\n%d Gold" % GameState.get_recruit_cost()
	recruit_btn.custom_minimum_size = Vector2(80, 60)
	recruit_btn.disabled = (
		GameState.gold < GameState.get_recruit_cost() or
		GameState.soldiers.size() >= GameState.get_max_soldiers()
	)
	recruit_btn.pressed.connect(func():
		if GameState.recruit_from_roster(recruit):
			_refresh_tavern()
	)
	hbox.add_child(recruit_btn)

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
	#var capacity = GameState.get_max_soldiers()
	var data = GameState.get_building_data("Barracks")
	var staffed = workers > 0
	workers_label.text = "Workers: %d  |  Available: %d / %d" % [
		workers,
		GameState.workforce_available,
		GameState.workforce_total
	]

	production_label.text = (
		"Soldier capacity: %d / %d\n" +
		"Morale: %d per turn \n" +
		"Food: %d per turn \n" +
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

func _on_recruit() -> void:
	var name_text = recruit_name_input.text.strip_edges()
	if name_text == "":
		name_text = "Soldier %d" % (GameState.soldiers.size() + 1)
	if GameState.recruit_soldier(name_text):
		recruit_name_input.text = ""
		_refresh_tavern()

func _on_market_buy_pressed(item: ItemData) -> void:
	if GameState.buy_market_item(item):
		_refresh_market()

func _close_popup() -> void:
	hide()

func blocks_screen_position(screen_position: Vector2) -> bool:
	if not visible or popup_panel == null:
		return false
	return popup_panel.get_global_rect().has_point(screen_position)
