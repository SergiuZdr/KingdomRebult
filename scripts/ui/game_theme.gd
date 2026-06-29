# res://scripts/ui/game_theme.gd
class_name GameTheme

## "War-Camp Parchment" — the visual identity for every NON-dungeon screen.
## The prince runs the reconstruction from a field command tent: parchment sheets
## pinned with iron tacks, red wax seals, faded crimson banner headers, ink-brown
## text, on dark backdrops so the parchment pops. Distinct from the dungeon's
## stone-and-gold look (which keeps its own DungeonTheme + UIPalette).
##
## Colours live HERE (referenced as GameTheme.INK, GameTheme.CRIMSON, ...) so there
## is one honest home for the parchment palette; ui_palette.gd is the dungeon's only.
##
## Authored chrome sprites (see docs/ui_art_prompts.md) are loaded from
## res://assets/ui/city/ when present; until then every slot falls back to a flat
## parchment StyleBox, so the new look is coherent immediately and each sprite
## upgrades it on drop-in with no code change.

# ── Palette ───────────────────────────────────────────────────────────────────
const PARCHMENT := Color("#d8c89e")  # main panel face
const VELLUM    := Color("#cabf94")  # card / sub-panel face
const PARCH_SHADE := Color("#b4a578") # bar troughs / pressed parchment
const INK       := Color("#2e2519")  # primary text
const INK_SOFT  := Color("#5a4a36")  # muted text
const CRIMSON   := Color("#8b2c2c")  # banner headers, key accent, hover
const WAX       := Color("#a83232")  # wax seals / danger fill
const IRON      := Color("#5c5a52")  # tacks / borders / straps
const IRON_HI   := Color("#8a857a")  # iron highlight
const LEATHER   := Color("#6b4e2e")  # straps, troughs, warm emphasis
const NIGHT     := Color("#17151c")  # dark backdrop behind parchment
const FADED_BLUE := Color("#4a6b6b") # info accent
const MOSS      := Color("#5d6b3f")  # muted gains

# ── Asset wiring ──────────────────────────────────────────────────────────────
const CITY_DIR := "res://assets/ui/city/"
# button0..3 now put the wax seal in a CORNER (9-slice-safe), so they're live.
const USE_CITY_BUTTONS := true
# panel.png / card.png v2 have CLEAN centers now (ornament only in the corners), so the
# tacked frames are readable — turned on.
const USE_CITY_PANELS := true
const FONT_BODY    := "res://assets/ui/dungeon/fonts/body.ttf"
const FONT_HEADING := "res://assets/ui/dungeon/fonts/heading.ttf"

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = _build()
	return _theme

## True if an authored chrome sprite exists for this filename.
static func _has(file: String) -> bool:
	return ResourceLoader.exists(CITY_DIR + file)

## Flat parchment-style StyleBox (the fallback look — sharp corners, 1px border).
static func flat(bg: Color, border: Color, pad: int = 8, border_px: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_px)
	sb.content_margin_left = pad + 2
	sb.content_margin_right = pad + 2
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb

## 9-slice frame from an authored sprite, or the flat fallback if it's not there yet.
static func _frame(file: String, margin: int, content: int, fb_bg: Color, fb_border: Color) -> StyleBox:
	if _has(file):
		return PixelUI.tex_stylebox(CITY_DIR + file, margin, content)
	return flat(fb_bg, fb_border, content)

