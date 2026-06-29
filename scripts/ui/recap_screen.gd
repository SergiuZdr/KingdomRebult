# recap_screen.gd
# Turn recap shown after End Turn, before faction event popups.
# All UI nodes live in recap_screen.tscn; this script only references them
# via @onready and fills the data-driven sections.
extends CanvasLayer

# --- Header ---
@onready var title_label: Label = $Panel/Root/Header/HeaderRow/Title
@onready var net_summary: Label = $Panel/Root/Header/HeaderRow/NetSummary

# --- Threat section ---
@onready var threat_value: Label = $Panel/Root/Body/BodyColumn/ThreatSection/ThreatHeaderRow/ThreatValue
@onready var threat_bar: ProgressBar = $Panel/Root/Body/BodyColumn/ThreatSection/ThreatBar
@onready var threat_forecast: Label = $Panel/Root/Body/BodyColumn/ThreatSection/ThreatForecast

# --- Faction section ---
@onready var faction_section: VBoxContainer = $Panel/Root/Body/BodyColumn/FactionSection
@onready var faction_list: VBoxContainer = $Panel/Root/Body/BodyColumn/FactionSection/FactionList

# --- Resource section ---
@onready var resource_section: VBoxContainer = $Panel/Root/Body/BodyColumn/ResourceSection
@onready var resource_grid: GridContainer = $Panel/Root/Body/BodyColumn/ResourceSection/ResourceGrid

# --- Events ("This Turn") section ---
@onready var recap_list: VBoxContainer = $Panel/Root/Body/BodyColumn/EventsSection/ScrollContainer/RecapList
@onready var events_scroll: ScrollContainer = $Panel/Root/Body/BodyColumn/EventsSection/ScrollContainer
@onready var recap_panel: PanelContainer = $Panel

# --- Footer ---
@onready var btn_continue: Button = $Panel/Root/Footer/FooterRow/BtnContinue

# Repointed to the shared ruined-city palette so the recap matches every other screen.
const COLOR_PARCHMENT := GameTheme.INK
const COLOR_MUTED := GameTheme.INK_SOFT
const COLOR_GAIN := GameTheme.MOSS
const COLOR_LOSS := GameTheme.CRIMSON
const COLOR_WARN := GameTheme.LEATHER
const COLOR_GOLD := GameTheme.CRIMSON

# Threat fill colors: calm below 50%, warning 50-79%, danger 80%+.
const THREAT_CALM := GameTheme.IRON
const THREAT_WARN := GameTheme.LEATHER
const THREAT_DANGER := GameTheme.WAX

const RESOURCE_ORDER: Array[String] = ["Gold", "Wood", "Stone", "Iron", "Steel", "Food", "Morale"]

func _ready() -> void:
	$Panel.theme = GameTheme.get_theme()
	_recolor_styleboxes()
	# Lighter parchment window frame — the heavy wood frame read as unpolished
	# for a big text document. Slim torn-paper border, flat readable center.
	var frame_sb := PixelUI.parchment_window_stylebox(10)
	if frame_sb != null:
		$Panel.add_theme_stylebox_override("panel", frame_sb)
	btn_continue.pressed.connect(_on_continue)
	GameState.recap_ready.connect(_on_recap_ready)
	hide()

