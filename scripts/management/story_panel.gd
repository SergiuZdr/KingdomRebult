# res://scripts/management/story_panel.gd
# Story tab content — diplomacy faction cards + letters. Extracted from
# hub_screen.gd so the 2,300-line hub script doesn't keep growing. The hub
# instances this as the VBoxContainer inside its Story ScrollContainer and
# calls rebuild() whenever the tab is opened or underlying state changes.
class_name StoryPanel
extends VBoxContainer

## Emitted whenever letters are read/marked, so the hub can refresh its tab badge.
signal letters_changed

# Faction ids that get a dedicated crest card, in display order.
const CARD_FACTIONS: Array[String] = ["wardens", "iron_legion", "pale_court"]

const CARD_DISPLAY := {
	"wardens":     "The Wardens",
	"iron_legion": "Iron Legion",
	"pale_court":  "The Pale Court",
}

# Authored faction crest art (NEW assets, generated later) — keyed by faction id.
const CREST_ICON_DIR := "res://assets/icons/factions/"
const CREST_ICON_FILES := {
	"wardens":     "wardens.png",
	"iron_legion": "iron_legion.png",
	"pale_court":  "pale_court.png",
}

const TIER_LABELS: Array[String] = ["Hostile", "Cold", "Neutral", "Friendly", "Allied"]
const TIER_MINS: Array[int] = [0, 20, 40, 60, 76]
const TIER_MAXES: Array[int] = [20, 40, 60, 76, 100]
# Muted to match FactionState.get_standing_color()'s parchment-palette ladder
# (no neon greens/yellows on the standing bar segments).
const TIER_COLORS: Array[Color] = [
	GameTheme.WAX,
	GameTheme.LEATHER,
	Color("#a39456"),
	GameTheme.MOSS,
	Color("#74875a"),
]


func _ready() -> void:
	add_theme_constant_override("separation", 6)


## Clears and rebuilds the entire Story tab.
func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	_build_status_strip()
	_build_rivalry_warning()
	_build_faction_cards()
	add_child(HSeparator.new())
	_build_letters_section()


# ---------------------------------------------------------------------------
# Status strip — "Diplomatic action this turn: Available/Used"
# ---------------------------------------------------------------------------
func _build_status_strip() -> void:
	var strip := UIKit.sunken_strip()
	var actions_remaining: int = 1 if FactionState.can_use_diplomatic_action() else 0

	var lbl := Label.new()
	lbl.text = "Diplomatic action this turn: %s" % ("Available" if actions_remaining > 0 else "Used")
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color",
		GameTheme.MOSS if actions_remaining > 0 else GameTheme.INK_SOFT)
	strip.add_child(lbl)

	add_child(strip)


# ---------------------------------------------------------------------------
# Rivalry warning
# ---------------------------------------------------------------------------
func _build_rivalry_warning() -> void:
	var w := FactionState.wardens_standing
	var il := FactionState.iron_legion_standing
	if w >= 55 or il >= 55:
		var rivalry_lbl := Label.new()
		rivalry_lbl.text = "Rivalry: Wardens and Iron Legion cannot both reach Friendly (61+) simultaneously."
		rivalry_lbl.add_theme_font_size_override("font_size", 11)
		rivalry_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
		rivalry_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		add_child(rivalry_lbl)


# ---------------------------------------------------------------------------
# Faction crest cards
# ---------------------------------------------------------------------------
func _build_faction_cards() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(row)

	for faction_id in CARD_FACTIONS:
		row.add_child(_build_faction_card(faction_id))

	# Audit: any DIPLOMACY_ACTIONS entries for non-card factions (e.g. "cross",
	# "king_aldric") get an "Other envoys" row so they're not silently dropped.
	var other_actions: Array[Dictionary] = []
	for action: Dictionary in FactionEvents.DIPLOMACY_ACTIONS:
		var faction: String = action.get("faction", "")
		if not CARD_FACTIONS.has(faction):
			other_actions.append(action)

	if not other_actions.is_empty():
		var other_header := UIKit.section_header("Other Envoys")
		add_child(other_header)
		for action in other_actions:
			add_child(_make_diplomacy_button(action))


