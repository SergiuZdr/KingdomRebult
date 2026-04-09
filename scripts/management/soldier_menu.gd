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
	get_tree().get_root().find_child("CityView", true, false).get_node("UI").visible = true
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
	panel.custom_minimum_size = Vector2(700, 120)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	# Linia 1 — nume + status
	var hbox_top = HBoxContainer.new()
	vbox.add_child(hbox_top)

	var name_lbl = Label.new()
	name_lbl.text = s.get_display_name()
	name_lbl.custom_minimum_size = Vector2(180, 0)
	name_lbl.add_theme_font_size_override("font_size", 15)
	hbox_top.add_child(name_lbl)

	var status_lbl = Label.new()
	status_lbl.text = "Ready" if s.is_alive() else "Dead"
	status_lbl.add_theme_color_override("font_color",
		Color(0.3, 0.9, 0.3) if s.is_alive() else Color(0.9, 0.2, 0.2))
	hbox_top.add_child(status_lbl)

	# Linia 2 — stats cu echipament
	var stats_lbl = Label.new()
	stats_lbl.text = "HP:%d/%d  POW:%d  SPD:%d  DEX:%d  DEF:%d" % [
		s.hp_current, s.hp_max,
		s.get_total_power(),
		s.get_total_speed(),
		s.dexterity,
		s.get_total_defense()
	]
	vbox.add_child(stats_lbl)

	# Linia 3 — XP
	var xp_hbox = HBoxContainer.new()
	vbox.add_child(xp_hbox)
	var xp_lbl = Label.new()
	xp_lbl.text = "XP: %d/%d  " % [s.experience, s.xp_to_next_level]
	xp_hbox.add_child(xp_lbl)
	var xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = s.xp_to_next_level
	xp_bar.value = s.experience
	xp_bar.custom_minimum_size = Vector2(180, 16)
	xp_bar.show_percentage = false
	xp_hbox.add_child(xp_bar)

	# Linia 4 — echipament curent
	var equip_hbox = HBoxContainer.new()
	equip_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(equip_hbox)

	var w1_lbl = Label.new()
	w1_lbl.text = "W1: %s" % (s.weapon_1.item_name if s.weapon_1 else "—")
	w1_lbl.add_theme_font_size_override("font_size", 11)
	equip_hbox.add_child(w1_lbl)

	var w2_lbl = Label.new()
	w2_lbl.text = "W2: %s" % (s.weapon_2.item_name if s.weapon_2 else "—")
	w2_lbl.add_theme_font_size_override("font_size", 11)
	equip_hbox.add_child(w2_lbl)

	var arm_lbl = Label.new()
	arm_lbl.text = "Armor: %s" % (s.armor.item_name if s.armor else "—")
	arm_lbl.add_theme_font_size_override("font_size", 11)
	equip_hbox.add_child(arm_lbl)

	var equip_btn = Button.new()
	equip_btn.text = "Equip..."
	equip_btn.custom_minimum_size = Vector2(80, 28)
	equip_btn.pressed.connect(func(): _open_equip_menu(s))
	equip_hbox.add_child(equip_btn)

	return panel

func _open_equip_menu(soldier: SoldierData) -> void:
	# Creeaza un popup de echipament
	var popup = AcceptDialog.new()
	popup.title = "Equip — %s" % soldier.soldier_name
	popup.min_size = Vector2(500, 400)
	add_child(popup)

	var vbox = VBoxContainer.new()
	popup.add_child(vbox)

	var gold_lbl = Label.new()
	gold_lbl.text = "Gold: %d" % GameState.gold
	vbox.add_child(gold_lbl)

	for item in GameState.available_items:
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var info_lbl = Label.new()
		info_lbl.text = "[%dg] %s — %s" % [item.gold_cost, item.item_name, item.get_stats_display()]
		info_lbl.custom_minimum_size = Vector2(320, 0)
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hbox.add_child(info_lbl)

		if item.item_type == ItemData.ItemType.ARMOR:
			var btn = Button.new()
			btn.text = "Armor slot"
			btn.pressed.connect(func():
				if GameState.buy_item(item, soldier, "armor"):
					popup.queue_free()
					_refresh()
			)
			hbox.add_child(btn)
		else:
			var btn1 = Button.new()
			btn1.text = "Slot 1"
			btn1.pressed.connect(func():
				if GameState.buy_item(item, soldier, "weapon_1"):
					popup.queue_free()
					_refresh()
			)
			hbox.add_child(btn1)

			var btn2 = Button.new()
			btn2.text = "Slot 2"
			btn2.pressed.connect(func():
				if GameState.buy_item(item, soldier, "weapon_2"):
					popup.queue_free()
					_refresh()
			)
			hbox.add_child(btn2)

	popup.popup_centered()
