# soldier_menu.gd
extends Control

@onready var soldier_list: VBoxContainer = $SoldierList
@onready var btn_close: Button = $BtnClose

var detail_overlay: ColorRect
var detail_window: PanelContainer
var detail_title: Label
var detail_content: VBoxContainer
var selected_soldier: SoldierData = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	btn_close.pressed.connect(_on_close)
	GameState.soldiers_changed.connect(_refresh)
	_build_detail_window()
	_refresh()

func open() -> void:
	GameState.menu_open = true
	show()

func _on_close() -> void:
	_close_detail_window()
	GameState.menu_open = false
	get_tree().get_root().find_child("CityView", true, false).get_node("UI").visible = true
	hide()

func _refresh() -> void:
	for child in soldier_list.get_children():
		child.queue_free()

	if GameState.soldiers.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No soldiers yet. Recruit from the Tavern."
		soldier_list.add_child(empty_label)
		_close_detail_window()
		return

	for soldier in GameState.soldiers:
		var card = _make_soldier_card(soldier)
		soldier_list.add_child(card)

	if selected_soldier != null:
		if not GameState.soldiers.has(selected_soldier):
			_close_detail_window()
		else:
			_refresh_detail_window()

func _make_soldier_card(soldier: SoldierData) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_soldier_details(soldier)
	)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 1.0)
	style.border_color = Color(0.42, 0.49, 0.64, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hbox_top = HBoxContainer.new()
	hbox_top.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox_top)

	var name_lbl = Label.new()
	name_lbl.text = soldier.get_display_name()
	name_lbl.custom_minimum_size = Vector2(180, 0)
	name_lbl.add_theme_font_size_override("font_size", 15)
	hbox_top.add_child(name_lbl)

	var status_lbl = Label.new()
	status_lbl.text = "Ready" if soldier.is_alive() else "Dead"
	status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3) if soldier.is_alive() else Color(0.9, 0.2, 0.2))
	hbox_top.add_child(status_lbl)

	var stats_lbl = Label.new()
	stats_lbl.text = "HP:%d/%d  POW:%d  SPD:%d  DEX:%d  DEF:%d" % [
		soldier.hp_current, soldier.hp_max,
		soldier.get_total_power(),
		soldier.get_total_speed(),
		soldier.dexterity,
		soldier.get_total_defense()
	]
	vbox.add_child(stats_lbl)

	var xp_hbox = HBoxContainer.new()
	xp_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(xp_hbox)

	var xp_lbl = Label.new()
	xp_lbl.text = "XP: %d/%d" % [soldier.experience, soldier.xp_to_next_level]
	xp_hbox.add_child(xp_lbl)

	var xp_bar = ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = soldier.xp_to_next_level
	xp_bar.value = soldier.experience
	xp_bar.custom_minimum_size = Vector2(180, 16)
	xp_bar.show_percentage = false
	xp_hbox.add_child(xp_bar)

	var equip_hbox = HBoxContainer.new()
	equip_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(equip_hbox)

	var w1_lbl = Label.new()
	w1_lbl.text = "W1: %s" % (soldier.weapon_1.item_name if soldier.weapon_1 else "Empty")
	equip_hbox.add_child(w1_lbl)

	var w2_lbl = Label.new()
	w2_lbl.text = "W2: %s" % (soldier.weapon_2.item_name if soldier.weapon_2 else "Empty")
	equip_hbox.add_child(w2_lbl)

	var arm_lbl = Label.new()
	arm_lbl.text = "Armor: %s" % (soldier.armor.item_name if soldier.armor else "Empty")
	equip_hbox.add_child(arm_lbl)

	var hint_lbl = Label.new()
	hint_lbl.text = "Click to inspect and equip"
	hint_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	equip_hbox.add_child(hint_lbl)

	return panel

