# combat_scene.gd
extends Control

const UNIT_CARD_SCENE := preload("res://scenes/ui/unit_card.tscn")

# Fixed slot dimensions for combat unit cards. Cards are placed at absolute
# positions (not flowed by a container) so a unit's card never shifts when a
# neighbouring unit dies and swaps to its death sprite.
const UNIT_CARD_SIZE := Vector2(140, 230)

var turn_order_container: HBoxContainer
@onready var allies_row: Control = $AlliesRow
@onready var enemies_row: Control = $EnemiesRow
@onready var turn_label: Label = $TurnLabel
@onready var skill_buttons_container: HBoxContainer = $ActionPanel/MarginContainer/VBoxContainer/SkillButtonsContainer
@onready var log_scroll: ScrollContainer = $LogPanel/ScrollContainer
@onready var log_container: VBoxContainer = $LogPanel/ScrollContainer/LogList

var btn_auto: Button
var btn_speed_2x: Button
var combat_speed: float = 1.0
var battle_bg: TextureRect

func _ready() -> void:
	# The .tscn root ships with a tiny 40x40 rect (legacy from before anchored
	# children existed). Anchored children (e.g. top_right_box below, and the
	# dynamically-created battle_bg) resolve their PRESET-based anchors against
	# this root's rect, so it must be full-rect for them to land correctly.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The root itself has no input handling — let clicks pass through to
	# whatever sits beneath it in the hub when this scene isn't actively
	# capturing input. Children (buttons, unit cards, panels) set their own
	# mouse_filter and still receive input normally.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameTheme.get_theme()
	# TurnLabel floats on the dark battlefield (not a parchment panel) — keep it light.
	turn_label.add_theme_color_override("font_color", GameTheme.PARCHMENT)
	_build_turn_order_bar()
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack.pressed.connect(_on_attack_pressed)
	$ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend.pressed.connect(_on_defend_pressed)

	# Auto / 2x speed buttons — anchored top-right, grouped in an HBoxContainer
	var top_right_box = HBoxContainer.new()
	top_right_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right_box.offset_left = -210.0
	top_right_box.offset_top = 10.0
	top_right_box.offset_right = -10.0
	top_right_box.offset_bottom = 46.0
	top_right_box.add_theme_constant_override("separation", 8)
	add_child(top_right_box)

	# 2x Speed button — left of Auto
	btn_speed_2x = Button.new()
	btn_speed_2x.text = "2x OFF"
	btn_speed_2x.custom_minimum_size = Vector2(90, 36)
	btn_speed_2x.theme_type_variation = "Ghost"
	btn_speed_2x.pressed.connect(_on_speed_toggle_pressed)
	top_right_box.add_child(btn_speed_2x)

	# Auto button — rightmost
	btn_auto = Button.new()
	btn_auto.text = "Auto: OFF"
	btn_auto.custom_minimum_size = Vector2(100, 36)
	btn_auto.theme_type_variation = "Ghost"
	btn_auto.pressed.connect(_on_auto_toggle_pressed)
	top_right_box.add_child(btn_auto)

	CombatState.combat_started.connect(_on_combat_started)
	CombatState.turn_changed.connect(_on_turn_changed)
	CombatState.unit_acted.connect(_on_unit_acted)
	CombatState.combat_ended.connect(_on_combat_ended)
	CombatState.dungeon_combat_ended.connect(_on_dungeon_fight_ended)
	CombatState.spectator_combat_ended.connect(_on_spectator_fight_ended)
	hide()

var ally_cards: Array = []
var enemy_cards: Array = []

# Referinte pentru cardurile de combat (AlliesRow/EnemiesRow)
var unit_hp_bars: Dictionary = {}
var unit_hp_labels: Dictionary = {}
var unit_combat_cards: Dictionary = {}  # unit -> card din AlliesRow/EnemiesRow
var unit_portraits: Dictionary = {}     # unit -> TextureRect

var selected_target: Variant = null

# Emitted once a live "watch the city defend itself" battle has finished its
# 1s last-blow pause and the combat scene has been hidden. hub_screen connects
# to this (one-shot) when it starts the spectator battle.
signal spectator_battle_finished(victory: bool)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not CombatState.active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				if not CombatState.spectator_mode:
					_on_auto_toggle_pressed()
			KEY_F:
				_on_speed_toggle_pressed()

