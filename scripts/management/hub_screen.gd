# res://scripts/management/hub_screen.gd
# Hub screen — full UI built in code, overlays instanced in the scene tree.
extends Control

# ---------------------------------------------------------------------------
# Instanced overlay nodes (from the .tscn)
# ---------------------------------------------------------------------------
@onready var recap_screen = $RecapScreen
@onready var combat_scene = $CombatScene
@onready var pre_combat_screen = $PreCombatScreen
@onready var combat_transition = $CombatTransition

# ---------------------------------------------------------------------------
# Layout roots
# ---------------------------------------------------------------------------
var _main_layout: HBoxContainer
var _backdrop: Control   # wrapper holding the NIGHT base + the active backdrop style's art
var _city_panel_content: VBoxContainer
var _army_panel_content: VBoxContainer
var _dungeon_panel_content: VBoxContainer
var _story_panel: StoryPanel

# Army roster grid (2 cards per row) — built fresh inside _army_panel_content
# each time _rebuild_army_panel runs.
var _army_roster_grid: GridContainer
# Maps SoldierData -> its roster card PanelContainer, so equip/unequip and
# stat-allocation refreshes can update a single card in place without
# rebuilding the whole Army tab (avoids scroll-position resets and flicker).
var _soldier_cards: Dictionary = {}

# Scroll container references (to toggle visibility)
var _city_scroll: ScrollContainer
var _army_scroll: ScrollContainer
var _dungeon_scroll: ScrollContainer
var _story_scroll: ScrollContainer

var _current_panel: String = "City"
var dungeon_map_scene: Node = null
var _soldier_detail_overlay: CanvasLayer = null

# Faction/story event popup — instanced once and reused
var _faction_event_popup: CanvasLayer = null
# Codex / Help overlay — instanced once and reused
var _codex_screen: CanvasLayer = null
# First-turn tutorial overlay — instanced once, runs when tutorial_seen is false
var _tutorial_overlay: CanvasLayer = null
# Widget references the tutorial spotlights
var _resource_bar_ref: Control
var _threat_container_ref: Control
var _btn_codex_ref: Button
# Queue of events to show after recap/combat clears (faction + story letters)
var _deferred_events: Array[Dictionary] = []

# ---------------------------------------------------------------------------
# Resource display labels
# ---------------------------------------------------------------------------
var label_gold: Label
var label_wood: Label
var label_stone: Label
var label_iron: Label
var label_steel: Label
var label_food: Label
var label_pep: Label
var label_turn: Label
var threat_bar: ProgressBar
var threat_pct_label: Label
var _threat_pulse: Tween = null   # subtle breathing pulse when threat is critical
var label_city_walls: Label       # "Walls: X/Y" shown beside the threat bar
var label_damaged_buildings: Label  # Warning banner; hidden when no damaged buildings

# ---------------------------------------------------------------------------
# Sidebar tab buttons
# ---------------------------------------------------------------------------
var btn_tab_city: Button
var btn_tab_army: Button
var btn_tab_dungeon: Button
var btn_tab_story: Button
var btn_end_turn: Button
var btn_main_menu: Button

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const _ICON_DIR := "res://assets/icons/resources/"

## Hub backdrop style — comparison switch while the city vista art is iterated on.
## "vista"    — painted city backdrop (assets/ui/city/hub_bg_vista.png), darkened.
## "wartable" — table_wood.png, scaled with slight overscan, no props/map.
## "flat"     — just the NIGHT ColorRect.
const HUB_BACKDROP_STYLE := "vista"

const DUNGEON_TIPS: Array = [
	"Tip: Assign workers to the Farm to produce Food each turn.",
	"Tip: Barracks increase your maximum soldier count.",
	"Tip: Fountain rooms heal your entire party for 20% HP.",
	"Tip: Keep Morale high for better hit chance in battle.",
	"Tip: Elite rooms are harder but reward more Gold.",
	"Tip: Markets in the dungeon sell gear and permanent traits.",
	"Tip: Boss waves hit every 5th difficulty. Prepare early.",
	"Tip: Soldiers gain XP from victories and Training Grounds.",
	"Tip: The Market building unlocks better weapons and armor.",
]

const _CATEGORY_ORDER: Array = [
	BuildingData.BuildingCategory.RESOURCE_OBTAINING,
	BuildingData.BuildingCategory.RESOURCE_PROCESSING,
	BuildingData.BuildingCategory.INTERMEDIARY,
	BuildingData.BuildingCategory.MILITARY,
	BuildingData.BuildingCategory.CONSTRUCTION,
	BuildingData.BuildingCategory.SPECIAL,
]

const _CATEGORY_NAMES: Dictionary = {
	BuildingData.BuildingCategory.RESOURCE_OBTAINING:  "Resource Obtaining",
	BuildingData.BuildingCategory.RESOURCE_PROCESSING: "Resource Processing",
	BuildingData.BuildingCategory.INTERMEDIARY:         "Intermediary",
	BuildingData.BuildingCategory.MILITARY:             "Military",
	BuildingData.BuildingCategory.CONSTRUCTION:         "Construction",
	BuildingData.BuildingCategory.SPECIAL:              "Special",
}

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	GameState.in_city_view = true
	add_to_group("city_view")

	theme = GameTheme.get_theme()
	_build_hub_layout()
	_setup_resource_icons()

	GameState.resources_changed.connect(_update_resource_display)
	GameState.resources_changed.connect(func():
		if _current_panel == "City":
			_rebuild_city_panel()
		_update_walls_display()
		_update_damaged_buildings_banner()
	)
	GameState.threat_updated.connect(_update_threat_display)
	GameState.turn_ended.connect(func(_t): _main_layout.visible = false)
	GameState.combat_started_from_turn.connect(_on_combat_started)
	GameState.dungeon_expedition_ready.connect(_open_dungeon_map)
	GameState.raid_pursuit_triggered.connect(_on_raid_pursuit_triggered)
	DungeonState.soldiers_retrieved.connect(_on_soldiers_retrieved)

	StoryManager.new_letter_received.connect(_on_new_letter_received)
	StoryManager.story_event_popup_ready.connect(_on_story_event_popup_ready)
	FactionState.faction_standing_changed.connect(_on_faction_standing_changed)
	FactionEvents.faction_event_ready.connect(_on_faction_event_ready)
	GameState.game_event_popup_ready.connect(_on_game_event_popup_ready)
	GameState.prince_consumed_by_veil.connect(_on_prince_consumed)
	GameState.scout_combat_result_ready.connect(_on_scout_combat_result)
	GameState.city_fallen.connect(_on_city_fallen)
	GameState.game_won.connect(_on_game_won)

	# Catch-up: if the final boss wave was already won (e.g. signal fired
	# before this hub instance existed), show the victory screen now.
	if GameState.game_won_achieved:
		_on_game_won()

	# Shared popup — reused for both faction events and story letters
	_faction_event_popup = preload("res://scenes/ui/faction_event_popup.tscn").instantiate()
	add_child(_faction_event_popup)
	_faction_event_popup.choice_made.connect(_on_popup_choice_made)

	# Codex / Help overlay — instanced once, opened from the sidebar button
	_codex_screen = preload("res://scenes/ui/codex_screen.tscn").instantiate()
	add_child(_codex_screen)

	# First-turn tutorial overlay — runs once per save
	_tutorial_overlay = preload("res://scenes/ui/tutorial_overlay.tscn").instantiate()
	add_child(_tutorial_overlay)
	_tutorial_overlay.finished.connect(_on_tutorial_finished)

	# DungeonState.expedition_started — connect if it exists (it does per the file)
	if DungeonState.has_signal("expedition_started"):
		DungeonState.expedition_started.connect(func(): _rebuild_dungeon_panel())

	_update_resource_display()
	_update_threat_display()
	_update_walls_display()
	_update_damaged_buildings_banner()
	_switch_panel("City")
	btn_tab_city.button_pressed = true
	_refresh_story_badge()

	MusicManager.play("hub")

	_maybe_start_tutorial()

# ---------------------------------------------------------------------------
# First-turn tutorial
# ---------------------------------------------------------------------------
func _maybe_start_tutorial() -> void:
	if GameState.tutorial_seen:
		return
	if _tutorial_overlay == null:
		return
	var steps: Array = [
		{
			"target": _resource_bar_ref,
			"title": "Your Treasury & Stores",
			"body": "These are your resources: Gold, Wood, Stone, Iron, Steel, and Food. You spend them to rebuild and grow the city. Hover any of them to see what it does. Food is spent every turn to feed your soldiers.",
		},
		{
			"target": _city_scroll,
			"title": "Rebuild Your City",
			"body": "Your buildings start as ruins. Click one to rebuild it with Gold, Wood, and Stone, then assign People to make it produce each turn. Start with a Farm for Food and a Forest for Wood.",
		},
		{
			"target": _threat_container_ref,
			"title": "The Threat Is Coming",
			"body": "This bar fills a little every turn. When it's full, an enemy wave attacks your walls. Win to push it back; lose and you lose a wall. If your walls reach zero, the city falls. Recruit soldiers before it fills.",
		},
		{
			"target": btn_tab_army,
			"title": "Raise an Army",
			"body": "Open the Army tab to recruit soldiers, equip them with gear, and send them on dungeon expeditions. A defended city survives the waves.",
		},
		{
			"target": btn_end_turn,
			"title": "End Your Turn",
			"body": "When you're done, End Turn. Production, training, upkeep, events, and any threat all resolve at once, and a recap shows what changed.",
		},
		{
			"target": _btn_codex_ref,
			"title": "You're Ready",
			"body": "Your objectives, your path to victory, are in the Codex. Complete them all, then hold until the king arrives to win. Open the Codex here anytime for help. Good luck, my prince.",
		},
	]
	_tutorial_overlay.start(steps)

func _on_tutorial_finished() -> void:
	# Persist tutorial_seen immediately so it never replays, even if the player quits now.
	if SaveManager.current_slot > 0:
		SaveManager.save_game(SaveManager.current_slot)