## One button-state stylebox cut from an authored 4-cell sheet (any even width).
static func _btn_cell(sheet: Texture2D, idx: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = sheet
	var cw: int = int(sheet.get_width() / 4.0)
	var ch: int = sheet.get_height()
	sb.region_rect = Rect2(idx * cw, 0, cw, ch)
	var m: int = max(4, int(min(cw, ch) * 0.28))
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

## A button-state stylebox from a single full-image state file (button0..3.png).
## NOTE: a centered ornament (e.g. a top-centre wax seal) will stretch on wide buttons —
## the corner zone (margin) stays put, the middle stretches. Keep seals in a corner.
## mr_over/mb_over: widen the right/bottom texture margins so a bottom-right wax
## seal sits entirely inside the fixed corner zone and never deforms.
static func _btn_tex(file: String, mr_over: int = -1, mb_over: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PixelUI.tex(CITY_DIR + file)
	# corner zone scales with the source so 64×32 and 64×64 buttons both slice cleanly.
	var m := 12
	if sb.texture != null:
		m = clampi(int(min(sb.texture.get_width(), sb.texture.get_height()) * 0.30), 8, 16)
	sb.texture_margin_left = m
	sb.texture_margin_right = m if mr_over < 0 else mr_over
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m if mb_over < 0 else mb_over
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

## A texture stylebox with explicit (possibly asymmetric) 9-slice margins.
static func _tex_sb(file: String, ml: int, mr: int, mt: int, mb: int, content: int = 0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PixelUI.tex(CITY_DIR + file)
	sb.texture_margin_left = ml
	sb.texture_margin_right = mr
	sb.texture_margin_top = mt
	sb.texture_margin_bottom = mb
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content
	sb.content_margin_bottom = content
	return sb

static func _build() -> Theme:
	var t := Theme.new()

	# Fonts (pixel fonts reused; docs/ui_art_prompts.md suggests an inky alternative).
	var body_font: Font = load(FONT_BODY)
	if body_font:
		t.default_font = body_font
		t.default_font_size = 16
	var heading_font: Font = load(FONT_HEADING)
	if heading_font == null:
		heading_font = body_font

	# ── Panels ────────────────────────────────────────────────────────────────
	# Clean flat parchment by default (readable; no map grid behind text). When
	# USE_CITY_PANELS is on, the tacked panel.png frame is used instead.
	var panel_sb: StyleBox = flat(PARCHMENT, IRON, 18)
	if USE_CITY_PANELS and _has("panel.png"):
		panel_sb = _frame("panel.png", 28, 18, PARCHMENT, IRON)
	t.set_stylebox("panel", "PanelContainer", panel_sb)
	t.set_stylebox("panel", "Panel", panel_sb)

	t.add_type("Card")
	t.set_type_variation("Card", "PanelContainer")
	var card_sb: StyleBox = flat(VELLUM, IRON, 12)
	if USE_CITY_PANELS and _has("card.png"):
		card_sb = _frame("card.png", 16, 12, VELLUM, IRON)
	t.set_stylebox("panel", "Card", card_sb)

	# "Frame" — the LARGE hub sheet. Deliberately a FLAT parchment fill, NOT panel.png:
	# stretching a 128px tacked sheet across ~1000px smears its grid/cracks. Flat reads
	# clean at any size; small popups still get the tacked panel.png above.
	t.add_type("Frame")
	t.set_type_variation("Frame", "PanelContainer")
	t.set_stylebox("panel", "Frame", flat(PARCHMENT, IRON, 14))

	# "Sunken" — resource/threat/turn STRIPS that hold ink text → always LIGHT parchment.
	# (bar_trough.png is dark and goes on the ProgressBar, not here.)
	t.add_type("Sunken")
	t.set_type_variation("Sunken", "PanelContainer")
	t.set_stylebox("panel", "Sunken", flat(PARCH_SHADE, LEATHER, 6))

	# ── Buttons — DEFAULT is the parchment button00-03.png set (seals removed,
	# clean 9-slice rectangles), falling back to a flat parchment tab if the
	# art is missing.
	if USE_CITY_BUTTONS and _has("buttons/button00.png"):
		t.set_stylebox("normal",   "Button", _btn_tex("buttons/button00.png"))
		t.set_stylebox("hover",    "Button", _btn_tex("buttons/button01.png"))
		t.set_stylebox("pressed",  "Button", _btn_tex("buttons/button02.png"))
		t.set_stylebox("disabled", "Button", _btn_tex("buttons/button03.png"))
	else:
		t.set_stylebox("normal",   "Button", flat(PARCHMENT, IRON, 8))
		t.set_stylebox("hover",    "Button", flat(PARCHMENT.lightened(0.06), CRIMSON, 8))
		t.set_stylebox("pressed",  "Button", flat(PARCH_SHADE, IRON, 8))
		t.set_stylebox("disabled", "Button", flat(PARCH_SHADE.darkened(0.08), INK_SOFT, 8))

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = CRIMSON
	focus.set_border_width_all(1)
	t.set_stylebox("focus", "Button", focus)

	if body_font:
		t.set_font("font", "Button", body_font)
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color",          "Button", INK)
	t.set_color("font_hover_color",    "Button", CRIMSON)
	t.set_color("font_pressed_color",  "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_SOFT)
	t.set_color("font_focus_color",    "Button", INK)

	# ── Labels ──────────────────────────────────────────────────────────────────
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 16)

	t.add_type("Title")
	t.set_type_variation("Title", "Label")
	if heading_font:
		t.set_font("font", "Title", heading_font)
	t.set_font_size("font_size", "Title", 30)
	t.set_color("font_color", "Title", CRIMSON)

	t.add_type("Heading")
	t.set_type_variation("Heading", "Label")
	if heading_font:
		t.set_font("font", "Heading", heading_font)
	t.set_font_size("font_size", "Heading", 19)
	t.set_color("font_color", "Heading", CRIMSON)

	t.add_type("Subtitle")
	t.set_type_variation("Subtitle", "Label")
	t.set_font_size("font_size", "Subtitle", 13)
	t.set_color("font_color", "Subtitle", INK_SOFT)

	# ── Separators — separator.png (stitched seam, knots in the ends) or a line ──
	if _has("separator.png"):
		t.set_stylebox("separator", "HSeparator", _tex_sb("separator.png", 16, 16, 0, 0, 0))
	else:
		var sep := StyleBoxLine.new()
		sep.color = Color(LEATHER.r, LEATHER.g, LEATHER.b, 0.7)
		sep.thickness = 2
		t.set_stylebox("separator", "HSeparator", sep)
	var vsep := StyleBoxLine.new()
	vsep.color = Color(LEATHER.r, LEATHER.g, LEATHER.b, 0.7)
	vsep.thickness = 2
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)

	# ── ProgressBar — dark bar_trough.png (caps in the ends) + code-tinted fill ──
	var pb_bg: StyleBox = flat(PARCH_SHADE, LEATHER, 0)
	if _has("bar_trough.png"):
		var tt := PixelUI.tex(CITY_DIR + "bar_trough.png")
		if tt != null and float(tt.get_width()) / float(max(1, tt.get_height())) >= 4.0:
			pb_bg = _tex_sb("bar_trough.png", 40, 40, 10, 10, 0)   # 384×96: iron end-caps
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = WAX
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", INK)

	# ── Scrollbar grabber — scroll_grab.png (leather strap) or flat ──────────────
	var grab: StyleBox = flat(LEATHER, LEATHER, 0)
	if _has("scroll_grab.png"):
		grab = _tex_sb("scroll_grab.png", 6, 6, 12, 12, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)

	# ── "Banner" — crimson cloth strip behind section headers (header_banner.png) ─
	t.add_type("Banner")
	t.set_type_variation("Banner", "PanelContainer")
	if _has("header_banner.png"):
		# 128×40 art on a ~30px-tall strip: margins must stay well under the
		# rendered height or the torn edges fold over themselves and smear.
		t.set_stylebox("panel", "Banner", _tex_sb("header_banner.png", 20, 20, 12, 12, 12))
	else:
		t.set_stylebox("panel", "Banner", flat(CRIMSON, LEATHER, 8))

	# ── "Close" — wax-seal X icon button (close.png), set text="" on the button ──
	t.add_type("Close")
	t.set_type_variation("Close", "Button")
	if _has("close.png"):
		var cls := _tex_sb("close.png", 0, 0, 0, 0, 0)   # whole seal, scales to the button rect
		t.set_stylebox("normal", "Close", cls)
		t.set_stylebox("hover", "Close", cls)
		t.set_stylebox("pressed", "Close", cls)
		t.set_stylebox("disabled", "Close", cls)

	# ── "Tab" — sealed parchment (style 1) for the prominent sidebar tabs ────────
	t.add_type("Tab")
	t.set_type_variation("Tab", "Button")
	if _has("buttons/button10.png"):
		# Wax seal occupies (54,22)-(63,31) of the 64×32 art → right/bottom
		# margins of 12 keep it whole inside the fixed corner zone.
		t.set_stylebox("normal",   "Tab", _btn_tex("buttons/button10.png", 12, 12))
		t.set_stylebox("hover",    "Tab", _btn_tex("buttons/button11.png", 12, 12))
		t.set_stylebox("pressed",  "Tab", _btn_tex("buttons/button12.png", 12, 12))
		t.set_stylebox("disabled", "Tab", _btn_tex("buttons/button13.png", 12, 12))

	# ── "Primary" — key actions (End Turn, Fight): crimson so they stand apart ───
	t.add_type("Primary")
	t.set_type_variation("Primary", "Button")
	if _has("buttons/button20.png"):
		# STYLE 2 (buttons/button2x, dark red) = the prominent primary action.
		# Wax seal occupies (48,16)-(62,29) of the 64×32 art → right/bottom
		# margins of 16 keep it whole inside the fixed corner zone.
		t.set_stylebox("normal",   "Primary", _btn_tex("buttons/button20.png", 16, 16))
		t.set_stylebox("hover",    "Primary", _btn_tex("buttons/button21.png", 16, 16))
		t.set_stylebox("pressed",  "Primary", _btn_tex("buttons/button22.png", 16, 16))
		t.set_stylebox("disabled", "Primary", _btn_tex("buttons/button23.png", 16, 16))
	elif _has("button_primary0.png"):
		t.set_stylebox("normal",   "Primary", _btn_tex("button_primary0.png"))
		t.set_stylebox("hover",    "Primary", _btn_tex("button_primary1.png"))
		t.set_stylebox("pressed",  "Primary", _btn_tex("button_primary2.png"))
		t.set_stylebox("disabled", "Primary", _btn_tex("button_primary3.png"))
	else:
		t.set_stylebox("normal",   "Primary", flat(CRIMSON, LEATHER, 8))
		t.set_stylebox("hover",    "Primary", flat(CRIMSON.lightened(0.10), PARCHMENT, 8))
		t.set_stylebox("pressed",  "Primary", flat(CRIMSON.darkened(0.12), LEATHER, 8))
		t.set_stylebox("disabled", "Primary", flat(CRIMSON.darkened(0.30), INK_SOFT, 8))
	t.set_color("font_color",          "Primary", PARCHMENT)
	t.set_color("font_hover_color",    "Primary", Color(1, 1, 1))
	t.set_color("font_pressed_color",  "Primary", PARCHMENT)
	t.set_color("font_disabled_color", "Primary", INK_SOFT)

	# ── LineEdit ─────────────────────────────────────────────────────────────────
	t.set_stylebox("normal", "LineEdit", flat(VELLUM, IRON, 6))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT)

	# ── "Ghost" — crimson button30-33.png variation (seal-free 9-slice), used
	# for wide action buttons (e.g. diplomacy) where the parchment Button would
	# blend into the panel behind it. Falls back to a flat crimson tab.
	t.add_type("Ghost")
	t.set_type_variation("Ghost", "Button")
	if USE_CITY_BUTTONS and _has("buttons/button30.png"):
		t.set_stylebox("normal",   "Ghost", _btn_tex("buttons/button30.png"))
		t.set_stylebox("hover",    "Ghost", _btn_tex("buttons/button31.png"))
		t.set_stylebox("pressed",  "Ghost", _btn_tex("buttons/button32.png"))
		t.set_stylebox("disabled", "Ghost", _btn_tex("buttons/button33.png"))
		# Dark-crimson 9-slice needs light text, same as "Primary" on button20.
		t.set_color("font_color",          "Ghost", PARCHMENT)
		t.set_color("font_hover_color",    "Ghost", PARCHMENT.lightened(0.15))
		t.set_color("font_pressed_color",  "Ghost", PARCHMENT.darkened(0.10))
		t.set_color("font_disabled_color", "Ghost", IRON_HI)
	else:
		t.set_stylebox("normal",   "Ghost", flat(PARCHMENT, IRON, 8))
		t.set_stylebox("hover",    "Ghost", flat(PARCHMENT.lightened(0.06), CRIMSON, 8))
		t.set_stylebox("pressed",  "Ghost", flat(PARCH_SHADE, IRON, 8))
		t.set_stylebox("disabled", "Ghost", flat(PARCH_SHADE.darkened(0.08), INK_SOFT, 8))
		# Light parchment fallback keeps the original dark-ink text.
		t.set_color("font_color",          "Ghost", INK)
		t.set_color("font_hover_color",    "Ghost", CRIMSON)
		t.set_color("font_pressed_color",  "Ghost", INK)
		t.set_color("font_disabled_color", "Ghost", INK_SOFT)
	if body_font:
		t.set_font("font", "Ghost", body_font)
	t.set_font_size("font_size", "Ghost", 16)

	# ── TabContainer — fixes the gray default overlay on the building popup.
	# TabBar items do NOT cascade into TabContainer; both must be styled.
	t.set_stylebox("panel", "TabContainer", flat(VELLUM, IRON, 10))
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())
	# Selected tab merges visually into the panel below it.
	t.set_stylebox("tab_selected", "TabContainer", flat(VELLUM, IRON, 10))
	t.set_stylebox("tab_unselected", "TabContainer", flat(PARCH_SHADE, IRON, 10))
	t.set_stylebox("tab_hovered", "TabContainer", flat(VELLUM.lightened(0.06), CRIMSON, 10))
	t.set_stylebox("tab_disabled", "TabContainer", flat(PARCH_SHADE.darkened(0.08), INK_SOFT, 10))
	if body_font:
		t.set_font("font", "TabContainer", body_font)
	t.set_font_size("font_size", "TabContainer", 15)
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", INK_SOFT)
	t.set_color("font_hovered_color", "TabContainer", CRIMSON)
	t.set_color("font_disabled_color", "TabContainer", INK_SOFT)

	# ── HSlider — leather trough + crimson grabber-area, code-built grabber icon ─
	t.set_stylebox("slider", "HSlider", flat(PARCH_SHADE, LEATHER, 0))
	t.set_stylebox("grabber_area", "HSlider", flat(CRIMSON, LEATHER, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(CRIMSON.lightened(0.08), LEATHER, 0))
	var grabber_icon := _grabber_icon(LEATHER, IRON)
	var grabber_icon_hi := _grabber_icon(LEATHER.lightened(0.15), CRIMSON)
	t.set_icon("grabber", "HSlider", grabber_icon)
	t.set_icon("grabber_highlight", "HSlider", grabber_icon_hi)
	t.set_icon("grabber_disabled", "HSlider", grabber_icon)

	# ── CheckBox — code-built 16×16 checked/unchecked icons (used by auto-battle) ─
	var check_unchecked := _checkbox_icon(false)
	var check_checked := _checkbox_icon(true)
	t.set_icon("unchecked", "CheckBox", check_unchecked)
	t.set_icon("checked", "CheckBox", check_checked)
	t.set_icon("unchecked_disabled", "CheckBox", check_unchecked)
	t.set_icon("checked_disabled", "CheckBox", check_checked)
	t.set_icon("radio_unchecked", "CheckBox", check_unchecked)
	t.set_icon("radio_checked", "CheckBox", check_checked)
	t.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "CheckBox", StyleBoxEmpty.new())
	if body_font:
		t.set_font("font", "CheckBox", body_font)
	t.set_font_size("font_size", "CheckBox", 15)
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", CRIMSON)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_disabled_color", "CheckBox", INK_SOFT)

	# ---- Tooltips: fully opaque parchment so text never blends into what's
	# behind it (Godot's default tooltip panel is semi-transparent).
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = PARCHMENT
	tip_sb.border_color = IRON
	tip_sb.set_border_width_all(2)
	tip_sb.content_margin_left = 10
	tip_sb.content_margin_right = 10
	tip_sb.content_margin_top = 6
	tip_sb.content_margin_bottom = 6
	t.set_stylebox("panel", "TooltipPanel", tip_sb)
	if body_font:
		t.set_font("font", "TooltipLabel", body_font)
	t.set_font_size("font_size", "TooltipLabel", 14)
	t.set_color("font_color", "TooltipLabel", INK)

	return t

