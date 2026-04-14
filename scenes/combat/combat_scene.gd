# combat_scene.gd
extends Control

var turn_order_container: HBoxContainer
@onready var allies_row: HBoxContainer = $AlliesRow
@onready var enemies_row: HBoxContainer = $EnemiesRow
@onready var turn_label: Label = $TurnLabel
@onready var skill_buttons_container: HBoxContainer = $ActionPanel/MarginContainer/VBoxContainer/SkillButtonsContainer
@onready var log_scroll: ScrollContainer = $LogPanel/ScrollContainer
@onready var log_container: VBoxContainer = $LogPanel/ScrollContainer/LogList

func _ready() -> void:
	_build_turn_order_bar()
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack.pressed.connect(_on_attack_pressed)
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend.pressed.connect(_on_defend_pressed)
	CombatState.combat_started.connect(_on_combat_started)
	CombatState.turn_changed.connect(_on_turn_changed)
	CombatState.unit_acted.connect(_on_unit_acted)
	CombatState.combat_ended.connect(_on_combat_ended)
	hide()
	
var ally_cards: Array = []
var enemy_cards: Array = []

# Referinte pentru cardurile de combat (AlliesRow/EnemiesRow)
var unit_hp_bars: Dictionary = {}
var unit_hp_labels: Dictionary = {}
var unit_combat_cards: Dictionary = {}  # unit -> card din AlliesRow/EnemiesRow

var selected_target = null

func _build_turn_order_bar() -> void:
	var bg = PanelContainer.new()
	bg.position = Vector2(40, 60)
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
	unit_combat_cards.clear()

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

	# Salveaza in dictionarul de combat cards
	unit_hp_bars[unit] = hp_bar
	unit_hp_labels[unit] = hp_lbl
	unit_combat_cards[unit] = panel  # ← combat cards separat

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

		if i == CombatState.current_unit_index:
			pill.self_modulate = Color(1.0, 0.9, 0.2)
		elif is_ally:
			pill.self_modulate = Color(0.3, 0.8, 0.5)
		else:
			pill.self_modulate = Color(0.9, 0.3, 0.3)

		if not unit.is_alive():
			pill.self_modulate = Color(0.3, 0.3, 0.3)

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
	_refresh_skill_buttons() 

func _refresh_all_cards() -> void:
	for unit in unit_hp_bars:
		if not is_instance_valid(unit_hp_bars[unit]):
			continue
		var hp_bar = unit_hp_bars[unit]
		var hp_lbl = unit_hp_labels[unit]
		var card = unit_combat_cards[unit]  # ← usa combat cards

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

# --- ANIMATII — folosesc unit_combat_cards, nu turn order pills ---

func _play_damage_animation(unit) -> void:
	print("Playing damage animation for: ", unit.enemy_name if unit is EnemyData else unit.soldier_name)

	if not unit_combat_cards.has(unit):
		print("Unit not found in unit_combat_cards!")

		return
	var card = unit_combat_cards[unit]
	print("Card position: ", card.position, " global: ", card.global_position)
	var tween = create_tween()
	tween.tween_property(card, "self_modulate", Color(1.5, 0.2, 0.2), 0.08)
	tween.tween_property(card, "self_modulate", Color(1, 1, 1), 0.25)
	var original_pos = card.position
	var shake = create_tween()
	shake.tween_property(card, "position", original_pos + Vector2(6, 0), 0.05)
	shake.tween_property(card, "position", original_pos - Vector2(6, 0), 0.05)
	shake.tween_property(card, "position", original_pos + Vector2(4, 0), 0.04)
	shake.tween_property(card, "position", original_pos, 0.04)

func _play_attack_animation(unit) -> void:
	if not unit_combat_cards.has(unit):
		return
	var card = unit_combat_cards[unit]
	var original_pos = card.position
	var is_ally = CombatState.allies.has(unit)
	var lunge_dir = Vector2(30, 0) if is_ally else Vector2(-30, 0)
	var tween = create_tween()
	tween.tween_property(card, "position", original_pos + lunge_dir, 0.1)
	tween.tween_property(card, "position", original_pos, 0.15)

