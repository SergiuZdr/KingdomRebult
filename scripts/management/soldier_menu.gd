# soldier_menu.gd
extends Control

@onready var soldier_list: VBoxContainer = $SoldierList
@onready var btn_close: Button = $BtnClose

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	btn_close.pressed.connect(_on_close)
	GameState.soldiers_changed.connect(_refresh)
	_refresh()
func open() -> void:              # ← funcția nouă aici
	GameState.menu_open = true

	show()
func _on_close() -> void:
	GameState.menu_open = false
	hide()
func _refresh() -> void:
# Curăță lista
	for child in soldier_list.get_children():
		child.queue_free()

	if GameState.soldiers.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No soldiers yet. Recruit from the Tavern."
		soldier_list.add_child(empty_label)
		return

# Adaugă un card pentru fiecare soldat
	for soldier in GameState.soldiers:
		var card = _make_soldier_card(soldier)
		soldier_list.add_child(card)

func _make_soldier_card(s: SoldierData) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 90)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Linia 1 — nume + status
	var hbox_top = HBoxContainer.new()
	vbox.add_child(hbox_top)

	var name_label = Label.new()
	name_label.text = s.get_display_name()
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.add_theme_font_size_override("font_size", 16)
	hbox_top.add_child(name_label)

	var status_label = Label.new()
	if s.is_alive():
		status_label.text = "Ready"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		status_label.text = "Dead"
		status_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	hbox_top.add_child(status_label)

	# Linia 2 — stats
	var stats_label = Label.new()
	stats_label.text = "HP:%d/%d  POW:%d  SPD:%d  DEX:%d" % [
		s.hp_current, s.hp_max, s.power, s.speed, s.dexterity
	]
	vbox.add_child(stats_label)

	# Linia 3 — XP bar
	var xp_hbox = HBoxContainer.new()
	vbox.add_child(xp_hbox)

	var xp_label = Label.new()
	xp_label.text = "XP: %d / %d  " % [s.experience, s.xp_to_next_level]
	xp_hbox.add_child(xp_label)

	var xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = s.xp_to_next_level
	xp_bar.value = s.experience
	xp_bar.custom_minimum_size = Vector2(200, 18)
	xp_bar.show_percentage = false
	xp_hbox.add_child(xp_bar)
	
	return panel
