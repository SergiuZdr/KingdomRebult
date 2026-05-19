# combat_scene.gd
extends Control

var turn_order_container: HBoxContainer
@onready var allies_row: HBoxContainer = $AlliesRow
@onready var enemies_row: HBoxContainer = $EnemiesRow
@onready var turn_label: Label = $TurnLabel
@onready var skill_buttons_container: HBoxContainer = $ActionPanel/MarginContainer/VBoxContainer/SkillButtonsContainer
@onready var log_scroll: ScrollContainer = $LogPanel/ScrollContainer
@onready var log_container: VBoxContainer = $LogPanel/ScrollContainer/LogList

var btn_auto: Button
var btn_speed_2x: Button
var combat_speed: float = 1.0

func _ready() -> void:
	_build_turn_order_bar()
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack.pressed.connect(_on_attack_pressed)
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend.pressed.connect(_on_defend_pressed)

	# Auto button — top-right corner, standalone
	btn_auto = Button.new()
	btn_auto.text = "Auto: OFF"
	btn_auto.custom_minimum_size = Vector2(100, 36)
	btn_auto.position = Vector2(1100, 10)
	btn_auto.pressed.connect(_on_auto_toggle_pressed)
	add_child(btn_auto)

	# 2x Speed button — top-right corner, next to Auto
	btn_speed_2x = Button.new()
	btn_speed_2x.text = "2x OFF"
	btn_speed_2x.custom_minimum_size = Vector2(90, 36)
	btn_speed_2x.position = Vector2(1000, 10)
	btn_speed_2x.pressed.connect(_on_speed_toggle_pressed)
	add_child(btn_speed_2x)

	CombatState.combat_started.connect(_on_combat_started)
	CombatState.turn_changed.connect(_on_turn_changed)
	CombatState.unit_acted.connect(_on_unit_acted)
	CombatState.combat_ended.connect(_on_combat_ended)
	CombatState.game_over.connect(_on_game_over)
	CombatState.dungeon_combat_ended.connect(_on_dungeon_fight_ended)
	hide()

var ally_cards: Array = []
var enemy_cards: Array = []

# Referinte pentru cardurile de combat (AlliesRow/EnemiesRow)
var unit_hp_bars: Dictionary = {}
var unit_hp_labels: Dictionary = {}
var unit_combat_cards: Dictionary = {}  # unit -> card din AlliesRow/EnemiesRow

var selected_target = null

var _replay_mode: bool = false
var _replay_on_done: Callable = Callable()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not CombatState.active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				_on_auto_toggle_pressed()
			KEY_F:
				_on_speed_toggle_pressed()

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
	# Reset speed & auto button visuals to match CombatState resets
	combat_speed = 1.0
	btn_speed_2x.text = "2x OFF"
	btn_auto.text = "Auto: OFF"
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

func _get_unit_portrait(unit, is_ally: bool) -> Texture2D:
	var path := ""
	if is_ally:
		match (unit as SoldierData).soldier_class:
			"Warrior": path = "res://Downloaded Game Assets/Characters/Warrior/GandalfHardcore Warrior.png"
			"Archer":  path = "res://Downloaded Game Assets/Characters/Archer/GandalfHardcore Archer sheet.png"
			"Mage":    path = "res://Downloaded Game Assets/Characters/Wizard/Purple Wizard sheet.png"
			"Knight":  path = "res://Downloaded Game Assets/Characters/Knight Run and Portrait/Knight Portrait 64x64.png"
			"Rogue":   path = "res://Downloaded Game Assets/Characters/Archer/GandalfHardcore Archer black sheet.png"
	else:
		var enemy := unit as EnemyData
		if enemy.hp_max > 100:
			path = "res://Downloaded Game Assets/Characters/ENEMIES/Orc sheet.png"
		else:
			var base = enemy.enemy_name.split(" ")[0]
			match base:
				"Goblin": path = "res://Downloaded Game Assets/Characters/ENEMIES/Goblins/Portrait 64x64.png"
				"Orc":    path = "res://Downloaded Game Assets/Characters/ENEMIES/Orc sheet.png"
				"Wolf":   path = "res://Downloaded Game Assets/Characters/ENEMIES/Goblins/Portrait 64x64.png"
				"Enemy":  path = "res://Downloaded Game Assets/Characters/Knight Run and Portrait/Knight Portrait 64x64.png"
	if path == "":
		return null
	return load(path) as Texture2D