func _show_damage_number(unit, amount: int, is_miss: bool) -> void:
	if not unit_combat_cards.has(unit):
		return
	var card = unit_combat_cards[unit]
	var lbl = Label.new()
	lbl.text = "MISS" if is_miss else "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color",
		Color(0.7, 0.7, 0.7) if is_miss else Color(0.95, 0.2, 0.2)
	)
	lbl.position = card.global_position + Vector2(30, -10)
	lbl.z_index = 10
	get_tree().get_root().add_child(lbl)
	var tween = create_tween()
	tween.tween_property(lbl, "position", lbl.position + Vector2(0, -40), 0.6)
	tween.parallel().tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.6)
	tween.tween_callback(lbl.queue_free)

func _on_unit_acted(log_line: String) -> void:
	_add_log(log_line)
	_refresh_all_cards()
	_refresh_turn_order_bar()

	if not "attacks" in log_line:
		return

	var is_miss = "MISS" in log_line
	var dmg = 0
	if not is_miss:
		var regex = RegEx.new()
		regex.compile("for (\\d+) dmg")
		var result = regex.search(log_line)
		if result:
			dmg = int(result.get_string(1))

	var parts = log_line.split(" attacks ")
	if parts.size() < 2:
		return

	var attacker_name = parts[0].strip_edges()
	var target_name = parts[1].split(" for ")[0].replace(" — MISS", "").strip_edges()

	var attacker_found = false
	var target_found = false

	for unit in unit_combat_cards:
		var unit_name = unit.soldier_name if unit is SoldierData else unit.enemy_name
		if not attacker_found and unit_name == attacker_name:
			_play_attack_animation(unit)
			attacker_found = true
		elif not target_found and unit_name == target_name:
			if is_miss:
				_show_damage_number(unit, 0, true)
			else:
				_play_damage_animation(unit)
				_show_damage_number(unit, dmg, false)
			target_found = true
		if attacker_found and target_found:
			break

func _add_log(text: String, color: Color = Color(0.6, 0.7, 0.8)) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.custom_minimum_size = Vector2(300, 0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_child(lbl)
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
	
func _on_skill_pressed(skill: SkillData) -> void:
	if selected_target == null:
		_add_log("Select a target first!", Color(0.9, 0.4, 0.4))
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", Color(0.9, 0.4, 0.4))
		return
	CombatState.player_act("Skill", {skill = skill, enemy_target = selected_target})
	selected_target = null
	for c in enemy_cards:
		c.self_modulate = Color(1, 1, 1)

func _refresh_skill_buttons() -> void:
	if skill_buttons_container == null:
		return       print("skill_buttons_container is null!")

	for child in skill_buttons_container.get_children():
		child.queue_free()

	if CombatState.turn_order.is_empty():
		return         print("turn_order is empty")

	if CombatState.current_unit_index >= CombatState.turn_order.size():
		return        print("index out of range")


	var entry = CombatState.turn_order[CombatState.current_unit_index]
	if not entry.is_ally:
		print("index out of range")

		return

	var actor: SoldierData = entry.unit
	print("Actor: ", actor.soldier_name, " class: ", actor.soldier_class, " skills: ", actor.unlocked_skills.size())

	for skill in actor.get_active_skills():
		print("Adding skill button: ", skill.skill_name)
		var btn = Button.new()
		var cooldown = actor.active_skill_cooldowns.get(skill.skill_id, 0)
		if cooldown > 0:
			btn.text = "%s\n(CD: %d)" % [skill.skill_name, cooldown]
			btn.disabled = true
		else:
			btn.text = skill.skill_name
		btn.custom_minimum_size = Vector2(110, 40)
		btn.tooltip_text = skill.description
		btn.pressed.connect(func(): _on_skill_pressed(skill))
		skill_buttons_container.add_child(btn)

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
	for child in log_container.get_children():
		child.queue_free()
	CombatState.combat_log.clear()
	GameState.emit_signal("recap_ready")
	GameState.emit_signal("turn_ended", GameState.current_turn)