func _build_turn_order_bar() -> void:
	var bg = PanelContainer.new()
	bg.theme_type_variation = "Sunken"
	bg.position = Vector2(40, 60)
	bg.custom_minimum_size = Vector2(1120, 44)
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
	_refresh_battle_background()
	_build_units()
	_refresh_turn_order_bar()

	var attack_btn: Button = $ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack
	var defend_btn: Button = $ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend

	if CombatState.spectator_mode:
		# Live city-defense battle: auto-battle is forced on and locked, manual
		# actions and target selection are disabled. The 2x speed button stays
		# usable so the player can speed through the fight.
		CombatState.auto_battle = true
		btn_auto.text = "Auto: ON"
		btn_auto.disabled = true
		attack_btn.disabled = true
		defend_btn.disabled = true
		_add_log("— The city defends itself! —", GameTheme.LEATHER)
		turn_label.text = "City Defense"
	else:
		btn_auto.text = "Auto: OFF"
		btn_auto.disabled = false
		attack_btn.disabled = false
		defend_btn.disabled = false
		_add_log("— Combat started —", GameTheme.LEATHER)

# Picks/refreshes the battle background for the current fight (city defense,
# dungeon, or dungeon boss). The CombatScene node is reused across fights, so
# this is called each time combat starts rather than only in _ready(). The
# flat ColorRect stays underneath as a fallback if the art asset is missing.
func _refresh_battle_background() -> void:
	var bg_path := CombatState.get_battle_bg_path()
	if not ResourceLoader.exists(bg_path):
		if battle_bg != null:
			battle_bg.visible = false
		return

	if battle_bg == null:
		battle_bg = TextureRect.new()
		battle_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Extend the rect above the screen so the art shifts up: the ground in
		# the battle backgrounds sits low (~y520 in the dungeon/boss art), and
		# this raises it to ~y500 on screen so unit sprites stand on it.
		battle_bg.offset_top = -100.0
		battle_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		battle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		battle_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		battle_bg.modulate = Color(0.8, 0.8, 0.85)
		var color_rect: Node = $ColorRect
		add_child(battle_bg)
		move_child(battle_bg, color_rect.get_index() + 1)

	battle_bg.texture = load(bg_path) as Texture2D
	battle_bg.visible = true

func _build_units() -> void:
	for c in allies_row.get_children(): c.queue_free()
	for c in enemies_row.get_children(): c.queue_free()
	ally_cards.clear()
	enemy_cards.clear()
	unit_hp_bars.clear()
	unit_hp_labels.clear()
	unit_combat_cards.clear()

	for i in CombatState.allies.size():
		var soldier = CombatState.allies[i]
		var card = _make_unit_card(soldier, true)
		_place_card_in_slot(card, allies_row, i, CombatState.allies.size())
		allies_row.add_child(card)
		ally_cards.append(card)

	for i in CombatState.enemies.size():
		var enemy = CombatState.enemies[i]
		var card = _make_unit_card(enemy, false)
		_place_card_in_slot(card, enemies_row, i, CombatState.enemies.size())
		enemies_row.add_child(card)
		enemy_cards.append(card)

# Assigns a card a fixed, non-flowing position within its row. The row's
# width is divided into `slot_count` equal slots and the (fixed-size) card is
# centered within its slot. Because this runs once per unit at combat start
# and slot_count never changes mid-fight (death only dims/swaps a card's
# sprite, it never removes it from the row), every living card keeps its slot
# for the whole battle — a neighbour dying cannot push it off-screen.
func _place_card_in_slot(card: PanelContainer, row: Control, index: int, slot_count: int) -> void:
	var row_width: float = row.size.x
	if row_width <= 0.0:
		row_width = row.get_rect().size.x
	var slot_width: float = row_width / float(max(slot_count, 1))
	var x: float = index * slot_width + (slot_width - UNIT_CARD_SIZE.x) * 0.5
	card.position = Vector2(x, 0.0)

func _enemy_slug(enemy_slug_name: String) -> String:
	var base := enemy_slug_name.split(" #")[0]
	base = base.replace("[Legion] ", "")
	return base.to_lower().replace(" ", "_")

# Unit art ships on canvases with large transparent margins (the visible
# sprite is roughly half the PNG), which made units render small and float
# above the ground. This crops each texture to its used pixels horizontally
# and to the feet line at the bottom — the top margin is kept so that
# KEEP_ASPECT_CENTERED scaling in the portrait box stays height-constrained
# and the visible feet land exactly on the box's bottom edge.
var _battle_sprite_cache: Dictionary = {}

