# dungeon_map_scene.gd — full-screen dungeon map, extends CanvasLayer
extends CanvasLayer

signal dungeon_scene_closed

const CELL_SIZE: int = 90
const CELL_PADDING: int = 10

@onready var _map_container: Control = $Root/MapContainer
@onready var _log_container: VBoxContainer = $Root/RightPanel/LogScroll/LogList
@onready var _soldiers_label: Label = $Root/SoldiersLabel
@onready var _recall_btn: Button = $Root/RightPanel/RecallBtn
@onready var _title_label: Label = $Root/Title

# InfoLabel is still in the scene tree but we build a replacement LOCATION label
# in _build_right_panel_backing(); keep the @onready so nothing errors on lookup.
@onready var _info_label: Label = $Root/RightPanel/InfoLabel

var _room_buttons: Dictionary = {}  # Vector2i -> RoomMedallion
var _map_content: Control = null
var _board_has_texture: bool = false

var _in_combat: bool = false
var _waiting_for_input: bool = true
var _fight_result_pending: bool = false
# Set on a party wipe: the dungeon closes only after the player dismisses the
# DEFEAT overlay, so the hub's recap/replay can never appear before it.
var _defeat_teardown_pending: bool = false

# Party HP strip inside the right panel.
var _party_strip_container: VBoxContainer = null

# Party movement token.
var _party_token: Control = null
var _last_token_pos: Vector2i = Vector2i(-999, -999)

# Per-soldier HP snapshot taken just before combat starts, so we can report
# exact damage dealt in the post-fight log block.
var _pre_combat_hp: Dictionary = {}  # soldier_name (String) -> hp_current (int)

# Header torch animation state (two torches, one atlas each).
var _torch_atlases: Array[AtlasTexture] = []
var _torch_anim_t: float = 0.0
var _torch_frame: int = 0
const _TORCH_FPS    := 10.0
const _TORCH_FRAMES := 7
const _TORCH_FW     := 32
const _TORCH_FH     := 48
const _TORCH_SCALE  := 2.0
const _TORCH_PHASE  := [0, 3]  # desync left vs right flame

const _MEDALLION_SCENE := preload("res://scenes/dungeon/components/RoomMedallion.tscn")

## Convert a small positive integer to a Roman numeral string (supports 1–39).
static func _to_roman(n: int) -> String:
	const VALS := [10, 9, 5, 4, 1]
	const SYMS := ["X", "IX", "V", "IV", "I"]
	var result := ""
	var remainder := n
	for i in VALS.size():
		while remainder >= VALS[i]:
			result    += SYMS[i]
			remainder -= VALS[i]
	return result

func _ready() -> void:
	GameState.menu_open = true

	$Root.theme = DungeonTheme.get_theme()

	# Hide legacy nodes replaced by the new panel layout.
	_soldiers_label.visible = false
	_info_label.visible = false

	# ── Title label styling ────────────────────────────────────────────────────
	var heading_font: Font = load("res://assets/ui/dungeon/fonts/heading.ttf")
	if heading_font:
		_title_label.add_theme_font_override("font", heading_font)
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", UIPalette.GOLD)
	# 1-px dark drop shadow so the text pops off the brick wall.
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 1)
	_title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "DEPTH " + _to_roman(DungeonState.dungeon_level)

	_recall_btn.pressed.connect(_on_recall_pressed)

	_build_header_crest()
	_build_right_panel_backing()
	_connect_combat_signals()

	# Replay saved log entries using the new styled log.
	for entry in DungeonState.expedition_log:
		_add_log_entry(entry.text)

	_refresh_party_strip()
	_render_map()
	_refresh_info()
	_add_party_info_button()

# ── Header: [torch] DEPTH IV [torch] + gold underline rule ────────────────────

func _build_header_crest() -> void:
	# The Title Label already lives in Root (full-width, top-aligned).
	# We build an HBoxContainer centered over it that holds the two torches.
	# The Title Label stays where it is for text; we just flank it with torch rects.
	# Approach: build a single HBox spanning the header area, containing
	# [left-torch-spacer | title | right-torch-spacer], then the actual torch
	# TextureRects are absolutely positioned to hug the title, updated after layout.
	# Simpler and more reliable: build the HBox with actual torch children + the Label.

	# Re-parent the existing Title Label into a new centered HBox.
	var root_ctrl: Control = $Root
	var old_parent: Node = _title_label.get_parent()

	# Build the HBox that will hold [left torch | title | right torch].
	var hbox := HBoxContainer.new()
	hbox.name = "TitleCrest"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	# Position to match where Title is: full-width, top 8→50 px.
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox.offset_top    = 6.0
	hbox.offset_bottom = 50.0
	hbox.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# Left torch TextureRect.
	var torch_l := _make_torch_rect(0)
	hbox.add_child(torch_l)

	# Remove Title from its current parent, add to hbox.
	old_parent.remove_child(_title_label)
	# Title should not expand-fill here — let it size to its text.
	_title_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_title_label)

	# Right torch TextureRect.
	var torch_r := _make_torch_rect(1)
	hbox.add_child(torch_r)

	root_ctrl.add_child(hbox)



func _make_torch_rect(_slot: int) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/ui/dungeon/fx/torch_strip.png")
	atlas.region = Rect2(0, 0, _TORCH_FW, _TORCH_FH)
	_torch_atlases.append(atlas)

	var rect := TextureRect.new()
	rect.texture = atlas
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(_TORCH_FW * _TORCH_SCALE, _TORCH_FH * _TORCH_SCALE)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # align flame-center to title
	return rect

func _process(delta: float) -> void:
	if _torch_atlases.is_empty():
		return
	_torch_anim_t += delta
	var ft := 1.0 / _TORCH_FPS
	if _torch_anim_t < ft:
		return
	_torch_anim_t -= ft
	_torch_frame = (_torch_frame + 1) % _TORCH_FRAMES
	for i in _torch_atlases.size():
		var f: int = (_torch_frame + _TORCH_PHASE[i]) % _TORCH_FRAMES
		_torch_atlases[i].region = Rect2(f * _TORCH_FW, 0, _TORCH_FW, _TORCH_FH)

# ── Right panel: padded backing + LOCATION / PARTY / LOG sections + footer ────