func _build_faction_card(faction_id: String) -> PanelContainer:
	var card := UIKit.themed_card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Dedicated pixel-art card frame takes priority once the user generates it.
	if ResourceLoader.exists("res://assets/ui/city/frames/card_frame.png"):
		card.add_theme_stylebox_override("panel",
			PixelUI.tex_stylebox_frame("res://assets/ui/city/frames/card_frame.png",
				Rect2(2, 1, 92, 93), 14, 16))
	# Keep the Card stylebox's torn-paper frame AND its content margins intact —
	# the same card.png 9-slice the tavern recruit cards use. The faction-colored
	# header strip sits inside that content area (slightly inset from the frame),
	# which reads as intentional on parchment rather than cropping the texture.

	var standing: int = _get_standing(faction_id)
	var faction_color: Color = FactionEvents.FACTION_COLORS.get(faction_id, Color(0.8, 0.8, 0.8))

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card.add_child(card_vbox)

	# --- Header strip: faction-colored band with crest, name, standing ---
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel",
		PixelUI.nameplate_stylebox(faction_color.darkened(0.55)))
	card_vbox.add_child(header_panel)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	header_panel.add_child(header)

	header.add_child(_build_crest_icon(faction_id, faction_color, 28))

	var name_lbl := Label.new()
	name_lbl.text = CARD_DISPLAY.get(faction_id, faction_id.capitalize())
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", faction_color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(name_lbl)

	# Standing value, right-aligned in the header.
	var standing_lbl := Label.new()
	standing_lbl.text = "%s (%d)" % [FactionState.get_standing_label(standing), standing]
	standing_lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)
	standing_lbl.add_theme_font_size_override("font_size", 12)
	standing_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(standing_lbl)

	# --- Body --- (the Card stylebox already supplies ~12px of frame padding
	# around card_vbox, so the body only needs a small top gap below the header)
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 0)
	body_margin.add_theme_constant_override("margin_right", 0)
	body_margin.add_theme_constant_override("margin_top", 2)
	body_margin.add_theme_constant_override("margin_bottom", 0)
	card_vbox.add_child(body_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	body_margin.add_child(vbox)

	# 12px-tall standing bar with current-value marker + tier name.
	vbox.add_child(_build_standing_bar(standing))

	var tier_lbl := Label.new()
	tier_lbl.text = FactionState.get_standing_label(standing)
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.add_theme_color_override("font_color", FactionState.get_standing_color(standing))
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tier_lbl)

	# Effects lines, inside a fixed-height box so the separator and diplomacy
	# buttons below sit at the SAME y across all three faction cards regardless
	# of how many active bonuses each faction has.
	var effects_box := VBoxContainer.new()
	effects_box.add_theme_constant_override("separation", 2)
	effects_box.custom_minimum_size = Vector2(0, 56)
	for line in _get_effects(faction_id):
		var effect_lbl := Label.new()
		effect_lbl.text = "- %s" % line
		effect_lbl.add_theme_font_size_override("font_size", 11)
		effect_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		effects_box.add_child(effect_lbl)
	vbox.add_child(effects_box)

	vbox.add_child(HSeparator.new())

	# This faction's diplomacy actions, full-width compact buttons.
	var has_action := false
	for action: Dictionary in FactionEvents.DIPLOMACY_ACTIONS:
		if action.get("faction", "") == faction_id:
			vbox.add_child(_make_diplomacy_button(action))
			has_action = true

	if not has_action:
		var none_lbl := Label.new()
		none_lbl.text = "No envoys available."
		none_lbl.add_theme_font_size_override("font_size", 11)
		none_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		vbox.add_child(none_lbl)

	return card


## A faction crest at `px` size — authored art from assets/icons/factions/ if
## present, else the code-drawn CrestIcon shield placeholder.
func _build_crest_icon(faction_id: String, faction_color: Color, px: int) -> Control:
	var fname: String = CREST_ICON_FILES.get(faction_id, "")
	if fname != "":
		var path := CREST_ICON_DIR + fname
		if ResourceLoader.exists(path):
			return UIKit.icon(path, px)

	var crest := CrestIcon.new()
	crest.crest_color = faction_color
	crest.custom_minimum_size = Vector2(px, px)
	return crest


