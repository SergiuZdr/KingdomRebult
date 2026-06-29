# res://scripts/ui/faction_event_popup.gd
# Popup that presents a single faction event to the player and waits for a
# choice. Entirely signal-driven — never blocks the main thread.
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal choice_made(event_id: String, choice_index: int)

# ---------------------------------------------------------------------------
# Node references
# ---------------------------------------------------------------------------
@onready var _faction_label: Label         = $Wrapper/Center/Panel/Margin/RootVBox/FactionLabel
@onready var _title_label: Label           = $Wrapper/Center/Panel/Margin/RootVBox/TitleLabel
@onready var _body_label: Label            = $Wrapper/Center/Panel/Margin/RootVBox/BodyScroll/BodyLabel
@onready var _choices_container: VBoxContainer = $Wrapper/Center/Panel/Margin/RootVBox/ChoicesContainer

# Tracks the event currently being shown
var _current_event_id: String = ""

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	$Wrapper.theme = GameTheme.get_theme()
	# Lighter parchment frame — the ornate wood frame's busy tiled center made
	# the long event body text hard to read. Flat parchment center is clean.
	var frame_sb := PixelUI.parchment_window_stylebox(22)
	if frame_sb != null:
		$Wrapper/Center/Panel.add_theme_stylebox_override("panel", frame_sb)
	hide()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
func show_event(event: Dictionary) -> void:
	_current_event_id = event.get("id", "")

	# Faction label — only shown for events tied to a faction. Generic events
	# (faction == "") hide it entirely instead of printing an empty "[]".
	# The color is the faction tint darkened so it reads on the parchment frame.
	var faction: String = event.get("faction", "")
	_faction_label.visible = faction != ""
	if _faction_label.visible:
		_faction_label.text = "[%s]" % _faction_display_name(faction)
		var faction_color: Color = FactionEvents.FACTION_COLORS.get(faction, Color(0.8, 0.8, 0.8))
		_faction_label.add_theme_color_override("font_color", faction_color.darkened(0.45))

	# Title
	_title_label.text = event.get("title", "")

	# Body
	_body_label.text = event.get("body", "")

	# Clear old choice buttons
	for child in _choices_container.get_children():
		child.queue_free()

	# Build choice buttons
	var choices: Array = event.get("choices", [])
	var event_type: String = event.get("type", "")
	for idx: int in choices.size():
		var choice: Dictionary = choices[idx]
		var choice_vbox := VBoxContainer.new()
		choice_vbox.add_theme_constant_override("separation", 2)

		# Determine whether this choice is locked by a game-state condition.
		var lock_condition: String = choice.get("lock_condition", "")
		var is_locked: bool = (lock_condition != "") and (event_type == "game_event") and _is_condition_locked(lock_condition)
		# Or locked because the player cannot pay the choice's resource cost.
		var afford_reason: String = ""
		if not is_locked:
			afford_reason = FactionEvents.choice_afford_reason(choice)
			if afford_reason != "":
				is_locked = true

		var btn := Button.new()
		btn.text = choice.get("label", "")
		btn.custom_minimum_size = Vector2(640, 48)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.disabled = is_locked   # themed rust button (normal/hover/disabled from GameTheme)

		if not is_locked:
			var captured_idx: int = idx
			var captured_id: String = _current_event_id
			btn.pressed.connect(func(): _on_choice_pressed(captured_id, captured_idx))

		choice_vbox.add_child(btn)

		# Lock reason label (shown instead of preview when locked)
		if is_locked:
			var lock_lbl := Label.new()
			var reason: String = afford_reason if afford_reason != "" else choice.get("lock_reason", "Requirements not met")
			lock_lbl.text = "[Locked] %s" % reason
			lock_lbl.add_theme_font_size_override("font_size", 11)
			lock_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON if afford_reason != "" else GameTheme.LEATHER)
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			choice_vbox.add_child(lock_lbl)
		else:
			# Preview / effects line
			var preview: String = choice.get("preview", "")
			if not preview.is_empty():
				var preview_lbl := Label.new()
				preview_lbl.text = preview
				preview_lbl.add_theme_font_size_override("font_size", 11)
				preview_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
				preview_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				choice_vbox.add_child(preview_lbl)

		_choices_container.add_child(choice_vbox)

	show()
	UIKit.fade_in($Wrapper/Center/Panel)

func _on_choice_pressed(event_id: String, choice_index: int) -> void:
	hide()
	emit_signal("choice_made", event_id, choice_index)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _faction_display_name(faction: String) -> String:
	match faction:
		"wardens":     return "The Wardens"
		"iron_legion": return "Iron Legion"
		"pale_court":  return "The Pale Court"
		"cross":       return "Multiple Factions"
		"king_aldric": return "King Aldric"
	return faction.capitalize()

func _is_condition_locked(condition: String) -> bool:
	match condition:
		"iron_legion_40": return FactionState.iron_legion_standing < 40
		"wardens_30":     return FactionState.wardens_standing < 30
		"gold_100":       return GameState.gold < 100
		"dungeon_3":      return DungeonState.dungeon_level < 3
		"no_soldiers":    return GameState.soldiers.size() <= 0
		"workers_at_max": return GameState.workforce_total >= GameState.workforce_cap
	return false
