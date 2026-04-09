# combat_scene.gd
extends Control

@onready var allies_row: HBoxContainer  = $AlliesRow
@onready var enemies_row: HBoxContainer = $EnemiesRow
@onready var turn_label: Label          = $TurnLabel

var log_container: VBoxContainer
var log_scroll: ScrollContainer
var turn_order_container: HBoxContainer

var ally_cards: Array = []
var enemy_cards: Array = []
var unit_hp_bars: Dictionary = {}
var unit_hp_labels: Dictionary = {}
var unit_cards: Dictionary = {}
var selected_target = null

func _ready() -> void:
	_build_turn_order_bar()
	_build_log_panel()
	_build_action_panel()
	CombatState.combat_started.connect(_on_combat_started)
	CombatState.turn_changed.connect(_on_turn_changed)
	CombatState.unit_acted.connect(_on_unit_acted)
	CombatState.combat_ended.connect(_on_combat_ended)
	hide()

func _build_turn_order_bar() -> void:
	var bg = PanelContainer.new()
	bg.position = Vector2(40, 20)
	bg.custom_minimum_size = Vector2(1200, 50)
	add_child(bg)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	bg.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "Turn order:  "
	lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(lbl)

	turn_order_container = HBoxContainer.new()
	turn_order_container.add_theme_constant_override("separation", 4)
	hbox.add_child(turn_order_container)

func _build_log_panel() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(900, 430)
	panel.custom_minimum_size = Vector2(340, 240)
	add_child(panel)

	log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size = Vector2(320, 220)
	panel.add_child(log_scroll)

	log_container = VBoxContainer.new()
	log_container.custom_minimum_size = Vector2(310, 0)
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_container)

func _build_action_panel() -> void:
	var panel = PanelContainer.new()
	panel.position = Vector2(40, 430)
	panel.custom_minimum_size = Vector2(420, 240)
	add_child(panel)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var label = Label.new()
	label.text = "Choose action:"
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var btn_attack = Button.new()
	btn_attack.text = "Attack"
	btn_attack.custom_minimum_size = Vector2(100, 40)
	btn_attack.pressed.connect(_on_attack_pressed)
	hbox.add_child(btn_attack)

	var btn_defend = Button.new()
	btn_defend.text = "Defend"
	btn_defend.custom_minimum_size = Vector2(100, 40)
	btn_defend.pressed.connect(_on_defend_pressed)
	hbox.add_child(btn_defend)

func _on_combat_started() -> void:
	GameState.menu_open = true
	show()
	selected_target = null
	_build_units()
	_refresh_turn_order_bar()
	_add_log("— Combat started —", Color(0.89, 0.78, 0.38))

func _build_units() -> void:
	for c in allies_row.get_children(): c.queue_free()
	for c in enemies_row.get_children(): c.queue_free()
	ally_cards.clear()
	enemy_cards.clear()
	unit_hp_bars.clear()
	unit_hp_labels.clear()
	unit_cards.clear()

	for soldier in CombatState.allies:
		var card = _make_unit_card(soldier, true)
		allies_row.add_child(card)
		ally_cards.append(card)

	for enemy in CombatState.enemies:
		var card = _make_unit_card(enemy, false)
		enemies_row.add_child(card)
		enemy_cards.append(card)

func _make_unit_card(unit, is_ally: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 130)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = unit.soldier_name if is_ally else unit.enemy_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var hp_lbl = Label.new()
	hp_lbl.text = "%d/%d" % [unit.hp_current, unit.hp_max]
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hp_lbl)

	var hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = unit.hp_max
	hp_bar.value = unit.hp_current
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(90, 14)
	vbox.add_child(hp_bar)

	unit_hp_bars[unit] = hp_bar
	unit_hp_labels[unit] = hp_lbl
	unit_cards[unit] = panel

	if not is_ally:
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				_select_target(unit, panel)
		)

	panel.set_meta("unit", unit)
	return panel