# ---------------------------------------------------------------------------
# Build full layout hierarchy in code
# ---------------------------------------------------------------------------
func _build_hub_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ---- Backdrop behind the parchment UI ----
	# Kept at the very back (index 0) so it can never paint over the combat /
	# pre-combat Control overlays that live in this scene, and mirrored to the
	# hub UI's visibility so it disappears whenever a turn / dungeon hides it.
	# A NIGHT ColorRect always sits at the bottom as a base/fallback; the active
	# HUB_BACKDROP_STYLE layer (if any) is drawn on top of it.
	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	move_child(_backdrop, 0)   # behind RecapScreen/CombatScene/PreCombatScreen/CombatTransition

	var night_base := ColorRect.new()
	night_base.name = "NightBase"
	night_base.color = GameTheme.NIGHT
	night_base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.add_child(night_base)

	match HUB_BACKDROP_STYLE:
		"vista":
			var vista_path := "res://assets/ui/city/hub_bg_vista.png"
			if ResourceLoader.exists(vista_path):
				var vista := TextureRect.new()
				vista.name = "Vista"
				vista.texture = load(vista_path) as Texture2D
				vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				vista.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				vista.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				vista.modulate = Color(0.55, 0.55, 0.6)
				vista.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_backdrop.add_child(vista)
		"wartable":
			var wood_path := "res://assets/ui/menu/wartable/table_wood.png"
			if ResourceLoader.exists(wood_path):
				var wood := TextureRect.new()
				wood.name = "TableWood"
				wood.texture = load(wood_path) as Texture2D
				# Slight overscan so the texture edges never show as the
				# viewport is resized.
				wood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				wood.offset_left -= 24
				wood.offset_top -= 24
				wood.offset_right += 24
				wood.offset_bottom += 24
				wood.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				wood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				wood.modulate = Color(0.8, 0.8, 0.8)
				wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_backdrop.add_child(wood)
		"flat":
			pass   # NIGHT base only

	# ---- Root HBox ----
	_main_layout = HBoxContainer.new()
	_main_layout.name = "MainLayout"
	_main_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main_layout.add_theme_constant_override("separation", 0)
	add_child(_main_layout)
	_main_layout.visibility_changed.connect(func():
		if is_instance_valid(_backdrop):
			_backdrop.visible = _main_layout.visible)

	# ---- Sidebar ----
	var sidebar := VBoxContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(160, 0)
	sidebar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 0)
	_main_layout.add_child(sidebar)

	# Title label
	var title_lbl := Label.new()
	title_lbl.text = "KINGDOM\nREBUILT"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)  # light on the dark sidebar
	title_lbl.custom_minimum_size = Vector2(160, 48)
	sidebar.add_child(title_lbl)

	sidebar.add_child(HSeparator.new())

	# Tab group
	var tab_group := ButtonGroup.new()

	btn_tab_city = Button.new()
	btn_tab_city.text = "City"
	btn_tab_city.theme_type_variation = "Tab"
	btn_tab_city.toggle_mode = true
	btn_tab_city.button_group = tab_group
	btn_tab_city.custom_minimum_size = Vector2(150, 44)
	sidebar.add_child(btn_tab_city)
	btn_tab_city.pressed.connect(func(): _switch_panel("City"))

	btn_tab_army = Button.new()
	btn_tab_army.text = "Army"
	btn_tab_army.theme_type_variation = "Tab"
	btn_tab_army.toggle_mode = true
	btn_tab_army.button_group = tab_group
	btn_tab_army.custom_minimum_size = Vector2(150, 44)
	sidebar.add_child(btn_tab_army)
	btn_tab_army.pressed.connect(func(): _switch_panel("Army"))

	btn_tab_dungeon = Button.new()
	btn_tab_dungeon.text = "Dungeon"
	btn_tab_dungeon.theme_type_variation = "Tab"
	btn_tab_dungeon.toggle_mode = true
	btn_tab_dungeon.button_group = tab_group
	btn_tab_dungeon.custom_minimum_size = Vector2(150, 44)
	sidebar.add_child(btn_tab_dungeon)
	btn_tab_dungeon.pressed.connect(func(): _switch_panel("Dungeon"))

	btn_tab_story = Button.new()
	btn_tab_story.text = "Story"
	btn_tab_story.theme_type_variation = "Tab"
	btn_tab_story.toggle_mode = true
	btn_tab_story.button_group = tab_group
	btn_tab_story.custom_minimum_size = Vector2(150, 44)
	sidebar.add_child(btn_tab_story)
	btn_tab_story.pressed.connect(func():
		_switch_panel("Story")
		_refresh_story_badge()
	)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(spacer)

	sidebar.add_child(HSeparator.new())

	btn_end_turn = Button.new()
	btn_end_turn.text = "End Turn"
	btn_end_turn.theme_type_variation = "Primary"   # crimson — the key action
	btn_end_turn.custom_minimum_size = Vector2(150, 36)
	btn_end_turn.add_to_group("no_ui_click")   # its own end_turn cue plays instead
	sidebar.add_child(btn_end_turn)
	btn_end_turn.pressed.connect(_on_btn_end_turn_pressed)

	btn_main_menu = Button.new()
	btn_main_menu.text = "Main Menu"
	btn_main_menu.theme_type_variation = "Ghost"
	btn_main_menu.custom_minimum_size = Vector2(150, 36)
	sidebar.add_child(btn_main_menu)
	btn_main_menu.pressed.connect(_on_btn_main_menu_pressed)

	var btn_codex := Button.new()
	btn_codex.text = "? Help / Codex"
	btn_codex.theme_type_variation = "Ghost"
	btn_codex.custom_minimum_size = Vector2(150, 36)
	btn_codex.tooltip_text = "Open the Codex: how to play, resources, combat, and how to win."
	sidebar.add_child(btn_codex)
	btn_codex.pressed.connect(func():
		if _codex_screen != null:
			_codex_screen.open()
	)
	_btn_codex_ref = btn_codex

	# ---- Right side ----
	var right_side := VBoxContainer.new()
	right_side.name = "RightSide"
	right_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_side.add_theme_constant_override("separation", 0)
	_main_layout.add_child(right_side)

	# Resource bar
	var resource_bar := PanelContainer.new()
	resource_bar.name = "ResourceBar"
	resource_bar.theme_type_variation = "Sunken"   # flat dark strip, not the ornate frame
	resource_bar.custom_minimum_size = Vector2(0, 38)
	right_side.add_child(resource_bar)
	_resource_bar_ref = resource_bar

	var resource_row := HBoxContainer.new()
	resource_row.name = "ResourceRow"
	resource_row.add_theme_constant_override("separation", 12)
	resource_bar.add_child(resource_row)

	# Build resource labels inside resource_row
	label_gold   = _make_resource_label("0");    resource_row.add_child(label_gold)
	label_wood   = _make_resource_label("0");    resource_row.add_child(label_wood)
	label_stone  = _make_resource_label("0");    resource_row.add_child(label_stone)
	label_iron   = _make_resource_label("0");    resource_row.add_child(label_iron)
	label_steel  = _make_resource_label("0");    resource_row.add_child(label_steel)
	label_food   = _make_resource_label("0");    resource_row.add_child(label_food)
	label_pep    = _make_resource_label("People: 0"); resource_row.add_child(label_pep)
	label_turn   = _make_resource_label("Turn: 0");   resource_row.add_child(label_turn)

	# --- Threat row: icon label + progress bar + percentage ---
	var threat_container := PanelContainer.new()
	threat_container.name = "ThreatContainer"
	threat_container.theme_type_variation = "Sunken"
	threat_container.custom_minimum_size = Vector2(0, 26)
	right_side.add_child(threat_container)
	_threat_container_ref = threat_container

	var threat_row := HBoxContainer.new()
	threat_row.add_theme_constant_override("separation", 8)
	threat_container.add_child(threat_row)

	var _threat_tip := "Threat rises every turn. When it fills, an enemy wave attacks your walls. Every 5th wave is a tougher boss wave."
	var threat_title := Label.new()
	threat_title.text = "Threat"
	threat_title.add_theme_font_size_override("font_size", 11)
	threat_title.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	threat_title.custom_minimum_size = Vector2(44, 0)
	threat_title.tooltip_text = _threat_tip
	threat_row.add_child(threat_title)

	threat_bar = ProgressBar.new()
	threat_bar.name = "ThreatBar"
	threat_bar.min_value = 0
	threat_bar.max_value = 100
	threat_bar.value = 0
	threat_bar.show_percentage = false
	threat_bar.custom_minimum_size = Vector2(160, 14)
	threat_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Red fill via StyleBox
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = GameTheme.WAX
	threat_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = GameTheme.LEATHER
	bg_style.border_color = GameTheme.LEATHER
	bg_style.set_border_width_all(1)
	threat_bar.add_theme_stylebox_override("background", bg_style)
	threat_bar.tooltip_text = _threat_tip
	threat_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	threat_row.add_child(threat_bar)

	threat_pct_label = Label.new()
	threat_pct_label.name = "ThreatPctLabel"
	threat_pct_label.text = "0%"
	threat_pct_label.add_theme_font_size_override("font_size", 11)
	threat_pct_label.add_theme_color_override("font_color", GameTheme.INK)
	threat_pct_label.custom_minimum_size = Vector2(50, 0)
	threat_pct_label.tooltip_text = _threat_tip
	threat_row.add_child(threat_pct_label)

	# Walls label — sits in the same row as the threat bar, after the percentage
	label_city_walls = Label.new()
	label_city_walls.name = "CityWallsLabel"
	label_city_walls.text = "Walls: 1/%d" % GameState.max_city_walls
	label_city_walls.add_theme_font_size_override("font_size", 11)
	label_city_walls.add_theme_color_override("font_color", GameTheme.INK)
	label_city_walls.custom_minimum_size = Vector2(80, 0)
	label_city_walls.tooltip_text = "Walls: your last line of defense. Lose a wave and you lose a wall. At zero walls, the city falls."
	threat_row.add_child(label_city_walls)

	# Damaged buildings warning banner — hidden until damage exists
	label_damaged_buildings = Label.new()
	label_damaged_buildings.name = "DamagedBuildingsLabel"
	label_damaged_buildings.text = ""
	label_damaged_buildings.add_theme_font_size_override("font_size", 11)
	label_damaged_buildings.add_theme_color_override("font_color", GameTheme.CRIMSON)
	label_damaged_buildings.visible = false
	right_side.add_child(label_damaged_buildings)

	# ---- Panel area: a Control wrapper holding 4 ScrollContainers ----
	var panel_area := Control.new()
	panel_area.name = "PanelArea"
	panel_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_side.add_child(panel_area)

	# Parchment sheet behind the scroll content, so ink text reads (not on the dark backdrop).
	var panel_bg := PanelContainer.new()
	panel_bg.theme_type_variation = "Frame"
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_area.add_child(panel_bg)

	_city_scroll   = _make_panel_scroll(panel_area)
	_army_scroll   = _make_panel_scroll(panel_area)
	_dungeon_scroll = _make_panel_scroll(panel_area)
	_story_scroll  = _make_panel_scroll(panel_area)

	# Army roster never needs horizontal scrolling (cards wrap in a fixed-column
	# grid); disabling it avoids a stray horizontal scrollbar. A right content
	# margin keeps the vertical scrollbar clear of the cards' Details buttons.
	_army_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	_city_panel_content   = _make_panel_vbox(_city_scroll)
	_army_panel_content   = _make_panel_vbox_margined(_army_scroll, 12)
	_dungeon_panel_content = _make_panel_vbox(_dungeon_scroll)

	_story_panel = StoryPanel.new()
	_story_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_panel.letters_changed.connect(_refresh_story_badge)
	_story_scroll.add_child(_story_panel)

	# All hidden by default; _switch_panel will show the correct one
	_city_scroll.visible   = false
	_army_scroll.visible   = false
	_dungeon_scroll.visible = false
	_story_scroll.visible  = false

