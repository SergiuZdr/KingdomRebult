# res://scripts/ui/ui_kit.gd
class_name UIKit

## Shared builders + motion helpers for the non-dungeon UI. Keeps every screen
## consistent (icons, headers, cards, deltas) and pixel-art clean. Pairs with
## GameTheme / UIPalette. All textures use the project's NEAREST filter default.

const RES_ICON_DIR := "res://assets/icons/resources/"
const BUILDING_ICON_DIR := "res://assets/buildings/"

# Canonical resource → icon file (only those that have art).
const RES_ICONS := {
	"gold": "gold.png", "wood": "wood.png", "stone": "stone.png",
	"iron": "iron.png", "steel": "steel.png", "food": "food.png",
	"morale": "morale.png",
}

# ── Icons ─────────────────────────────────────────────────────────────────────
static func resource_icon_path(res_name: String) -> String:
	var f: String = RES_ICONS.get(res_name.to_lower(), "")
	return (RES_ICON_DIR + f) if f != "" else ""

## A pixel icon at a fixed display size (keeps aspect, nearest filter).
static func icon(path: String, px: int = 20) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = PixelUI.tex(path)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## Icon + value, e.g. the resource bar: [coin] 500
static func resource_pill(res_name: String, value, px: int = 20) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var p := resource_icon_path(res_name)
	if p != "":
		box.add_child(icon(p, px))
	var lbl := Label.new()
	lbl.text = str(value)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	box.set_meta("value_label", lbl)   # so callers can update without rebuilding
	return box

## Update a pill built above (avoids re-instancing the icon every tick).
static func set_pill_value(pill: HBoxContainer, value) -> void:
	if pill and pill.has_meta("value_label"):
		var lbl: Label = pill.get_meta("value_label")
		if is_instance_valid(lbl):
			lbl.text = str(value)

# ── Text ──────────────────────────────────────────────────────────────────────
static func title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Title"
	return l

static func section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Heading"
	return l

## A section header sitting on a crimson banner cloth ("Banner" panel + light text).
static func banner_header(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Banner"
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.custom_minimum_size = Vector2(0, 36)   # give the frayed cloth room so it doesn't squish
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", GameTheme.PARCHMENT)   # light on crimson cloth
	var hf: Font = load(GameTheme.FONT_HEADING)
	if hf:
		l.add_theme_font_override("font", hf)
	l.add_theme_font_size_override("font_size", 17)
	p.add_child(l)
	return p

static func subtitle(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = "Subtitle"
	return l

## A signed delta, coloured muted-moss (gain) or rust (loss). Zero = muted.
static func delta_label(amount: float, suffix: String = "") -> Label:
	var l := Label.new()
	var n := int(round(amount))
	if n > 0:
		l.text = "+%d%s" % [n, suffix]
		l.add_theme_color_override("font_color", GameTheme.MOSS)
	elif n < 0:
		l.text = "%d%s" % [n, suffix]
		l.add_theme_color_override("font_color", GameTheme.CRIMSON)
	else:
		l.text = "0%s" % suffix
		l.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	return l

# ── Panels ────────────────────────────────────────────────────────────────────
static func themed_card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Card"
	return p

static func frame_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Frame"
	return p

static func sunken_strip() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Sunken"
	return p

# ── Motion ────────────────────────────────────────────────────────────────────
## Fade a control in from transparent. Safe to call in _ready().
static func fade_in(node: CanvasItem, dur: float = 0.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur)

## Subtle slide-up + fade, for panels appearing (recap/victory).
static func pop_in(node: Control, dur: float = 0.20, rise: float = 14.0) -> void:
	if node == null or not is_instance_valid(node):
		return
	var target := node.position
	node.position = target + Vector2(0, rise)
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, dur)
	tw.tween_property(node, "position", target, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Hover "pop" — gently scales a control up on mouse-over. Pixel-clean (scales whole).
static func attach_hover_pop(control: Control, scale_to: float = 1.06) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.mouse_entered.connect(func():
		if not is_instance_valid(control):
			return
		control.pivot_offset = control.size * 0.5
		var tw := control.create_tween()
		tw.tween_property(control, "scale", Vector2(scale_to, scale_to), 0.08).set_trans(Tween.TRANS_QUAD)
	)
	control.mouse_exited.connect(func():
		if not is_instance_valid(control):
			return
		var tw := control.create_tween()
		tw.tween_property(control, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD)
	)
