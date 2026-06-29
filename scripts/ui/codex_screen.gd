# res://scripts/ui/codex_screen.gd
# Codex / Help overlay — a scrollable, sectioned reference explaining the game's
# systems for new players. Built fully in code to match the rest of the hub UI.
# Instanced once by hub_screen and shown via open(); hidden by default.
extends CanvasLayer

var _root: Control
var _sections_vbox: VBoxContainer

# Static reference content. "How to Win" is generated live in _build_sections()
# from GameState.get_objectives_progress() so it never drifts from the real targets.
const SECTIONS: Array = [
	{
		"title": "Your Mission",
		"body": "You are the prince, sent by your father the king to rebuild the ruined city of Ostrava and hold it against the forces that destroyed it once before. Rebuild from the rubble, raise an army, descend into the dungeon beneath the city, and survive long enough for the king to arrive.",
	},
	{
		"title": "Resources",
		"body": "Gold pays for rebuilding, recruiting, upgrades, and trade.\nWood and Stone are raw materials for rebuilding and upgrading buildings.\nIron is mined ore, processed into Steel and used in crafting.\nSteel is refined from Iron at the Steel Forge; needed for stronger gear.\nFood is consumed every turn by your soldiers. Run out and morale falls.",
	},
	{
		"title": "Workforce & Houses",
		"body": "Your People are the workers you assign to buildings to make them produce. A building does nothing without workers. Your total workforce is capped, so build and upgrade Houses to raise the cap and recruit more workers (each new worker costs Gold and Food).",
	},
	{
		"title": "Morale",
		"body": "Morale reflects your soldiers' spirit. High morale improves their hit chance in battle; low morale weakens them. Keep your army fed and win battles to keep morale up. Starvation, defeats, and losing walls all drain it.",
	},
	{
		"title": "Threat & Waves",
		"body": "The Threat bar rises every turn. When it fills, an enemy wave attacks your walls. Win the defense to push it back; lose and you lose a wall. If your walls reach zero, the city falls and the game is over. Watch the bar and prepare your soldiers before it fills. Every fifth wave is a tougher boss wave.",
	},
	{
		"title": "Buildings",
		"body": "Buildings start as ruins. Rebuild them with Gold, Wood, and Stone, then assign workers to produce. Categories: Resource Obtaining (Farm, Forest, Quarry, Iron Mine), Resource Processing (Steel Forge, Butchery), Military (Barracks, Training Grounds), Construction (Blacksmith), and Special (Market, Tavern, House). Upgrade buildings to increase their output.",
	},
	{
		"title": "Soldiers & Combat",
		"body": "Recruit soldiers at the Tavern and equip them with gear from the Market or Blacksmith. Battles are turn-based: each unit acts in turn order. Attack, Defend (reduce incoming damage), or use a Skill (hover a skill for its description; skills have cooldowns). Soldiers earn XP and level up; the Training Grounds grants XP between battles.",
	},
	{
		"title": "Dungeon Expeditions",
		"body": "Send soldiers into the dungeon beneath the city. They enter on your next End Turn and explore room by room: monsters, elites, bosses, healing fountains, and markets selling gear and permanent traits. Clearing the boss advances the dungeon level. Soldiers sent below cannot defend the city, so leave a garrison behind.",
	},
	{
		"title": "Factions",
		"body": "Three powers watch your city: the Iron Legion, the Wardens, and the Pale Court. Your choices in events shift your standing with each. Reaching a high standing with one shapes how your story ends. The Wardens and the Iron Legion will not both befriend you at once.",
	},
]


func _ready() -> void:
	layer = 90
	_build_ui()
	visible = false


func _build_ui() -> void:
	# Dimmer
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.7)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameTheme.get_theme()
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 560)
	# Uses the themed stone frame from GameTheme (no inline stylebox).
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Codex: How to Play"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GameTheme.LEATHER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 36)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 460)
	vbox.add_child(scroll)

	_sections_vbox = VBoxContainer.new()
	_sections_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(_sections_vbox)


func _build_sections() -> void:
	for child in _sections_vbox.get_children():
		child.queue_free()

	# Live "How to Win" section from the shared objectives source.
	_add_section("How to Win", _win_condition_text())

	for s in SECTIONS:
		_add_section(s["title"], s["body"])


func _win_condition_text() -> String:
	var lines: Array = ["Achieve all of the following, then hold until the king arrives:"]
	for row in GameState.get_objectives_progress():
		var mark := "[x]" if row["done"] else "[ ]"
		lines.append("  %s %s  (%d/%d)" % [mark, row["label"], row["current"], row["target"]])
	return "\n".join(lines)


func _add_section(title: String, body: String) -> void:
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
	_sections_vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.add_theme_color_override("font_color", GameTheme.INK)
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections_vbox.add_child(body_lbl)


func open() -> void:
	_build_sections()   # rebuild so the live win-progress is current
	visible = true
	UIKit.fade_in(_root)


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