func _load_battle_sprite(path: String) -> Texture2D:
	if _battle_sprite_cache.has(path):
		return _battle_sprite_cache[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			result = tex
			var img := tex.get_image()
			if img != null:
				var used := img.get_used_rect()
				if used.size.x > 0 and used.size.y > 0:
					var atlas := AtlasTexture.new()
					atlas.atlas = tex
					atlas.region = Rect2(used.position.x, 0, used.size.x, used.end.y)
					result = atlas
	_battle_sprite_cache[path] = result
	return result

func _get_unit_portrait(unit, is_ally: bool) -> Texture2D:
	if is_ally:
		var soldier := unit as SoldierData
		var cls = soldier.soldier_class.to_lower()
		var variant = soldier.sprite_variant if soldier.sprite_variant > 1 else 0
		var suffix = ("_%d" % soldier.sprite_variant) if variant > 0 else ""
		var tex := _load_battle_sprite("res://assets/soldiers/%s/idle%s.png" % [cls, suffix])
		if tex == null:
			tex = _load_battle_sprite("res://assets/soldiers/%s/idle.png" % cls)
		return tex
	else:
		var enemy := unit as EnemyData
		var slug := _enemy_slug(enemy.enemy_name)
		return _load_battle_sprite("res://assets/enemies/%s/idle.png" % slug)

func _set_unit_portrait_state(unit, state: String) -> void:
	if not unit_portraits.has(unit):
		return
	if unit is SoldierData:
		var soldier := unit as SoldierData
		var cls = soldier.soldier_class.to_lower()
		var suffix = ("_%d" % soldier.sprite_variant) if soldier.sprite_variant > 1 else ""
		var tex := _load_battle_sprite("res://assets/soldiers/%s/%s%s.png" % [cls, state, suffix])
		if tex == null:
			tex = _load_battle_sprite("res://assets/soldiers/%s/%s.png" % [cls, state])
		if tex != null:
			unit_portraits[unit].texture = tex
	elif unit is EnemyData:
		var enemy := unit as EnemyData
		var slug := _enemy_slug(enemy.enemy_name)
		var tex := _load_battle_sprite("res://assets/enemies/%s/%s.png" % [slug, state])
		if tex != null:
			unit_portraits[unit].texture = tex
	return

func _make_unit_card(unit, is_ally: bool) -> PanelContainer:
	var card := UNIT_CARD_SCENE.instantiate() as PanelContainer
	card.custom_minimum_size = UNIT_CARD_SIZE
	# AlliesRow/EnemiesRow are plain Controls (not containers), so the card's
	# size must be set explicitly — custom_minimum_size alone has no effect
	# without a layout container to apply it.
	card.size = UNIT_CARD_SIZE

	var portrait: TextureRect = card.get_node("VBoxContainer/Portrait")
	var name_lbl: Label = card.get_node("VBoxContainer/NameLabel")
	var hp_lbl: Label = card.get_node("VBoxContainer/HPLabel")
	var hp_bar: ProgressBar = card.get_node("VBoxContainer/HPBar")

	var portrait_tex := _get_unit_portrait(unit, is_ally)
	if portrait_tex != null:
		portrait.texture = portrait_tex
	else:
		portrait.visible = false

	name_lbl.text = unit.soldier_name if is_ally else unit.enemy_name

	hp_lbl.text = "%d/%d" % [unit.hp_current, unit.hp_max]

	# The card panel is transparent (units stand directly on the battlefield),
	# so the floating name/HP text needs light ink + a dark outline to stay
	# readable against the background art.
	for lbl in [name_lbl, hp_lbl]:
		lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.06))
		lbl.add_theme_constant_override("outline_size", 4)

	hp_bar.max_value = unit.hp_max
	hp_bar.value = unit.hp_current

	# Store references for per-frame updates
	unit_hp_bars[unit] = hp_bar
	unit_hp_labels[unit] = hp_lbl
	unit_combat_cards[unit] = card
	unit_portraits[unit] = portrait

	if not is_ally:
		card.gui_input.connect(func(event: InputEvent):
			if CombatState.spectator_mode:
				return
			if event is InputEventMouseButton and event.pressed:
				_select_target(unit, card)
		)

	card.set_meta("unit", unit)
	return card

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
			# Muted aged gold — the bright yellow read as noise on parchment.
			pill.self_modulate = Color(0.83, 0.69, 0.27)
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
	# Cards have a transparent panel, so tints go on `modulate` (sprite +
	# labels) — `self_modulate` would only color the invisible stylebox.
	for c in enemy_cards:
		c.modulate = Color(1, 1, 1)
	card.modulate = Color(1.4, 0.6, 0.6)