func _make_resource_label(initial_text: String) -> Label:
	var lbl := Label.new()
	lbl.text = initial_text
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl

func _make_panel_scroll(parent: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(sc)
	return sc

func _make_panel_vbox(scroll: ScrollContainer) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)
	return vbox

## Same as _make_panel_vbox, but wraps the content vbox in a MarginContainer
## with the given right margin so the scrollbar doesn't overlap card content
## (e.g. the Details button in the Army roster cards).
func _make_panel_vbox_margined(scroll: ScrollContainer, right_margin: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", right_margin)
	scroll.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	return vbox

# ---------------------------------------------------------------------------
# Resource icons — port from City_view.gd
# ---------------------------------------------------------------------------
func _make_file_icon(filename: String, icon_size: int = 22) -> TextureRect:
	var tex := load(_ICON_DIR + filename) as Texture2D
	var rect := TextureRect.new()
	if tex != null:
		rect.texture = tex
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _wrap_with_icon(label: Label, icon: TextureRect) -> void:
	var parent := label.get_parent()
	var idx := label.get_index()
	var wrapper := HBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	label.reparent(wrapper)
	wrapper.add_child(icon)
	wrapper.move_child(icon, 0)

func _setup_resource_icons() -> void:
	_wrap_with_icon(label_gold,   _make_file_icon("gold.png"))
	_wrap_with_icon(label_wood,   _make_file_icon("wood.png"))
	_wrap_with_icon(label_stone,  _make_file_icon("stone.png"))
	_wrap_with_icon(label_iron,   _make_file_icon("iron.png"))
	_wrap_with_icon(label_steel,  _make_file_icon("steel.png"))
	_wrap_with_icon(label_food,   _make_file_icon("food.png"))

	# Tooltips — short, plain definitions for every resource chip.
	_set_resource_tooltip(label_gold,  "Gold: pays for rebuilding, recruiting, upgrades, and trade.")
	_set_resource_tooltip(label_wood,  "Wood: raw material for rebuilding and upgrading buildings. Produced by the Forest.")
	_set_resource_tooltip(label_stone, "Stone: raw material for rebuilding and upgrading. Produced by the Quarry.")
	_set_resource_tooltip(label_iron,  "Iron: mined ore. Processed into Steel and used in crafting.")
	_set_resource_tooltip(label_steel, "Steel: refined from Iron at the Steel Forge. Needed for stronger gear.")
	_set_resource_tooltip(label_food,  "Food: consumed every turn by your soldiers. Run out and morale falls.")
	label_pep.tooltip_text  = "People: workers you assign to buildings to produce. Build Houses to raise the cap."
	label_turn.tooltip_text = "Turn: each turn, production, training, upkeep, events, and threats resolve."

# Applies the same tooltip to a resource label, its icon, and the wrapper HBox so
# hovering anywhere on the chip shows it (children may swallow the hover otherwise).
func _set_resource_tooltip(label: Label, text: String) -> void:
	label.tooltip_text = text
	var wrapper := label.get_parent()
	if wrapper is Control:
		(wrapper as Control).tooltip_text = text
		(wrapper as Control).mouse_filter = Control.MOUSE_FILTER_STOP
		for child in wrapper.get_children():
			if child is Control:
				(child as Control).tooltip_text = text

# ---------------------------------------------------------------------------
# Panel switching
# ---------------------------------------------------------------------------
func _switch_panel(panel_name: String) -> void:
	_current_panel = panel_name
	_city_scroll.visible   = (panel_name == "City")
	_army_scroll.visible   = (panel_name == "Army")
	_dungeon_scroll.visible = (panel_name == "Dungeon")
	_story_scroll.visible  = (panel_name == "Story")

	match panel_name:
		"City":    _rebuild_city_panel()
		"Army":    _rebuild_army_panel()
		"Dungeon": _rebuild_dungeon_panel()
		"Story":
			_rebuild_story_panel()
			_refresh_story_badge()

# ---------------------------------------------------------------------------
# OBJECTIVES — path to victory, shown at the top of the City panel
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# CITY PANEL
# ---------------------------------------------------------------------------
func _rebuild_city_panel() -> void:
	for child in _city_panel_content.get_children():
		child.queue_free()

	# Objectives live in the Codex ("How to Win") only — not duplicated here.

	# Group buildings by category
	var groups: Dictionary = {}
	for cat in _CATEGORY_ORDER:
		groups[cat] = []

	for b_name in GameState.building_definitions.keys():
		var data: BuildingData = GameState.get_building_data(b_name)
		if data == null:
			continue
		var cat = data.category
		if groups.has(cat):
			groups[cat].append(b_name)

	for cat in _CATEGORY_ORDER:
		var b_list: Array = groups[cat]
		if b_list.is_empty():
			continue

		_city_panel_content.add_child(UIKit.banner_header(_CATEGORY_NAMES[cat]))

		_city_panel_content.add_child(HSeparator.new())

		for b_name in b_list:
			var row := _make_building_row(b_name)
			_city_panel_content.add_child(row)

func _make_building_row(b_name: String) -> HBoxContainer:
	var data: BuildingData = GameState.get_building_data(b_name)
	var level: int = GameState.get_building_level(b_name)
	var is_built: bool = GameState.is_building_built(b_name)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 40)

	# Building icon
	var tex_path := BuildingData.get_texture_path(b_name)
	if tex_path != "":
		var tex := load(tex_path) as Texture2D
		if tex != null:
			var img := TextureRect.new()
			img.texture = tex
			img.custom_minimum_size = Vector2(36, 36)
			img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(img)

	var name_lbl := Label.new()
	name_lbl.text = b_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var level_lbl := Label.new()
	if is_built:
		level_lbl.text = "Lv %d" % level
		level_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
	else:
		level_lbl.text = "Ruins"
		level_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
	level_lbl.custom_minimum_size = Vector2(54, 0)
	row.add_child(level_lbl)

	var manage_btn := Button.new()
	manage_btn.text = "Manage"
	manage_btn.custom_minimum_size = Vector2(90, 36)
	var captured_name := b_name
	var captured_desc: String = data.description if data != null else ""
	manage_btn.pressed.connect(func():
		BuildingPopup.reopen_menu_on_close = true
		BuildingPopup.show_building(captured_name, captured_desc)
	)
	row.add_child(manage_btn)

	return row

# ---------------------------------------------------------------------------
# ARMY PANEL
# ---------------------------------------------------------------------------
func _rebuild_army_panel() -> void:
	for child in _army_panel_content.get_children():
		child.queue_free()
	_soldier_cards.clear()
	_army_roster_grid = null

	# Soldier roster (full-width header above the 2-column grid)
	_army_panel_content.add_child(UIKit.banner_header("Soldiers  (%d / %d)" % [GameState.soldiers.size(), GameState.get_max_soldiers()]))

	if GameState.soldiers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No soldiers yet. Recruit from the Tavern building."
		empty_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		_army_panel_content.add_child(empty_lbl)
		return

	_army_roster_grid = GridContainer.new()
	_army_roster_grid.columns = 2
	_army_roster_grid.add_theme_constant_override("h_separation", 10)
	_army_roster_grid.add_theme_constant_override("v_separation", 10)
	_army_panel_content.add_child(_army_roster_grid)

	for soldier in GameState.soldiers:
		var card := _make_soldier_card(soldier)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_army_roster_grid.add_child(card)
		_soldier_cards[soldier] = card

## Rebuilds a single soldier's roster card in place at its current grid
## position, so equip/unequip and stat changes refresh instantly without
## tearing down the whole Army tab (no scroll reset, no flicker).
func _refresh_soldier_card(soldier: SoldierData) -> void:
	if _army_roster_grid == null or not is_instance_valid(_army_roster_grid):
		return
	var old_card: PanelContainer = _soldier_cards.get(soldier)
	var idx := -1
	if old_card != null and is_instance_valid(old_card):
		idx = old_card.get_index()
		_army_roster_grid.remove_child(old_card)
		old_card.queue_free()

	var new_card := _make_soldier_card(soldier)
	new_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_army_roster_grid.add_child(new_card)
	if idx >= 0:
		_army_roster_grid.move_child(new_card, idx)
	_soldier_cards[soldier] = new_card

