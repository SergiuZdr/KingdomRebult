# res://scripts/ui/dungeon_theme.gd
class_name DungeonTheme

## Builds and caches a Godot Theme at runtime from the dungeon art assets.
## Using a runtime-built Theme avoids uid/import fragility from hand-authored .tres files.
## Call DungeonTheme.get_theme() and assign it to the root Control of any dungeon scene.

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = _build()
	return _theme

## One button-state stylebox cut from the 4-cell pack sheet (cell index 0..3).
static func _button_sb(sheet: Texture2D, idx: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = sheet
	if sheet != null:
		sb.region_rect = Rect2(idx * 64, 0, 64, 64)
	sb.texture_margin_left   = 12
	sb.texture_margin_right  = 12
	sb.texture_margin_top    = 12
	sb.texture_margin_bottom = 12
	sb.content_margin_left   = 14
	sb.content_margin_right  = 14
	sb.content_margin_top    = 8
	sb.content_margin_bottom = 8
	return sb

static func _build() -> Theme:
	var t := Theme.new()

	# ── Default font ────────────────────────────────────────────────────────────
	var body_font: Font = load("res://assets/ui/dungeon/fonts/body.ttf")
	if body_font:
		t.default_font      = body_font
		t.default_font_size = 16

	# ── PanelContainer (main overlay frame — window.png 128×128) ──────────────
	# content margin 32 so child text/buttons sit INSIDE the ornate ~30px border.
	t.set_stylebox("panel", "PanelContainer",
		PixelUI.tex_stylebox("res://assets/ui/dungeon/frames/window.png", 30, 32))

	# ── "Card" type variation — smaller panel.png 64×64, margin 16 ─────────────
	# Soldier cards and sub-panels use theme_type_variation = "Card".
	t.add_type("Card")
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card",
		PixelUI.tex_stylebox("res://assets/ui/dungeon/frames/panel.png", 16, 10))

	# ── Button styleboxes — downloaded-pack 4-state sheet (256×64, 4×64px cells:
	#    normal / hover / pressed / disabled) ────────────────────────────────────
	var _btn_sheet := PixelUI.tex("res://assets/ui/dungeon/buttons/pack_sheet.png")
	var _sb_normal   := _button_sb(_btn_sheet, 0)
	var _sb_hover    := _button_sb(_btn_sheet, 1)
	var _sb_pressed  := _button_sb(_btn_sheet, 2)
	var _sb_disabled := _button_sb(_btn_sheet, 3)

	# Focus outline: thin gold flat border, no fill
	var _sb_focus := StyleBoxFlat.new()
	_sb_focus.bg_color     = Color(0, 0, 0, 0)
	_sb_focus.border_color = UIPalette.GOLD
	_sb_focus.border_width_left   = 1
	_sb_focus.border_width_right  = 1
	_sb_focus.border_width_top    = 1
	_sb_focus.border_width_bottom = 1

	t.set_stylebox("normal",   "Button", _sb_normal)
	t.set_stylebox("hover",    "Button", _sb_hover)
	t.set_stylebox("pressed",  "Button", _sb_pressed)
	t.set_stylebox("disabled", "Button", _sb_disabled)
	t.set_stylebox("focus",    "Button", _sb_focus)

	# Button font colours
	if body_font:
		t.set_font("font", "Button", body_font)
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color",          "Button", UIPalette.PARCHMENT)
	t.set_color("font_hover_color",    "Button", UIPalette.GOLD_HI)
	t.set_color("font_pressed_color",  "Button", UIPalette.GOLD)
	t.set_color("font_disabled_color", "Button", UIPalette.MUTED)
	t.set_color("font_focus_color",    "Button", UIPalette.PARCHMENT)

	# ── Label defaults ──────────────────────────────────────────────────────────
	t.set_color("font_color", "Label", UIPalette.PARCHMENT)
	t.set_font_size("font_size", "Label", 16)

	# ── HSeparator ──────────────────────────────────────────────────────────────
	var _sep_style := StyleBoxLine.new()
	_sep_style.color     = Color(UIPalette.GOLD.r, UIPalette.GOLD.g, UIPalette.GOLD.b, 0.30)
	_sep_style.thickness = 2
	t.set_stylebox("separator", "HSeparator", _sep_style)

	# ── ProgressBar ─────────────────────────────────────────────────────────────
	# Background: dark groove with a light border
	var _pb_bg := StyleBoxFlat.new()
	_pb_bg.bg_color          = UIPalette.STONE_DARKEST
	_pb_bg.border_color      = UIPalette.STONE_LIGHT
	_pb_bg.border_width_left   = 1
	_pb_bg.border_width_right  = 1
	_pb_bg.border_width_top    = 1
	_pb_bg.border_width_bottom = 1
	_pb_bg.corner_radius_top_left     = 3
	_pb_bg.corner_radius_top_right    = 3
	_pb_bg.corner_radius_bottom_left  = 3
	_pb_bg.corner_radius_bottom_right = 3

	# Fill: near-white so code can tint by HP% via .modulate
	var _pb_fill := StyleBoxFlat.new()
	_pb_fill.bg_color = Color(0.88, 0.92, 0.88, 1.0)
	_pb_fill.corner_radius_top_left     = 3
	_pb_fill.corner_radius_top_right    = 3
	_pb_fill.corner_radius_bottom_left  = 3
	_pb_fill.corner_radius_bottom_right = 3

	t.set_stylebox("background", "ProgressBar", _pb_bg)
	t.set_stylebox("fill",       "ProgressBar", _pb_fill)

	return t
