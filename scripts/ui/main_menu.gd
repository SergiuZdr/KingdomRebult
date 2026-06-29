# res://scripts/ui/main_menu.gd
extends Control

## War-table diegetic main menu. Three interactive props sit on the table:
## a sealed letter (New Game), a leather ledger (Load Save), and a lit
## candle (Quit). Hover/click feedback per assets/ui/menu/wartable/SPEC.md.

const ART_DIR := "res://assets/ui/menu/wartable/"

@onready var prop_new_game: Control = $PropNewGame
@onready var prop_load_save: Control = $PropLoadSave
@onready var prop_quit: Control = $PropQuit
@onready var save_slots_panel: PanelContainer = $SaveSlotsPanel
@onready var slots_container: VBoxContainer = $SaveSlotsPanel/VBoxContainer

var _backdrop: MainMenuBackdrop
var _load_available: bool = true
var _input_locked: bool = false  # blocks prop interaction during click feedback

var current_mode: String = ""  # "save" or "load"


func _ready() -> void:
	theme = GameTheme.get_theme()

	# War-table backdrop, on a layer behind the menu UI.
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	_backdrop = MainMenuBackdrop.new()
	bg_layer.add_child(_backdrop)

	_setup_prop(prop_new_game, "prop_letter.png", Vector2(210, 210), _on_new_game_prop_pressed)
	_setup_prop(prop_load_save, "prop_ledger.png", Vector2(210, 210), _on_load_prop_pressed)
	_setup_prop(prop_quit, "prop_candle.png", Vector2(143, 169), _on_quit_prop_pressed)

	save_slots_panel.hide()
	_check_load_available()
	MusicManager.play("menu")
	_play_entrance()


func _tex(file: String) -> Texture2D:
	var p := ART_DIR + file
	# NOTE: prop_ledger.png (Load Save) was still generating at write time.
	# Fall back to parchment_sheet.png at the same node so the wiring is
	# identical once the real asset lands — just re-run import.
	if file == "prop_ledger.png" and not ResourceLoader.exists(p):
		p = ART_DIR + "parchment_sheet.png"
	return (load(p) as Texture2D) if ResourceLoader.exists(p) else null


## Wires up a TextureRect+Label prop: texture, sizing/pivot, idle label
## styling, hover scale/brighten, and click handling.
func _setup_prop(root: Control, tex_file: String, display_size: Vector2, on_click: Callable) -> void:
	var texture_rect: TextureRect = root.get_node("Texture")
	var label: Label = root.get_node("Label")

	texture_rect.texture = _tex(tex_file)
	texture_rect.size = display_size
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	texture_rect.pivot_offset = display_size * 0.5

	var body_font: Font = load(GameTheme.FONT_BODY)
	if body_font:
		label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_outline_color", GameTheme.NIGHT)
	label.add_theme_constant_override("outline_size", 2)
	_set_label_idle(label)

	texture_rect.mouse_entered.connect(_on_prop_hover_enter.bind(root, texture_rect, label))
	texture_rect.mouse_exited.connect(_on_prop_hover_exit.bind(root, texture_rect, label))
	texture_rect.gui_input.connect(_on_prop_gui_input.bind(root, on_click))


func _set_label_idle(label: Label) -> void:
	label.add_theme_color_override("font_color", GameTheme.PARCHMENT)


func _set_label_disabled(label: Label) -> void:
	label.add_theme_color_override("font_color", GameTheme.INK_SOFT)


func _set_label_hover(label: Label) -> void:
	label.add_theme_color_override("font_color", GameTheme.PARCHMENT)


# ── Entrance ──────────────────────────────────────────────────────────────────