func _make_unit_card(unit, is_ally: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(110, 160)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var portrait_tex = _get_unit_portrait(unit, is_ally)
	if portrait_tex != null:
		var portrait = TextureRect.new()
		portrait.texture = portrait_tex
		portrait.custom_minimum_size = Vector2(90, 56)
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(portrait)

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
	var unit_name = unit.soldier_name if is_ally else unit.enemy_name
	turn_label.text = "Active: %s" % unit_name

	for c in ally_cards:
		c.self_modulate = Color(1.5, 1.5, 0.5) if c.get_meta("unit") == unit else Color(1, 1, 1)

	_refresh_turn_order_bar()
	_refresh_all_cards()
	_refresh_skill_buttons()

	if is_ally and CombatState.auto_battle:
		_schedule_auto_act()

func _on_auto_toggle_pressed() -> void:
	CombatState.auto_battle = not CombatState.auto_battle
	btn_auto.text = "Auto: ON" if CombatState.auto_battle else "Auto: OFF"
	if CombatState.auto_battle:
		# Trigger immediately if it's already a player turn
		if not CombatState.turn_order.is_empty() and CombatState.current_unit_index < CombatState.turn_order.size():
			if CombatState.turn_order[CombatState.current_unit_index].is_ally:
				_schedule_auto_act()

func _on_speed_toggle_pressed() -> void:
	if combat_speed == 1.0:
		combat_speed = 2.0
		CombatState.speed_multiplier = 2.0
		btn_speed_2x.text = "2x ON"
	else:
		combat_speed = 1.0
		CombatState.speed_multiplier = 1.0
		btn_speed_2x.text = "2x OFF"

func _schedule_auto_act() -> void:
	await get_tree().create_timer(0.8 / CombatState.speed_multiplier).timeout
	if not CombatState.auto_battle or not CombatState.active:
		return
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		return

	var actor: SoldierData = CombatState.turn_order[CombatState.current_unit_index].unit
	var alive_enemies = CombatState.enemies.filter(func(e): return e.is_alive())
	if alive_enemies.is_empty():
		return

	# Try to use best available active skill
	var best_skill: SkillData = null
	for skill in actor.get_active_skills():
		if actor.active_skill_cooldowns.get(skill.skill_id, 0) <= 0:
			if best_skill == null or skill.damage_multiplier > best_skill.damage_multiplier:
				best_skill = skill

	# Pick best target: lowest-HP enemy to try to finish them off
	var target: EnemyData = alive_enemies[0]
	for e in alive_enemies:
		if e.hp_current < target.hp_current:
			target = e

	if best_skill != null:
		CombatState.player_act("Skill", {skill = best_skill, enemy_target = target})
	else:
		CombatState.player_act("Attack", target)

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
	var is_ally = unit is SoldierData
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

	if "attacks" in log_line:
		var is_miss = "MISS" in log_line
		var dmg = 0
		if not is_miss:
			var regex = RegEx.new()
			regex.compile("for (\\d+) dmg")
			var result = regex.search(log_line)
			if result:
				dmg = int(result.get_string(1))

		var parts = log_line.split(" attacks ")
		if parts.size() >= 2:
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

	elif "uses" in log_line and " on " in log_line:
		# Skill log format: "X uses SKILL on Y for N dmg!" or "X uses SKILL — MISS!"
		var is_miss = "MISS" in log_line
		var dmg = 0
		if not is_miss:
			var regex = RegEx.new()
			regex.compile("for (\\d+) dmg")
			var result = regex.search(log_line)
			if result:
				dmg = int(result.get_string(1))

		# Parse attacker: everything before " uses "
		var uses_parts = log_line.split(" uses ")
		if uses_parts.size() >= 2:
			var attacker_name = uses_parts[0].strip_edges()
			# Parse target: everything after " on " and before " for " or end
			var on_parts = uses_parts[1].split(" on ")
			if on_parts.size() >= 2:
				var target_name = on_parts[1].split(" for ")[0].strip_edges()

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
	log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)

