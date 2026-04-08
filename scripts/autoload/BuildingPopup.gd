# BuildingPopup.gd
extends CanvasLayer

var popup_panel: Panel
var title_label: Label
var desc_label: Label
var close_button: Button

# Sectiunea standard (muncitori + productie)
var workers_label: Label
var production_label: Label
var btn_add: Button
var btn_remove: Button

# Sectiunea Tavern
var tavern_section: VBoxContainer
var tavern_info_label: Label
var recruit_name_input: LineEdit
var recruit_button: Button

var current_building: String = ""

func _ready() -> void:
	_build_popup()
	hide()

func _build_popup() -> void:
	popup_panel = Panel.new()
	popup_panel.size = Vector2(420, 320)
	popup_panel.position = Vector2(430, 200)
	add_child(popup_panel)

	# Titlu
	title_label = Label.new()
	title_label.position = Vector2(20, 15)
	title_label.size = Vector2(380, 35)
	title_label.add_theme_font_size_override("font_size", 20)
	popup_panel.add_child(title_label)

	# Descriere
	desc_label = Label.new()
	desc_label.position = Vector2(20, 55)
	desc_label.size = Vector2(380, 50)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_panel.add_child(desc_label)

	# --- SECTIUNEA STANDARD ---
	workers_label = Label.new()
	workers_label.position = Vector2(20, 115)
	workers_label.size = Vector2(380, 30)
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
	production_label.size = Vector2(380, 60)
	production_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	production_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	popup_panel.add_child(production_label)

	# --- SECTIUNEA TAVERN ---
	tavern_section = VBoxContainer.new()
	tavern_section.position = Vector2(20, 115)
	tavern_section.size = Vector2(380, 160)
	popup_panel.add_child(tavern_section)

	tavern_info_label = Label.new()
	tavern_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	tavern_info_label.custom_minimum_size = Vector2(380, 60)
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
	recruit_name_input.custom_minimum_size = Vector2(380, 36)
	tavern_section.add_child(recruit_name_input)

	recruit_button = Button.new()
	recruit_button.custom_minimum_size = Vector2(380, 36)
	recruit_button.pressed.connect(_on_recruit)
	tavern_section.add_child(recruit_button)

	# --- CLOSE (mereu ultimul, mereu vizibil) ---
	close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(160, 268)
	close_button.size = Vector2(100, 36)
	close_button.pressed.connect(hide)
	popup_panel.add_child(close_button)

func show_building(b_name: String, b_desc: String) -> void:
	current_building = b_name
	title_label.text = b_name
	desc_label.text = b_desc

	var is_tavern = (b_name == "Tavern")
	#var is_training = (b_name == "Training Ground")

	tavern_section.visible = is_tavern
	workers_label.visible = not is_tavern
	btn_add.visible = not is_tavern
	btn_remove.visible = not is_tavern
	production_label.visible = not is_tavern

	_refresh()
	show()

func _refresh() -> void:
	if current_building == "":
		return

	if current_building == "Tavern":
		_refresh_tavern()
	else:
		_refresh_standard()

func _refresh_standard() -> void:
	var workers = GameState.building_workers.get(current_building, 0)
	workers_label.text = "Workers: %d  |  Available: %d / %d" % [
		workers,
		GameState.workforce_available,
		GameState.workforce_total
	]

# caz special Training Ground
	if current_building == "Training Grounds":
		var xp = workers * 10
		production_label.text = "XP per turn: +%d to all living soldiers\n(%d trainers × 10 XP)" % [
			xp, workers
		]
		return
#restul cladirilor
	var prod_text = "Production per turn:\n"
	if GameState.PRODUCTION.has(current_building):
		var prod = GameState.PRODUCTION[current_building]
		if prod.is_empty():
			prod_text += "  — (special building)"
		else:
			for resource in prod:
				var amount = prod[resource] * workers
				#var sign = "+" if amount >= 0 else ""
				prod_text += "  %d %s\n" % [ amount, resource]
	if workers == 0:
		prod_text += "  (assign workers to produce)"
	production_label.text = prod_text

func _refresh_tavern() -> void:
	var workers = GameState.building_workers.get("Tavern", 0)
	var cost = _get_recruit_cost()
	var stat_bonus = workers * 5

	tavern_info_label.text = (
		"Innkeepers assigned: %d / %d available\n" +
		"Recruit cost: %d Gold\n" +
		"Stat bonus from innkeepers: +%d to all ranges\n" +
        "Slots: %d / %d"
	) % [
		workers,
		GameState.workforce_available + workers,
		cost,
		stat_bonus,
		GameState.soldiers.size(),
		GameState.max_soldiers
	]

	recruit_button.text = "Recruit  (%d Gold)" % cost

	# Butoane +/- direct in label — folosim tavern workers separat
	if not btn_add.pressed.is_connected(_on_add_worker):
		pass
	workers_label.text = ""

func _get_recruit_cost() -> int:
	var workers = GameState.building_workers.get("Tavern", 0)
	return max(50, 100 - workers * 10)

func _on_add_worker() -> void:
	GameState.assign_worker(current_building, 1)
	_refresh()

func _on_remove_worker() -> void:
	GameState.assign_worker(current_building, -1)
	_refresh()

func _on_recruit() -> void:
	var name_text = recruit_name_input.text.strip_edges()
	if name_text == "":
		name_text = "Soldier %d" % (GameState.soldiers.size() + 1)
	var workers = GameState.building_workers.get("Tavern", 0)
	if GameState.recruit_soldier(name_text, workers):
		recruit_name_input.text = ""
		_refresh_tavern()