func _make_soldier_card(soldier: SoldierData) -> PanelContainer:
	var cls_color := _get_class_color(soldier.soldier_class)

	# Pixel-art card frame: prefer the dedicated card_frame.png once generated,
	# else the torn-paper "Card" variation. Content margins are kept intact so
	# the frame border stays visible; the class-colored header strip sits inset
	# within it (same pattern as the faction cards in story_panel.gd).
	var panel := UIKit.themed_card()
	if ResourceLoader.exists("res://assets/ui/city/frames/card_frame.png"):
		panel.add_theme_stylebox_override("panel",
			PixelUI.tex_stylebox_frame("res://assets/ui/city/frames/card_frame.png",
				Rect2(2, 1, 92, 93), 14, 16))

	# Outer column: class-colored header strip on top, body below.
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(card_vbox)

	# --- Header strip: class icon, name, class, level, Details ---
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel",
		PixelUI.nameplate_stylebox(cls_color.darkened(0.55)))
	card_vbox.add_child(header_panel)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	header_panel.add_child(name_row)

	var cls_icon_path := "res://assets/icons/classes/%s.png" % soldier.soldier_class.to_lower()
	if ResourceLoader.exists(cls_icon_path):
		# Small leading spacer so the class icon sits a bit further right of the
		# nameplate's left edge rather than hugging it.
		var icon_pad := Control.new()
		icon_pad.custom_minimum_size = Vector2(12, 0)
		name_row.add_child(icon_pad)
		var cls_icon := UIKit.icon(cls_icon_path, 22)
		cls_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(cls_icon)

	var name_lbl := Label.new()
	name_lbl.text = soldier.soldier_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(name_lbl)

	var class_lbl := Label.new()
	class_lbl.text = soldier.soldier_class
	class_lbl.add_theme_color_override("font_color", cls_color)
	class_lbl.add_theme_font_size_override("font_size", 12)
	name_row.add_child(class_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Lv.%d" % soldier.level
	level_lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)
	level_lbl.add_theme_font_size_override("font_size", 12)
	name_row.add_child(level_lbl)

	var details_btn := Button.new()
	details_btn.text = "Details"
	details_btn.custom_minimum_size = Vector2(72, 26)
	details_btn.add_theme_font_size_override("font_size", 11)
	var captured_soldier: SoldierData = soldier
	details_btn.pressed.connect(func(): _open_soldier_details(captured_soldier))
	name_row.add_child(details_btn)

	# --- Body: portrait | info column ---
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 10)
	body_margin.add_theme_constant_override("margin_right", 8)
	body_margin.add_theme_constant_override("margin_top", 6)
	body_margin.add_theme_constant_override("margin_bottom", 6)
	card_vbox.add_child(body_margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	body_margin.add_child(hbox)

	# --- Portrait (smaller: half the previous footprint) ---
	var portrait_bg := PanelContainer.new()
	portrait_bg.custom_minimum_size = Vector2(64, 80)
	var pbg_style := StyleBoxFlat.new()
	pbg_style.bg_color = GameTheme.LEATHER
	pbg_style.border_color = cls_color.darkened(0.3)
	pbg_style.border_width_left = 1
	pbg_style.border_width_top = 1
	pbg_style.border_width_right = 1
	pbg_style.border_width_bottom = 1
	portrait_bg.add_theme_stylebox_override("panel", pbg_style)
	hbox.add_child(portrait_bg)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var cls := soldier.soldier_class.to_lower()
	var suffix := "" if soldier.sprite_variant <= 1 else "_%d" % soldier.sprite_variant
	var tex_path := "res://assets/soldiers/%s/idle%s.png" % [cls, suffix]
	if ResourceLoader.exists(tex_path):
		portrait.texture = load(tex_path) as Texture2D
	elif ResourceLoader.exists("res://assets/soldiers/%s/idle.png" % cls):
		portrait.texture = load("res://assets/soldiers/%s/idle.png" % cls) as Texture2D
	portrait_bg.add_child(portrait)

	# --- Info column ---
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Stat chips: HP cur/max, STR, SPD, DEX (effective totals; no bars)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 4)
	info_vbox.add_child(stats_row)

	var chip_texts: Array[String] = [
		"HP %d/%d" % [soldier.hp_current, soldier.hp_max],
		"STR %d" % soldier.get_total_power(),
		"SPD %d" % soldier.get_total_speed(),
		"DEX %d" % soldier.get_total_dexterity(),
	]
	for chip_text in chip_texts:
		var chip := PanelContainer.new()
		var chip_style := StyleBoxFlat.new()
		chip_style.bg_color = Color(0.10, 0.10, 0.14, 1.0)
		chip_style.border_color = Color(0.28, 0.28, 0.38)
		chip_style.border_width_left = 1
		chip_style.border_width_top = 1
		chip_style.border_width_right = 1
		chip_style.border_width_bottom = 1
		chip_style.corner_radius_top_left = 3
		chip_style.corner_radius_top_right = 3
		chip_style.corner_radius_bottom_left = 3
		chip_style.corner_radius_bottom_right = 3
		chip_style.content_margin_left = 6
		chip_style.content_margin_right = 6
		chip_style.content_margin_top = 3
		chip_style.content_margin_bottom = 3
		chip.add_theme_stylebox_override("panel", chip_style)
		var chip_lbl := Label.new()
		chip_lbl.text = chip_text
		chip_lbl.add_theme_font_size_override("font_size", 13)
		# Light parchment on the dark chip — INK_SOFT was too dim to read here.
		chip_lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)
		chip.add_child(chip_lbl)
		stats_row.add_child(chip)

	# Equipment row: Weapon 1 / Weapon 2 / Armor — small slot chips
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 6)
	info_vbox.add_child(equip_row)

	for slot_data in [["Weapon 1", soldier.weapon_1], ["Weapon 2", soldier.weapon_2], ["Armor", soldier.armor]]:
		var slot_label: String = slot_data[0]
		var slot_item: ItemData = slot_data[1]
		equip_row.add_child(_make_equip_slot_chip(slot_label, slot_item))

	# Skills / traits summary chip
	var counts_lbl := Label.new()
	counts_lbl.text = "Skills: %d · Traits: %d" % [soldier.equipped_skills.size(), soldier.traits.size()]
	counts_lbl.add_theme_font_size_override("font_size", 10)
	counts_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	info_vbox.add_child(counts_lbl)

	# Injured row
	if soldier.unavailable_turns > 0:
		var heal_row := HBoxContainer.new()
		heal_row.add_theme_constant_override("separation", 8)
		info_vbox.add_child(heal_row)

		var unavail_lbl := Label.new()
		unavail_lbl.text = "Injured: %d turn(s)" % soldier.unavailable_turns
		unavail_lbl.add_theme_font_size_override("font_size", 11)
		unavail_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
		unavail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heal_row.add_child(unavail_lbl)

		var heal_btn := Button.new()
		heal_btn.text = "Heal (50G, 70%)"
		heal_btn.custom_minimum_size = Vector2(120, 26)
		heal_btn.add_theme_font_size_override("font_size", 11)
		heal_btn.disabled = GameState.gold < 50
		var captured_heal_soldier: SoldierData = soldier
		heal_btn.pressed.connect(func(): _on_heal_soldier_pressed(captured_heal_soldier))
		heal_row.add_child(heal_btn)

	return panel

## A 28x28 equipment slot chip — item icon if equipped, else a dark sunken
## empty slot. Tooltip shows the item name + stats, or a hint to equip.
func _make_equip_slot_chip(slot_label: String, item: ItemData) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(28, 28)

	var chip_style := StyleBoxFlat.new()
	if item != null:
		chip_style.bg_color = GameTheme.LEATHER.darkened(0.2)
		chip_style.border_color = GameTheme.IRON_HI
	else:
		chip_style.bg_color = GameTheme.NIGHT
		chip_style.border_color = GameTheme.PARCH_SHADE
	chip_style.set_border_width_all(1)
	chip_style.content_margin_left = 2
	chip_style.content_margin_right = 2
	chip_style.content_margin_top = 2
	chip_style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", chip_style)

	if item != null:
		var icon_path := ItemData.get_icon_path(item)
		if icon_path != "" and ResourceLoader.exists(icon_path):
			chip.add_child(UIKit.icon(icon_path, 24))
		chip.tooltip_text = "%s (%s)\n%s" % [slot_label, item.item_name, item.get_stats_display()]
	else:
		chip.tooltip_text = "%s: Empty. Equip in Details." % slot_label

	return chip

func _get_class_color(soldier_class: String) -> Color:
	match soldier_class:
		"Warrior": return Color(0.9, 0.4, 0.3)
		"Archer":  return GameTheme.MOSS
		"Rogue":   return Color(0.6, 0.3, 0.9)
		"Mage":    return Color(0.3, 0.6, 0.9)
		"Knight":  return Color(0.9, 0.8, 0.3)
	return Color(0.8, 0.8, 0.8)

## Builds the "HP: x/y  Strength: ...  Morale: ...  XP: ..." summary line shown
## in the soldier details overlay. Pulled into a helper so StatAllocUI's
## on_changed callback can refresh just this label's text in place.
func _build_soldier_stats_text(soldier: SoldierData) -> String:
	return (
		"HP: %d / %d     Strength: %d     Defense: %d     Initiative: %d     Cunning: %d\n"
		+ "Morale: %d / 100     XP: %d / %d"
	) % [
		soldier.hp_current, soldier.hp_max,
		soldier.get_total_power(),
		soldier.get_total_defense(),
		soldier.get_total_speed(),
		soldier.get_total_dexterity(),
		soldier.morale,
		soldier.experience, soldier.xp_to_next_level,
	]

## MOSS for a net-positive trait, CRIMSON for a net-negative one, INK_SOFT for
## a wash (no bonuses, or buffs/downsides that cancel out).
func _get_trait_stat_color(t: TraitData) -> Color:
	var net := 0.0
	net += t.power_bonus
	net += t.speed_bonus
	net += t.dexterity_bonus
	net += t.hp_bonus
	net += t.defense_bonus
	net += t.hit_chance_bonus * 100.0
	net += t.dodge_bonus * 100.0
	if net > 0:
		return GameTheme.MOSS
	elif net < 0:
		return GameTheme.CRIMSON
	return GameTheme.INK_SOFT