func _refresh_turn_order_bar() -> void:
	for c in turn_order_container.get_children():
		c.queue_free()

	for i in CombatState.turn_order.size():
		var entry = CombatState.turn_order[i]
		var unit = entry.unit
		var is_ally = entry.is_ally

		var pill = PanelContainer.new()
		pill.custom_minimum_size = Vector2(80, 34)

		var lbl = Label.new()
		lbl.text = unit.soldier_name if is_ally else unit.enemy_name
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(lbl)

		# Coloreaza: verde=aliat, rosu=inamic, galben=activ
		if i == CombatState.current_unit_index:
			pill.self_modulate = Color(1.0, 0.9, 0.2)  # activ
		elif is_ally:
			pill.self_modulate = Color(0.3, 0.8, 0.5)  # aliat
		else:
			pill.self_modulate = Color(0.9, 0.3, 0.3)  # inamic

		if not unit.is_alive():
			pill.self_modulate = Color(0.3, 0.3, 0.3)  # mort

		turn_order_container.add_child(pill)

func _select_target(enemy: EnemyData, card: PanelContainer) -> void:
	if not enemy.is_alive():
		return
	selected_target = enemy
	for c in enemy_cards:
		c.self_modulate = Color(1, 1, 1)
	card.self_modulate = Color(1.4, 0.6, 0.6)

func _on_turn_changed(entry: Dictionary) -> void:
	var unit = entry.unit
	var is_ally = entry.is_ally
	var name = unit.soldier_name if is_ally else unit.enemy_name
	turn_label.text = "Active: %s" % name

	for c in ally_cards:
		c.self_modulate = Color(1.5, 1.5, 0.5) if c.get_meta("unit") == unit else Color(1, 1, 1)

	_refresh_turn_order_bar()
	_refresh_all_cards()

func _refresh_all_cards() -> void:
	for unit in unit_hp_bars:
		if not is_instance_valid(unit_hp_bars[unit]):
			continue
		var hp_bar = unit_hp_bars[unit]
		var hp_lbl = unit_hp_labels[unit]
		var card = unit_cards[unit]

		hp_bar.value = unit.hp_current
		hp_lbl.text = "%d/%d" % [unit.hp_current, unit.hp_max]

		var pct = float(unit.hp_current) / float(unit.hp_max)
		if pct > 0.5:
			hp_bar.modulate = Color(0.2, 0.9, 0.2)
		elif pct > 0.25:
			hp_bar.modulate = Color(0.9, 0.7, 0.1)
		else:
			hp_bar.modulate = Color(0.9, 0.2, 0.2)

		if not unit.is_alive():
			card.self_modulate = Color(0.4, 0.4, 0.4)

func _on_unit_acted(log_line: String) -> void:
	_add_log(log_line)
	_refresh_all_cards()
	_refresh_turn_order_bar()

func _add_log(text: String, color: Color = Color(0.6, 0.7, 0.8)) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.custom_minimum_size = Vector2(300, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_child(lbl)

	# Scroll automat in jos
	await get_tree().process_frame
	log_scroll.scroll_vertical = log_scroll.get_v_scroll_bar().max_value

func _on_attack_pressed() -> void:
	if selected_target == null:
		_add_log("Select a target first!", Color(0.9, 0.4, 0.4))
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", Color(0.9, 0.4, 0.4))
		return
	CombatState.player_act("Attack", selected_target)
	selected_target = null
	for c in enemy_cards:
		c.self_modulate = Color(1, 1, 1)

func _on_defend_pressed() -> void:
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", Color(0.9, 0.4, 0.4))
		return
	CombatState.player_act("Defend", null)

func _on_combat_ended(victory: bool) -> void:
	if victory:
		_add_log("— Victory! +%d Gold, +%d XP —" % [
			CombatState.gold_earned, CombatState.xp_earned
		], Color(0.3, 1.0, 0.3))
	else:
		_add_log("— Defeat... —", Color(0.9, 0.2, 0.2))
	await get_tree().create_timer(2.0).timeout
	GameState.menu_open = false
	hide()
	GameState.emit_signal("recap_ready")
	GameState.emit_signal("turn_ended", GameState.current_turn)