func _build_detail_window() -> void:
	detail_overlay = ColorRect.new()
	detail_overlay.name = "DetailOverlay"
	detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_overlay.color = Color(0.02, 0.03, 0.06, 0.72)
	detail_overlay.visible = false
	detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.gui_input.connect(_on_detail_overlay_input)
	add_child(detail_overlay)

	detail_window = PanelContainer.new()
	detail_window.position = Vector2(660, 70)
	detail_window.custom_minimum_size = Vector2(560, 580)
	detail_window.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_overlay.add_child(detail_window)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.12, 0.16, 0.98)
	panel_style.border_color = Color(0.50, 0.58, 0.72, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	detail_window.add_theme_stylebox_override("panel", panel_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	detail_window.add_child(margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(outer_vbox)

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header)

	detail_title = Label.new()
	detail_title.text = "Soldier Details"
	detail_title.add_theme_font_size_override("font_size", 22)
	detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(detail_title)

	var close_detail_button = Button.new()
	close_detail_button.text = "Close"
	close_detail_button.custom_minimum_size = Vector2(100, 34)
	close_detail_button.pressed.connect(_close_detail_window)
	header.add_child(close_detail_button)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 500)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	detail_content = VBoxContainer.new()
	detail_content.custom_minimum_size = Vector2(500, 0)
	detail_content.add_theme_constant_override("separation", 10)
	scroll.add_child(detail_content)

func _on_detail_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_detail_window()

func _open_soldier_details(soldier: SoldierData) -> void:
	selected_soldier = soldier
	_refresh_detail_window()
	detail_overlay.show()

func _close_detail_window() -> void:
	selected_soldier = null
	if detail_overlay != null:
		detail_overlay.hide()

func _refresh_detail_window() -> void:
	if selected_soldier == null:
		return

	for child in detail_content.get_children():
		child.queue_free()

	detail_title.text = selected_soldier.get_display_name()

	var overview = Label.new()
	overview.text = "HP %d/%d | POW %d | SPD %d | DEX %d | DEF %d | XP %d/%d" % [
		selected_soldier.hp_current,
		selected_soldier.hp_max,
		selected_soldier.get_total_power(),
		selected_soldier.get_total_speed(),
		selected_soldier.dexterity,
		selected_soldier.get_total_defense(),
		selected_soldier.experience,
		selected_soldier.xp_to_next_level
	]
	overview.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_content.add_child(overview)

	#var limbs = Label.new()
	#limbs.text = "Head %d | Left Arm %d | Right Arm %d | Legs %d" % [
		#selected_soldier.hp_head,
		#selected_soldier.hp_left_arm,
		#selected_soldier.hp_right_arm,
		#selected_soldier.hp_legs
	#]
	_add_separator()
	var traits_title = Label.new()
	traits_title.text = "Traits"
	traits_title.add_theme_font_size_override("font_size", 16)
	detail_content.add_child(traits_title)
	if selected_soldier.traits.is_empty():
		var no_traits = Label.new()
		no_traits.text = "No traits yet. Survive hard battles to earn them."
		no_traits.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		detail_content.add_child(no_traits)
	else:
		for soldier_trait in selected_soldier.traits:
			var trait_lbl = Label.new()
			trait_lbl.text = "%s — %s\n%s" % [
				soldier_trait.trait_name,
				soldier_trait.get_stats_display(),
				soldier_trait.description
			]
			trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			trait_lbl.custom_minimum_size = Vector2(500, 0)
			trait_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			detail_content.add_child(trait_lbl)
	#detail_content.add_child(limbs)
	_add_separator()
	var skills_title = Label.new()
	skills_title.text = "Skills"
	skills_title.add_theme_font_size_override("font_size", 16)
	detail_content.add_child(skills_title)

	var class_lbl = Label.new()
	class_lbl.text = "Class: %s" % (selected_soldier.soldier_class if selected_soldier.soldier_class != "" else "Unknown")
	class_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
	detail_content.add_child(class_lbl)

	if selected_soldier.unlocked_skills.is_empty():
		var no_skills = Label.new()
		no_skills.text = "No skills unlocked yet."
		no_skills.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		detail_content.add_child(no_skills)
	else:
		for soldier_skill in selected_soldier.unlocked_skills:
			var skill_lbl = Label.new()
			var type_str = "Passive" if soldier_skill.skill_type == SkillData.SkillType.PASSIVE else "Active (CD:%d)" % soldier_skill.cooldown_turns
			skill_lbl.text = "[%s] %s — %s\n%s" % [
				type_str,
				soldier_skill.skill_name,
				soldier_skill.get_stats_display(),
				soldier_skill.description
			]
			skill_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			skill_lbl.custom_minimum_size = Vector2(500, 0)
			skill_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 0.9))
			detail_content.add_child(skill_lbl)

	# Arata si skills neblocate
	var locked_title = Label.new()
	locked_title.text = "Locked skills:"
	locked_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	detail_content.add_child(locked_title)

	var all_possible = SkillLibrary.get_class_skills(selected_soldier.soldier_class)
	all_possible.append_array(SkillLibrary.get_universal_skills())
	for soldier_skill in all_possible:
		if selected_soldier.has_skill(soldier_skill.skill_id):
			continue
		var locked_lbl = Label.new()
		locked_lbl.text = "[Locked] %s — %s" % [
			soldier_skill.skill_name,
			soldier_skill.get_unlock_description()
		]
		locked_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		locked_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		locked_lbl.custom_minimum_size = Vector2(500, 0)
		detail_content.add_child(locked_lbl)


	var inventory_info = Label.new()
	inventory_info.text = "Unequipped inventory: %d item(s). Buy gear from the Market building, then equip or unequip it here." % GameState.owned_items.size()
	inventory_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_content.add_child(inventory_info)
	
	_add_separator()
	detail_content.add_child(_make_slot_section(selected_soldier, "Weapon Slot 1", "weapon_1", selected_soldier.weapon_1))
	_add_separator()
	detail_content.add_child(_make_slot_section(selected_soldier, "Weapon Slot 2", "weapon_2", selected_soldier.weapon_2))
	_add_separator()
	detail_content.add_child(_make_slot_section(selected_soldier, "Armor Slot", "armor", selected_soldier.armor))