func _build_right_panel_backing() -> void:
	# Backing panel behind RightPanel — try 9-slice texture art; fall back to StyleBoxFlat.
	var panel := PanelContainer.new()
	panel.name = "RightPanelBacking"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left   = 780.0
	panel.offset_top    = 56.0
	panel.offset_right  = 1180.0
	panel.offset_bottom = 696.0
	panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var panel_tex := PixelUI.tex("res://assets/ui/dungeon/frames/side_panel.png")
	if panel_tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = panel_tex
		sbt.texture_margin_left   = 28
		sbt.texture_margin_right  = 28
		sbt.texture_margin_top    = 28
		sbt.texture_margin_bottom = 28
		panel.add_theme_stylebox_override("panel", sbt)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color             = Color(0.10, 0.09, 0.14, 0.97)
		sb.border_color         = Color(UIPalette.GOLD.r, UIPalette.GOLD.g, UIPalette.GOLD.b, 0.45)
		sb.border_width_left    = 2
		sb.border_width_right   = 2
		sb.border_width_top     = 2
		sb.border_width_bottom  = 2
		sb.corner_radius_top_left     = 6
		sb.corner_radius_top_right    = 6
		sb.corner_radius_bottom_left  = 6
		sb.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", sb)

	$Root.add_child(panel)
	$Root.move_child(panel, $Root/RightPanel.get_index())

	# Wrap the entire RightPanel content in a MarginContainer.
	var margin := MarginContainer.new()
	margin.name = "RightPanelMargin"
	# Clear the side_panel.png ornate inner border (~28px) so nothing overlaps it.
	margin.add_theme_constant_override("margin_left",   34)
	margin.add_theme_constant_override("margin_right",  34)
	margin.add_theme_constant_override("margin_top",    30)
	margin.add_theme_constant_override("margin_bottom", 28)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	var inner_vbox := VBoxContainer.new()
	inner_vbox.name  = "RightPanelInner"
	inner_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(inner_vbox)

	# Re-parent all existing children of RightPanel into inner_vbox.
	var rp: VBoxContainer = $Root/RightPanel
	var existing_children: Array[Node] = []
	for c in rp.get_children():
		existing_children.append(c)
	for c in existing_children:
		rp.remove_child(c)

	rp.add_child(margin)
	rp.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── Section 1: PARTY (HP strip) ───────────────────────────────────────────
	inner_vbox.add_child(_make_section_heading("PARTY"))
	inner_vbox.add_child(_make_thin_separator())

	_party_strip_container = VBoxContainer.new()
	_party_strip_container.name = "PartyStrip"
	_party_strip_container.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(_party_strip_container)

	# ── Section 2: EXPEDITION LOG (fills remaining space) ─────────────────────
	inner_vbox.add_child(_make_section_heading("EXPEDITION LOG"))
	inner_vbox.add_child(_make_thin_separator())

	# Re-parent the original LogScroll so its existing LogList content is preserved.
	var log_scroll: ScrollContainer = null
	for c in existing_children:
		if c.name == "LogScroll":
			log_scroll = c as ScrollContainer
			break
	if log_scroll != null:
		log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Drop the .tscn's fixed 380px width so it fills the inner area instead of
		# overflowing the frame (the cause of the scrollbar poking past the border).
		log_scroll.custom_minimum_size.x = 0
		log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		if _log_container != null:
			_log_container.custom_minimum_size.x = 0
			_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_vbox.add_child(log_scroll)

	# ── Footer: rule + symmetric buttons ──────────────────────────────────────
	inner_vbox.add_child(_make_thin_separator())

	# CenterContainer makes both buttons sit centred with equal L/R margins.
	var footer_center := CenterContainer.new()
	footer_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_child(footer_center)

	var footer_vbox := VBoxContainer.new()
	footer_vbox.add_theme_constant_override("separation", 6)
	footer_vbox.custom_minimum_size = Vector2(300, 0)
	footer_center.add_child(footer_vbox)

	var party_btn := Button.new()
	party_btn.name  = "PartyInfoBtnFooter"
	party_btn.text  = "Party Details"
	party_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_btn.custom_minimum_size = Vector2(0, 40)
	party_btn.pressed.connect(_open_party_info_overlay)
	footer_vbox.add_child(party_btn)

	# Recall button — ghost styling.
	if _recall_btn.get_parent() != null:
		_recall_btn.get_parent().remove_child(_recall_btn)
	_recall_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recall_btn.custom_minimum_size = Vector2(0, 34)
	_recall_btn.text = "Recall to City"
	_recall_btn.add_theme_color_override("font_color", UIPalette.MUTED)
	_recall_btn.add_theme_font_size_override("font_size", 13)
	footer_vbox.add_child(_recall_btn)

## Returns a small gold section heading Label (~13px).
func _make_section_heading(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UIPalette.GOLD)
	return lbl

## Returns a 30%-gold thin HSeparator (reuses DungeonTheme stylebox).
func _make_thin_separator() -> HSeparator:
	return HSeparator.new()

# ── Party HP strip ─────────────────────────────────────────────────────────────

func _refresh_party_strip() -> void:
	if _party_strip_container == null:
		return
	for child in _party_strip_container.get_children():
		child.queue_free()

	var soldiers := DungeonState.soldiers_in_dungeon
	if soldiers.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "Party: (none)"
		none_lbl.add_theme_font_size_override("font_size", 11)
		none_lbl.add_theme_color_override("font_color", UIPalette.MUTED)
		_party_strip_container.add_child(none_lbl)
		return

	for sol in soldiers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_party_strip_container.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = sol.soldier_name
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.custom_minimum_size = Vector2(90, 0)
		name_lbl.clip_text = true
		name_lbl.add_theme_color_override("font_color",
			UIPalette.DANGER if not sol.is_alive() else UIPalette.PARCHMENT)
		row.add_child(name_lbl)

		var hp_pct := float(sol.hp_current) / float(sol.hp_max) if sol.hp_max > 0 else 0.0
		var bar := ProgressBar.new()
		bar.min_value   = 0
		bar.max_value   = sol.hp_max
		bar.value       = sol.hp_current
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(130, 10)  # slimmed to 10px
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
		bar.modulate = _hp_bar_color(hp_pct)
		row.add_child(bar)

		var hp_lbl := Label.new()
		hp_lbl.text = "%d/%d" % [sol.hp_current, sol.hp_max]
		hp_lbl.add_theme_font_size_override("font_size", 10)
		hp_lbl.add_theme_color_override("font_color", UIPalette.MUTED)
		hp_lbl.custom_minimum_size = Vector2(52, 0)
		row.add_child(hp_lbl)

## Returns the palette HP-bar tint for a given 0–1 fraction.
func _hp_bar_color(pct: float) -> Color:
	if pct > 0.6:
		return Color("#6fa84e")   # healthy green
	elif pct > 0.3:
		return UIPalette.GOLD     # wounded amber
	else:
		return UIPalette.DANGER   # critical red

## Legacy alias kept so no existing call site breaks.
func _refresh_soldiers_label() -> void:
	_refresh_party_strip()


# ── Map rendering ──────────────────────────────────────────────────────────────

func _render_map() -> void:
	for child in _map_container.get_children():
		child.queue_free()
	_room_buttons.clear()
	_map_content = null

	var map: DungeonMap = DungeonState.map

	_build_map_board()

	_map_content = Control.new()
	_map_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_container.add_child(_map_content)

	for pos in map.get_occupied_positions():
		for neighbor_room in map.get_neighbors(pos):
			var np: Vector2i = neighbor_room.grid_pos
			if np.x > pos.x or (np.x == pos.x and np.y > pos.y):
				_draw_connection_line(pos, np)

	for pos in map.get_occupied_positions():
		_create_room_button(pos, map.get_room_at(pos))

	_refresh_room_states()
	_build_map_frame()
	_fit_map_to_board()

	_party_token = null
	_build_party_token()
	_last_token_pos = DungeonState.current_pos

## Returns the center of a grid cell in _map_content local space.
func _room_center_in_content(pos: Vector2i) -> Vector2:
	return _grid_to_screen(pos) + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)

func _build_party_token() -> void:
	if _map_content == null:
		return
	var token := Control.new()
	token.name = "PartyToken"
	token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	token.custom_minimum_size = Vector2(16, 16)
	var center := _room_center_in_content(DungeonState.current_pos)
	token.position = center - Vector2(8, 8)
	token.z_index = 10
	_map_content.add_child(token)
	_party_token = token

func _animate_party_token(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if _party_token == null or _map_content == null:
		return
	if not is_instance_valid(_party_token):
		return
	var from_center := _room_center_in_content(from_pos) - Vector2(8, 8)
	var to_center   := _room_center_in_content(to_pos)   - Vector2(8, 8)
	_party_token.position = from_center
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_party_token, "position", to_center, 0.25)