# `animate = false` skips the fade-in: used when the overlay is rebuilt in
# place after equip/unequip/skill changes, where the fade reads as a flicker.
func _open_soldier_details(soldier: SoldierData, animate: bool = true) -> void:
	# Free any previously open detail overlay before creating a new one.
	if is_instance_valid(_soldier_detail_overlay):
		_soldier_detail_overlay.queue_free()
	_soldier_detail_overlay = null

	var overlay := CanvasLayer.new()
	overlay.layer = 60
	add_child(overlay)
	_soldier_detail_overlay = overlay

	# Semi-transparent dimmer — clicking it closes the popup.
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(bg)

	bg.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			overlay.queue_free()
			_soldier_detail_overlay = null
	)

	# Full-rect wrapper + CenterContainer so the panel is truly centred on screen.
	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance — set explicitly
	overlay.add_child(wrapper)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Uses the themed stone frame from GameTheme.
	center.add_child(panel)
	if animate:
		UIKit.fade_in(panel)

	# Margin inside panel.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# --- Header row ---
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "%s (%s, Lv.%d)" % [soldier.soldier_name, soldier.soldier_class, soldier.level]
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = ""
	close_btn.theme_type_variation = "Close"   # wax-seal X icon
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		_soldier_detail_overlay = null
	)
	header_hbox.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# --- Scrollable body ---
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	# Right margin keeps the vertical scrollbar clear of row content
	# (Unequip/Equip buttons, etc).
	var body_margin := MarginContainer.new()
	body_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(body_margin)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 10)
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_margin.add_child(body_vbox)

	# --- Stats ---
	var hp_bar := ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max(1, soldier.hp_max)
	hp_bar.value = soldier.hp_current
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.show_percentage = false
	body_vbox.add_child(hp_bar)

	var stats_lbl := Label.new()
	stats_lbl.text = _build_soldier_stats_text(soldier)
	stats_lbl.add_theme_font_size_override("font_size", 13)
	body_vbox.add_child(stats_lbl)

	body_vbox.add_child(HSeparator.new())

	# --- Attribute allocation (+ buttons) ---
	# The panel refreshes its own labels/buttons in place when a point is spent.
	# on_changed updates the stats text block above and the roster card chips
	# without tearing down this overlay (no flicker, no scroll reset).
	var captured_stats_lbl: Label = stats_lbl
	var captured_hp_bar: ProgressBar = hp_bar
	body_vbox.add_child(StatAllocUI.build(soldier, func():
		captured_stats_lbl.text = _build_soldier_stats_text(soldier)
		captured_hp_bar.max_value = max(1, soldier.hp_max)
		captured_hp_bar.value = soldier.hp_current
		_refresh_soldier_card(soldier)
	))

	body_vbox.add_child(HSeparator.new())

	# --- Equipment ---
	var equip_hdr := Label.new()
	equip_hdr.text = "Equipment"
	equip_hdr.add_theme_font_size_override("font_size", 14)
	equip_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	body_vbox.add_child(equip_hdr)

	var equip_slots: Array = [
		["Weapon 1", "weapon_1", soldier.weapon_1],
		["Weapon 2", "weapon_2", soldier.weapon_2],
		["Armor",    "armor",    soldier.armor],
	]
	for slot_entry in equip_slots:
		var slot_label: String = slot_entry[0]
		var slot_key: String   = slot_entry[1]
		var item: ItemData     = slot_entry[2]

		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 10)
		body_vbox.add_child(slot_row)

		if item != null:
			var icon_path := ItemData.get_icon_path(item)
			if icon_path != "" and ResourceLoader.exists(icon_path):
				slot_row.add_child(UIKit.icon(icon_path, 28))

		var slot_name_lbl := Label.new()
		slot_name_lbl.text = slot_label + ":"
		slot_name_lbl.custom_minimum_size = Vector2(80, 0)
		slot_row.add_child(slot_name_lbl)

		var item_lbl := Label.new()
		if item != null:
			var eq_hand: String = ItemData.hand_label(item)
			var eq_suffix: String = "" if eq_hand == "" else "  ·  " + eq_hand
			item_lbl.text = "%s  (%s)%s" % [item.item_name, item.get_stats_display(), eq_suffix]
			item_lbl.add_theme_color_override("font_color", GameTheme.INK)
		else:
			item_lbl.text = "(empty)"
			item_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		slot_row.add_child(item_lbl)

		if item != null:
			var unequip_btn := Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(82, 28)
			unequip_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var captured_slot: String = slot_key
			unequip_btn.pressed.connect(func():
				GameState.unequip_item(soldier, captured_slot)
				_open_soldier_details(soldier, false)
				_refresh_soldier_card(soldier)
			)
			slot_row.add_child(unequip_btn)

		var equip_open_btn := Button.new()
		equip_open_btn.text = "Equip"
		equip_open_btn.custom_minimum_size = Vector2(70, 28)
		equip_open_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var cap_slot: String = slot_key
		equip_open_btn.pressed.connect(func():
			_open_equip_window(soldier, cap_slot, overlay)
		)
		# A two-handed primary weapon occupies both hands: the off-hand slot
		# stays locked until it is unequipped.
		if slot_key == "weapon_2" and soldier.weapon_1 != null \
				and soldier.weapon_1.item_type == ItemData.ItemType.WEAPON \
				and soldier.weapon_1.hand_type == ItemData.HandType.TWO_HAND:
			equip_open_btn.disabled = true
			equip_open_btn.tooltip_text = "%s needs both hands. Unequip it to free this slot." % soldier.weapon_1.item_name
			item_lbl.text = "(blocked by %s)" % soldier.weapon_1.item_name
			item_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		slot_row.add_child(equip_open_btn)

	body_vbox.add_child(HSeparator.new())

	# --- Skills (equip up to 3; learn more at the Dungeon Skill Trainer) ---
	body_vbox.add_child(SkillLoadoutUI.build(soldier, func(): _open_soldier_details(soldier, false)))

	body_vbox.add_child(HSeparator.new())

	# --- Traits ---
	var traits_hdr := Label.new()
	traits_hdr.text = "Traits"
	traits_hdr.add_theme_font_size_override("font_size", 14)
	traits_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	body_vbox.add_child(traits_hdr)

	if soldier.traits.is_empty():
		var no_traits_lbl := Label.new()
		no_traits_lbl.text = "No traits yet. Survive hard battles to earn them."
		no_traits_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		body_vbox.add_child(no_traits_lbl)
	else:
		var cls_color := _get_class_color(soldier.soldier_class)
		for t in soldier.traits:
			var trait_card := UIKit.themed_card()
			trait_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var trait_vbox := VBoxContainer.new()
			trait_vbox.add_theme_constant_override("separation", 2)
			trait_card.add_child(trait_vbox)

			var trait_name_lbl := Label.new()
			trait_name_lbl.text = t.trait_name
			trait_name_lbl.add_theme_font_size_override("font_size", 13)
			trait_name_lbl.add_theme_color_override("font_color", cls_color if cls_color != Color(0.8, 0.8, 0.8) else GameTheme.LEATHER)
			trait_vbox.add_child(trait_name_lbl)

			var trait_stats_lbl := Label.new()
			trait_stats_lbl.text = t.get_stats_display()
			trait_stats_lbl.add_theme_font_size_override("font_size", 12)
			trait_stats_lbl.add_theme_color_override("font_color", _get_trait_stat_color(t))
			trait_vbox.add_child(trait_stats_lbl)

			var trait_desc_lbl := Label.new()
			trait_desc_lbl.text = t.description
			trait_desc_lbl.add_theme_font_size_override("font_size", 11)
			trait_desc_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
			trait_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			trait_desc_lbl.custom_minimum_size = Vector2(480, 0)
			trait_vbox.add_child(trait_desc_lbl)

			body_vbox.add_child(trait_card)


## Returns the soldier's currently equipped item for the given slot key, or
## null if the slot is empty.
func _get_equipped_item(soldier: SoldierData, slot_key: String) -> ItemData:
	match slot_key:
		"weapon_1": return soldier.weapon_1
		"weapon_2": return soldier.weapon_2
		"armor":    return soldier.armor
	return null

## Appends compact delta_label chips comparing `candidate` against `current`
## (or treating `current == null` as all-zero, i.e. every candidate stat is a
## gain). Only non-zero deltas are shown.
func _build_item_delta_chips(parent: HBoxContainer, candidate: ItemData, current: ItemData) -> void:
	var cur_dmg_min := 0
	var cur_dmg_max := 0
	var cur_defense := 0
	var cur_speed := 0
	var cur_dex := 0
	var cur_hp := 0
	var cur_hit := 0.0
	if current != null:
		cur_dmg_min = current.damage_min
		cur_dmg_max = current.damage_max
		cur_defense = current.defense
		cur_speed = current.speed_bonus
		cur_dex = current.dexterity_bonus
		cur_hp = current.hp_bonus
		cur_hit = current.hit_chance_bonus

	var dmg_min_delta := candidate.damage_min - cur_dmg_min
	var dmg_max_delta := candidate.damage_max - cur_dmg_max
	if dmg_min_delta != 0 or dmg_max_delta != 0:
		parent.add_child(UIKit.delta_label(dmg_min_delta, " DMG"))
	var defense_delta := candidate.defense - cur_defense
	if defense_delta != 0:
		parent.add_child(UIKit.delta_label(defense_delta, " DEF"))
	var speed_delta := candidate.speed_bonus - cur_speed
	if speed_delta != 0:
		parent.add_child(UIKit.delta_label(speed_delta, " SPD"))
	var dex_delta := candidate.dexterity_bonus - cur_dex
	if dex_delta != 0:
		parent.add_child(UIKit.delta_label(dex_delta, " DEX"))
	var hp_delta := candidate.hp_bonus - cur_hp
	if hp_delta != 0:
		parent.add_child(UIKit.delta_label(hp_delta, " HP"))
	var hit_delta := roundi((candidate.hit_chance_bonus - cur_hit) * 100.0)
	if hit_delta != 0:
		parent.add_child(UIKit.delta_label(hit_delta, "% HIT"))