func _on_attack_pressed() -> void:
	if selected_target == null:
		_add_log("Select a target first!", Color(0.9, 0.4, 0.4))
		return
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", Color(0.9, 0.4, 0.4))
		return
	CombatState.player_act("Attack", selected_target)
	selected_target = null
	for c in enemy_cards:
		c.self_modulate = Color(1, 1, 1)

func _on_defend_pressed() -> void:
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", Color(0.9, 0.4, 0.4))
		return
	CombatState.player_act("Defend", null)

func _on_skill_pressed(skill: SkillData) -> void:
	if selected_target == null:
		_add_log("Select a target first!", Color(0.9, 0.4, 0.4))
		return
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
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
		print("skill_buttons_container is null!")
		return

	for child in skill_buttons_container.get_children():
		child.queue_free()

	if CombatState.turn_order.is_empty():
		print("turn_order is empty")
		return

	if CombatState.current_unit_index >= CombatState.turn_order.size():
		print("index out of range")
		return

	var entry = CombatState.turn_order[CombatState.current_unit_index]
	if not entry.is_ally:
		print("current unit is not an ally, skipping skill buttons")
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
	CombatState.auto_battle = false
	btn_auto.text = "Auto: OFF"

	if victory:
		_add_log("— Victory! +%d Gold, +%d XP —" % [
			CombatState.gold_earned, CombatState.xp_earned
		], Color(0.3, 1.0, 0.3))
	else:
		_add_log("— Defeat! Your soldiers have fallen. —", Color(0.9, 0.2, 0.2))

	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	_show_battle_end_screen(victory)

func _show_battle_end_screen(victory: bool) -> void:
	var overlay = CanvasLayer.new()
	overlay.layer = 60
	get_tree().get_root().add_child(overlay)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	overlay.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(480, 320)
	vbox.position -= Vector2(240, 160)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)

	var tween = get_tree().get_root().create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.45)

	# Title
	var title = Label.new()
	title.text = "VICTORY!" if victory else "DEFEAT!"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color",
		Color(0.2, 1.0, 0.3) if victory else Color(0.95, 0.2, 0.2)
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Rewards (victory only)
	if victory:
		var gold_lbl = Label.new()
		gold_lbl.text = "+%d Gold" % CombatState.gold_earned
		gold_lbl.add_theme_font_size_override("font_size", 20)
		gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_lbl)

		var xp_lbl = Label.new()
		xp_lbl.text = "+%d XP" % CombatState.xp_earned
		xp_lbl.add_theme_font_size_override("font_size", 18)
		xp_lbl.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(xp_lbl)

		# Level ups
		if not CombatState.leveled_up_soldiers.is_empty():
			for soldier_name in CombatState.leveled_up_soldiers:
				var lvl_lbl = Label.new()
				lvl_lbl.text = "Level Up! %s" % soldier_name
				lvl_lbl.add_theme_font_size_override("font_size", 15)
				lvl_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
				lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(lvl_lbl)

	# Dead soldiers
	var dead_soldiers = CombatState.allies.filter(func(s): return not s.is_alive())
	if not dead_soldiers.is_empty():
		var dead_header = Label.new()
		dead_header.text = "Fallen soldiers:"
		dead_header.add_theme_font_size_override("font_size", 15)
		dead_header.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
		dead_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(dead_header)
		for s in dead_soldiers:
			var dead_lbl = Label.new()
			dead_lbl.text = s.soldier_name
			dead_lbl.add_theme_font_size_override("font_size", 13)
			dead_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
			dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(dead_lbl)

	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(180, 48)
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.pressed.connect(func():
		overlay.queue_free()
		for child in log_container.get_children():
			child.queue_free()
		CombatState.combat_log.clear()
		GameState.emit_signal("turn_ended", GameState.current_turn)
		GameState.emit_signal("recap_ready")
		hide()
	)
	vbox.add_child(continue_btn)

