# pre_combat_screen.gd
extends Control

const MAX_COMBAT_SLOTS = 5

var selected_soldiers: Array[SoldierData] = []
var pending_wave: Array[EnemyData] = []
signal selection_confirmed(soldiers: Array)

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/VBoxContainer/SubtitleLabel
@onready var soldier_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/SoldierList
@onready var selected_count: Label = $Panel/MarginContainer/VBoxContainer/Footer/SelectedCount
@onready var btn_fight: Button = $Panel/MarginContainer/VBoxContainer/Footer/BtnFight

func _ready() -> void:
	btn_fight.pressed.connect(_on_fight_pressed)
	btn_fight.disabled = true
	hide()

func open(enemy_wave: Array[EnemyData]) -> void:
	pending_wave = enemy_wave
	selected_soldiers.clear()

	var enemy_names = {}
	for e in enemy_wave:
		enemy_names[e.enemy_name] = enemy_names.get(e.enemy_name, 0) + 1
	var parts = []
	for name in enemy_names:
		parts.append("%dx %s" % [enemy_names[name], name])

	subtitle_label.text = "Incoming: %s\nSelect up to %d soldiers." % [
		" + ".join(parts), MAX_COMBAT_SLOTS
	]

	_build_soldier_list()
	_update_count()
	show()
	GameState.menu_open = true

func _build_soldier_list() -> void:
	for child in soldier_list.get_children():
		child.queue_free()

	var alive = GameState.soldiers.filter(func(s): return s.is_alive())

	if alive.is_empty():
		var lbl = Label.new()
		lbl.text = "No soldiers available! The city is defenseless..."
		lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		soldier_list.add_child(lbl)
		return

	for soldier in alive:
		var card = _make_select_card(soldier)
		soldier_list.add_child(card)

func _make_select_card(soldier: SoldierData) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 70)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.12, 0.18)
	style_normal.border_color = Color(0.3, 0.35, 0.5)
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(6)

	var style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.08, 0.22, 0.12)
	style_selected.border_color = Color(0.2, 0.8, 0.4)
	style_selected.set_border_width_all(2)
	style_selected.set_corner_radius_all(6)

	panel.add_theme_stylebox_override("panel", style_normal)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var checkbox = CheckBox.new()
	hbox.add_child(checkbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = soldier.get_display_name()
	name_lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(name_lbl)

	var stats_lbl = Label.new()
	stats_lbl.text = "HP:%d/%d  POW:%d  SPD:%d  DEF:%d  | W1:%s  Armor:%s" % [
		soldier.hp_current, soldier.hp_max,
		soldier.get_total_power(),
		soldier.get_total_speed(),
		soldier.get_total_defense(),
		soldier.weapon_1.item_name if soldier.weapon_1 else "None",
		soldier.armor.item_name if soldier.armor else "None"
	]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	vbox.add_child(stats_lbl)

	checkbox.toggled.connect(func(pressed: bool):
		if pressed:
			if selected_soldiers.size() >= MAX_COMBAT_SLOTS:
				checkbox.button_pressed = false
				return
			selected_soldiers.append(soldier)
			panel.add_theme_stylebox_override("panel", style_selected)
		else:
			selected_soldiers.erase(soldier)
			panel.add_theme_stylebox_override("panel", style_normal)
		_update_count()
	)

	return panel

func _update_count() -> void:
	selected_count.text = "Selected: %d / %d" % [
		selected_soldiers.size(), MAX_COMBAT_SLOTS
	]
	btn_fight.disabled = selected_soldiers.is_empty()

func _on_fight_pressed() -> void:
	if selected_soldiers.is_empty():
		return
	GameState.menu_open = false
	emit_signal("selection_confirmed", selected_soldiers)
	hide()
	