func _open_equip_window(soldier: SoldierData, slot_key: String, _parent_overlay: CanvasLayer) -> void:
	var slot_labels := {"weapon_1": "Primary Weapon", "weapon_2": "Secondary / Shield", "armor": "Armor"}
	var slot_title: String = slot_labels.get(slot_key, slot_key)

	var win_layer := CanvasLayer.new()
	win_layer.layer = 70
	add_child(win_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	win_layer.add_child(bg)
	bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			win_layer.queue_free()
	)

	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance — set explicitly
	win_layer.add_child(wrapper)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 400)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Uses the themed stone frame from GameTheme.
	center.add_child(panel)
	UIKit.fade_in(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title_lbl := Label.new()
	title_lbl.text = "Equip: %s (%s)" % [slot_title, soldier.soldier_class]
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var close_btn := Button.new()
	close_btn.text = ""
	close_btn.theme_type_variation = "Close"   # wax-seal X icon
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(func(): win_layer.queue_free())
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Scrollable item list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var candidates: Array[ItemData] = GameState.get_owned_items_for_slot(slot_key)
	var filtered: Array[ItemData] = []
	for it in candidates:
		# Effective classes backfill legacy items (empty array) from the catalog.
		var eff_classes: Array = ItemData.get_effective_classes(it)
		if eff_classes.is_empty() or soldier.soldier_class in eff_classes:
			filtered.append(it)

	var equipped_item: ItemData = _get_equipped_item(soldier, slot_key)

	if filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No items available for this slot and class."
		empty_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		list.add_child(empty_lbl)
	else:
		for it in filtered:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_theme_constant_override("margin_top", 2)
			list.add_child(row)

			var icon_rect := TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(40, 40)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var icon_path: String = ItemData.get_icon_path(it)
			if icon_path != "" and ResourceLoader.exists(icon_path):
				icon_rect.texture = load(icon_path) as Texture2D
			row.add_child(icon_rect)

			var info_lbl := Label.new()
			var hand_tag: String = ItemData.hand_label(it)
			var name_line: String = it.item_name if hand_tag == "" else "%s  ·  %s" % [it.item_name, hand_tag]
			info_lbl.text = "%s\n%s" % [name_line, it.get_stats_display()]
			info_lbl.add_theme_color_override("font_color", GameTheme.INK)
			info_lbl.add_theme_font_size_override("font_size", 12)
			info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			row.add_child(info_lbl)

			# Stat deltas vs the currently equipped item in this slot (or all-gain
			# if the slot is empty).
			var delta_box := HBoxContainer.new()
			delta_box.add_theme_constant_override("separation", 6)
			delta_box.size_flags_horizontal = Control.SIZE_SHRINK_END
			_build_item_delta_chips(delta_box, it, equipped_item)
			row.add_child(delta_box)

			var pick_btn := Button.new()
			pick_btn.text = "Equip"
			pick_btn.custom_minimum_size = Vector2(70, 28)
			pick_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var captured_item: ItemData = it
			pick_btn.pressed.connect(func():
				GameState.equip_owned_item(soldier, captured_item, slot_key)
				win_layer.queue_free()
				_open_soldier_details(soldier, false)
				_refresh_soldier_card(soldier)
			)
			row.add_child(pick_btn)

	vbox.add_child(HSeparator.new())

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel_btn.pressed.connect(func(): win_layer.queue_free())
	vbox.add_child(cancel_btn)

# ---------------------------------------------------------------------------
# DUNGEON PANEL — inline port of expedition_panel.gd
# ---------------------------------------------------------------------------
func _rebuild_dungeon_panel() -> void:
	for child in _dungeon_panel_content.get_children():
		child.queue_free()

	if DungeonState.active:
		_build_active_expedition_ui()
	else:
		_build_start_expedition_ui()

func _build_active_expedition_ui() -> void:
	var status_lbl := Label.new()
	status_lbl.text = "Active Expedition: Dungeon Level %d" % DungeonState.dungeon_level
	status_lbl.add_theme_font_size_override("font_size", 18)
	status_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
	_dungeon_panel_content.add_child(status_lbl)

	var party_hdr := Label.new()
	party_hdr.text = "Party Status:"
	party_hdr.add_theme_font_size_override("font_size", 14)
	party_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	_dungeon_panel_content.add_child(party_hdr)

	for s in DungeonState.soldiers_in_dungeon:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_lbl := Label.new()
		name_lbl.text = "%s [%s]" % [s.soldier_name, s.soldier_class]
		name_lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_lbl)
		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d / %d" % [s.hp_current, s.hp_max]
		hp_lbl.add_theme_color_override("font_color", _hp_color(s))
		row.add_child(hp_lbl)
		_dungeon_panel_content.add_child(row)

	_dungeon_panel_content.add_child(HSeparator.new())

	var enter_btn := Button.new()
	enter_btn.text = "Enter Dungeon Map"
	enter_btn.custom_minimum_size = Vector2(400, 50)
	enter_btn.add_theme_font_size_override("font_size", 16)
	enter_btn.pressed.connect(_open_dungeon_map)
	_dungeon_panel_content.add_child(enter_btn)

	var recall_btn := Button.new()
	recall_btn.text = "Recall All Soldiers to City"
	recall_btn.custom_minimum_size = Vector2(400, 44)
	recall_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	recall_btn.pressed.connect(func():
		DungeonState.recall_soldiers()
		_rebuild_dungeon_panel()
	)
	_dungeon_panel_content.add_child(recall_btn)