## Table/map/dressing fade in via the backdrop's own _ready (no extra work
## needed there since it's drawn first frame). Interactive props pop in
## staggered, then the title fades in last.
func _play_entrance() -> void:
	var props: Array[Control] = [prop_new_game, prop_load_save, prop_quit]
	for i in props.size():
		var prop := props[i]
		var target_pos := prop.position
		prop.position = target_pos + Vector2(0, 14)
		prop.modulate.a = 0.0
		var delay := 0.08 * i
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(prop, "modulate:a", 1.0, 0.20)
		tw.tween_property(prop, "position", target_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Title fades in last, after the props finish.
	if is_instance_valid(_backdrop):
		var title_delay := 0.08 * props.size() + 0.15
		for lbl in _backdrop.get_title_labels():
			if is_instance_valid(lbl):
				lbl.modulate.a = 0.0
				var tw2 := create_tween()
				tw2.tween_interval(title_delay)
				tw2.tween_property(lbl, "modulate:a", 1.0, 0.4)


# ── Hover feedback ────────────────────────────────────────────────────────────

func _on_prop_hover_enter(root: Control, texture_rect: TextureRect, label: Label) -> void:
	if _input_locked:
		return
	if root == prop_load_save and not _load_available:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(texture_rect, "scale", Vector2(1.07, 1.07), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(texture_rect, "modulate", Color(1.15, 1.15, 1.15), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_set_label_hover(label)


func _on_prop_hover_exit(root: Control, texture_rect: TextureRect, label: Label) -> void:
	if _input_locked:
		return
	if root == prop_load_save and not _load_available:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(texture_rect, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(texture_rect, "modulate", Color.WHITE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_set_label_idle(label)


# ── Click feedback ────────────────────────────────────────────────────────────

func _on_prop_gui_input(event: InputEvent, root: Control, on_click: Callable) -> void:
	if _input_locked:
		return
	if root == prop_load_save and not _load_available:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		on_click.call()


## Letter → quick press feedback (scale down then back up), then opens the
## save-slot panel in "new game" mode.
func _on_new_game_prop_pressed() -> void:
	_input_locked = true
	var texture_rect: TextureRect = prop_new_game.get_node("Texture")
	texture_rect.pivot_offset = texture_rect.size * 0.5

	var tw := create_tween()
	tw.tween_property(texture_rect, "scale", Vector2(0.94, 0.94), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(texture_rect, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_input_locked = false
		_on_new_game()
	)


## Ledger → slight tilt tween, then opens the save-slot panel in "load" mode.
func _on_load_prop_pressed() -> void:
	_input_locked = true
	var texture_rect: TextureRect = prop_load_save.get_node("Texture")
	texture_rect.pivot_offset = texture_rect.size * 0.5

	var tw := create_tween()
	tw.tween_property(texture_rect, "rotation_degrees", -6.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(texture_rect, "rotation_degrees", 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_input_locked = false
		_on_load_pressed()
	)


## Candle → snuff out (modulate to dark), then quit.
func _on_quit_prop_pressed() -> void:
	_input_locked = true
	var texture_rect: TextureRect = prop_quit.get_node("Texture")

	var tw := create_tween()
	tw.tween_property(texture_rect, "modulate", Color(0.25, 0.25, 0.3, 1.0), 0.4)
	tw.tween_callback(_on_quit)


# ── Save slot handling (unchanged behaviour) ─────────────────────────────────

func _check_load_available() -> void:
	var any_save = false
	for i in range(1, SaveManager.MAX_SLOTS + 1):
		if not SaveManager.get_slot_info(i).get("empty", true):
			any_save = true
			break
	_load_available = any_save
	_apply_load_prop_state()


## No-saves state: ledger dimmed 0.55, label INK_SOFT, no hover response.
func _apply_load_prop_state() -> void:
	var texture_rect: TextureRect = prop_load_save.get_node("Texture")
	var label: Label = prop_load_save.get_node("Label")
	if _load_available:
		texture_rect.modulate = Color.WHITE
		texture_rect.scale = Vector2.ONE
		_set_label_idle(label)
	else:
		texture_rect.modulate = Color(0.55, 0.55, 0.55, 1.0)
		texture_rect.scale = Vector2.ONE
		_set_label_disabled(label)


## "2026-06-11T03:27:05" → "11 Jun 2026, 03:27". Unparseable values pass through.
func _format_save_timestamp(ts: String) -> String:
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var parts := ts.split("T")
	if parts.size() != 2:
		return ts
	var d := parts[0].split("-")
	var tm := parts[1].split(":")
	if d.size() != 3 or tm.size() < 2:
		return ts
	var month_idx := d[1].to_int() - 1
	if month_idx < 0 or month_idx > 11:
		return ts
	return "%d %s %s, %s:%s" % [d[2].to_int(), months[month_idx], d[0], tm[0], tm[1]]


func _on_new_game() -> void:
	current_mode = "save"
	_show_slots_panel("Choose a save slot for your new game:")


func _on_load_pressed() -> void:
	current_mode = "load"
	_show_slots_panel("Choose a save slot to load:")


## Reskins the save-slots panel to match the prop that opened it:
## - "save" (New Game letter) → panel_sheet.png, a blank weathered parchment sheet.
## - "load" (Load ledger)     → panel_book.png, an open crimson leather book.
## Falls back to a flat parchment/crimson stylebox if the art hasn't landed yet.
func _apply_slots_panel_skin(mode: String) -> void:
	var sheet_path := ART_DIR + "panel_sheet.png"
	var book_path := ART_DIR + "panel_book.png"
	var sb: StyleBox

	if mode == "load":
		if ResourceLoader.exists(book_path):
			sb = PixelUI.tex_stylebox(book_path, 24, 28)
		else:
			sb = GameTheme.flat(GameTheme.PARCHMENT, GameTheme.CRIMSON, 18, 2)
	else:
		if ResourceLoader.exists(sheet_path):
			sb = PixelUI.tex_stylebox(sheet_path, 24, 28)
		else:
			sb = GameTheme.flat(GameTheme.PARCHMENT, GameTheme.LEATHER, 18, 2)

	# Stretch the 256×256 source art to the panel's on-screen size.
	if sb is StyleBoxTexture:
		(sb as StyleBoxTexture).content_margin_left = 32
		(sb as StyleBoxTexture).content_margin_right = 32
		(sb as StyleBoxTexture).content_margin_top = 28
		(sb as StyleBoxTexture).content_margin_bottom = 28

	save_slots_panel.add_theme_stylebox_override("panel", sb)


func _show_slots_panel(title: String) -> void:
	_apply_slots_panel_skin(current_mode)

	for child in slots_container.get_children():
		child.queue_free()

	var title_lbl = Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", GameTheme.INK)
	title_lbl.add_theme_color_override("font_outline_color", GameTheme.PARCHMENT)
	title_lbl.add_theme_constant_override("outline_size", 2)
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
	panel.theme_type_variation = "Card"
	UIKit.attach_hover_pop(panel, 1.03)
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
		slot_info.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	else:
		slot_info.text = "Turn %d  |  Gold: %d  |  Soldiers: %d  |  %s" % [
			info.get("turn", 0),
			info.get("gold", 0),
			info.get("soldiers", 0),
			_format_save_timestamp(info.get("timestamp", ""))
		]
	info_vbox.add_child(slot_info)

	# Primary button (New Game / Load)
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

	# Delete button (only if a save exists)
	if not info.get("empty", true):
		var del_btn = Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(80, 40)
		del_btn.add_theme_color_override("font_color", GameTheme.CRIMSON)
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

	GameState.workforce_total = 10
	GameState.workforce_available = 10
	GameState.current_turn = 0
	GameState.combat_difficulty = 1
	GameState.soldiers.clear()
	GameState.owned_items.clear()
	for b in GameState.building_workers:
		GameState.building_workers[b] = 0
	for b in GameState.building_levels:
		var data := GameState.get_building_data(b)
		GameState.building_levels[b] = 1 if (data != null and data.starts_built) else 0
	GameState.max_soldiers = 4
	GameState.workforce_cap = GameState.BASE_WORKFORCE_CAP
	GameState.barracks_city_defense_bonus = 0.0
	GameState.house_recruits_this_turn = 0
	# Fresh game — play the opening cinematic and the first-turn tutorial.
	GameState.intro_seen = false
	GameState.tutorial_seen = false
	GameState._schedule_next_battle(true)

	# Salveaza slot-ul gol ca placeholder
	SaveManager.game_over = false  # fresh run — lift the permadeath save block
	SaveManager.current_slot = slot
	SaveManager.save_game(slot)

	# Play the opening cinematic; it hands off to the hub when done or skipped.
	SceneFader.change_scene("res://scenes/ui/intro_cinematic.tscn")


func _load_game(slot: int) -> void:
	if SaveManager.load_game(slot):
		SceneFader.change_scene("res://scenes/management/hub_screen.tscn")


func _delete_save(slot: int) -> void:
	SaveManager.delete_save(slot)
	_show_slots_panel(
		"Choose a save slot to load:" if current_mode == "load" else "Choose a save slot for your new game:"
	)
	_check_load_available()


func _on_quit() -> void:
	get_tree().quit()