## Board surface under the medallions.
## OVER=1.0 + STRETCH_KEEP_ASPECT_CENTERED: the whole parchment scroll (rolled
## ends included) is visible, centered in the 740×640 container. The thin dark
## band top/bottom is the cavern wall acting as a matte — intentional.
## A drop-shadow TextureRect is inserted one z-order behind the board.
func _build_map_board() -> void:
	_board_has_texture = false

	var board_tex := PixelUI.tex("res://assets/ui/dungeon/background/map_board.png")
	if board_tex != null:
		_board_has_texture = true

		var cw: float = _map_container.size.x if _map_container.size.x > 0 else 740.0
		var ch: float = _map_container.size.y if _map_container.size.y > 0 else 640.0

		# Drop shadow — same texture, dark modulate, offset (+4,+6), behind the board.
		var shadow := TextureRect.new()
		shadow.name = "MapBoardShadow"
		shadow.texture = board_tex
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.modulate     = Color(0, 0, 0, 0.35)
		shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
		shadow.offset_left   = 4.0
		shadow.offset_top    = 6.0
		shadow.offset_right  = cw + 4.0
		shadow.offset_bottom = ch + 6.0
		_map_container.add_child(shadow)

		# Main board — fills container exactly; aspect-centering keeps scroll intact.
		var board := TextureRect.new()
		board.name = "MapBoard"
		board.texture = board_tex
		board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_map_container.add_child(board)
	else:
		var base := ColorRect.new()
		base.name = "MapBase"
		base.color = UIPalette.STONE_DARKEST
		base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_container.add_child(base)

func _build_map_frame() -> void:
	if _board_has_texture:
		return
	var frame_tex := PixelUI.tex("res://assets/ui/dungeon/frames/window.png")
	if frame_tex == null:
		return
	var frame := NinePatchRect.new()
	frame.name = "MapFrame"
	frame.texture = frame_tex
	frame.patch_margin_left = 30
	frame.patch_margin_right = 30
	frame.patch_margin_top = 30
	frame.patch_margin_bottom = 30
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_container.add_child(frame)

## Scale + centre the occupied-room bounding box onto the writable parchment body.
## Margins of ~(70,60) push the rooms off the rolled ends at top/bottom.
func _fit_map_to_board() -> void:
	var map: DungeonMap = DungeonState.map
	if map == null:
		return
	var occ: Array = map.get_occupied_positions()
	if occ.is_empty():
		return

	var min_c := 1 << 30; var min_r := 1 << 30
	var max_c := -(1 << 30); var max_r := -(1 << 30)
	for p in occ:
		min_c = mini(min_c, p.x); max_c = maxi(max_c, p.x)
		min_r = mini(min_r, p.y); max_r = maxi(max_r, p.y)

	var cell := float(CELL_SIZE + CELL_PADDING)
	var bbox := Vector2((max_c - min_c + 1) * cell, (max_r - min_r + 1) * cell)

	var container := _map_container.size
	if container == Vector2.ZERO:
		container = Vector2(740.0, 640.0)

	# Texture is STRETCH_KEEP_ASPECT_CENTERED at OVER=1.0 — the scroll body sits
	# roughly inset by the rolled-end height (~9% of the PNG on each axis). Use
	# slightly larger margins (70 h, 60 v) to keep medallions on the flat parchment.
	var margin := Vector2(70.0, 60.0) if _board_has_texture else Vector2(46.0, 46.0)
	var inner  := container - margin * 2.0

	var scale_v := minf(inner.x / bbox.x, inner.y / bbox.y)
	scale_v = minf(scale_v, 1.0)
	_map_content.scale = Vector2(scale_v, scale_v)

	var bbox_origin := Vector2(min_c * cell, min_r * cell)
	var map_offset := margin + (inner - bbox * scale_v) * 0.5
	_map_content.position = map_offset - bbox_origin * scale_v

func _create_room_button(pos: Vector2i, room: DungeonRoom) -> void:
	var medallion: RoomMedallion = _MEDALLION_SCENE.instantiate() as RoomMedallion
	var icon_path := _icon_path_for(room)
	var icon_tex: Texture2D = PixelUI.tex(icon_path) if icon_path != "" else null
	var icon_mod := Color(1.4, 1.4, 1.4) if room.room_type == DungeonRoom.RoomType.SPAWN else Color.WHITE
	medallion.setup(icon_tex, room.get_display_color(), icon_mod)

	var cell_screen := _grid_to_screen(pos)
	medallion.position = cell_screen + Vector2((CELL_SIZE - 80) * 0.5, (CELL_SIZE - 80) * 0.5)

	medallion.get_node("Hit").pressed.connect(func(): _on_room_clicked(pos))
	medallion.set_room_name(room.get_display_name())

	_map_content.add_child(medallion)
	_room_buttons[pos] = medallion

func _icon_path_for(room: DungeonRoom) -> String:
	const BASE := "res://assets/ui/dungeon/icons/rooms/"
	match room.room_type:
		DungeonRoom.RoomType.SPAWN:        return BASE + "spawn.png"
		DungeonRoom.RoomType.MONSTER:      return BASE + "monster.png"
		DungeonRoom.RoomType.ELITE:        return BASE + "elite.png"
		DungeonRoom.RoomType.BOSS:         return BASE + "boss.png"
		DungeonRoom.RoomType.FOUNTAIN:     return BASE + "fountain.png"
		DungeonRoom.RoomType.EMPTY:        return BASE + "empty.png"
		DungeonRoom.RoomType.MARKET_TRAIT: return BASE + "market_trait.png"
		DungeonRoom.RoomType.MARKET_GEAR:  return BASE + "market_gear.png"
		DungeonRoom.RoomType.LORE:         return BASE + "lore.png"
	return ""