## A 12px-tall, 5-segment standing bar (one segment per tier) with a small
## WAX marker notch positioned at the current standing value across the full
## 0-100 span. Returned as a Control wrapper so the marker can overlay the
## segment row.
func _build_standing_bar(standing: int) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(0, 16)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var track_row := HBoxContainer.new()
	track_row.add_theme_constant_override("separation", 2)
	track_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(track_row)

	for i in 5:
		var seg_bar := ProgressBar.new()
		seg_bar.min_value = TIER_MINS[i]
		seg_bar.max_value = TIER_MAXES[i]
		seg_bar.value = clampi(standing, TIER_MINS[i], TIER_MAXES[i])
		seg_bar.show_percentage = false
		seg_bar.custom_minimum_size = Vector2(0, 12)
		seg_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seg_bar.tooltip_text = TIER_LABELS[i]

		var seg_fill := StyleBoxFlat.new()
		seg_fill.bg_color = TIER_COLORS[i] if standing >= TIER_MINS[i] else GameTheme.INK_SOFT
		seg_bar.add_theme_stylebox_override("fill", seg_fill)

		var seg_bg := StyleBoxFlat.new()
		seg_bg.bg_color = GameTheme.PARCH_SHADE
		seg_bar.add_theme_stylebox_override("background", seg_bg)

		track_row.add_child(seg_bar)

	var marker := StandingMarker.new()
	marker.standing = standing
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(marker)

	return wrapper


func _get_standing(faction_id: String) -> int:
	match faction_id:
		"wardens": return FactionState.wardens_standing
		"iron_legion": return FactionState.iron_legion_standing
		"pale_court": return FactionState.pale_court_standing
		_: return 0


func _get_effects(faction_id: String) -> Array[String]:
	match faction_id:
		"wardens": return FactionState.get_wardens_effects_text()
		"iron_legion": return FactionState.get_iron_legion_effects_text()
		"pale_court": return FactionState.get_pale_court_effects_text()
		_: return []


# ---------------------------------------------------------------------------
# Diplomacy action button — disabled-state logic kept verbatim from the
# original _make_diplomacy_button (cooldown/afford/requirements/slot).
# Cost, preview, and flavor text moved into the tooltip.
# ---------------------------------------------------------------------------
func _make_diplomacy_button(action: Dictionary) -> Button:
	var action_id: String  = action.get("id", "")
	var label_text: String = action.get("label", "")
	var cost: Dictionary   = action.get("cost", {})
	var preview: String    = action.get("preview", "")
	var flavor: String     = action.get("flavor", "")
	var faction: String    = action.get("faction", "")

	var on_cooldown: bool       = FactionEvents.is_action_on_cooldown(action_id)
	var cd_remaining: int       = FactionEvents.get_cooldown_remaining(action_id)
	var req_met: bool           = FactionEvents.is_action_requirement_met(action_id)
	var action_slot_free: bool  = FactionState.can_use_diplomatic_action()

	var can_afford: bool = true
	if not on_cooldown and req_met:
		for res_key in cost:
			var needed: int = int(cost[res_key])
			match res_key:
				"gold":  if GameState.gold  < needed: can_afford = false
				"food":  if GameState.food  < needed: can_afford = false
				"iron":  if GameState.iron  < needed: can_afford = false
				"steel": if GameState.steel < needed: can_afford = false

	var cost_parts: Array[String] = []
	for res_key in cost:
		if int(cost[res_key]) > 0:
			cost_parts.append("%d %s" % [int(cost[res_key]), res_key.capitalize()])
	var cost_str: String = "Free" if cost_parts.is_empty() else ", ".join(cost_parts)

	var btn := Button.new()
	# "Ghost" (flat) fallback — the button00-03.png 9-slice corner art smears
	# when stretched across a wide, EXPAND_FILL button like these.
	btn.theme_type_variation = "Ghost"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.add_theme_font_size_override("font_size", 14)

	# Faction crest prefix (NEW asset, falls back to no icon if missing).
	var crest_path: String = CREST_ICON_DIR + CREST_ICON_FILES.get(faction, "")
	if CREST_ICON_FILES.has(faction) and ResourceLoader.exists(crest_path):
		btn.icon = load(crest_path) as Texture2D
		btn.expand_icon = false
		btn.add_theme_constant_override("icon_max_width", 18)
		btn.add_theme_constant_override("h_separation", 8)

	var tooltip := "Cost: %s  |  %s" % [cost_str, preview]
	if not flavor.is_empty():
		tooltip += "\n%s" % flavor
	btn.tooltip_text = tooltip

	if on_cooldown:
		btn.text = "%s (ready in %d turn%s)" % [label_text, cd_remaining, "s" if cd_remaining != 1 else ""]
		btn.disabled = true
	elif not req_met:
		btn.text = "%s (requirements not met)" % label_text
		btn.disabled = true
		btn.add_theme_color_override("font_color", GameTheme.LEATHER)
		btn.add_theme_color_override("font_disabled_color", GameTheme.LEATHER)
	elif not can_afford:
		btn.text = "%s (cannot afford)" % label_text
		btn.disabled = true
		btn.add_theme_color_override("font_color", GameTheme.CRIMSON)
		btn.add_theme_color_override("font_disabled_color", GameTheme.CRIMSON)
	elif not action_slot_free:
		btn.text = "%s (used this turn)" % label_text
		btn.disabled = true
		btn.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		btn.add_theme_color_override("font_disabled_color", GameTheme.INK_SOFT)
	else:
		btn.text = "%s (%s)" % [label_text, cost_str]
		btn.disabled = false
		# No font override: the Ghost variant's parchment-on-dark text reads
		# far better than bright faction colors; the crest carries identity.
		var captured_id: String = action_id
		btn.pressed.connect(func():
			if FactionEvents.resolve_diplomacy_action(captured_id):
				rebuild()
		)

	return btn