func _on_turn_changed(entry: Dictionary) -> void:
	var unit = entry.unit
	var is_ally = entry.is_ally
	var unit_name = unit.soldier_name if is_ally else unit.enemy_name
	turn_label.text = "Active: %s" % unit_name

	for c in ally_cards:
		# Active unit: subtle warm brightening; inactive units dim slightly so
		# the contrast does the work instead of a hard yellow tint.
		if c.get_meta("unit") == unit:
			c.modulate = Color(1.18, 1.14, 1.0)
		else:
			c.modulate = Color(0.82, 0.82, 0.85)

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
			hp_bar.modulate = GameTheme.WAX

		if not unit.is_alive():
			card.modulate = Color(0.4, 0.4, 0.4)
			_set_unit_portrait_state(unit, "death")

# --- ANIMATII — folosesc unit_combat_cards, nu turn order pills ---

func _play_damage_animation(unit) -> void:
	if not unit_combat_cards.has(unit):
		return
	var card = unit_combat_cards[unit]
	_set_unit_portrait_state(unit, "hurt")
	var tween = create_tween()
	tween.tween_property(card, "modulate", Color(1.5, 0.2, 0.2), 0.08)
	tween.tween_property(card, "modulate", Color(1, 1, 1), 0.25)
	tween.tween_callback(func():
		_set_unit_portrait_state(unit, "idle" if unit.is_alive() else "death")
	)
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
	_set_unit_portrait_state(unit, "attack")
	var tween = create_tween()
	tween.tween_property(card, "position", original_pos + lunge_dir, 0.1)
	tween.tween_property(card, "position", original_pos, 0.15)
	tween.tween_callback(func(): _set_unit_portrait_state(unit, "idle"))

func _show_damage_number(unit, amount: int, is_miss: bool) -> void:
	if not unit_combat_cards.has(unit):
		return
	var card = unit_combat_cards[unit]
	var lbl = Label.new()
	lbl.text = "MISS" if is_miss else "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color",
		GameTheme.INK_SOFT if is_miss else GameTheme.WAX
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
		var is_miss = "MISS" in log_line or "DODGE" in log_line
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

func _add_log(text: String, color: Color = GameTheme.INK_SOFT) -> void:
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
		_add_log("Select a target first!", GameTheme.WAX)
		return
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", GameTheme.WAX)
		return
	CombatState.player_act("Attack", selected_target)
	selected_target = null
	for c in enemy_cards:
		c.modulate = Color(1, 1, 1)

func _on_defend_pressed() -> void:
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", GameTheme.WAX)
		return
	CombatState.player_act("Defend", null)

func _on_skill_pressed(skill: SkillData) -> void:
	if CombatState.turn_order.is_empty() or CombatState.current_unit_index >= CombatState.turn_order.size():
		return
	if not CombatState.turn_order[CombatState.current_unit_index].is_ally:
		_add_log("Not your turn!", GameTheme.WAX)
		return
	# Only single-target offensive skills need a selected enemy.
	if skill.target_mode == SkillData.TargetMode.ENEMY_SINGLE and selected_target == null:
		_add_log("Select a target first!", GameTheme.WAX)
		return
	CombatState.player_act("Skill", {skill = skill, enemy_target = selected_target})
	selected_target = null
	for c in enemy_cards:
		c.modulate = Color(1, 1, 1)

