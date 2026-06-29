# res://scripts/ui/pixel_ui.gd
class_name PixelUI

## Static helpers for building runtime UI assets (textures, styleboxes, gradients).
## Nearest-neighbour filtering comes from the project default; no per-texture override needed.

static var _tex_cache: Dictionary = {}

## Cached texture load — avoids re-loading the same asset multiple times per session.
static func tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = load(path) as Texture2D
	_tex_cache[path] = t
	return t

## Build a 9-slice StyleBoxTexture from a PNG path.
## margin   = px inset from each edge that must NOT stretch (corner art).
## content  = inner content margin in px (padding for child text/icons).
static func tex_stylebox(path: String, margin: int, content: int = 10) -> StyleBoxTexture:
	var sbt := StyleBoxTexture.new()
	sbt.texture = tex(path)
	sbt.texture_margin_left   = margin
	sbt.texture_margin_right  = margin
	sbt.texture_margin_top    = margin
	sbt.texture_margin_bottom = margin
	sbt.content_margin_left   = content
	sbt.content_margin_right  = content
	sbt.content_margin_top    = content
	sbt.content_margin_bottom = content
	sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sbt.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	return sbt

## 9-slice StyleBoxTexture for frame art that has transparent padding around it
## and a textured (non-flat) center. `region` crops to the actual artwork, and
## edges/center TILE instead of stretching, so pixel detail never smears.
static func tex_stylebox_frame(path: String, region: Rect2, margin: int, content: int) -> StyleBoxTexture:
	var sbt := tex_stylebox(path, margin, content)
	sbt.region_rect = region
	sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sbt.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sbt

## The ornate wooden popup window frame, for dialog-sized PanelContainers
## (recap, victory, story/faction events). Returns null when the art is
## missing so callers can keep their flat fallback.
static func popup_frame_stylebox(content: int = 28) -> StyleBoxTexture:
	const FRAME := "res://assets/ui/city/frames/popup_frame.png"
	if not ResourceLoader.exists(FRAME):
		return null
	var sbt := tex_stylebox_frame(FRAME, Rect2(28, 25, 200, 205), 48, content)
	return sbt

## Lighter parchment window frame for big text dialogs (recap, victory/defeat,
## story/faction events). Uses card_frame.png — a slim torn-paper border with a
## clean FLAT parchment center — so body text stays readable, unlike the heavy
## ornate wood popup_frame. Returns null if the art is missing.
static func parchment_window_stylebox(content: int = 22) -> StyleBoxTexture:
	const F := "res://assets/ui/city/frames/card_frame.png"
	if not ResourceLoader.exists(F):
		return null
	return tex_stylebox_frame(F, Rect2(2, 1, 92, 93), 14, content)

## Tinted pixel-art nameplate for card header strips (soldier/faction names).
## Uses the neutral strip_frame.png tinted via modulate when the art exists;
## falls back to the flat colored strip used before.
static func nameplate_stylebox(tint: Color) -> StyleBox:
	const STRIP := "res://assets/ui/city/frames/strip_frame.png"
	if ResourceLoader.exists(STRIP):
		var sbt := tex_stylebox(STRIP, 10, 6)
		sbt.content_margin_left = 8
		sbt.content_margin_right = 8
		sbt.content_margin_top = 4
		sbt.content_margin_bottom = 4
		sbt.modulate_color = tint
		return sbt
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

## Build a radial GradientTexture2D useful for vignettes and glows.
## inner_color is at the center; outer_color is at the edge.
static func radial_gradient(inner_color: Color, outer_color: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, inner_color)
	grad.add_point(1.0, outer_color)

	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to   = Vector2(0.5, 1.0)
	gtex.width  = 256
	gtex.height = 256
	return gtex
