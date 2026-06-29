# res://scripts/ui/tutorial_overlay.gd
# First-turn guided tutorial. Dims the screen, spotlights a target widget, and
# shows a coach-mark with Next / Skip All. Steps are supplied by hub_screen as
# { target: Control (or null for a centred message), title: String, body: String }.
extends CanvasLayer

signal finished

const PAD: float = 6.0
const COACH_WIDTH: float = 540.0

var _steps: Array = []
var _index: int = 0

# Full-rect Control that hosts every visual element. CanvasLayer itself has no
# `theme` property, so GameTheme is applied here and cascades to all children.
var _root: Control

# Four dim panels surround the spotlight hole so the target stays bright.
var _dim_top: ColorRect
var _dim_bottom: ColorRect
var _dim_left: ColorRect
var _dim_right: ColorRect
var _highlight: Panel
var _coach: PanelContainer
var _title_lbl: Label
var _body_lbl: Label
var _step_lbl: Label
var _next_btn: Button


func _ready() -> void:
	layer = 95
	_build_ui()
	visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameTheme.get_theme()
	add_child(_root)

	var dim_color := Color(0, 0, 0, 0.68)
	_dim_top = _make_dim(dim_color)
	_dim_bottom = _make_dim(dim_color)
	_dim_left = _make_dim(dim_color)
	_dim_right = _make_dim(dim_color)

	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)
	hl_style.border_color = GameTheme.CRIMSON
	hl_style.set_border_width_all(3)
	hl_style.set_corner_radius_all(4)
	_highlight.add_theme_stylebox_override("panel", hl_style)
	_root.add_child(_highlight)

	_coach = PanelContainer.new()
	_coach.theme_type_variation = "Card"
	_coach.custom_minimum_size = Vector2(COACH_WIDTH, 0)
	_root.add_child(_coach)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_coach.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
	vbox.add_child(_title_lbl)

	_body_lbl = Label.new()
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.add_theme_font_size_override("font_size", 14)
	_body_lbl.add_theme_color_override("font_color", GameTheme.INK)
	_body_lbl.custom_minimum_size = Vector2(COACH_WIDTH - 32, 0)
	vbox.add_child(_body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_step_lbl = Label.new()
	_step_lbl.add_theme_font_size_override("font_size", 12)
	_step_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	_step_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_row.add_child(_step_lbl)

	var skip_btn := Button.new()
	skip_btn.theme_type_variation = "Ghost"
	skip_btn.text = "Skip All"
	skip_btn.custom_minimum_size = Vector2(90, 36)
	skip_btn.pressed.connect(_finish)
	btn_row.add_child(skip_btn)

	_next_btn = Button.new()
	_next_btn.theme_type_variation = "Primary"
	_next_btn.text = "Next"
	_next_btn.custom_minimum_size = Vector2(110, 36)
	_next_btn.pressed.connect(_advance)
	btn_row.add_child(_next_btn)


func _make_dim(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_STOP   # block clicks to gameplay during the tutorial
	_root.add_child(r)
	return r


# Public entry point.
func start(steps: Array) -> void:
	if steps.is_empty():
		_finish()
		return
	_steps = steps
	_index = 0
	visible = true
	# Wait a frame so target widgets have valid global rects after layout.
	await get_tree().process_frame
	_show_step(0)


func _advance() -> void:
	_index += 1
	if _index >= _steps.size():
		_finish()
	else:
		_show_step(_index)


func _show_step(i: int) -> void:
	var step: Dictionary = _steps[i]
	_title_lbl.text = step.get("title", "")
	_body_lbl.text = step.get("body", "")
	_step_lbl.text = "Step %d / %d" % [i + 1, _steps.size()]
	_next_btn.text = "Finish" if i == _steps.size() - 1 else "Next"

	var screen: Vector2 = get_viewport().get_visible_rect().size
	var target = step.get("target", null)
	var has_target: bool = target is Control and is_instance_valid(target) and target.is_visible_in_tree()

	if has_target:
		var r: Rect2 = (target as Control).get_global_rect().grow(PAD)
		r = r.intersection(Rect2(Vector2.ZERO, screen))
		_set_spotlight(r, screen)
		_highlight.visible = true
		_highlight.global_position = r.position
		_highlight.size = r.size
		_position_coach(r, screen)
	else:
		# No target — dim the whole screen and centre the coach mark.
		_set_spotlight(Rect2(screen.x * 0.5, screen.y * 0.5, 0, 0), screen)
		_highlight.visible = false
		_coach.position = Vector2(
			(screen.x - _coach_width()) * 0.5,
			(screen.y - _coach.size.y) * 0.5
		)


# Lay out the four dim panels around the hole rect.
func _set_spotlight(hole: Rect2, screen: Vector2) -> void:
	_dim_top.position = Vector2.ZERO
	_dim_top.size = Vector2(screen.x, max(0.0, hole.position.y))

	_dim_bottom.position = Vector2(0, hole.end.y)
	_dim_bottom.size = Vector2(screen.x, max(0.0, screen.y - hole.end.y))

	_dim_left.position = Vector2(0, hole.position.y)
	_dim_left.size = Vector2(max(0.0, hole.position.x), hole.size.y)

	_dim_right.position = Vector2(hole.end.x, hole.position.y)
	_dim_right.size = Vector2(max(0.0, screen.x - hole.end.x), hole.size.y)


func _coach_width() -> float:
	return max(COACH_WIDTH, _coach.size.x)


# Place the coach mark on the opposite half of the screen from the target so it
# never covers what it is pointing at.
func _position_coach(target_rect: Rect2, screen: Vector2) -> void:
	var w: float = _coach_width()
	var x: float = clamp(target_rect.get_center().x - w * 0.5, 16.0, screen.x - w - 16.0)
	var y: float
	if target_rect.get_center().y < screen.y * 0.5:
		y = min(target_rect.end.y + 24.0, screen.y - _coach.size.y - 16.0)
	else:
		y = max(target_rect.position.y - _coach.size.y - 24.0, 16.0)
	_coach.position = Vector2(x, y)


func _finish() -> void:
	visible = false
	GameState.tutorial_seen = true
	finished.emit()