# ---------------------------------------------------------------------------
# Letters
# ---------------------------------------------------------------------------
func _build_letters_section() -> void:
	add_child(UIKit.banner_header("Letters"))

	var letters: Array = StoryManager.letters

	if letters.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No letters received yet."
		empty_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		add_child(empty_lbl)
		return

	var mark_all_btn := Button.new()
	mark_all_btn.text = "Mark All Read"
	mark_all_btn.custom_minimum_size = Vector2(160, 34)
	mark_all_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark_all_btn.pressed.connect(func():
		StoryManager.mark_all_read()
		rebuild()
		letters_changed.emit()
	)
	add_child(mark_all_btn)

	# Newest first
	var sorted_letters: Array = letters.duplicate()
	sorted_letters.reverse()

	for letter in sorted_letters:
		add_child(_build_letter_row(letter))


## Maps a letter's sender to a faction-tinted accent colour. Letters carry a
## "sender_tag" matching FactionEvents.FACTION_COLORS keys (faction ids, plus
## "cross"/"king_aldric" for non-faction senders); unknown senders fall back
## to LEATHER (parchment-ink neutral).
func _get_sender_color(letter: Dictionary) -> Color:
	var tag: String = letter.get("sender_tag", "")
	if tag != "" and FactionEvents.FACTION_COLORS.has(tag):
		return FactionEvents.FACTION_COLORS[tag]
	return GameTheme.LEATHER