func _add_separator() -> void:
	var separator = HSeparator.new()
	detail_content.add_child(separator)

func _make_slot_section(soldier: SoldierData, section_title: String, slot: String, equipped_item: ItemData) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var title = Label.new()
	title.text = "%s: %s" % [section_title, equipped_item.item_name if equipped_item else "Empty"]
	title.add_theme_font_size_override("font_size", 16)
	section.add_child(title)

	var slot_hint = Label.new()
	if slot == "armor":
		slot_hint.text = "Only armor pieces appear here."
	else:
		slot_hint.text = "Only weapons appear here."
	slot_hint.add_theme_color_override("font_color", Color(0.75, 0.79, 0.88, 1.0))
	section.add_child(slot_hint)

	if equipped_item != null:
		var equipped_row = HBoxContainer.new()
		equipped_row.add_theme_constant_override("separation", 10)
		section.add_child(equipped_row)

		var equipped_info = Label.new()
		equipped_info.text = "Equipped now: %s — %s" % [equipped_item.item_name, equipped_item.get_stats_display()]
		equipped_info.custom_minimum_size = Vector2(360, 0)
		equipped_info.autowrap_mode = TextServer.AUTOWRAP_WORD
		equipped_row.add_child(equipped_info)

		var unequip_btn = Button.new()
		unequip_btn.text = "Unequip"
		unequip_btn.custom_minimum_size = Vector2(90, 28)
		unequip_btn.pressed.connect(_on_unequip_pressed.bind(soldier, slot))
		equipped_row.add_child(unequip_btn)

	var items = GameState.get_owned_items_for_slot(slot)
	if items.is_empty():
		var empty = Label.new()
		empty.text = "No valid unequipped items. Buy them from the Market building."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		section.add_child(empty)
		return section

	for item in items:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		section.add_child(row)

		var info = Label.new()
		info.text = "%s — %s" % [item.item_name, item.get_stats_display()]
		info.custom_minimum_size = Vector2(360, 0)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(info)

		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(90, 28)
		equip_btn.pressed.connect(_on_equip_pressed.bind(soldier, item, slot))
		row.add_child(equip_btn)

	return section

func _on_equip_pressed(soldier: SoldierData, item: ItemData, slot: String) -> void:
	if GameState.equip_owned_item(soldier, item, slot):
		_refresh()
		_refresh_detail_window()

func _on_unequip_pressed(soldier: SoldierData, slot: String) -> void:
	if GameState.unequip_item(soldier, slot):
		_refresh()
		_refresh_detail_window()