func _on_dungeon_fight_ended(victory: bool) -> void:
	CombatState.auto_battle = false
	if btn_auto != null:
		btn_auto.text = "Auto: OFF"
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	_show_dungeon_fight_result(victory)

func _show_dungeon_fight_result(victory: bool) -> void:
	var overlay = CanvasLayer.new()
	overlay.layer = 60
	get_tree().get_root().add_child(overlay)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.modulate.a = 0.0
	overlay.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(380, 220)
	vbox.position -= Vector2(190, 110)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)

	var tween = get_tree().get_root().create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.45)

	var title = Label.new()
	title.text = "VICTORY!" if victory else "DEFEAT!"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color",
		Color(0.2, 1.0, 0.3) if victory else Color(0.95, 0.2, 0.2)
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if victory and CombatState.gold_earned > 0:
		var gold_lbl = Label.new()
		gold_lbl.text = "+%d Gold" % CombatState.gold_earned
		gold_lbl.add_theme_font_size_override("font_size", 18)
		gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_lbl)

	# Dead soldiers in this dungeon fight
	var dead_soldiers = CombatState.allies.filter(func(s): return not s.is_alive())
	if not dead_soldiers.is_empty():
		var dead_header = Label.new()
		dead_header.text = "Fallen:"
		dead_header.add_theme_font_size_override("font_size", 14)
		dead_header.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
		dead_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(dead_header)
		for s in dead_soldiers:
			var dead_lbl = Label.new()
			dead_lbl.text = s.soldier_name
			dead_lbl.add_theme_font_size_override("font_size", 13)
			dead_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
			dead_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(dead_lbl)

	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(160, 44)
	continue_btn.add_theme_font_size_override("font_size", 16)
	continue_btn.pressed.connect(func():
		overlay.queue_free()
		for child in log_container.get_children():
			child.queue_free()
		CombatState.combat_log.clear()
		GameState.menu_open = false
		CombatState.notify_dungeon_result_dismissed()
		call_deferred("hide")
	)
	vbox.add_child(continue_btn)

func _on_game_over() -> void:
	await get_tree().create_timer(1.5).timeout
	# Clean up combat scene state before showing game over overlay
	GameState.menu_open = false
	hide()
	for child in log_container.get_children():
		child.queue_free()
	CombatState.combat_log.clear()
	_show_game_over_screen()

func _show_game_over_screen() -> void:
	var overlay = CanvasLayer.new()
	overlay.layer = 10
	get_tree().get_root().add_child(overlay)

	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.02, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(500, 300)
	vbox.position -= Vector2(250, 150)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	root.add_child(vbox)

	var title = Label.new()
	title.text = "THE CITY HAS FALLEN"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "All your soldiers are dead.\nThe kingdom is lost."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(subtitle)

	var stats_lbl = Label.new()
	stats_lbl.text = "Turn %d reached | Difficulty %d" % [GameState.current_turn, GameState.combat_difficulty]
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	var btn = Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(220, 50)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func():
		overlay.queue_free()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	vbox.add_child(btn)

