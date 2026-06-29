# res://scripts/autoload/PauseMenu.gd
# Autoload — ESC-triggered pause overlay with Resume / Settings / Main Menu.
# Only opens on screens in the "city_view" group (hub + dungeon map) while no
# combat is active; the intro cinematic and codex screen already consume ESC
# in their own _input/_unhandled_input via set_input_as_handled().
extends CanvasLayer

const DIM_ALPHA := 0.6

var _root: Control
var _dim: ColorRect
var _card: PanelContainer
var _main_view: VBoxContainer
var _settings_view: VBoxContainer
var _is_open: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = GameTheme.get_theme()
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(GameTheme.NIGHT.r, GameTheme.NIGHT.g, GameTheme.NIGHT.b, DIM_ALPHA)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_card = PanelContainer.new()
	_card.theme_type_variation = "Frame"
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.position = Vector2(-160, -130)
	_card.custom_minimum_size = Vector2(320, 260)
	_root.add_child(_card)

	_build_main_view()
	_build_settings_view()

	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_open:
		close()
		get_viewport().set_input_as_handled()
		return
	if not _can_open():
		return
	open()
	get_viewport().set_input_as_handled()


## Only the hub and dungeon map (both in the "city_view" group) may pause, and
## only outside of active combat and modal dialogs (recap, building popups,
## city-defense choice, etc — anything that sets GameState.menu_open).
func _can_open() -> bool:
	var scene := get_tree().current_scene
	if scene == null or not scene.is_in_group("city_view"):
		return false
	if CombatState.active:
		return false
	if GameState.menu_open:
		return false
	return true


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_show_main_view()
	_root.visible = true
	get_tree().paused = true


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_root.visible = false
	get_tree().paused = false


# ---------------------------------------------------------------------------
# Main view: Resume / Settings / Main Menu
# ---------------------------------------------------------------------------
func _build_main_view() -> void:
	_main_view = VBoxContainer.new()
	_main_view.add_theme_constant_override("separation", 12)
	_card.add_child(_main_view)

	var title := UIKit.title("Paused")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_view.add_child(title)
	_main_view.add_child(HSeparator.new())

	var btn_resume := Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(0, 44)
	btn_resume.pressed.connect(close)
	_main_view.add_child(btn_resume)

	var btn_settings := Button.new()
	btn_settings.text = "Settings"
	btn_settings.custom_minimum_size = Vector2(0, 44)
	btn_settings.pressed.connect(_show_settings_view)
	_main_view.add_child(btn_settings)

	var btn_main_menu := Button.new()
	btn_main_menu.text = "Main Menu"
	btn_main_menu.custom_minimum_size = Vector2(0, 44)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	_main_view.add_child(btn_main_menu)


# ---------------------------------------------------------------------------
# Settings view: Music + SFX volume sliders
# ---------------------------------------------------------------------------
func _build_settings_view() -> void:
	_settings_view = VBoxContainer.new()
	_settings_view.add_theme_constant_override("separation", 12)
	_settings_view.visible = false
	_card.add_child(_settings_view)

	var title := UIKit.title("Settings")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_view.add_child(title)
	_settings_view.add_child(HSeparator.new())

	_settings_view.add_child(_build_volume_row("Music", Settings.music_volume, _on_music_changed))
	_settings_view.add_child(_build_volume_row("SFX", Settings.sfx_volume, _on_sfx_changed))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_settings_view.add_child(spacer)

	var btn_back := Button.new()
	btn_back.text = "Back"
	btn_back.custom_minimum_size = Vector2(0, 44)
	btn_back.pressed.connect(_on_settings_back_pressed)
	_settings_view.add_child(btn_back)


func _build_volume_row(label_text: String, initial: float, on_change: Callable) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = label_text
	vbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(on_change)
	vbox.add_child(slider)

	return vbox


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value)


func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx_volume(value)


func _on_settings_back_pressed() -> void:
	Settings.save_settings()
	_show_main_view()


# ---------------------------------------------------------------------------
# View switching
# ---------------------------------------------------------------------------
func _show_main_view() -> void:
	_main_view.visible = true
	_settings_view.visible = false


func _show_settings_view() -> void:
	_main_view.visible = false
	_settings_view.visible = true


# ---------------------------------------------------------------------------
# Main Menu: autosave (if a slot is active), close, fade to main menu
# ---------------------------------------------------------------------------
func _on_main_menu_pressed() -> void:
	if SaveManager.current_slot > 0:
		SaveManager.save_game(SaveManager.current_slot)
	GameState.in_city_view = false
	close()
	SceneFader.change_scene("res://scenes/ui/main_menu.tscn")