# ---------------------------------------------------------------------------
# Repoint the .tscn's hardcoded StyleBoxFlat colors to GameTheme constants so
# the recap stays in sync with the rest of the parchment UI. Each stylebox is
# duplicated before mutation since some SubResources are shared between nodes
# (Header + Footer, and the three BtnContinue states).
# ---------------------------------------------------------------------------
func _recolor_styleboxes() -> void:
	# Main panel — parchment face, iron-highlight border.
	var panel_sb := ($Panel.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	panel_sb.bg_color = GameTheme.PARCHMENT
	panel_sb.border_color = Color(GameTheme.IRON_HI.r, GameTheme.IRON_HI.g, GameTheme.IRON_HI.b, 0.470588)
	$Panel.add_theme_stylebox_override("panel", panel_sb)

	# Header banner — crimson cloth strip.
	var header := $Panel/Root/Header
	var header_sb := (header.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	header_sb.bg_color = GameTheme.CRIMSON
	header_sb.border_color = Color(GameTheme.IRON_HI.r, GameTheme.IRON_HI.g, GameTheme.IRON_HI.b, 0.392157)
	header.add_theme_stylebox_override("panel", header_sb)

	# Footer — same crimson banner look as the header (separate SubResource instance).
	var footer := $Panel/Root/Footer
	var footer_sb := (footer.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	footer_sb.bg_color = GameTheme.CRIMSON
	footer_sb.border_color = Color(GameTheme.IRON_HI.r, GameTheme.IRON_HI.g, GameTheme.IRON_HI.b, 0.392157)
	footer.add_theme_stylebox_override("panel", footer_sb)

	# Threat bar trough — sunken parchment shade. Border kept as authored (no
	# matching GameTheme constant for the dark outline).
	var threat_bg := (threat_bar.get_theme_stylebox("background") as StyleBoxFlat).duplicate() as StyleBoxFlat
	threat_bg.bg_color = GameTheme.PARCH_SHADE
	threat_bar.add_theme_stylebox_override("background", threat_bg)

	# Threat bar fill — default to the "calm" tint; _populate_threat() repaints
	# this per-turn based on the threat percentage.
	var threat_fill := (threat_bar.get_theme_stylebox("fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
	threat_fill.bg_color = THREAT_CALM
	threat_bar.add_theme_stylebox_override("fill", threat_fill)

	# Continue button — crimson action fill, iron-highlight border, all states share one look.
	var continue_sb := (btn_continue.get_theme_stylebox("normal") as StyleBoxFlat).duplicate() as StyleBoxFlat
	continue_sb.bg_color = GameTheme.CRIMSON
	continue_sb.border_color = Color(GameTheme.IRON_HI.r, GameTheme.IRON_HI.g, GameTheme.IRON_HI.b, 0.627451)
	btn_continue.add_theme_stylebox_override("normal", continue_sb)
	btn_continue.add_theme_stylebox_override("hover", continue_sb)
	btn_continue.add_theme_stylebox_override("pressed", continue_sb)

func _on_recap_ready() -> void:
	title_label.text = "Turn %d Recap" % GameState.current_turn
	net_summary.text = _build_net_summary_text()
	_populate_threat()
	_populate_factions()
	_populate_resources()
	_populate_events(GameState.turn_recap)
	show()
	UIKit.fade_in($Panel)
	GameState.menu_open = true
	_fit_panel_to_content()

# Shrink the window to its content so quiet turns don't leave a tall empty void.
# A long event log is capped and scrolls instead of stretching the panel.
func _fit_panel_to_content() -> void:
	await get_tree().process_frame
	var list_h: float = recap_list.get_combined_minimum_size().y
	events_scroll.custom_minimum_size.y = clampf(list_h, 0.0, 240.0)
	await get_tree().process_frame
	var h: float = clampf(recap_panel.get_combined_minimum_size().y, 240.0, 660.0)
	recap_panel.offset_top = -h * 0.5
	recap_panel.offset_bottom = h * 0.5

# ---------------------------------------------------------------------------
# Header net summary
# ---------------------------------------------------------------------------
func _build_net_summary_text() -> String:
	var deltas: Dictionary = GameState.last_turn_resource_deltas
	var parts: Array[String] = []
	for res in RESOURCE_ORDER:
		var d := int(deltas.get(res, 0))
		if d != 0:
			parts.append("%s %s%d" % [res, "+" if d > 0 else "", d])
	if parts.is_empty():
		return "No net change this turn"
	return "  ".join(parts)

# ---------------------------------------------------------------------------
# Threat bar
# ---------------------------------------------------------------------------
func _populate_threat() -> void:
	var threat := int(GameState.threat)
	var threat_max := int(GameState.threat_max)
	var pct: float = 0.0 if threat_max <= 0 else clampf(float(threat) / float(threat_max) * 100.0, 0.0, 100.0)

	threat_bar.max_value = 100.0
	threat_bar.value = pct
	threat_value.text = "%d%%" % int(round(pct))

	var fill_color := THREAT_CALM
	if pct >= 80.0:
		fill_color = THREAT_DANGER
		threat_value.add_theme_color_override("font_color", THREAT_DANGER)
	elif pct >= 50.0:
		fill_color = THREAT_WARN
		threat_value.add_theme_color_override("font_color", THREAT_WARN)
	else:
		threat_value.add_theme_color_override("font_color", COLOR_PARCHMENT)

	var fill_style := threat_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		(fill_style as StyleBoxFlat).bg_color = fill_color

	threat_forecast.text = _threat_forecast_text()

func _threat_forecast_text() -> String:
	var diff := int(GameState.combat_difficulty)
	var gain := int(GameState._get_threat_gain())
	var is_boss := diff > 0 and diff % 5 == 0
	var boss_tag := "   BOSS WAVE INCOMING" if is_boss else ""
	return "Difficulty %d   |   +%d threat/turn%s" % [diff, gain, boss_tag]

# ---------------------------------------------------------------------------
# Faction standing changes (only factions that moved this turn)
# ---------------------------------------------------------------------------
func _populate_factions() -> void:
	for child in faction_list.get_children():
		child.queue_free()

	var changes := FactionState.get_turn_standing_changes()
	if changes.is_empty():
		faction_section.hide()
		return

	faction_section.show()
	for change in changes:
		faction_list.add_child(_make_faction_row(change))

func _make_faction_row(change: Dictionary) -> Control:
	var faction_color: Color = change.get("color", COLOR_PARCHMENT)
	var delta := int(change.get("delta", 0))
	var value := int(change.get("value", 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Left color chip to identify the faction at a glance.
	var chip := ColorRect.new()
	chip.color = faction_color
	chip.custom_minimum_size = Vector2(4, 0)
	chip.size_flags_vertical = Control.SIZE_FILL
	row.add_child(chip)

	var name_lbl := Label.new()
	name_lbl.text = str(change.get("name", "Faction"))
	name_lbl.add_theme_color_override("font_color", faction_color)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var delta_lbl := Label.new()
	delta_lbl.text = "%s%d" % ["+" if delta > 0 else "", delta]
	delta_lbl.add_theme_color_override("font_color", COLOR_GAIN if delta > 0 else COLOR_LOSS)
	delta_lbl.add_theme_font_size_override("font_size", 14)
	delta_lbl.custom_minimum_size = Vector2(44, 0)
	delta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(delta_lbl)

	var standing_lbl := Label.new()
	standing_lbl.text = "%s (%d)" % [str(change.get("label", "")), value]
	standing_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	standing_lbl.add_theme_font_size_override("font_size", 13)
	standing_lbl.custom_minimum_size = Vector2(110, 0)
	standing_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(standing_lbl)

	return row

# ---------------------------------------------------------------------------
# Resource deltas (only resources that changed)
# ---------------------------------------------------------------------------
func _populate_resources() -> void:
	for child in resource_grid.get_children():
		child.queue_free()

	var deltas: Dictionary = GameState.last_turn_resource_deltas
	var shown := 0
	for res in RESOURCE_ORDER:
		var d := int(deltas.get(res, 0))
		if d == 0:
			continue
		resource_grid.add_child(_make_resource_chip(res, d))
		shown += 1

	resource_section.visible = shown > 0

func _make_resource_chip(res_name: String, delta: int) -> Control:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 5)

	var icon_path := "res://assets/icons/resources/%s.png" % res_name.to_lower()
	if ResourceLoader.exists(icon_path):
		var ic := UIKit.icon(icon_path, 18)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)

	var name_lbl := Label.new()
	name_lbl.text = res_name
	name_lbl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	name_lbl.add_theme_font_size_override("font_size", 13)
	cell.add_child(name_lbl)

	var delta_lbl := Label.new()
	delta_lbl.text = "%s%d" % ["+" if delta > 0 else "", delta]
	delta_lbl.add_theme_color_override("font_color", COLOR_GAIN if delta > 0 else COLOR_LOSS)
	delta_lbl.add_theme_font_size_override("font_size", 13)
	cell.add_child(delta_lbl)

	return cell

# ---------------------------------------------------------------------------
# "This Turn" event stream
# Section dividers (=== / ---), the threat forecast line, and the net-resources
# summary are filtered out because they now have dedicated UI above.
# ---------------------------------------------------------------------------
func _populate_events(lines: Array) -> void:
	for child in recap_list.get_children():
		child.queue_free()

	var any_shown := false
	for raw_line in lines:
		var line := str(raw_line)
		if _is_skippable_line(line):
			continue
		if line == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 6)
			recap_list.add_child(spacer)
			continue

		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(540, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_line_style(label, line)
		recap_list.add_child(label)
		any_shown = true

	if not any_shown:
		var quiet := Label.new()
		quiet.text = "A quiet turn. The city rests."
		quiet.add_theme_color_override("font_color", COLOR_MUTED)
		quiet.add_theme_font_size_override("font_size", 13)
		recap_list.add_child(quiet)

func _is_skippable_line(line: String) -> bool:
	if line.begins_with("==="):
		return true
	if line.begins_with("Threat ") and line.contains("/turn"):
		return true
	if line.begins_with("Net resources gain:"):
		return true
	return false

func _apply_line_style(label: Label, line: String) -> void:
	# Subsection headers like "--- Production ---"
	if line.begins_with("---"):
		label.text = line.replace("---", "").strip_edges().to_upper()
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", COLOR_GOLD)
		return

	if line.begins_with("[+]") or line.contains("reached Level") or line.contains("complete!") or line.contains("upgraded"):
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", COLOR_GAIN)
		return

	if line.begins_with("[!]") or line.contains("shortage") or line.contains("unfed") or line.contains("underfed") or line.contains("attacked") or line.contains("steal"):
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", COLOR_LOSS)
		return

	if line.begins_with("[~]") or line.contains("arrives!") or line.contains("arrived!") or line.contains("Threat +") or line.contains("Low Morale"):
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", COLOR_WARN)
		return

	if line.contains("High Morale") or line.contains("disrupt the Veiled"):
		label.add_theme_color_override("font_color", COLOR_GAIN)
		return

	if line.begins_with("No production") or line.begins_with("No training") or line.begins_with("No soldiers") or line.begins_with("No net change"):
		label.add_theme_color_override("font_color", COLOR_MUTED)
		return

	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.180392, 0.145098, 0.098039, 1))

# ---------------------------------------------------------------------------
# Continue / event-popup forwarding (unchanged contract)
# ---------------------------------------------------------------------------
func _on_continue() -> void:
	SaveManager.save_game(SaveManager.current_slot)  # auto-save to the active slot
	GameState.menu_open = false
	get_tree().call_group("city_view", "_on_recap_dismissed")
	hide()
