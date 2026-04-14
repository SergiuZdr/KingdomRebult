# main_menu.gd
extends Control

@onready var btn_new_game: Button = $VBoxCenter/BtnNewGame
@onready var btn_load: Button = $VBoxCenter/BtnLoad
@onready var btn_quit: Button = $VBoxCenter/BtnQuit
@onready var save_slots_panel: PanelContainer = $SaveSlotsPanel
@onready var slots_container: VBoxContainer = $SaveSlotsPanel/VBoxContainer

var current_mode: String = ""  # "save" sau "load"

func _ready() -> void:
	btn_new_game.pressed.connect(_on_new_game)
	btn_load.pressed.connect(_on_load_pressed)
	btn_quit.pressed.connect(_on_quit)
	save_slots_panel.hide()
	_check_load_available()

func _check_load_available() -> void:
	var any_save = false
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		if not SaveManager.get_slot_info(i).get("empty", true):
			any_save = true
			break
	btn_load.disabled = not any_save

func _on_new_game() -> void:
	current_mode = "save"
	_show_slots_panel("Choose a save slot for your new game:")

func _on_load_pressed() -> void:
	current_mode = "load"
	_show_slots_panel("Choose a save slot to load:")

func _show_slots_panel(title: String) -> void:
	for child in slots_container.get_children():
		child.queue_free()

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	slots_container.add_child(title_lbl)

	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var info = SaveManager.get_slot_info(i)
		var slot_card = _make_slot_card(i, info)
		slots_container.add_child(slot_card)

	var btn_back = Button.new()
	btn_back.text = "Back"
	btn_back.custom_minimum_size = Vector2(120, 40)
	btn_back.pressed.connect(func(): save_slots_panel.hide())
	slots_container.add_child(btn_back)

	save_slots_panel.show()

func _make_slot_card(slot: int, info: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 70)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var slot_title = Label.new()
	slot_title.text = "Slot %d" % slot
	slot_title.add_theme_font_size_override("font_size", 15)
	info_vbox.add_child(slot_title)

	var slot_info = Label.new()
	if info.get("empty", true):
		slot_info.text = "Empty"
		slot_info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	else:
		slot_info.text = "Turn %d  |  Gold: %d  |  Soldiers: %d  |  %s" % [
			info.get("turn", 0),
			info.get("gold", 0),
			info.get("soldiers", 0),
			info.get("timestamp", "")
		]
	info_vbox.add_child(slot_info)

	# Buton principal (New Game / Load)
	var action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(120, 40)
	hbox.add_child(action_btn)

	if current_mode == "save":
		action_btn.text = "Start Here"
		action_btn.pressed.connect(func(): _start_new_game(slot))
	else:
		action_btn.text = "Load"
		action_btn.disabled = info.get("empty", true)
		action_btn.pressed.connect(func(): _load_game(slot))

	# Buton delete (doar dacă există save)
	if not info.get("empty", true):
		var del_btn = Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(80, 40)
		del_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		del_btn.pressed.connect(func(): _delete_save(slot))
		hbox.add_child(del_btn)

	return panel

func _start_new_game(slot: int) -> void:
	# Reset GameState
	GameState.gold = 500
	GameState.wood = 0
	GameState.stone = 0
	GameState.iron = 0
	GameState.steel = 0
	GameState.food = 0
	GameState.morale = 100
	GameState.workforce_total = 10
	GameState.workforce_available = 10
	GameState.current_turn = 0
	GameState.combat_difficulty = 1
	GameState.soldiers.clear()
	GameState.owned_items.clear()
	for b in GameState.building_workers:
		GameState.building_workers[b] = 0
	GameState._schedule_next_battle(true)

	# Salveaza slot-ul gol ca placeholder
	SaveManager.save_game(slot)

	# Treci la city view
	get_tree().change_scene_to_file("res://scenes/management/city_view.tscn")

func _load_game(slot: int) -> void:
	if SaveManager.load_game(slot):
		get_tree().change_scene_to_file("res://scenes/management/city_view.tscn")

func _delete_save(slot: int) -> void:
	SaveManager.delete_save(slot)
	_show_slots_panel(
		"Choose a save slot to load:" if current_mode == "load" else "Choose a save slot for your new game:"
	)
	_check_load_available()

func _on_quit() -> void:
	get_tree().quit()