func _build_start_expedition_ui() -> void:
	var level_lbl := Label.new()
	level_lbl.text = "Dungeon Level %d  |  Recommended soldier level: %d+" % [
		DungeonState.dungeon_level,
		1 + (DungeonState.dungeon_level - 1) * 2,
	]
	level_lbl.add_theme_font_size_override("font_size", 16)
	_dungeon_panel_content.add_child(level_lbl)

	# Surface an in-progress dungeon left behind by a previous recall: the next
	# party resumes the same map where the last one left off, not a fresh one.
	if DungeonState.map != null and DungeonState.map.dungeon_level == DungeonState.dungeon_level:
		var resume_lbl := Label.new()
		resume_lbl.text = "An expedition is already underway here. Your soldiers will resume where the last party left off."
		resume_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		resume_lbl.custom_minimum_size = Vector2(600, 0)
		resume_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
		_dungeon_panel_content.add_child(resume_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = (
		"Assign soldiers to explore the dungeon. They will enter on your next End Turn.\n"
		+ "Soldiers in the dungeon CANNOT defend the city: choose carefully.\n"
		+ "Soldiers who die in the dungeon are lost permanently."
	)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(600, 0)
	desc_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	_dungeon_panel_content.add_child(desc_lbl)

	_dungeon_panel_content.add_child(HSeparator.new())

	# Assign section header
	var assign_hdr := Label.new()
	assign_hdr.text = "Assign Soldiers to Expedition"
	assign_hdr.add_theme_font_size_override("font_size", 14)
	assign_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	_dungeon_panel_content.add_child(assign_hdr)

	if GameState.soldiers.is_empty():
		var no_sol := Label.new()
		no_sol.text = "No soldiers available."
		_dungeon_panel_content.add_child(no_sol)
	else:
		for s in GameState.soldiers:
			if not s.is_alive():
				continue
			if GameState.training_soldiers.has(s):
				var trainer_row := HBoxContainer.new()
				trainer_row.add_theme_constant_override("separation", 12)
				var name_lbl := Label.new()
				name_lbl.text = "%s [%s Lv.%d]" % [s.soldier_name, s.soldier_class, s.level]
				name_lbl.custom_minimum_size = Vector2(280, 0)
				name_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
				trainer_row.add_child(name_lbl)
				var status_lbl := Label.new()
				status_lbl.text = "[Training]"
				status_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
				trainer_row.add_child(status_lbl)
				_dungeon_panel_content.add_child(trainer_row)
				continue

			var row := _make_dungeon_soldier_row(s)
			_dungeon_panel_content.add_child(row)

	_dungeon_panel_content.add_child(HSeparator.new())

	# Staged section
	var staged_hdr := Label.new()
	staged_hdr.text = "Staged for Expedition (%d)" % DungeonState.pending_soldiers.size()
	staged_hdr.add_theme_font_size_override("font_size", 14)
	staged_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	_dungeon_panel_content.add_child(staged_hdr)

	if DungeonState.pending_soldiers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No soldiers staged yet."
		empty_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		_dungeon_panel_content.add_child(empty_lbl)
	else:
		for s in DungeonState.pending_soldiers:
			var staged_lbl := Label.new()
			staged_lbl.text = "  -> %s [%s Lv.%d]" % [s.soldier_name, s.soldier_class, s.level]
			staged_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
			_dungeon_panel_content.add_child(staged_lbl)

	_dungeon_panel_content.add_child(HSeparator.new())

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm: Soldiers will enter dungeon on End Turn (%d staged)" % DungeonState.pending_soldiers.size()
	confirm_btn.disabled = DungeonState.pending_soldiers.is_empty()
	confirm_btn.custom_minimum_size = Vector2(600, 50)
	confirm_btn.add_theme_font_size_override("font_size", 15)
	confirm_btn.pressed.connect(_on_dungeon_confirm_pressed)
	_dungeon_panel_content.add_child(confirm_btn)

func _make_dungeon_soldier_row(s: SoldierData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = "%s [%s Lv.%d]" % [s.soldier_name, s.soldier_class, s.level]
	name_lbl.custom_minimum_size = Vector2(280, 0)
	row.add_child(name_lbl)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP %d/%d  POW %d  SPD %d" % [s.hp_current, s.hp_max, s.power, s.speed]
	hp_lbl.add_theme_color_override("font_color", _hp_color(s))
	hp_lbl.custom_minimum_size = Vector2(260, 0)
	row.add_child(hp_lbl)

	var is_staged: bool = DungeonState.pending_soldiers.has(s)
	var assign_btn := Button.new()
	assign_btn.text = "Remove" if is_staged else "Stage"
	assign_btn.custom_minimum_size = Vector2(90, 32)
	var captured_s: SoldierData = s
	assign_btn.pressed.connect(func():
		if DungeonState.pending_soldiers.has(captured_s):
			DungeonState.pending_soldiers.erase(captured_s)
		else:
			DungeonState.pending_soldiers.append(captured_s)
		_rebuild_dungeon_panel()
	)
	row.add_child(assign_btn)
	return row

func _on_dungeon_confirm_pressed() -> void:
	for s in DungeonState.pending_soldiers:
		if GameState.soldiers.has(s):
			GameState.soldiers.erase(s)
	GameState.emit_signal("soldiers_changed")
	_rebuild_dungeon_panel()

func _hp_color(s) -> Color:
	var pct: float = float(s.hp_current) / float(max(1, s.hp_max))
	if pct > 0.6:
		return GameTheme.MOSS
	elif pct > 0.3:
		return Color(0.9, 0.7, 0.2)
	return Color(0.9, 0.3, 0.3)

# ---------------------------------------------------------------------------
# STORY PANEL
# ---------------------------------------------------------------------------
func _rebuild_story_panel() -> void:
	_story_panel.rebuild()


func _on_faction_standing_changed() -> void:
	if _current_panel == "Story":
		_rebuild_story_panel()

func _refresh_story_badge() -> void:
	if not is_instance_valid(btn_tab_story):
		return

	var count: int = StoryManager.get_unread_count()

	if count > 0:
		btn_tab_story.text = "Story (%d)" % count
		btn_tab_story.add_theme_color_override("font_color", GameTheme.LEATHER)
	else:
		btn_tab_story.text = "Story"
		btn_tab_story.remove_theme_color_override("font_color")

func _on_new_letter_received(_letter: Dictionary) -> void:
	_refresh_story_badge()
	if _current_panel == "Story":
		_rebuild_story_panel()

# ---------------------------------------------------------------------------
# End Turn
# ---------------------------------------------------------------------------
func _on_btn_end_turn_pressed() -> void:
	if GameState.menu_open:
		return
	SFX.play("end_turn")
	GameState.end_turn()

# ---------------------------------------------------------------------------
# Main Menu — autosaves to the current slot (recap already autosaves on end
# turn; this covers leaving mid-turn) then fades to the title screen.
# ---------------------------------------------------------------------------
func _on_btn_main_menu_pressed() -> void:
	if GameState.menu_open:
		return
	if SaveManager.current_slot > 0:
		SaveManager.save_game(SaveManager.current_slot)
	GameState.in_city_view = false
	SceneFader.change_scene("res://scenes/ui/main_menu.tscn")

# ---------------------------------------------------------------------------
# Combat flow — ported from City_view.gd
# ---------------------------------------------------------------------------
func _on_combat_started() -> void:
	_main_layout.visible = false
	if not pre_combat_screen.selection_confirmed.is_connected(_on_soldiers_selected):
		pre_combat_screen.selection_confirmed.connect(_on_soldiers_selected, CONNECT_ONE_SHOT)
	pre_combat_screen.open(CombatState.enemies)

# ---------------------------------------------------------------------------
# Raid pursuit — bandit_raid event "Send soldiers to pursue them"
# ---------------------------------------------------------------------------
func _on_raid_pursuit_triggered() -> void:
	# Build a small raider encounter (2–3 bandits at low difficulty).
	var raider_wave: Array[EnemyData] = []
	raider_wave.assign(EnemyData.make_random_wave(2).slice(0, randi_range(2, 3)))
	CombatState.start_combat(raider_wave)

	# Register a one-shot callback so we can apply the gold recovery on victory.
	CombatState.combat_ended.connect(_on_raid_pursuit_combat_ended, CONNECT_ONE_SHOT)

	# Open soldier selection exactly like a normal wave defence.
	_main_layout.visible = false
	if not pre_combat_screen.selection_confirmed.is_connected(_on_soldiers_selected):
		pre_combat_screen.selection_confirmed.connect(_on_soldiers_selected, CONNECT_ONE_SHOT)
	pre_combat_screen.open(CombatState.enemies)

func _on_raid_pursuit_combat_ended(victory: bool) -> void:
	if victory:
		# Raiders are routed — recover some of the stolen gold.
		var recovered: int = randi_range(10, 20)
		GameState.add_post_turn_resource_delta("Gold", recovered)
		GameState.turn_recap.append("Raiders routed: recovered %d Gold." % recovered)

func _on_scout_combat_result(result: Dictionary) -> void:
	GameState.menu_open = true
	var overlay := CanvasLayer.new()
	overlay.layer = 70
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(420, 180)
	panel.custom_minimum_size = Vector2(440, 300)
	panel.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Scout Party Report"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var scouts: Array = result.get("scout_names", [])
	var sent_lbl := Label.new()
	sent_lbl.text = "Sent: %s" % (", ".join(scouts) if not scouts.is_empty() else "None")
	sent_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	sent_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sent_lbl)

	var victory: bool = result.get("victory", false)
	var outcome_lbl := Label.new()
	outcome_lbl.text = "VICTORY! Scouts scattered." if victory else "DEFEAT! Scouts drove them back."
	outcome_lbl.add_theme_font_size_override("font_size", 16)
	outcome_lbl.add_theme_color_override("font_color", GameTheme.MOSS if victory else GameTheme.WAX)
	outcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(outcome_lbl)

	var lost: int = result.get("soldiers_lost", 0)
	var loss_lbl := Label.new()
	loss_lbl.text = "%d soldier%s lost." % [lost, "s" if lost != 1 else ""] if lost > 0 else "No soldiers lost."
	loss_lbl.add_theme_color_override("font_color", GameTheme.WAX if lost > 0 else GameTheme.MOSS)
	loss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(loss_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(400, 44)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
	)
	vbox.add_child(close_btn)

func _on_soldiers_selected(soldiers: Array) -> void:
	CombatState.allies = soldiers
	combat_transition.play(CombatState.enemies)
	combat_transition.transition_finished.connect(
		func(): CombatState.begin_after_selection(),
		CONNECT_ONE_SHOT
	)

func _on_soldiers_retrieved() -> void:
	_main_layout.visible = true
	if _current_panel == "Dungeon":
		_rebuild_dungeon_panel()

# Called via group — recap screen dismissed
func _on_recap_dismissed() -> void:
	_main_layout.visible = true
	_flush_next_event()

func _flush_next_event() -> void:
	if _deferred_events.is_empty():
		return
	if not is_instance_valid(_faction_event_popup):
		return
	var event: Dictionary = _deferred_events.pop_front()
	_faction_event_popup.show_event(event)

# ---------------------------------------------------------------------------
# Event popup handlers (faction events + story letters share the same popup)
# ---------------------------------------------------------------------------
func _on_faction_event_ready(event: Dictionary) -> void:
	var e := event.duplicate()
	e["type"] = "faction"
	_deferred_events.append(e)

func _on_story_event_popup_ready(event: Dictionary) -> void:
	_deferred_events.append(event.duplicate())

func _on_game_event_popup_ready(event: Dictionary) -> void:
	_deferred_events.append(event.duplicate())

func _on_popup_choice_made(event_id: String, choice_index: int) -> void:
	if StoryManager.LETTER_CONTENT.has(event_id):
		StoryManager.mark_read(event_id)
		FactionState.on_letter_read(StoryManager.LETTER_CONTENT[event_id].get("sender", ""))
	elif _is_game_event_id(event_id):
		GameEvents.resolve_game_event(event_id, choice_index)
	else:
		FactionEvents.resolve(event_id, choice_index)

	if _current_panel == "Story":
		_rebuild_story_panel()

	_flush_next_event()

func _is_game_event_id(event_id: String) -> bool:
	for e in GameState.EVENTS:
		if e.get("id", "") == event_id:
			return true
	return false

# ---------------------------------------------------------------------------
# City defense result / replay — ported from City_view.gd
# ---------------------------------------------------------------------------
func _on_city_defense_result(result: Dictionary) -> void:
	GameState.menu_open = true
	var overlay := CanvasLayer.new()
	overlay.layer = 70
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	# Full-rect wrapper + CenterContainer so the panel is truly centred on the
	# 1200x720 screen regardless of its final (content-driven) size.
	var wrapper := Control.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance
	overlay.add_child(wrapper)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 300)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var cd_frame := PixelUI.parchment_window_stylebox(22)
	if cd_frame != null:
		panel.add_theme_stylebox_override("panel", cd_frame)
	else:
		# Fallback so the panel never reads as a bare/unframed container if the
		# card_frame.png art is ever missing.
		panel.add_theme_stylebox_override("panel",
			GameTheme.flat(GameTheme.PARCHMENT, GameTheme.IRON, 22, 2))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Smaller header — "City Attacked!" + the wave source, both dark/readable
	# on the light parchment.
	var title := Label.new()
	title.text = "City Attacked!"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var source_lbl := Label.new()
	source_lbl.text = result.get("wave_source", "Enemy Wave")
	source_lbl.add_theme_font_size_override("font_size", 13)
	source_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	source_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(source_lbl)

	# Big VICTORY/DEFEAT headline — the focal point of the panel, matching the
	# combat scene's end-of-fight overlay convention.
	var victory: bool = result.get("victory", false)
	var outcome_lbl := Label.new()
	outcome_lbl.text = "VICTORY! City held." if victory else "DEFEAT! City overwhelmed."
	outcome_lbl.add_theme_font_size_override("font_size", 32)
	outcome_lbl.add_theme_color_override("font_color",
		GameTheme.MOSS if victory else GameTheme.WAX)
	outcome_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	outcome_lbl.custom_minimum_size = Vector2(380, 0)
	vbox.add_child(outcome_lbl)

	var soldiers_lost: int = result.get("soldiers_lost", 0)
	if soldiers_lost > 0:
		var loss_lbl := Label.new()
		loss_lbl.text = "%d soldier%s lost." % [soldiers_lost, "s" if soldiers_lost != 1 else ""]
		loss_lbl.add_theme_font_size_override("font_size", 16)
		loss_lbl.add_theme_color_override("font_color", GameTheme.WAX)
		loss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(loss_lbl)
	else:
		var no_loss_lbl := Label.new()
		no_loss_lbl.text = "No soldiers lost."
		no_loss_lbl.add_theme_font_size_override("font_size", 16)
		no_loss_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
		no_loss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_loss_lbl)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(400, 44)
	continue_btn.add_theme_font_size_override("font_size", 16)
	continue_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
		if GameState.city_walls <= 0:
			_show_city_fallen_overlay()
			return
		if GameState.game_won_achieved:
			# The final boss wave was just won via city-defense — show the
			# victory screen now that the "City Attacked!" dialog has been
			# dismissed. The run is over, so skip the normal turn continuation.
			GameState.announce_game_won_if_pending()
			return
		GameState.emit_signal("turn_ended", GameState.current_turn)
		GameState.emit_signal("recap_ready")
	)
	vbox.add_child(continue_btn)

# ---------------------------------------------------------------------------
# City defense choice — shown when a wave attacked while the expedition was
# active and the city has at least one defender. The player picks how the
# fight is resolved; "Skip" semantics live in the result dialog above.
# ---------------------------------------------------------------------------
func _show_city_defense_choice() -> void:
	var battle: Dictionary = GameState._pending_city_defense_battle
	var defenders: Array = battle.get("defenders", [])

	# No defenders to fight with — the city falls automatically, no choice to make.
	if defenders.is_empty():
		_on_city_defense_result(GameState.resolve_city_defense_auto())
		return

	GameState.menu_open = true
	var overlay := CanvasLayer.new()
	overlay.layer = 70
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(420, 180)
	panel.custom_minimum_size = Vector2(440, 260)
	panel.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Enemies attack the city!"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	var source_lbl := Label.new()
	source_lbl.text = battle.get("wave_source", "Enemy Wave")
	source_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	source_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(source_lbl)

	var body_lbl := Label.new()
	body_lbl.text = "Your remaining soldiers defend."
	body_lbl.add_theme_color_override("font_color", GameTheme.INK)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(body_lbl)

	var watch_btn := Button.new()
	watch_btn.text = "Watch Battle"
	watch_btn.custom_minimum_size = Vector2(400, 44)
	watch_btn.add_theme_font_size_override("font_size", 16)
	watch_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
		_start_city_defense_spectator(battle)
	)
	vbox.add_child(watch_btn)

	var auto_btn := Button.new()
	auto_btn.text = "Auto-Resolve"
	auto_btn.custom_minimum_size = Vector2(400, 44)
	auto_btn.add_theme_font_size_override("font_size", 16)
	auto_btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
		_on_city_defense_result(GameState.resolve_city_defense_auto())
	)
	vbox.add_child(auto_btn)

## Launches a live spectator battle (real defenders vs. the actual wave) using
## the normal combat scene with locked, auto-battle-only controls. When the
## fight ends, shows the same "City Attacked!" result dialog as Auto-Resolve.
func _start_city_defense_spectator(battle: Dictionary) -> void:
	var defenders: Array[SoldierData] = []
	defenders.assign(battle.get("defenders", []))
	var wave_names: Array[String] = []
	wave_names.assign(battle.get("wave_names", []))
	var wave_source: String = battle.get("wave_source", "Enemy Wave")

	_main_layout.visible = false
	combat_scene.spectator_battle_finished.connect(
		_on_city_defense_spectator_finished.bind(defenders, wave_names, wave_source),
		CONNECT_ONE_SHOT
	)
	GameState.start_city_defense_spectator_battle()

