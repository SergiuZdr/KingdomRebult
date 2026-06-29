# res://scripts/ui/main_menu_backdrop.gd
class_name MainMenuBackdrop
extends Control

## War-table diegetic menu backdrop. The prince's planning table at night:
## a wood table-top, a parchment city map thrown across it at a careless
## angle, and dressing props (sword, ink pot, candle). Purely decorative —
## owns no interactive elements.

const ART_DIR := "res://assets/ui/menu/wartable/"
const W := 1200.0
const H := 720.0

## The rotated parchment map node — exposed so the title text can be parented
## to it and inherit the same −1.5° tilt.
var map_node: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _tex(file: String) -> Texture2D:
	var p := ART_DIR + file
	return (load(p) as Texture2D) if ResourceLoader.exists(p) else null


func _img(tex: Texture2D, pos: Vector2, sz: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = pos
	rect.size = sz
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _build() -> void:
	# 1. NIGHT base — safety fill behind everything.
	var base := ColorRect.new()
	base.color = GameTheme.NIGHT
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	# 2. Table surface — stretched, centered, 60px overscan each side.
	var table_tex := _tex("table_wood.png")
	if table_tex:
		var table_size := Vector2(1320.0, 800.0)
		var table_pos := (Vector2(W, H) - table_size) * 0.5
		var table := _img(table_tex, table_pos, table_size)
		add_child(table)

	# 3. Parchment city map — ×2.4 scale, centered at (600, 368), rotated −1.5°.
	var map_tex := _tex("map_parchment.png")
	if map_tex:
		var map_size := Vector2(map_tex.get_width(), map_tex.get_height()) * 3.4
		var map := _img(map_tex, -map_size * 0.5, map_size)
		map.position = Vector2.ZERO
		# Wrap in a Control positioned at the map's center so rotation pivots
		# correctly and the title can be parented at local (0,0).
		var map_anchor := Control.new()
		map_anchor.position = Vector2(600.0, 320.0)
		map_anchor.size = Vector2.ZERO
		map_anchor.rotation_degrees = -1.5
		map_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_anchor.add_child(map)
		add_child(map_anchor)
		map_node = map_anchor

	# 4. Title text, parented to the map so it shares the −1.5° tilt.
	if map_node:
		_add_title(map_node)

	# 5. Dressing props — non-interactive, parented to root (table layer).
	# Sword (prop_dagger.png, 160×100) — oversized table-prop scale (×3.5 ≈
	# 560×350) running off the LEFT screen edge: hilt off-screen, blade lying
	# across the table's left side. Centered well above the New Game letter's
	# hover zone (~(160,520)) so it never overlaps it.
	var dagger_tex := _tex("prop_dagger.png")
	if dagger_tex:
		var dagger_size := Vector2(dagger_tex.get_width(), dagger_tex.get_height()) * 5.5
		var dagger := _img(dagger_tex, Vector2(210, 110.0) - dagger_size * 0.5, dagger_size)
		dagger.pivot_offset = dagger_size * 0.5
		dagger.rotation_degrees = -12.0
		add_child(dagger)

	var inkpot_tex := _tex("prop_inkpot.png")
	if inkpot_tex:
		var inkpot_size := Vector2(inkpot_tex.get_width(), inkpot_tex.get_height()) * 1.2
		var inkpot := _img(inkpot_tex, Vector2(1030.0, 290.0) - inkpot_size * 0.5, inkpot_size)
		add_child(inkpot)


## Title text rendered over the map's top parchment band, parented to
## `map_node` so it shares the map's −1.5° rotation. Coordinates are local
## to the map anchor, which sits at world (600, 368).
func _add_title(parent: Control) -> void:
	var heading_font: Font = load(GameTheme.FONT_HEADING)
	var body_font: Font = load(GameTheme.FONT_BODY)

	# Title: large, INK on a strong PARCHMENT outline so it pops against both
	# the parchment map and any darker map detail behind it.
	var title_lbl := Label.new()
	title_lbl.text = "KINGDOM REBUILT"
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if heading_font:
		title_lbl.add_theme_font_override("font", heading_font)
	title_lbl.add_theme_font_size_override("font_size", 54)
	title_lbl.add_theme_color_override("font_color", GameTheme.INK)
	title_lbl.add_theme_color_override("font_outline_color", GameTheme.PARCHMENT)
	title_lbl.add_theme_constant_override("outline_size", 8)
	# Centered at map-local (0, -200): map center (600,368) - 168 = 200 above center.
	title_lbl.size = Vector2(560.0, 70.0)
	title_lbl.position = Vector2(-280.0, -235.0)
	parent.add_child(title_lbl)

	# Subtitle: same INK-on-PARCHMENT treatment, smaller outline.
	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "The prince returns to a city of ash."
	subtitle_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if body_font:
		subtitle_lbl.add_theme_font_override("font", body_font)
	subtitle_lbl.add_theme_font_size_override("font_size", 15)
	subtitle_lbl.add_theme_color_override("font_color", GameTheme.INK)
	subtitle_lbl.add_theme_color_override("font_outline_color", GameTheme.PARCHMENT)
	subtitle_lbl.add_theme_constant_override("outline_size", 4)
	# Centered at map-local (0, -162): map center (600,368) - 206 = 162 above center.
	subtitle_lbl.size = Vector2(520.0, 30.0)
	subtitle_lbl.position = Vector2(-260.0, -177.0)
	parent.add_child(subtitle_lbl)

	# Stash references so the menu can fade the title in last during entrance.
	set_meta("title_label", title_lbl)
	set_meta("subtitle_label", subtitle_lbl)


## Returns the title + subtitle labels for the entrance animation, or an
## empty array if the title hasn't been built yet.
func get_title_labels() -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	if has_meta("title_label"):
		out.append(get_meta("title_label"))
	if has_meta("subtitle_label"):
		out.append(get_meta("subtitle_label"))
	return out