func _draw_connection_line(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var half_cell := Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
	var fp := _grid_to_screen(from_pos) + half_cell
	var tp := _grid_to_screen(to_pos)   + half_cell

	var from_room: DungeonRoom = DungeonState.map.get_room_at(from_pos)
	var to_room:   DungeonRoom = DungeonState.map.get_room_at(to_pos)
	var both_visited: bool = (from_room != null and from_room.visited) and \
							  (to_room   != null and to_room.visited)

	var shadow := Line2D.new()
	shadow.default_color = Color(UIPalette.STONE_DARKEST.r, UIPalette.STONE_DARKEST.g,
								  UIPalette.STONE_DARKEST.b, 0.85 if both_visited else 0.55)
	shadow.width = 8.0
	shadow.add_point(fp); shadow.add_point(tp)
	_map_content.add_child(shadow)

	var surface := Line2D.new()
	if both_visited:
		surface.default_color = Color(UIPalette.GOLD.r, UIPalette.GOLD.g, UIPalette.GOLD.b, 0.55)
	else:
		surface.default_color = Color(UIPalette.STONE_LIGHT.r, UIPalette.STONE_LIGHT.g,
									   UIPalette.STONE_LIGHT.b, 0.45)
	surface.width = 3.0
	surface.add_point(fp); surface.add_point(tp)
	_map_content.add_child(surface)

func _grid_to_screen(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * (CELL_SIZE + CELL_PADDING), pos.y * (CELL_SIZE + CELL_PADDING))

func _refresh_room_states() -> void:
	var accessible: Array = DungeonState.get_accessible_positions()
	var all_revealed: bool = DungeonState.dungeon_map_reveal_active and DungeonState.dungeon_level >= 4

	for pos in _room_buttons.keys():
		var medallion: RoomMedallion = _room_buttons[pos] as RoomMedallion
		if not is_instance_valid(medallion):
			continue
		var room: DungeonRoom = DungeonState.map.get_room_at(pos)
		if room == null:
			continue

		var state: RoomMedallion.State
		var is_current: bool = (pos == DungeonState.current_pos)

		if is_current:
			state = RoomMedallion.State.CURRENT
		elif accessible.has(pos) and not room.cleared:
			state = RoomMedallion.State.ACCESSIBLE
		elif room.cleared:
			# Re-enterable shops/lore adjacent to current pos get the CLEARED_REENTER tint.
			if (room.is_shop() or room.room_type == DungeonRoom.RoomType.LORE) \
					and accessible.has(pos):
				state = RoomMedallion.State.CLEARED_REENTER
			else:
				# CLEARED rooms that are adjacent to current pos are clickable for backtracking.
				# Rooms reachable via fast-travel also stay CLEARED (clickable via hit button).
				state = RoomMedallion.State.CLEARED
		elif room.seen or all_revealed:
			# Passed-by ("seen") rooms and map-reveal rooms show their type
			# permanently, dimmed and non-interactive, for planning.
			state = RoomMedallion.State.REVEALED
		else:
			state = RoomMedallion.State.LOCKED

		medallion.set_state(state, is_current, room.cleared)
		if state == RoomMedallion.State.LOCKED:
			medallion.set_room_name("???")
		else:
			medallion.set_room_name(room.get_display_name())

# ── Info refresh (no-op — LOCATION section removed) ───────────────────────────

func _refresh_info() -> void:
	pass  # LOCATION section was removed; nothing to refresh here.

# ── Navigation ─────────────────────────────────────────────────────────────────

func _on_room_clicked(pos: Vector2i) -> void:
	if _in_combat or not _waiting_for_input or _fight_result_pending:
		return

	var room: DungeonRoom = DungeonState.map.get_room_at(pos)
	if room == null:
		return

	# ── Re-open current room if it is a shop or lore ──────────────────────────
	if pos == DungeonState.current_pos:
		if room.is_shop():
			if room.room_type == DungeonRoom.RoomType.MARKET_TRAIT:
				_open_market_trait(room)
			else:
				_open_market_gear(room)
		elif room.room_type == DungeonRoom.RoomType.LORE:
			_handle_lore_room(room)
		return

	# ── Direct adjacent move (cleared re-enterable or accessible new room) ────
	if DungeonState.is_pos_accessible(pos):
		_enter_room(pos)
		return

	# ── Fast-travel: BFS through cleared/visited rooms ────────────────────────
	var path: Array[Vector2i] = DungeonState.map.find_cleared_path(
		DungeonState.current_pos, pos)
	if path.size() < 2:
		return  # no cleared path exists — do nothing

	# Walk path[1..end] sequentially, animating the token along each step.
	_waiting_for_input = false
	_fast_travel_along_path(path, 1)

## Walk the party along a pre-computed cleared path, one step per ~0.18 s.
## Called recursively from a deferred callback until all steps are done.
func _fast_travel_along_path(path: Array[Vector2i], step_idx: int) -> void:
	if step_idx >= path.size():
		# Arrived — resolve the destination room normally.
		_waiting_for_input = true
		var dest: Vector2i = path[path.size() - 1]
		var dest_room: DungeonRoom = DungeonState.map.get_room_at(dest)
		if dest_room != null and dest_room.cleared:
			# Cleared non-interactive room: just move there silently.
			if not (dest_room.is_shop() or dest_room.room_type == DungeonRoom.RoomType.LORE):
				if _last_token_pos != dest:
					_animate_party_token(_last_token_pos, dest)
				_last_token_pos = dest
				DungeonState.enter_room(dest)
				_render_map()
				_refresh_info()
				_refresh_soldiers_label()
				return
		# Otherwise let _enter_room handle it (shop/lore/new room).
		_enter_room(dest)
		return

	var from_pos: Vector2i = path[step_idx - 1]
	var next_pos: Vector2i = path[step_idx]

	# Animate the token for this step.
	_animate_party_token(from_pos, next_pos)
	_last_token_pos = next_pos

	# Update DungeonState position quietly (no room events for intermediate cleared steps).
	DungeonState.current_pos = next_pos
	_refresh_room_states()

	# Wait for step duration then continue.
	var timer := get_tree().create_timer(0.18)
	timer.timeout.connect(func():
		_fast_travel_along_path(path, step_idx + 1)
	)

func _enter_room(pos: Vector2i) -> void:
	if _last_token_pos != Vector2i(-999, -999) and _last_token_pos != pos:
		_animate_party_token(_last_token_pos, pos)
	_last_token_pos = pos

	DungeonState.enter_room(pos)
	var room: DungeonRoom = DungeonState.map.get_room_at(pos)

	if room.cleared and not room.is_shop() and room.room_type not in [
		DungeonRoom.RoomType.MONSTER,
		DungeonRoom.RoomType.ELITE,
		DungeonRoom.RoomType.BOSS,
		DungeonRoom.RoomType.LORE,
	]:
		_render_map()
		_refresh_info()
		_refresh_soldiers_label()
		return

	match room.room_type:
		DungeonRoom.RoomType.MONSTER, DungeonRoom.RoomType.ELITE, DungeonRoom.RoomType.BOSS:
			if not room.cleared:
				_start_dungeon_combat(room)
				return
		DungeonRoom.RoomType.FOUNTAIN:
			_handle_fountain(room)
		DungeonRoom.RoomType.EMPTY:
			_handle_empty_room(room)
		DungeonRoom.RoomType.MARKET_TRAIT:
			_open_market_trait(room)
			return
		DungeonRoom.RoomType.MARKET_GEAR:
			_open_market_gear(room)
			return
		DungeonRoom.RoomType.LORE:
			_handle_lore_room(room)
			return

	room.cleared = true
	_render_map()
	_refresh_info()
	_refresh_soldiers_label()

# ── Combat ─────────────────────────────────────────────────────────────────────

func _start_dungeon_combat(room: DungeonRoom) -> void:
	_in_combat = true
	_waiting_for_input = false

	# Snapshot each soldier's HP so we can report exact damage in the post-fight log.
	_pre_combat_hp.clear()
	for s in DungeonState.soldiers_in_dungeon:
		_pre_combat_hp[s.soldier_name] = s.hp_current

	var recap = get_tree().get_root().find_child("RecapScreen", true, false)
	if recap != null and recap.visible:
		recap.hide()
		GameState.menu_open = false

	CombatState.is_dungeon_combat = true
	CombatState.start_combat(room.enemies)
	CombatState.allies = DungeonState.soldiers_in_dungeon.filter(func(s): return s.is_alive())
	hide()
	CombatState.begin_after_selection()

func _on_dungeon_combat_ended(victory: bool) -> void:
	_in_combat = false
	_waiting_for_input = true
	_fight_result_pending = true
	GameState.menu_open = true

	var room: DungeonRoom = DungeonState.map.get_room_at(DungeonState.current_pos)

	if victory:
		room.cleared = true
		GameState.gold += room.loot_gold

		# Build a structured combat-victory log block.
		var enemy_names: Array[String] = []
		for e in room.enemies:
			enemy_names.append(e.enemy_name)

		var damage_lines: Array[String] = []
		for s in DungeonState.soldiers_in_dungeon:
			var pre: int = _pre_combat_hp.get(s.soldier_name, s.hp_current)
			var dmg: int = pre - s.hp_current
			if dmg > 0:
				damage_lines.append("%s  −%d HP" % [s.soldier_name, dmg])

		var reward_lines: Array[String] = []
		if room.loot_gold > 0:
			reward_lines.append("+%d Gold" % room.loot_gold)
			DungeonState.log_event("loot", "Found %d Gold!" % room.loot_gold)
		# XP: CombatState tracks leveled_up_soldiers list and xp_earned.
		if CombatState.xp_earned > 0:
			reward_lines.append("+%d XP" % CombatState.xp_earned)
		for sol_name in CombatState.leveled_up_soldiers:
			_add_log_block("★", "%s leveled up!" % sol_name, UIPalette.GOLD, [], UIPalette.GOLD)

		var detail: Array[String] = []
		if not enemy_names.is_empty():
			detail.append("Defeated: " + ", ".join(enemy_names))
		detail.append_array(damage_lines)
		if not reward_lines.is_empty():
			detail.append("Rewards: " + ", ".join(reward_lines))

		_add_log_block("⚔", "Cleared — %s" % room.get_display_name(), UIPalette.GOLD, detail, UIPalette.GOLD)

		# Casualties.
		var dead := DungeonState.soldiers_in_dungeon.filter(func(s): return not s.is_alive())
		for s in dead:
			DungeonState.soldier_died_in_dungeon(s)
			_add_log_block("☠", "%s has fallen — lost permanently." % s.soldier_name,
				UIPalette.DANGER, [], UIPalette.DANGER)

		if room.room_type == DungeonRoom.RoomType.BOSS:
			var completed_level := DungeonState.dungeon_level
			DungeonState.dungeon_level += 1
			_add_log_block("♛", "BOSS DEFEATED — Depth %s complete!" % _to_roman(completed_level),
				UIPalette.GOLD,
				["Depth %s unlocked." % _to_roman(DungeonState.dungeon_level)],
				UIPalette.GOLD)
			DungeonState.log_event("boss_cleared", "Boss defeated! Dungeon Level %d unlocked." % DungeonState.dungeon_level)
			_title_label.text = "DEPTH %s · CLEARED" % _to_roman(completed_level)
			_fight_result_pending = false
			_render_map()
			_refresh_info()
			_refresh_soldiers_label()
			_show_boss_cleared_return_button()
			return
	else:
		_add_log_block("⚔", "Defeat — soldiers retreat.", UIPalette.DANGER, [], UIPalette.DANGER)
		var dead := DungeonState.soldiers_in_dungeon.filter(func(s): return not s.is_alive())
		for s in dead:
			DungeonState.soldier_died_in_dungeon(s)
			_add_log_block("☠", "%s has fallen — lost permanently." % s.soldier_name,
				UIPalette.DANGER, [], UIPalette.DANGER)
		var survivors := DungeonState.soldiers_in_dungeon.filter(func(s): return s.is_alive())
		for s in survivors:
			s.hp_current = max(1, int(s.hp_max * 0.3))
		# Do NOT recall/close yet: the combat scene's "DEFEAT!" overlay appears
		# after a short delay, and tearing the dungeon down now lets the hub's
		# recap/replay windows pop first. The teardown runs when the player
		# dismisses the result (_on_dungeon_result_dismissed).
		_defeat_teardown_pending = true
		return

	_render_map()
	_refresh_info()
	_refresh_soldiers_label()

# ── Room events ────────────────────────────────────────────────────────────────

func _handle_fountain(_room: DungeonRoom) -> void:
	for s in DungeonState.soldiers_in_dungeon:
		if s.is_alive():
			var healed := int(s.hp_max * 0.20)
			s.hp_current = mini(s.hp_max, s.hp_current + healed)
	DungeonState.log_event("fountain", "Fountain healed all soldiers for 20% max HP.")
	_add_log_block("✦", "Fountain", UIPalette.HEAL,
		["Party restored 20% HP."], UIPalette.HEAL)

func _handle_empty_room(room: DungeonRoom) -> void:
	if not room.visited and room.flavor_text != "":
		_add_log_entry_italic(room.flavor_text)
	if room.has_remains:
		_show_remains_event(room)
		return
	var roll := randf()
	if roll < 0.30:
		var dmg_pct := randf_range(0.08, 0.18)
		for s in DungeonState.soldiers_in_dungeon:
			if s.is_alive():
				var dmg := int(s.hp_max * dmg_pct)
				s.hp_current = max(1, s.hp_current - dmg)
		var pct_str := "%d%%" % int(dmg_pct * 100.0)
		DungeonState.log_event("trap", "Trap! All soldiers lost ~%s HP." % pct_str)
		_add_log_block("◷", "Trap sprung", UIPalette.DANGER,
			["All soldiers −%s HP." % pct_str], UIPalette.DANGER)
	elif roll < 0.55:
		var gold := randi_range(4, 10) * DungeonState.dungeon_level
		GameState.gold += gold
		DungeonState.log_event("gold_cache", "Found a cache of %d Gold." % gold)
		_add_log_block("◆", "Ruins cache", UIPalette.GOLD,
			["Found %d Gold." % gold], UIPalette.MUTED)
	else:
		DungeonState.log_event("empty", "Nothing of note here.")
		_add_log_block("◆", "Empty room", UIPalette.MUTED, ["Nothing of note here."], UIPalette.MUTED)

func _show_remains_event(room: DungeonRoom) -> void:
	var detail: Array[String] = []
	if room.remains_items.is_empty():
		detail.append("Nothing left to recover.")
	else:
		for item in room.remains_items:
			GameState.owned_items.append(item)
			DungeonState.expedition_pool.append(item)
			detail.append("Recovered: %s" % item.item_name)
	room.has_remains = false
	DungeonState.log_event("remains", "Found remains of %s." % room.remains_soldier_name)
	_add_log_block("◆", "Remains of %s" % room.remains_soldier_name, UIPalette.MUTED,
		detail, UIPalette.MUTED)

# ── Boss cleared return button ─────────────────────────────────────────────────

func _show_boss_cleared_return_button() -> void:
	# Repurpose the existing footer Recall button into a prominent "Return to City"
	# so it stays inside the framed panel footer instead of floating below the frame.
	_recall_btn.text = "Return to City"
	_recall_btn.add_theme_font_size_override("font_size", 16)
	_recall_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_recall_btn.visible = true

func _on_recall_pressed() -> void:
	DungeonState.recall_soldiers()
	_add_log_block("◷", "Recalled to city", UIPalette.MUTED, [], UIPalette.MUTED)
	GameState.menu_open = false
	emit_signal("dungeon_scene_closed")
	queue_free()

# ── Expedition log ─────────────────────────────────────────────────────────────

## Simple one-line log entry (used for legacy replayed entries + fallback).
func _add_log_entry(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", UIPalette.PARCHMENT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(285, 0)
	_log_container.add_child(lbl)
	_scroll_log_to_bottom()

## Italic muted entry for atmospheric flavor text.
func _add_log_entry_italic(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.80))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(285, 0)
	_log_container.add_child(lbl)
	_scroll_log_to_bottom()

## Structured "log card" with a 3px left accent bar, glyph+title in the event
## colour, and indented muted detail lines (~11px).
## glyph      — unicode symbol (⚔ ★ ☠ ✦ ◷ ◆ ♛)
## title      — event headline
## title_color — color for glyph+title
## detail_lines — array of detail strings; rendered in MUTED/PARCHMENT below
## accent_color — color of the 3px left border bar
func _add_log_block(glyph: String, title: String, title_color: Color,
					detail_lines: Array, accent_color: Color) -> void:
	# Outer HBox: [3px bar] + [content VBox]
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	hbox.custom_minimum_size = Vector2(285, 0)

	# Left accent bar (ColorRect 3px wide).
	var bar := ColorRect.new()
	bar.color = accent_color
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar)

	# Content VBox.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Header line: glyph + title.
	var header_lbl := Label.new()
	header_lbl.text = "%s  %s" % [glyph, title]
	header_lbl.add_theme_font_size_override("font_size", 11)
	header_lbl.add_theme_color_override("font_color", title_color)
	header_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(header_lbl)

	# Detail lines indented, muted.
	for line in detail_lines:
		var dl := Label.new()
		dl.text = "  " + line
		dl.add_theme_font_size_override("font_size", 11)
		dl.add_theme_color_override("font_color", UIPalette.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(dl)

	_log_container.add_child(hbox)
	_scroll_log_to_bottom()

## Scrolls the expedition log to the newest (bottom) entry after a deferred frame.
func _scroll_log_to_bottom() -> void:
	var scroll := _log_container.get_parent() as ScrollContainer
	if scroll == null:
		return
	# Await one layout frame so the container has expanded, then set the property directly.
	await get_tree().process_frame
	if is_instance_valid(scroll):
		var vbar := scroll.get_v_scroll_bar()
		if vbar != null:
			scroll.scroll_vertical = int(vbar.max_value)
		else:
			scroll.scroll_vertical = 999999

# ── Lore + market overlays (unchanged from original) ──────────────────────────

func _handle_lore_room(room: DungeonRoom) -> void:
	_waiting_for_input = false

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = DungeonTheme.get_theme()

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.02, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(240, 110)
	panel.size = Vector2(700, 480)
	panel.self_modulate = Color(0.80, 0.70, 1.0, 1.0)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var heading_font: Font = load("res://assets/ui/dungeon/fonts/heading.ttf")
	var title_lbl := Label.new()
	title_lbl.text = room.lore_title if room.lore_title != "" else "Inscription"
	if heading_font:
		title_lbl.add_theme_font_override("font", heading_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", UIPalette.GOLD)
	vbox.add_child(title_lbl)

	vbox.add_child(HSeparator.new())

	var body_lbl := Label.new()
	body_lbl.text = room.lore_text if room.lore_text != "" else ""
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.custom_minimum_size = Vector2(600, 220)
	body_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body_lbl)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(600, 44)
	leave_btn.pressed.connect(func():
		room.cleared = true
		overlay.queue_free()
		_waiting_for_input = true
		_render_map()
		_refresh_info()
		_refresh_soldiers_label()
	)
	vbox.add_child(leave_btn)

	add_child(overlay)

	if not room.visited:
		_add_log_block("◆", "Inscription: \"%s\"" % room.lore_title, UIPalette.LORE, [], UIPalette.LORE)

func _open_market_trait(room: DungeonRoom) -> void:
	var overlay: Control = _make_market_overlay("Skill Trainer & Stat Training", room, true)
	add_child(overlay)

func _open_market_gear(room: DungeonRoom) -> void:
	var overlay: Control = _make_market_overlay("Gear Market — buy equipment and potions", room, false)
	add_child(overlay)

func _make_market_overlay(title: String, room: DungeonRoom, is_trait_market: bool) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.theme = DungeonTheme.get_theme()

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(210, 90)
	panel.size = Vector2(760, 580)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var heading_font: Font = load("res://assets/ui/dungeon/fonts/heading.ttf")
	var title_lbl := Label.new()
	title_lbl.text = title
	if heading_font:
		title_lbl.add_theme_font_override("font", heading_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", UIPalette.GOLD)
	vbox.add_child(title_lbl)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 440)
	vbox.add_child(scroll)
	var items_vbox := VBoxContainer.new()
	items_vbox.custom_minimum_size = Vector2(700, 0)
	scroll.add_child(items_vbox)

	if is_trait_market:
		var selected_idx := [0]
		_populate_trainer(items_vbox, room, selected_idx)
	else:
		_populate_gear_market(items_vbox, room)

	var close_btn := Button.new()
	close_btn.text = "Leave Market"
	close_btn.custom_minimum_size = Vector2(720, 40)
	close_btn.pressed.connect(func():
		room.cleared = true
		overlay.queue_free()
		_render_map()
		_refresh_info()
	)
	vbox.add_child(close_btn)
	return overlay

func _trait_gold_cost(t: TraitData) -> int:
	var v := 30
	v += (abs(t.power_bonus) + abs(t.speed_bonus) + abs(t.dexterity_bonus) + abs(t.defense_bonus)) * 12
	v += int(abs(t.hp_bonus))
	v += int(t.hit_chance_bonus * 200.0)
	v += int(t.dodge_bonus * 200.0)
	return maxi(30, v)

func _skill_gold_cost(sk: SkillData) -> int:
	var v := 80
	v += sk.required_level * 8
	v += maxi(sk.req_power, maxi(sk.req_speed, maxi(sk.req_dex, int(sk.req_hp / 8.0)))) * 3
	if sk.damage_multiplier > 1.0:
		v += int((sk.damage_multiplier - 1.0) * 60.0)
	if sk.skill_type == SkillData.SkillType.ACTIVE:
		v += 30
	return maxi(60, v)

func _stat_point_cost(sol: SoldierData) -> int:
	return 40 + sol.level * 6

func _populate_trainer(container: VBoxContainer, room: DungeonRoom, selected_idx: Array) -> void:
	for child in container.get_children():
		child.queue_free()

	var alive := DungeonState.soldiers_in_dungeon.filter(func(s): return s.is_alive())
	if alive.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No living soldiers to train."
		container.add_child(empty_lbl)
		return

	if selected_idx[0] >= alive.size():
		selected_idx[0] = 0

	var gold_lbl := Label.new()
	gold_lbl.text = "Gold: %d" % GameState.gold
	gold_lbl.add_theme_color_override("font_color", UIPalette.GOLD)
	container.add_child(gold_lbl)

	var sel_lbl := Label.new()
	sel_lbl.text = "Select a soldier:"
	container.add_child(sel_lbl)

	var sel_hbox := HBoxContainer.new()
	sel_hbox.add_theme_constant_override("separation", 6)
	container.add_child(sel_hbox)
	for i in alive.size():
		var s: SoldierData = alive[i]
		var sbtn := Button.new()
		sbtn.text = "%s\n[%s Lv.%d]\nPts:%d" % [s.soldier_name, s.soldier_class, s.level, s.unspent_stat_points]
		sbtn.custom_minimum_size = Vector2(130, 62)
		sbtn.toggle_mode = true
		sbtn.button_pressed = (i == selected_idx[0])
		var capture_i := i
		sbtn.pressed.connect(func():
			selected_idx[0] = capture_i
			_populate_trainer(container, room, selected_idx)
		)
		sel_hbox.add_child(sbtn)

	var sol: SoldierData = alive[selected_idx[0]]

	container.add_child(HSeparator.new())

	var st_header := Label.new()
	st_header.text = "Stat Training"
	st_header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	container.add_child(st_header)

	var st_row := HBoxContainer.new()
	st_row.add_theme_constant_override("separation", 8)
	container.add_child(st_row)
	var st_info := Label.new()
	st_info.text = "Gain +1 stat point (allocate it in the Army tab). Unspent points: %d" % sol.unspent_stat_points
	st_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	st_info.custom_minimum_size = Vector2(360, 0)
	st_row.add_child(st_info)
	var st_cost := _stat_point_cost(sol)
	var st_btn := Button.new()
	st_btn.text = "+1 Point  (%d Gold)" % st_cost
	st_btn.custom_minimum_size = Vector2(150, 44)
	st_btn.disabled = GameState.gold < st_cost
	st_btn.pressed.connect(func():
		if GameState.gold < st_cost:
			return
		GameState.gold -= st_cost
		sol.unspent_stat_points += 1
		DungeonState.log_event("trainer_stat", "%s trained for +1 stat point (-%d Gold)." % [sol.soldier_name, st_cost])
		GameState.emit_signal("resources_changed")
		_populate_trainer(container, room, selected_idx)
	)
	st_row.add_child(st_btn)

	container.add_child(HSeparator.new())

	var sk_header := Label.new()
	sk_header.text = "Learn Skills  (equipped %d/%d — arrange in the Army tab)" % [sol.equipped_skills.size(), sol.max_skill_slots()]
	sk_header.add_theme_color_override("font_color", Color(0.4, 0.85, 0.9))
	container.add_child(sk_header)

	for sk in SkillLibrary.get_class_skills(sol.soldier_class):
		if sol.has_skill(sk.skill_id):
			continue
		var cost := _skill_gold_cost(sk)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		container.add_child(row)

		var info := Label.new()
		var type_str: String = "Passive" if sk.skill_type == SkillData.SkillType.PASSIVE \
								else "Active CD:%d" % sk.cooldown_turns
		info.text = "[%s] %s — %s\n%s" % [type_str, sk.skill_name, sk.get_stats_display(), sk.get_unlock_description()]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.custom_minimum_size = Vector2(360, 0)
		row.add_child(info)

		if not sol.meets_skill_conditions(sk):
			var locked_lbl := Label.new()
			locked_lbl.text = "[Locked]"
			locked_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
			locked_lbl.custom_minimum_size = Vector2(130, 50)
			locked_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			locked_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(locked_lbl)
		else:
			var buy_btn := Button.new()
			buy_btn.text = "Learn  (%d Gold)" % cost
			buy_btn.custom_minimum_size = Vector2(130, 50)
			buy_btn.disabled = GameState.gold < cost
			buy_btn.pressed.connect(func():
				if GameState.gold < cost or sol.has_skill(sk.skill_id) or not sol.meets_skill_conditions(sk):
					return
				GameState.gold -= cost
				sol.learn_skill(sk)
				DungeonState.log_event("trainer_skill", "%s learned %s (-%d Gold)." % [sol.soldier_name, sk.skill_name, cost])
				GameState.emit_signal("resources_changed")
				_populate_trainer(container, room, selected_idx)
			)
			row.add_child(buy_btn)

	container.add_child(HSeparator.new())

	var t_header := Label.new()
	t_header.text = "Traits  (permanent passives):"
	t_header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	container.add_child(t_header)

	var market_traits := TraitLibrary.get_all().filter(
		func(t: TraitData) -> bool: return t.trigger != TraitData.TraitTrigger.LEVEL_UP
	)
	for t in market_traits:
		if sol.has_trait(t.trait_id):
			continue
		var tcost := _trait_gold_cost(t)
		var trow := HBoxContainer.new()
		trow.add_theme_constant_override("separation", 8)
		container.add_child(trow)

		var tinfo := Label.new()
		tinfo.text = "%s — %s" % [t.trait_name, t.get_stats_display()]
		tinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tinfo.autowrap_mode = TextServer.AUTOWRAP_WORD
		tinfo.custom_minimum_size = Vector2(360, 0)
		trow.add_child(tinfo)

		var tbuy := Button.new()
		tbuy.text = "Give  (%d Gold)" % tcost
		tbuy.custom_minimum_size = Vector2(130, 50)
		tbuy.disabled = GameState.gold < tcost
		tbuy.pressed.connect(func():
			if GameState.gold < tcost or sol.has_trait(t.trait_id):
				return
			GameState.gold -= tcost
			sol.traits.append(t)
			DungeonState.log_event("trainer_trait", "%s gained trait %s (-%d Gold)." % [sol.soldier_name, t.trait_name, tcost])
			GameState.emit_signal("resources_changed")
			_populate_trainer(container, room, selected_idx)
		)
		trow.add_child(tbuy)

func _populate_gear_market(container: VBoxContainer, _room: DungeonRoom) -> void:
	var all_btns: Array[Button] = []
	var gold_lbl := Label.new()
	gold_lbl.text = "Gold: %d" % GameState.gold
	gold_lbl.add_theme_color_override("font_color", UIPalette.GOLD)
	container.add_child(gold_lbl)

	var refresh_btns := func():
		gold_lbl.text = "Gold: %d" % GameState.gold
		for b in all_btns:
			if is_instance_valid(b):
				b.disabled = GameState.gold < int(b.get_meta("cost", 0))

	for item in GameState.available_items.slice(0, 5):
		var row := HBoxContainer.new()
		container.add_child(row)
		var icon_path := ItemData.get_icon_path(item)
		if icon_path != "":
			var icon_tex := load(icon_path) as Texture2D
			if icon_tex:
				var icon_rect := TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(28, 28)
				icon_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				row.add_child(icon_rect)
		var info := Label.new()
		info.text = "%s — %d Gold" % [item.item_name, item.gold_cost]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.set_meta("cost", item.gold_cost)
		buy_btn.disabled = GameState.gold < item.gold_cost
		buy_btn.pressed.connect(func():
			var prev_count := GameState.owned_items.size()
			if GameState.buy_market_item(item):
				DungeonState.log_event("market_gear", "Purchased %s." % item.item_name)
				# The new copy is always appended last — add it to the expedition pool.
				if GameState.owned_items.size() > prev_count:
					DungeonState.expedition_pool.append(
						GameState.owned_items[GameState.owned_items.size() - 1])
				refresh_btns.call()
		)
		row.add_child(buy_btn)
		all_btns.append(buy_btn)

	var potion_row := HBoxContainer.new()
	container.add_child(potion_row)
	var potion_cost := 30 * DungeonState.dungeon_level
	var potion_tex := load("res://assets/icons/items/healing_potion.png") as Texture2D
	if potion_tex:
		var potion_icon := TextureRect.new()
		potion_icon.texture = potion_tex
		potion_icon.custom_minimum_size = Vector2(28, 28)
		potion_icon.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		potion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		potion_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		potion_row.add_child(potion_icon)
	var potion_info := Label.new()
	potion_info.text = "Healing Potion (15-25%% HP) — %d Gold" % potion_cost
	potion_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_row.add_child(potion_info)
	var potion_btn := Button.new()
	potion_btn.text = "Buy"
	potion_btn.set_meta("cost", potion_cost)
	potion_btn.disabled = GameState.gold < potion_cost
	potion_btn.pressed.connect(func():
		if GameState.gold >= potion_cost:
			GameState.gold -= potion_cost
			for s in DungeonState.soldiers_in_dungeon:
				if s.is_alive():
					var heal := int(s.hp_max * randf_range(0.15, 0.25))
					s.hp_current = mini(s.hp_max, s.hp_current + heal)
			DungeonState.log_event("market_potion", "Used healing potion.")
			GameState.emit_signal("resources_changed")
			refresh_btns.call()
	)
	potion_row.add_child(potion_btn)
	all_btns.append(potion_btn)

# ── Combat signals ─────────────────────────────────────────────────────────────

func _connect_combat_signals() -> void:
	if not CombatState.dungeon_combat_ended.is_connected(_on_dungeon_combat_ended):
		CombatState.dungeon_combat_ended.connect(_on_dungeon_combat_ended)
	if not CombatState.dungeon_result_dismissed.is_connected(_on_dungeon_result_dismissed):
		CombatState.dungeon_result_dismissed.connect(_on_dungeon_result_dismissed)

func _on_dungeon_result_dismissed() -> void:
	_fight_result_pending = false
	if _defeat_teardown_pending:
		# Deferred from the defeat branch of _on_dungeon_combat_ended so the
		# "DEFEAT!" overlay is seen before the hub (recap/replay) takes over.
		_defeat_teardown_pending = false
		DungeonState.recall_soldiers()
		GameState.menu_open = false
		emit_signal("dungeon_scene_closed")
		queue_free()
		return
	show()
	if DungeonState.map != null:
		_render_map()
		_refresh_info()
		_refresh_soldiers_label()

# ── WASD / arrow-key navigation ────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _in_combat or not _waiting_for_input or _fight_result_pending:
		return
	if not (event is InputEventKey and event.pressed):
		return
	var dir: Vector2i = Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:    dir = Vector2i(0, -1)
		KEY_S, KEY_DOWN:  dir = Vector2i(0,  1)
		KEY_A, KEY_LEFT:  dir = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT: dir = Vector2i( 1, 0)
		_: return
	var target := DungeonState.current_pos + dir
	if DungeonState.is_pos_accessible(target):
		_enter_room(target)

# ── Party Info overlay ─────────────────────────────────────────────────────────

## The Party Details button in the footer calls this directly; the legacy
## in-panel button (_add_party_info_button) is no longer added since the footer
## already provides the action. Kept for compatibility if called elsewhere.
func _add_party_info_button() -> void:
	pass  # Footer Party Details button added in _build_right_panel_backing()

func _open_party_info_overlay(scroll_y: float = 0.0) -> void:
	_waiting_for_input = false

	var overlay := CanvasLayer.new()
	overlay.layer = 55
	overlay.name  = "PartyInfoOverlay"
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.theme = DungeonTheme.get_theme()
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(120, 40)
	panel.size = Vector2(940, 700)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(outer_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header)

	var heading_font: Font = load("res://assets/ui/dungeon/fonts/heading.ttf")
	var title_lbl := Label.new()
	title_lbl.text = "Party — Dungeon Level %d" % DungeonState.dungeon_level
	if heading_font:
		title_lbl.add_theme_font_override("font", heading_font)
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", UIPalette.GOLD)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 32)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_waiting_for_input = true
	)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(890, 620)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(860, 0)
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var soldiers := DungeonState.soldiers_in_dungeon
	if soldiers.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No soldiers in dungeon."
		content.add_child(none_lbl)
	else:
		for sol in soldiers:
			content.add_child(_make_party_soldier_card(sol, overlay, scroll))

	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll_y)