func start_city_defense_replay(events: Array, on_done: Callable) -> void:
	if events.is_empty():
		on_done.call()
		return

	_replay_mode = true
	_replay_on_done = on_done

	# --- Build unit data from event log ---
	var ally_hp: Dictionary = {}    # name -> hp_max
	var enemy_hp: Dictionary = {}

	for ev in events:
		if ev.get("type") != "attack":
			continue
		var tname: String = ev.get("target_name", "")
		var thp_max: int = ev.get("target_hp_max", 100)
		if ev.get("target_is_ally", false):
			if not ally_hp.has(tname):
				ally_hp[tname] = thp_max
		else:
			if not enemy_hp.has(tname):
				enemy_hp[tname] = thp_max
		var aname: String = ev.get("attacker_name", "")
		if ev.get("attacker_is_ally", false):
			if not ally_hp.has(aname):
				ally_hp[aname] = 100
		else:
			if not enemy_hp.has(aname):
				enemy_hp[aname] = 100

	# Create SoldierData and EnemyData for display
	var allies_arr: Array[SoldierData] = []
	for unit_name in ally_hp:
		var s = SoldierData.new()
		s.soldier_name = unit_name
		s.hp_max = ally_hp[unit_name]
		s.hp_current = ally_hp[unit_name]
		allies_arr.append(s)

	var enemies_arr: Array[EnemyData] = []
	for unit_name in enemy_hp:
		var e = EnemyData.new()
		e.enemy_name = unit_name
		e.hp_max = enemy_hp[unit_name]
		e.hp_current = enemy_hp[unit_name]
		enemies_arr.append(e)

	CombatState.allies = allies_arr
	CombatState.enemies = enemies_arr

	GameState.menu_open = true
	show()
	selected_target = null
	_build_units()
	_add_log("— City Defense Replay —", Color(1.0, 0.5, 0.2))
	turn_label.text = "City Defense — Replay"

	# Disable interactive buttons
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack.disabled = true
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend.disabled = true
	btn_auto.disabled = true
	btn_speed_2x.disabled = true

	# Skip button
	var skip_btn = Button.new()
	skip_btn.name = "ReplaySkipBtn"
	skip_btn.text = "Skip Replay"
	skip_btn.position = Vector2(1050, 680)
	skip_btn.custom_minimum_size = Vector2(220, 44)
	skip_btn.add_theme_font_size_override("font_size", 15)
	skip_btn.pressed.connect(func():
		if _replay_mode:
			_replay_mode = false
			_end_city_defense_replay()
	)
	add_child(skip_btn)

	_run_city_defense_replay_events(events, skip_btn)

func _end_city_defense_replay() -> void:
	_replay_mode = false
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack.disabled = false
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend.disabled = false
	btn_auto.disabled = false
	btn_speed_2x.disabled = false
	var skip_btn = get_node_or_null("ReplaySkipBtn")
	if skip_btn:
		skip_btn.queue_free()
	for child in log_container.get_children():
		child.queue_free()
	CombatState.allies.clear()
	CombatState.enemies.clear()
	GameState.menu_open = false
	hide()
	if _replay_on_done.is_valid():
		_replay_on_done.call()

func _run_city_defense_replay_events(events: Array, skip_btn: Button) -> void:
	for ev in events:
		if not _replay_mode:
			return

		if ev.get("type") == "attack":
			var attacker: String = ev.get("attacker_name", "?")
			var target_name: String = ev.get("target_name", "?")
			var dmg: int = ev.get("damage", 0)
			var hp_after: int = ev.get("target_hp_after", 0)
			var is_ally_att: bool = ev.get("attacker_is_ally", false)

			turn_label.text = "%s attacks %s" % [attacker, target_name]

			# Update unit HP
			var all_units: Array = []
			all_units.append_array(CombatState.allies)
			all_units.append_array(CombatState.enemies)
			for unit in all_units:
				var uname = unit.soldier_name if unit is SoldierData else unit.enemy_name
				if uname == target_name:
					unit.hp_current = hp_after
					break
			_refresh_all_cards()

			await _add_log("%s → %s  [-%d]" % [attacker, target_name, dmg],
				Color(0.5, 0.9, 0.5) if is_ally_att else Color(0.9, 0.5, 0.4))

		elif ev.get("type") == "death":
			var unit_name: String = ev.get("unit_name", "?")
			turn_label.text = "%s has fallen!" % unit_name
			var all_units: Array = []
			all_units.append_array(CombatState.allies)
			all_units.append_array(CombatState.enemies)
			for unit in all_units:
				var uname = unit.soldier_name if unit is SoldierData else unit.enemy_name
				if uname == unit_name and unit_combat_cards.has(unit):
					unit_combat_cards[unit].modulate = Color(0.4, 0.4, 0.4)
					break
			await _add_log("✗ %s defeated!" % unit_name, Color(0.85, 0.3, 0.3))

		await get_tree().create_timer(0.5).timeout

	if not _replay_mode:
		return

	turn_label.text = "— Replay Complete —"
	await _add_log("— Replay Complete —", Color(0.85, 0.82, 0.5))
	if is_instance_valid(skip_btn):
		skip_btn.text = "Continue"