func _on_city_defense_spectator_finished(victory: bool, defenders: Array[SoldierData], wave_names: Array[String], wave_source: String) -> void:
	_main_layout.visible = true
	var result := GameState.build_city_defense_spectator_result(defenders, wave_names, wave_source, victory)
	_on_city_defense_result(result)

# ---------------------------------------------------------------------------
# Dungeon map transition — ported from City_view.gd
# ---------------------------------------------------------------------------
func _play_dungeon_transition(header_text: String, at_peak: Callable, on_complete: Callable = Callable(), start_black: bool = false) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 1.0 if start_black else 0.0
	root.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance
	overlay.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(700, 120)
	vbox.position -= Vector2(350, 60)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	root.add_child(vbox)

	var header_lbl := Label.new()
	header_lbl.text = header_text
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 22)
	header_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
	vbox.add_child(header_lbl)

	var tip_lbl := Label.new()
	tip_lbl.text = DUNGEON_TIPS[randi() % DUNGEON_TIPS.size()]
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.add_theme_font_size_override("font_size", 14)
	tip_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip_lbl.custom_minimum_size = Vector2(700, 0)
	vbox.add_child(tip_lbl)

	var tween := create_tween()
	if not start_black:
		tween.tween_property(root, "modulate:a", 1.0, 0.35)
	tween.tween_callback(at_peak)
	tween.tween_interval(1.2)
	tween.tween_property(root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func():
		overlay.queue_free()
		if on_complete.is_valid():
			on_complete.call()
	)

func _open_dungeon_map() -> void:
	_main_layout.visible = false
	MusicManager.play("dungeon")
	if dungeon_map_scene != null:
		if not dungeon_map_scene.dungeon_scene_closed.is_connected(_on_dungeon_scene_closed):
			dungeon_map_scene.dungeon_scene_closed.connect(_on_dungeon_scene_closed, CONNECT_ONE_SHOT)
		dungeon_map_scene.show()
		return
	var header: String = "Entering Dungeon: Level %d" % DungeonState.dungeon_level
	_play_dungeon_transition(header, func():
		dungeon_map_scene = preload("res://scenes/dungeon/dungeon_map_scene.tscn").instantiate()
		dungeon_map_scene.dungeon_scene_closed.connect(_on_dungeon_scene_closed, CONNECT_ONE_SHOT)
		add_child(dungeon_map_scene)
	)

func _on_dungeon_scene_closed() -> void:
	dungeon_map_scene = null
	MusicManager.play("hub")
	var at_peak := func():
		_main_layout.visible = true
		if _current_panel == "Dungeon":
			_rebuild_dungeon_panel()
	var on_complete := func():
		if not DungeonState.active:
			if not GameState._pending_city_defense_battle.is_empty():
				_show_city_defense_choice()
			else:
				GameState.emit_signal("turn_ended", GameState.current_turn)
				GameState.emit_signal("recap_ready")
	_play_dungeon_transition("Returning to City...", at_peak, on_complete, true)

# ---------------------------------------------------------------------------
# Prince death overlay
# ---------------------------------------------------------------------------
func _on_prince_consumed() -> void:
	var overlay: CanvasLayer = preload("res://scenes/ui/prince_death_overlay.tscn").instantiate()
	add_child(overlay)

# ---------------------------------------------------------------------------
# Resource display — ported from City_view.gd
# ---------------------------------------------------------------------------
func _update_resource_display() -> void:
	if not is_instance_valid(label_gold):
		return
	label_gold.text   = "%d" % GameState.gold
	label_wood.text   = "%d" % GameState.wood
	label_stone.text  = "%d" % GameState.stone
	label_iron.text   = "%d" % GameState.iron
	label_steel.text  = "%d" % GameState.steel
	label_food.text   = "%d" % GameState.food
	label_pep.text    = "People: %d" % GameState.workforce_total
	label_turn.text   = "Turn: %d" % GameState.current_turn

func _update_threat_display() -> void:
	if not is_instance_valid(threat_bar):
		return
	var t: int = GameState.threat
	threat_bar.value = min(t, 100)
	threat_pct_label.text = "%d%%" % t
	# Calm weathered slate at low threat → rust → bright danger as it fills.
	var f: float = clampf(t / 100.0, 0.0, 1.0)
	var fill_color: Color = GameTheme.IRON.lerp(GameTheme.CRIMSON, clampf(f * 1.4, 0.0, 1.0))
	if f >= 0.8:
		fill_color = GameTheme.CRIMSON.lerp(GameTheme.WAX, (f - 0.8) / 0.2)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	threat_bar.add_theme_stylebox_override("fill", fill_style)
	threat_pct_label.add_theme_color_override("font_color",
		GameTheme.WAX if t >= 70 else GameTheme.INK)

	# Breathing pulse once threat is critical; steady otherwise.
	if t >= 80:
		if _threat_pulse == null or not _threat_pulse.is_valid():
			_threat_pulse = create_tween().set_loops()
			_threat_pulse.tween_property(threat_bar, "modulate:a", 0.55, 0.5)
			_threat_pulse.tween_property(threat_bar, "modulate:a", 1.0, 0.5)
	else:
		if _threat_pulse != null and _threat_pulse.is_valid():
			_threat_pulse.kill()
		_threat_pulse = null
		threat_bar.modulate.a = 1.0

func _update_walls_display() -> void:
	if not is_instance_valid(label_city_walls):
		return
	label_city_walls.text = "Walls: %d/%d" % [GameState.city_walls, GameState.max_city_walls]
	if GameState.city_walls <= 1:
		label_city_walls.add_theme_color_override("font_color", GameTheme.WAX)
	else:
		label_city_walls.add_theme_color_override("font_color", GameTheme.INK)

func _update_damaged_buildings_banner() -> void:
	if not is_instance_valid(label_damaged_buildings):
		return
	var count: int = GameState.damaged_buildings.size()
	if count == 0:
		label_damaged_buildings.visible = false
		return
	label_damaged_buildings.text = "  [!] %d building%s damaged. Open City tab and click Manage to repair (30 Gold each)" % [
		count, "s" if count != 1 else ""
	]
	label_damaged_buildings.visible = true

# ---------------------------------------------------------------------------
# Heal injured / unavailable soldier
# ---------------------------------------------------------------------------
func _on_heal_soldier_pressed(soldier: SoldierData) -> void:
	if GameState.gold < 50:
		return
	GameState.gold -= 50
	GameState.emit_signal("resources_changed")
	if randf() < 0.7:
		soldier.unavailable_turns = 0
		_show_brief_feedback("Treatment successful: %s is ready." % soldier.soldier_name, GameTheme.MOSS)
	else:
		_show_brief_feedback("Treatment failed for %s." % soldier.soldier_name, GameTheme.CRIMSON)
	GameState.emit_signal("soldiers_changed")
	if _current_panel == "Army":
		_rebuild_army_panel()

## Shows a small floating label at the top of the army panel that fades out after ~2 s.
func _show_brief_feedback(message: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = message
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	# Insert at the top of the army panel so it is immediately visible
	_army_panel_content.add_child(lbl)
	_army_panel_content.move_child(lbl, 0)
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tween.tween_callback(lbl.queue_free)

# ---------------------------------------------------------------------------
# City fallen / game won handlers
# ---------------------------------------------------------------------------
## Fired when GameState.city_walls hits 0 (apply_wave_loss_consequences) or
## CombatState reports game_over. This does NOT immediately pop an overlay —
## the result dialog for whatever battle just ended (City Attacked! / DEFEAT!)
## must be shown and dismissed first. _show_city_fallen_overlay() is what
## actually presents the game-over screen, called from each "Continue" handler
## once GameState.city_walls <= 0 is observed. This handler only guards against
## redundant emissions and is otherwise a no-op — kept so future signal-based
## hooks have a single place to attach.
func _on_city_fallen() -> void:
	pass

## The proper "city has fallen" game-over screen — used for ANY path that
## drives GameState.city_walls to 0 (normal combat defeat, city-defense
## Auto-Resolve, city-defense Watch/spectator). NOT to be confused with
## prince_death_overlay.tscn, which is reserved for the actual veil-death
## condition (GameState.prince_consumed_by_veil, Pale Court vial).
func _show_city_fallen_overlay() -> void:
	# Guard: don't double-stack if already shown.
	for child in get_children():
		if child is CanvasLayer and child.has_meta("is_game_over_overlay"):
			return

	# Permadeath: delete the save the instant this game-over screen is shown,
	# and permanently block any later autosave (recap continue, Main Menu
	# buttons, etc) — so quitting from this screen can't preserve the save.
	SaveManager.delete_save_on_game_over()

	GameState.menu_open = true
	var overlay := CanvasLayer.new()
	overlay.layer = 128
	overlay.set_meta("is_game_over_overlay", true)
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.02, 0.02, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = GameTheme.get_theme()   # CanvasLayer breaks inheritance
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "THE CITY HAS FALLEN"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GameTheme.WAX)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "The walls have broken.\nThe kingdom is lost."
	subtitle.custom_minimum_size = Vector2(500, 0)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(subtitle)

	var stats_lbl := Label.new()
	stats_lbl.text = "Turn %d reached" % GameState.current_turn
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	var btn := Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(260, 50)
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(func():
		overlay.queue_free()
		GameState.menu_open = false
		SceneFader.change_scene("res://scenes/ui/main_menu.tscn")
	)
	vbox.add_child(btn)

func _on_game_won() -> void:
	# Prevent showing victory if a game-over overlay is already up, or if the
	# victory screen is already showing (e.g. game_won fired again, or
	# _ready()'s game_won_achieved catch-up ran after the live signal).
	for child in get_children():
		if child is CanvasLayer and (child.has_meta("is_game_over_overlay") or child.has_meta("is_victory_overlay")):
			return

	var scene_path := "res://scenes/ui/victory_screen.tscn"
	if not ResourceLoader.exists(scene_path):
		return

	GameState.menu_open = true
	var victory_scene: PackedScene = load(scene_path)
	var victory_node: Node = victory_scene.instantiate()
	victory_node.set_meta("is_victory_overlay", true)
	add_child(victory_node)
	if victory_node.has_method("show_ending"):
		victory_node.show_ending(GameState.get_win_ending())