func _refresh_skill_buttons() -> void:
	if skill_buttons_container == null:
		return

	for child in skill_buttons_container.get_children():
		child.queue_free()

	# Spectator city-defense battles are fully auto-resolved — no skill buttons.
	if CombatState.spectator_mode:
		return

	if CombatState.turn_order.is_empty():
		return

	if CombatState.current_unit_index >= CombatState.turn_order.size():
		return

	var entry = CombatState.turn_order[CombatState.current_unit_index]
	if not entry.is_ally:
		return

	var actor: SoldierData = entry.unit

	for skill in actor.get_active_skills():
		var btn = Button.new()
		var cooldown: int = actor.active_skill_cooldowns.get(skill.skill_id, 0)
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
		], GameTheme.MOSS)
	else:
		_add_log("— Defeat! Your soldiers have fallen. —", GameTheme.WAX)

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
		GameTheme.MOSS if victory else GameTheme.WAX
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Rewards (victory only)
	if victory:
		var gold_lbl = Label.new()
		gold_lbl.text = "+%d Gold" % CombatState.gold_earned
		gold_lbl.add_theme_font_size_override("font_size", 20)
		gold_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_lbl)

		var xp_lbl = Label.new()
		xp_lbl.text = "+%d XP" % CombatState.xp_earned
		xp_lbl.add_theme_font_size_override("font_size", 18)
		xp_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(xp_lbl)

		# Level ups
		if not CombatState.leveled_up_soldiers.is_empty():
			for soldier_name in CombatState.leveled_up_soldiers:
				var lvl_lbl = Label.new()
				lvl_lbl.text = "Level Up! %s" % soldier_name
				lvl_lbl.add_theme_font_size_override("font_size", 15)
				lvl_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
				lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(lvl_lbl)

	# Dead soldiers
	var dead_soldiers = CombatState.allies.filter(func(s): return not s.is_alive())
	if not dead_soldiers.is_empty():
		var dead_header = Label.new()
		dead_header.text = "Fallen soldiers:"
		dead_header.add_theme_font_size_override("font_size", 15)
		dead_header.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		dead_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(dead_header)
		for s in dead_soldiers:
			var dead_lbl = Label.new()
			dead_lbl.text = s.soldier_name
			dead_lbl.add_theme_font_size_override("font_size", 13)
			dead_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
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
		hide()
		if GameState.city_walls <= 0:
			# City defense lost and walls hit 0 — show "DEFEAT!" first (above),
			# then the city-fallen game-over screen instead of the recap.
			var hub: Node = get_tree().get_first_node_in_group("city_view")
			if hub != null and hub.has_method("_show_city_fallen_overlay"):
				hub._show_city_fallen_overlay()
			return
		if GameState.game_won_achieved:
			# The final boss wave was just won — show the victory screen now
			# that the "VICTORY!" popup has been dismissed. The run is over,
			# so skip turn_ended/recap_ready entirely.
			GameState.announce_game_won_if_pending()
			return
		GameState.emit_signal("turn_ended", GameState.current_turn)
		GameState.emit_signal("recap_ready")
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

	# Framed parchment panel (matches recap/victory) instead of bare centered text.
	var panel = PanelContainer.new()
	panel.theme = GameTheme.get_theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 240)
	panel.position -= Vector2(210, 120)
	var panel_frame = PixelUI.parchment_window_stylebox(22)
	if panel_frame != null:
		panel.add_theme_stylebox_override("panel", panel_frame)
	root.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var tween = get_tree().get_root().create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.45)

	var title = Label.new()
	title.text = "VICTORY!" if victory else "DEFEAT!"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color",
		GameTheme.MOSS if victory else GameTheme.WAX
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	if victory and CombatState.gold_earned > 0:
		var gold_lbl = Label.new()
		gold_lbl.text = "+%d Gold" % CombatState.gold_earned
		gold_lbl.add_theme_font_size_override("font_size", 18)
		gold_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
		gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_lbl)

	# Dead soldiers in this dungeon fight
	var dead_soldiers = CombatState.allies.filter(func(s): return not s.is_alive())
	if not dead_soldiers.is_empty():
		var dead_header = Label.new()
		dead_header.text = "Fallen:"
		dead_header.add_theme_font_size_override("font_size", 14)
		dead_header.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		dead_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(dead_header)
		for s in dead_soldiers:
			var dead_lbl = Label.new()
			dead_lbl.text = s.soldier_name
			dead_lbl.add_theme_font_size_override("font_size", 13)
			dead_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
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

# ---------------------------------------------------------------------------
# Live city-defense spectator battle — see CombatState.spectator_mode.
# The fight runs through the normal combat loop with locked controls; once it
# ends, the last blow stays on screen briefly, then the scene hides itself and
# hub_screen takes over to show the "City Attacked!" result dialog.
# ---------------------------------------------------------------------------
func _on_spectator_fight_ended(victory: bool) -> void:
	CombatState.auto_battle = false
	if btn_auto != null:
		btn_auto.text = "Auto: OFF"
		btn_auto.disabled = false
	var attack_btn: Button = $ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnAttack
	var defend_btn: Button = $ActionPanel/MarginContainer/VBoxContainer/HBoxButtons/BtnDefend
	attack_btn.disabled = false
	defend_btn.disabled = false

	_add_log("— Victory! —" if victory else "— Defeat! —", GameTheme.MOSS if victory else GameTheme.WAX)
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout

	for child in log_container.get_children():
		child.queue_free()
	CombatState.combat_log.clear()
	CombatState.allies.clear()
	CombatState.enemies.clear()
	GameState.menu_open = false
	hide()
	spectator_battle_finished.emit(victory)