func _make_party_soldier_card(sol: SoldierData, overlay: CanvasLayer, scroll: ScrollContainer) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(840, 0)
	card.theme_type_variation = "Card"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(name_hbox)

	var name_lbl := Label.new()
	name_lbl.text = sol.get_display_name()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(name_lbl)

	var status_lbl := Label.new()
	if sol.is_alive():
		status_lbl.text = "Alive"
		status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		status_lbl.text = "Dead"
		status_lbl.add_theme_color_override("font_color", UIPalette.DANGER)
	name_hbox.add_child(status_lbl)

	# HP bar — palette tints, 18px tall for card context.
	var hp_pct := float(sol.hp_current) / float(sol.hp_max) if sol.hp_max > 0 else 0.0
	var hp_bar_hbox := HBoxContainer.new()
	hp_bar_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_bar_hbox)

	var hp_bar_lbl := Label.new()
	hp_bar_lbl.text = "HP:"
	hp_bar_hbox.add_child(hp_bar_lbl)

	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = sol.hp_max
	hp_bar.value     = sol.hp_current
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(200, 18)
	hp_bar.modulate = _hp_bar_color(hp_pct)
	hp_bar_hbox.add_child(hp_bar)

	var hp_num_lbl := Label.new()
	hp_num_lbl.text = "%d / %d" % [sol.hp_current, sol.hp_max]
	hp_bar_hbox.add_child(hp_num_lbl)

	var stats_lbl := Label.new()
	stats_lbl.text = "Strength: %d   Initiative: %d   Cunning: %d   Defense: %d" % [
		sol.get_total_power(), sol.get_total_speed(), sol.get_total_dexterity(), sol.get_total_defense()
	]
	vbox.add_child(stats_lbl)

	var alloc_refresh := func():
		var saved_scroll := scroll.scroll_vertical
		overlay.queue_free()
		call_deferred("_open_party_info_overlay", float(saved_scroll))
	vbox.add_child(StatAllocUI.build(sol, alloc_refresh))

	var equip_hdr := Label.new()
	equip_hdr.text = "Equipment:"
	equip_hdr.add_theme_color_override("font_color", Color(0.75, 0.80, 0.95))
	vbox.add_child(equip_hdr)

	for slot_info in [["weapon_1", "Weapon 1"], ["weapon_2", "Weapon 2"], ["armor", "Armor"]]:
		var slot: String = slot_info[0]
		var slot_title: String = slot_info[1]
		var equipped := sol.get(slot) as ItemData

		var slot_hbox := HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(slot_hbox)

		var slot_lbl := Label.new()
		slot_lbl.text = "%s: %s" % [slot_title, equipped.item_name if equipped else "Empty"]
		slot_lbl.custom_minimum_size = Vector2(380, 0)
		slot_lbl.add_theme_color_override("font_color", Color(0.75, 0.79, 0.88))
		slot_hbox.add_child(slot_lbl)

		if equipped != null:
			var unequip_btn := Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(90, 28)
			unequip_btn.pressed.connect(func():
				var saved_scroll := scroll.scroll_vertical
				GameState.unequip_item(sol, slot)
				overlay.queue_free()
				call_deferred("_open_party_info_overlay", float(saved_scroll))
			)
			slot_hbox.add_child(unequip_btn)

		# Filter: only show items in the expedition pool that the soldier can equip.
		var all_for_slot := GameState.get_owned_items_for_slot(slot)
		var owned: Array[ItemData] = []
		for item in all_for_slot:
			if not DungeonState.expedition_pool.has(item):
				continue
			if not (item.classes.is_empty() or sol.soldier_class in item.classes):
				continue
			owned.append(item)
		for item in owned:
			var item_row := HBoxContainer.new()
			item_row.add_theme_constant_override("separation", 8)
			vbox.add_child(item_row)

			var item_lbl := Label.new()
			item_lbl.text = "  → %s — %s" % [item.item_name, item.get_stats_display()]
			item_lbl.custom_minimum_size = Vector2(420, 0)
			item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			item_row.add_child(item_lbl)

			var equip_btn := Button.new()
			equip_btn.text = "Equip"
			equip_btn.custom_minimum_size = Vector2(80, 28)
			equip_btn.pressed.connect(func():
				var saved_scroll := scroll.scroll_vertical
				GameState.equip_owned_item(sol, item, slot)
				overlay.queue_free()
				call_deferred("_open_party_info_overlay", float(saved_scroll))
			)
			item_row.add_child(equip_btn)

	vbox.add_child(SkillLoadoutUI.build(sol, alloc_refresh))

	if not sol.traits.is_empty():
		var traits_hdr := Label.new()
		traits_hdr.text = "Traits:"
		traits_hdr.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
		vbox.add_child(traits_hdr)
		for trait_item in sol.traits:
			var tr_lbl := Label.new()
			tr_lbl.text = "  • %s — %s" % [trait_item.trait_name, trait_item.description.substr(0, 60)]
			tr_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
			tr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			tr_lbl.custom_minimum_size = Vector2(820, 0)
			vbox.add_child(tr_lbl)

	return card