func _build_letter_row(letter: Dictionary) -> PanelContainer:
	var is_read: bool = letter.get("read", false)
	var sender_color: Color = _get_sender_color(letter)

	# Same textured card.png frame as the faction cards — letters sit on
	# parchment, not a flat slab. Unread letters get a brighter modulate so
	# the frame itself reads as "fresh"; read letters are dimmed slightly.
	var letter_panel := UIKit.themed_card()
	var card_style: StyleBox = letter_panel.get_theme_stylebox("panel")
	if card_style is StyleBoxTexture:
		var dup_style: StyleBoxTexture = card_style.duplicate()
		dup_style.modulate_color = Color(1, 1, 1) if not is_read else Color(0.88, 0.86, 0.8)
		letter_panel.add_theme_stylebox_override("panel", dup_style)
	elif card_style is StyleBoxFlat:
		var dup_flat: StyleBoxFlat = card_style.duplicate()
		dup_flat.bg_color = GameTheme.VELLUM if not is_read else GameTheme.PARCH_SHADE
		dup_flat.border_color = GameTheme.LEATHER if not is_read else GameTheme.IRON
		letter_panel.add_theme_stylebox_override("panel", dup_flat)

	# Sender/faction-colored accent strip spanning the full row height —
	# replaces the old border_width_left (StyleBoxTexture doesn't support flat
	# border colors). Wider for unread letters so they stand out without
	# dropping the card texture.
	var row_hbox := HBoxContainer.new()
	row_hbox.add_theme_constant_override("separation", 8)
	letter_panel.add_child(row_hbox)

	var accent := ColorRect.new()
	accent.color = sender_color
	accent.custom_minimum_size = Vector2(4 if not is_read else 3, 0)
	row_hbox.add_child(accent)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_hbox.add_child(outer_vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(header_hbox)

	# Unread indicator: small WAX-background "NEW" chip (not a glyph — pixel
	# font may lack ✉).
	var new_chip := PanelContainer.new()
	var new_chip_style := StyleBoxFlat.new()
	new_chip_style.bg_color = GameTheme.WAX
	new_chip_style.content_margin_left = 5
	new_chip_style.content_margin_right = 5
	new_chip_style.content_margin_top = 1
	new_chip_style.content_margin_bottom = 1
	new_chip.add_theme_stylebox_override("panel", new_chip_style)
	new_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	new_chip.visible = not is_read
	var new_lbl := Label.new()
	new_lbl.text = "NEW"
	new_lbl.add_theme_font_size_override("font_size", 10)
	new_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	new_chip.add_child(new_lbl)
	header_hbox.add_child(new_chip)

	var subject_lbl := Label.new()
	subject_lbl.text = letter.get("subject", "(no subject)")
	subject_lbl.add_theme_font_size_override("font_size", 15)
	if is_read:
		subject_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	subject_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(subject_lbl)

	var sender_lbl := Label.new()
	sender_lbl.text = "from %s" % letter.get("sender", "Unknown")
	sender_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	header_hbox.add_child(sender_lbl)

	var turn_lbl := Label.new()
	turn_lbl.text = "Turn %d" % letter.get("turn_received", 0)
	turn_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	turn_lbl.add_theme_font_size_override("font_size", 11)
	header_hbox.add_child(turn_lbl)

	var body_lbl := Label.new()
	body_lbl.text = letter.get("body", "")
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.visible = false
	outer_vbox.add_child(body_lbl)

	# Toggle button — sits in the header row so it is always visible and clickable.
	var toggle_btn := Button.new()
	toggle_btn.flat = true
	toggle_btn.text = "▶ Read"
	toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle_btn.custom_minimum_size = Vector2(80, 0)
	header_hbox.add_child(toggle_btn)

	var captured_letter: Dictionary = letter
	var captured_body_lbl: Label = body_lbl
	var captured_new_chip: PanelContainer = new_chip
	var captured_btn: Button = toggle_btn
	toggle_btn.pressed.connect(func():
		captured_body_lbl.visible = not captured_body_lbl.visible
		captured_btn.text = "▼ Close" if captured_body_lbl.visible else "▶ Read"
		if not captured_letter.get("read", false):
			captured_letter["read"] = true
			captured_new_chip.visible = false
			if captured_letter.has("id"):
				StoryManager.mark_read(captured_letter.id)
			FactionState.on_letter_read(captured_letter.get("sender", ""))
			letters_changed.emit()
	)

	return letter_panel


# ---------------------------------------------------------------------------
# Inner class: code-drawn faction crest (shield) placeholder.
# ---------------------------------------------------------------------------
class CrestIcon:
	extends Control

	var crest_color: Color = Color(0.8, 0.8, 0.8)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var points := PackedVector2Array([
			Vector2(w * 0.5, 0),
			Vector2(w, h * 0.18),
			Vector2(w, h * 0.55),
			Vector2(w * 0.5, h),
			Vector2(0, h * 0.55),
			Vector2(0, h * 0.18),
		])
		draw_colored_polygon(points, crest_color)
		draw_polyline(points + PackedVector2Array([points[0]]), GameTheme.INK, 1.5, true)


# ---------------------------------------------------------------------------
# Inner class: thin WAX notch marking the current standing value (0-100) on
# the standing bar. Redraws on resize so it tracks the bar's actual width.
# ---------------------------------------------------------------------------
class StandingMarker:
	extends Control

	var standing: int = 0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var x: float = clampf(float(standing) / 100.0, 0.0, 1.0) * w
		# Small downward-pointing triangle notch sitting on top of the bar.
		var points := PackedVector2Array([
			Vector2(x - 3, 0),
			Vector2(x + 3, 0),
			Vector2(x, h * 0.5),
		])
		draw_colored_polygon(points, GameTheme.WAX)