## A small (14×14) code-built ImageTexture for the HSlider grabber — a leather
## square with an iron/crimson border. Avoids needing authored grabber art.
static func _grabber_icon(fill: Color, border: Color) -> ImageTexture:
	const SZ := 14
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	for y in SZ:
		for x in SZ:
			var on_border: bool = x == 0 or y == 0 or x == SZ - 1 or y == SZ - 1
			img.set_pixel(x, y, border if on_border else fill)
	return ImageTexture.create_from_image(img)

## A code-built 16×16 checkbox icon — empty parchment box, or filled with a
## crimson check-mark when `checked`.
static func _checkbox_icon(checked: bool) -> ImageTexture:
	const SZ := 16
	var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Box outline (iron) over a parchment fill.
	for y in SZ:
		for x in SZ:
			var on_border: bool = x == 0 or y == 0 or x == SZ - 1 or y == SZ - 1
			if on_border:
				img.set_pixel(x, y, IRON)
			else:
				img.set_pixel(x, y, VELLUM)
	if checked:
		# Simple crimson check-mark (two strokes forming a "v").
		var pts := [
			Vector2i(3, 8), Vector2i(4, 9), Vector2i(5, 10), Vector2i(6, 11),
			Vector2i(7, 10), Vector2i(8, 8), Vector2i(9, 6), Vector2i(10, 4),
			Vector2i(11, 3),
			Vector2i(4, 8), Vector2i(5, 9), Vector2i(6, 10),
			Vector2i(7, 9), Vector2i(8, 7), Vector2i(9, 5), Vector2i(10, 3),
		]
		for p in pts:
			if p.x >= 0 and p.x < SZ and p.y >= 0 and p.y < SZ:
				img.set_pixel(p.x, p.y, CRIMSON)
	return ImageTexture.create_from_image(img)
