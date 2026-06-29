# BuildingPopup.gd
extends CanvasLayer

# Static structure lives in res://scenes/ui/building_popup.tscn.
# Only dynamic list content (tavern roster, market items, etc.) is still built in code.

@onready var popup_panel: Panel = $PopupPanel
@onready var header_label: Label = $PopupPanel/HeaderBanner/HeaderLabel
@onready var building_img: TextureRect = $PopupPanel/ImageFrame/BuildingImg
@onready var image_frame: PanelContainer = $PopupPanel/ImageFrame
@onready var content_tabs: TabContainer = $PopupPanel/ContentTabs
@onready var rebuild_section: VBoxContainer = $PopupPanel/RebuildSection
@onready var close_button: Button = $PopupPanel/CloseButton

# Building-specific sub-tab pages, rebuilt on every show_building/_refresh.
# Keyed by tab name (e.g. "Production", "Workers", "Buy", "Sell", "Upgrade").
# Values are plain VBoxContainers ready to receive content — for pages that
# need a single internal scroll, the VBox IS the scroll's inner content and
# is wrapped by a ScrollContainer before being added as a tab page.
var _tab_pages: Dictionary = {}

# Market Buy/Sell are now top-level sub-tabs; this persists which one was
# active across refreshes (index within ContentTabs, relative to the Market
# tab map ["Buy", "Sell", "Upgrade"]).
var _market_active_tab: int = 0

var current_building: String = ""
var reopen_menu_on_close: bool = false

func _ready() -> void:
	layer = 50
	popup_panel.theme = GameTheme.get_theme()
	# PopupPanel is a plain Panel (absolute-positioned children). Unlike the large
	# hub "Frame" stylebox (deliberately flat — stretching panel.png across ~1000px
	# smears its tacked corners), this popup is small enough (540x620) that the
	# 128px panel.png 9-slice reads cleanly: corners stay crisp, the clean center
	# stretches without visible grid/crack smearing.
	var frame_sb: StyleBox = popup_panel.theme.get_stylebox("panel", "Frame")
	# Dedicated ornate popup frame takes priority once the user generates it.
	# The art has ~28px transparent padding (region crops it) and ~48px corner
	# plates; edges/center tile so the parchment grain stays crisp. Children in
	# the .tscn are inset to live inside the border ring.
	if ResourceLoader.exists("res://assets/ui/city/frames/popup_frame.png"):
		frame_sb = PixelUI.tex_stylebox_frame(
			"res://assets/ui/city/frames/popup_frame.png",
			Rect2(28, 25, 200, 205), 48, 0)
	elif GameTheme.USE_CITY_PANELS and ResourceLoader.exists(GameTheme.CITY_DIR + "panel.png"):
		frame_sb = PixelUI.tex_stylebox(GameTheme.CITY_DIR + "panel.png", 28, 18)
	if frame_sb != null:
		popup_panel.add_theme_stylebox_override("panel", frame_sb)
	# Match UIKit.banner_header's heading font (the scene only sets size/color).
	var heading_font: Font = load(GameTheme.FONT_HEADING)
	if heading_font:
		header_label.add_theme_font_override("font", heading_font)
	_style_tabs(content_tabs)
	close_button.pressed.connect(_close_popup)
	popup_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
	)
	content_tabs.tab_changed.connect(_on_content_tab_changed)
	GameState.turn_ended.connect(func(_turn): _close_popup())
	hide()

# Pixel-art skin for a TabContainer: the page panel gets the textured card
# frame (tiled parchment, not a flat box) and the tab buttons reuse the
# parchment button art from GameTheme instead of Godot's flat default tabs.
# `framed = false` removes the page panel entirely — used for the market's
# inner Buy/Sell tabs so there is no frame-inside-a-frame; the tabs read as
# plain buttons above the list, sitting directly on the outer frame.
# The page panel has NO box frame of its own: the popup window already provides
# the ornate wooden frame, and a second box inside it read as "container in a
# container". Content sits directly on the window's parchment. The page draws
# only a thin IRON rule along its TOP edge, so the tab strip reads as a real
# tab bar with content underneath rather than buttons floating in space.
func _style_tabs(tc: TabContainer, _framed: bool = true) -> void:
	var page := StyleBoxFlat.new()
	page.bg_color = Color(0, 0, 0, 0)        # transparent: shows the parchment
	page.border_color = GameTheme.IRON
	page.border_width_top = 2
	page.content_margin_left = 6
	page.content_margin_right = 10           # keeps text clear of the scrollbar
	page.content_margin_top = 8
	page.content_margin_bottom = 4
	tc.add_theme_stylebox_override("panel", page)
	tc.add_theme_constant_override("side_margin", 4)
	var theme_ref: Theme = GameTheme.get_theme()
	var tab_on: StyleBox = theme_ref.get_stylebox("normal", "Button")
	var tab_off: StyleBox = theme_ref.get_stylebox("disabled", "Button")
	# Transparent strip behind the tab row so it sits on the parchment cleanly.
	tc.add_theme_stylebox_override("tabbar_background", StyleBoxEmpty.new())
	if tab_on != null:
		tc.add_theme_stylebox_override("tab_selected", tab_on)
	if tab_off != null:
		tc.add_theme_stylebox_override("tab_unselected", tab_off)
		tc.add_theme_stylebox_override("tab_hovered", tab_on if tab_on != null else tab_off)
	tc.add_theme_color_override("font_selected_color", GameTheme.INK)
	tc.add_theme_color_override("font_unselected_color", GameTheme.INK_SOFT)

## For Market, remembers which sub-tab (Buy/Sell/Upgrade) was active so
## `_refresh_info_market` (called on every buy/sell click) can restore it.
## Other buildings don't need persistence: their sub-tabs are cheap to
## rebuild and Godot keeps `content_tabs.current_tab` stable across our
## `_rebuild_tabs` calls only because we restore it explicitly below.
func _on_content_tab_changed(tab: int) -> void:
	if current_building == "Market":
		_market_active_tab = tab

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
func show_building(b_name: String, _b_desc: String) -> void:
	if DungeonState.active:
		return
	if GameState.menu_open and not reopen_menu_on_close:
		return

	current_building = b_name
	var _data = GameState.get_building_data(current_building)
	var _level := GameState.get_building_level(b_name)

	building_img.texture = _get_building_texture(b_name)
	image_frame.visible = building_img.texture != null

	var is_built: bool = GameState.is_building_built(b_name)
	_update_header()

	if not is_built:
		content_tabs.visible = false
		rebuild_section.visible = true
		_refresh_rebuild()
	else:
		rebuild_section.visible = false
		content_tabs.visible = true
		_rebuild_tabs(current_building)
		_refresh()
		# Restore the remembered Buy/Sell/Upgrade sub-tab for Market; every
		# other building simply opens on its first sub-tab.
		if current_building == "Market":
			content_tabs.current_tab = clampi(_market_active_tab, 0, content_tabs.get_tab_count() - 1)
		else:
			content_tabs.current_tab = 0

	GameState.menu_open = true
	show()
	UIKit.fade_in(popup_panel)

# ---------------------------------------------------------------------------
# Sub-tab scaffolding
# ---------------------------------------------------------------------------
## Returns the ordered list of sub-tab names for the given building. The last
## entry is always "Upgrade". A page name maps 1:1 to a key in `_tab_pages`.
func _get_tab_map(b_name: String) -> Array[String]:
	match b_name:
		"Tavern":
			return ["Recruits", "Upgrade"]
		"Market":
			return ["Buy", "Sell", "Upgrade"]
		"House":
			return ["Workers", "Upgrade"]
		"Barracks":
			return ["Status", "Upgrade"]
		"Steel Forge":
			return ["Production", "Upgrade"]
		"Training Grounds":
			return ["Trainers", "Upgrade"]
		"Blacksmith":
			return ["Craft", "Queue", "Upgrade"]
		_:
			return ["Production", "Upgrade"]

## Tab names whose page is a single ScrollContainer (genuinely long lists).
## All other pages are plain, non-scrolling VBoxContainers.
const SCROLL_TABS: Dictionary = {
	"Buy": true,         # Market buy list
	"Sell": true,        # Market sell list
	"Craft": true,       # Blacksmith craftable items
	"Queue": true,       # Blacksmith crafting queue (can grow long)
	"Trainers": true,    # Training Grounds assign/remove list
}

## Tab names that need static content ABOVE a single scrolling list, both on
## the same page. For these, `_tab_pages[tab_name]` is the non-scrolling
## header VBox and `_tab_pages[tab_name + "__scroll"]` is the scrolling
## list's inner VBox.
const SPLIT_SCROLL_TABS: Dictionary = {
	"Recruits": true,    # Tavern: innkeeper info/worker row, then roster grid
}

## Suffix appended to a SPLIT_SCROLL_TABS name to get its scroll-content key.
const SCROLL_SUFFIX: String = "__scroll"

## Rebuilds ContentTabs from scratch for `current_building`: frees any old
## tab pages, creates one fresh VBoxContainer per entry in `_get_tab_map`,
## wraps pages listed in SCROLL_TABS in a single ScrollContainer (or, for
## SPLIT_SCROLL_TABS, a static header VBox above a single scroll), and stores
## each content VBox in `_tab_pages` keyed by tab name. Called once per
## `show_building` (not on every in-tab refresh) so `content_tabs.current_tab`
## survives subsequent `_refresh()` calls triggered by button presses.
func _rebuild_tabs(b_name: String) -> void:
	for child in content_tabs.get_children():
		content_tabs.remove_child(child)
		child.queue_free()
	_tab_pages.clear()

	for tab_name in _get_tab_map(b_name):
		var content_vbox := VBoxContainer.new()
		content_vbox.add_theme_constant_override("separation", 7)
		content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var page: Control
		if SPLIT_SCROLL_TABS.get(tab_name, false):
			# Outer page: static header VBox on top, single scroll below.
			content_vbox.name = tab_name
			content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			page = content_vbox

			var header_vbox := VBoxContainer.new()
			header_vbox.add_theme_constant_override("separation", 7)
			header_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_vbox.add_child(header_vbox)

			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content_vbox.add_child(scroll)

			var scroll_vbox := VBoxContainer.new()
			scroll_vbox.add_theme_constant_override("separation", 7)
			scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(scroll_vbox)

			_tab_pages[tab_name] = header_vbox
			_tab_pages[tab_name + SCROLL_SUFFIX] = scroll_vbox
			content_tabs.add_child(page)
			continue

		if SCROLL_TABS.get(tab_name, false):
			var scroll := ScrollContainer.new()
			scroll.name = tab_name
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
			content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
			scroll.add_child(content_vbox)
			page = scroll
		else:
			content_vbox.name = tab_name
			page = content_vbox

		content_tabs.add_child(page)
		_tab_pages[tab_name] = content_vbox

	_style_tabs(content_tabs)

# ---------------------------------------------------------------------------
# Core refresh dispatcher — refills the CURRENT tab pages without touching
# ContentTabs' structure (so the active sub-tab doesn't jump on every click).
# ---------------------------------------------------------------------------
func _refresh() -> void:
	if current_building == "" or not GameState.is_building_built(current_building):
		return

	match current_building:
		"Tavern":
			_refresh_info_tavern()
		"Market":
			_refresh_info_market()
		"House":
			_refresh_info_house()
		"Training Grounds":
			_refresh_info_training_grounds()
		"Blacksmith":
			_refresh_info_weapon_forge()
		_:
			_refresh_info_standard()

	_fill_upgrade_vbox(_tab_pages["Upgrade"], current_building)

## Frees all children of a tab content VBox before refilling it.
## Detach first, then queue_free: a button's own `pressed` lambda often triggers
## this refresh, and immediate free() on the still-emitting button throws
## "Object is locked and can't be freed". remove_child detaches it from the tree
## right away (no overlap with the new content) and queue_free defers the actual
## free until the signal has finished.
func _clear_page(page: VBoxContainer) -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()

## Updates the top banner with "{Building name}  |  Lv X" (or "Ruins" if destroyed).
func _update_header() -> void:
	var level := GameState.get_building_level(current_building)
	var level_str: String = "Lv %d" % level if level >= 1 else "Ruins"
	header_label.text = "%s  |  %s" % [current_building, level_str]

# ---------------------------------------------------------------------------
# Shared row builders
# ---------------------------------------------------------------------------
## A "Workers: X | Available: A/B" sunken strip flanked by [-5][-1]  strip  [+1][+5]
## Ghost-styled steppers. `on_changed` is called after each click to refresh the
## owning tab. `building_name` is the worker pool key in GameState.building_workers.
## `extra_text` (optional) is appended to the strip label, e.g. a worker bonus note.
func _build_worker_row(building_name: String, on_changed: Callable, extra_text: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var workers: int = GameState.building_workers.get(building_name, 0)
	var strip := UIKit.sunken_strip()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strip_lbl := Label.new()
	strip_lbl.text = "Workers: %d  |  Available: %d / %d" % [
		workers,
		GameState.workforce_available,
		GameState.workforce_total,
	]
	strip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long text must shrink, not force the popup wider: the label's minimum
	# width stays 0 and overflow is clipped (tooltip carries the details).
	strip_lbl.clip_text = true
	strip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_lbl.tooltip_text = "Workforce cap: %d%s" % [GameState.workforce_cap, extra_text]
	strip.add_child(strip_lbl)

	var make_step_btn := func(label: String, delta: int, count: int) -> Button:
		var b := Button.new()
		b.text = label
		b.theme_type_variation = "Ghost"
		b.custom_minimum_size = Vector2(40, 36)
		b.add_to_group("no_ui_click")
		b.pressed.connect(func():
			for _i in count:
				var success := GameState.assign_worker(building_name, delta)
				if not success and delta < 0 and building_name == "Barracks":
					_show_barracks_remove_error()
			SFX.play("worker_tick")
			on_changed.call()
		)
		return b

	row.add_child(make_step_btn.call("-5", -1, 5))
	row.add_child(make_step_btn.call("-1", -1, 1))
	row.add_child(strip)
	row.add_child(make_step_btn.call("+1", 1, 1))
	row.add_child(make_step_btn.call("+5", 1, 5))
	return row

## A row of resource pills (icon + value) for a {resource_name: amount} dict.
## Positive amounts are tinted INK (affordable/gain), negative WAX (cost/loss).
func _build_resource_pills_row(amounts: Dictionary, px: int = 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for resource in amounts:
		var amount: int = amounts[resource]
		var sign_str := "+" if amount >= 0 else ""
		var pill := UIKit.resource_pill(resource, "%s%d" % [sign_str, amount], px)
		var lbl: Label = pill.get_meta("value_label")
		if lbl != null:
			lbl.add_theme_color_override("font_color", GameTheme.INK if amount >= 0 else GameTheme.WAX)
		row.add_child(pill)
	return row

## A row of resource pills for an upgrade/rebuild COST list: [["Gold", 50, true], ...]
## where the third element is `affordable` (bool) → INK if true, WAX if false.
func _build_cost_pills_row(cost_entries: Array, px: int = 18) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for entry in cost_entries:
		var res_name: String = entry[0]
		var amount: int = entry[1]
		var affordable: bool = entry[2]
		var pill := UIKit.resource_pill(res_name, amount, px)
		var lbl: Label = pill.get_meta("value_label")
		if lbl != null:
			lbl.add_theme_color_override("font_color", GameTheme.INK if affordable else GameTheme.WAX)
		row.add_child(pill)
	return row

# ---------------------------------------------------------------------------
# Info tab — Standard buildings (Farm, Forest, Quarry, Iron Mine, Butchery,
#            Steel Forge -> "Production" tab, Barracks -> "Status" tab)
# ---------------------------------------------------------------------------
func _refresh_info_standard() -> void:
	# Resource buildings and the Steel Forge land on "Production"; the Barracks
	# uses "Status" but shares this builder's layout.
	var page: VBoxContainer = _tab_pages.get("Production", null)
	if page == null:
		page = _tab_pages.get("Status", null)
	if page == null:
		return
	_clear_page(page)

	# Description label
	var data := GameState.get_building_data(current_building)
	var desc := Label.new()
	desc.text = data.description if data != null else ""
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.custom_minimum_size = Vector2(400, 0)
	desc.add_theme_font_size_override("font_size", 13)
	page.add_child(desc)

	var workers: int = GameState.building_workers.get(current_building, 0)
	var level := GameState.get_building_level(current_building)

	page.add_child(_build_worker_row(current_building, func(): _refresh()))

	page.add_child(HSeparator.new())

	if data == null:
		var no_data_lbl := Label.new()
		no_data_lbl.text = "No building data configured."
		page.add_child(no_data_lbl)
		return

	# Barracks — special production display
	if current_building == "Barracks":
		var staffed := workers > 0
		var morale_bonus := data.get_stat_at_level(data.morale_flat_by_level, level, 0)
		var regen_flat := data.get_stat_at_level(data.idle_hp_regen_by_level, level, 0)
		var regen_pct := data.get_float_stat_at_level(data.idle_hp_regen_pct_by_level, level, 0.0)
		var regen_str := ""
		if regen_pct > 0.0:
			regen_str = "  HP regen: %.0f%% of max HP per idle soldier\n" % (regen_pct * 100.0)
		elif regen_flat > 0:
			regen_str = "  HP regen: +%d flat HP per idle soldier\n" % regen_flat
		var defense_str := ""
		if level >= 3:
			defense_str = "  City defense: +5%% hit bonus\n"
		var barracks_prod_lbl := Label.new()
		barracks_prod_lbl.text = (
			"Soldier capacity: %d / %d\n" +
			"Morale: +%d per turn\n" +
			"Food consumed: -%d per turn\n" +
			"%s%s%s"
		) % [
			GameState.soldiers.size(),
			GameState.get_max_soldiers(),
			morale_bonus if staffed else 0,
			abs(data.consumes_food) if staffed else 0,
			regen_str,
			defense_str,
			"Assign workers to activate." if not staffed else "Barracks active."
		]
		barracks_prod_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
		barracks_prod_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		page.add_child(barracks_prod_lbl)
		return

	# Steel Forge — conversion building; production is driven by GameState iron→steel logic
	if current_building == "Steel Forge":
		var rate: int = data.get_stat_at_level(data.iron_by_level, level, 0)
		# iron_by_level stores the negative iron consumed per worker; steel_by_level the positive yield
		var iron_consumed: int = absi(rate)
		var steel_produced: int = data.get_stat_at_level(data.steel_by_level, level, 0)
		var conv_hdr := Label.new()
		conv_hdr.text = "Production per turn:" if workers > 0 else "Assign workers to turn Iron into Steel."
		conv_hdr.add_theme_color_override("font_color", GameTheme.MOSS)
		conv_hdr.autowrap_mode = TextServer.AUTOWRAP_WORD
		page.add_child(conv_hdr)
		if workers > 0:
			page.add_child(_build_resource_pills_row({
				"Iron": -iron_consumed * workers,
				"Steel": steel_produced * workers,
			}))
		return

	# Standard production
	var prod_hdr := Label.new()
	prod_hdr.text = "Production per turn:"
	prod_hdr.add_theme_color_override("font_color", GameTheme.MOSS)
	page.add_child(prod_hdr)

	var prod := data.get_production_for_workers(workers, level)
	var pill_amounts := {}
	for resource in prod:
		pill_amounts[resource] = prod[resource]

	var flat_morale := data.get_stat_at_level(data.morale_flat_by_level, level, 0)
	if flat_morale != 0:
		pill_amounts["Morale"] = flat_morale

	if pill_amounts.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "  (special building)"
		none_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
		page.add_child(none_lbl)
	else:
		page.add_child(_build_resource_pills_row(pill_amounts))

	if workers == 0 and not prod.is_empty():
		var assign_lbl := Label.new()
		assign_lbl.text = "(assign workers to produce)"
		assign_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		page.add_child(assign_lbl)

# Shows a brief inline error when Barracks worker removal is blocked.
func _show_barracks_remove_error() -> void:
	var page: VBoxContainer = _tab_pages.get("Status", null)
	if page == null:
		return
	var err_lbl := Label.new()
	err_lbl.text = "Cannot reduce staff - dismiss soldiers first."
	err_lbl.add_theme_color_override("font_color", GameTheme.WAX)
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	page.add_child(err_lbl)
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(err_lbl):
			err_lbl.queue_free()
	)

# ---------------------------------------------------------------------------
# Info tab — Tavern
# ---------------------------------------------------------------------------
func _refresh_info_tavern() -> void:
	var header: VBoxContainer = _tab_pages.get("Recruits", null)
	var roster_list: VBoxContainer = _tab_pages.get("Recruits" + SCROLL_SUFFIX, null)
	if header == null or roster_list == null:
		return
	_clear_page(header)
	_clear_page(roster_list)

	var innkeepers: int = GameState.building_workers.get("Tavern", 0)
	var committed_innkeepers: int = GameState.tavern_workers_last_turn
	var cost: int = GameState.get_recruit_cost()

	var info_lbl := Label.new()
	info_lbl.text = "Innkeepers: %d  (committed last turn: %d)\nRecruit cost: %d Gold  |  Slots: %d / %d\nRecruit bonus: +%d combat, +%d HP" % [
		innkeepers, committed_innkeepers, cost,
		GameState.soldiers.size(), GameState.get_max_soldiers(),
		GameState.get_recruit_combat_bonus(), GameState.get_recruit_hp_bonus()
	]
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_lbl.custom_minimum_size = Vector2(480, 0)
	info_lbl.add_theme_font_size_override("font_size", 12)
	header.add_child(info_lbl)

	# Innkeeper ±1/±5 buttons
	header.add_child(_build_worker_row("Tavern", func(): _refresh_info_tavern()))

	header.add_child(HSeparator.new())

	if GameState.tavern_roster.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No recruits available. Wait for next turn."
		roster_list.add_child(empty_lbl)
		return

	# Cards are now 170px wide; 480px scroll width fits 2 comfortably (3 would crowd).
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	roster_list.add_child(grid)
	for recruit in GameState.tavern_roster:
		grid.add_child(_make_recruit_card(recruit, committed_innkeepers))

func _make_recruit_card(recruit: SoldierData, innkeepers: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Card"
	UIKit.attach_hover_pop(panel)
	panel.custom_minimum_size = Vector2(170, 180)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = recruit.soldier_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.clip_contents = true
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# Idle sprite portrait — centered, takes the slack vertical space so the
	# card never shows a dead band between the name/class and the price button.
	var portrait_wrap := CenterContainer.new()
	portrait_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(portrait_wrap)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 88)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_wrap.add_child(portrait)

	var cls := recruit.soldier_class.to_lower()
	var suffix := "" if recruit.sprite_variant <= 1 else "_%d" % recruit.sprite_variant
	var tex_path := "res://assets/soldiers/%s/idle%s.png" % [cls, suffix]
	var idle_tex: Texture2D = null
	if ResourceLoader.exists(tex_path):
		idle_tex = load(tex_path) as Texture2D
	elif ResourceLoader.exists("res://assets/soldiers/%s/idle.png" % cls):
		idle_tex = load("res://assets/soldiers/%s/idle.png" % cls) as Texture2D
	portrait.texture = idle_tex
	if innkeepers < 1:
		# Mystery recruit: show the silhouette of the real sprite (so the card
		# isn't an empty void) but darken it near-black so the class/identity
		# stays hidden until innkeepers are staffed.
		portrait.self_modulate = Color(0.08, 0.07, 0.09)

	var class_lbl := Label.new()
	if innkeepers >= 1:
		class_lbl.text = recruit.soldier_class
		class_lbl.add_theme_color_override("font_color", _get_class_color(recruit.soldier_class))
	else:
		class_lbl.text = "???"
		class_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	class_lbl.add_theme_font_size_override("font_size", 11)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(class_lbl)

	var recruit_btn := Button.new()
	recruit_btn.text = "%d G" % GameState.get_recruit_cost()
	recruit_btn.add_theme_font_size_override("font_size", 11)
	recruit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recruit_btn.disabled = (
		GameState.gold < GameState.get_recruit_cost() or
		GameState.soldiers.size() >= GameState.get_max_soldiers()
	)
	recruit_btn.pressed.connect(func():
		if GameState.recruit_from_roster(recruit):
			_refresh_info_tavern()
	)
	vbox.add_child(recruit_btn)

	return panel

func _get_class_color(soldier_class: String) -> Color:
	match soldier_class:
		"Warrior": return GameTheme.CRIMSON
		"Archer":  return GameTheme.MOSS
		"Rogue":   return Color("#6b5380")  # muted plum, fits the parchment palette
		"Mage":    return GameTheme.FADED_BLUE
		"Knight":  return GameTheme.LEATHER
	return GameTheme.INK_SOFT

## A small colored chip showing an item's quality tier (Common/Uncommon/Rare —
## see GameState.QUALITY_NAMES). 0=muted iron, 1=moss (uncommon), 2=crimson (rare).
func _make_quality_badge(quality: int) -> PanelContainer:
	var q := clampi(quality, 0, 2)
	var colors := [GameTheme.IRON, GameTheme.MOSS, GameTheme.CRIMSON]
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = colors[q]
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", sb)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var lbl := Label.new()
	lbl.text = GameState.QUALITY_NAMES[q]
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", GameTheme.PARCHMENT)
	badge.add_child(lbl)
	return badge

# ---------------------------------------------------------------------------
# Info tab — Market
# ---------------------------------------------------------------------------
func _refresh_info_market() -> void:
	var buy_vbox: VBoxContainer = _tab_pages.get("Buy", null)
	var sell_vbox: VBoxContainer = _tab_pages.get("Sell", null)
	if buy_vbox == null or sell_vbox == null:
		return
	_clear_page(buy_vbox)
	_clear_page(sell_vbox)

	var info_lbl := Label.new()
	info_lbl.text = "Gold: %d  |  Inventory: %d item(s)" % [GameState.gold, GameState.owned_items.size()]
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_lbl.custom_minimum_size = Vector2(460, 0)
	buy_vbox.add_child(info_lbl)
	buy_vbox.add_child(HSeparator.new())

	var sell_info_lbl := Label.new()
	sell_info_lbl.text = "Gold: %d  |  Inventory: %d item(s)" % [GameState.gold, GameState.owned_items.size()]
	sell_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	sell_info_lbl.custom_minimum_size = Vector2(460, 0)
	sell_vbox.add_child(sell_info_lbl)
	sell_vbox.add_child(HSeparator.new())

	# --- BUY ---
	if GameState.available_items.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No items available. Upgrade the Market to stock more."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		buy_vbox.add_child(empty_lbl)
	else:
		for item in GameState.available_items:
			var wrapper := VBoxContainer.new()
			wrapper.add_theme_constant_override("separation", 3)
			buy_vbox.add_child(wrapper)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			wrapper.add_child(row)

			var icon_path := ItemData.get_icon_path(item)
			if icon_path != "" and ResourceLoader.exists(icon_path, "Texture2D"):
				var icon_tex := load(icon_path) as Texture2D
				if icon_tex:
					var icon_rect := TextureRect.new()
					icon_rect.texture = icon_tex
					icon_rect.custom_minimum_size = Vector2(28, 28)
					icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					row.add_child(icon_rect)

			row.add_child(_make_quality_badge(item.quality))

			var display_cost: int = GameState.get_market_item_cost(item)
			var info := Label.new()
			var discount := FactionState.iron_legion_trade_discount
			var cost_str: String
			if discount > 0.0:
				cost_str = "%dg (-%d%%)" % [display_cost, int(discount * 100.0)]
			else:
				cost_str = "%dg" % display_cost
			info.text = "%s [%s]  |  %s" % [
				item.item_name, cost_str, item.get_stats_display()
			]
			info.custom_minimum_size = Vector2(260, 0)
			info.autowrap_mode = TextServer.AUTOWRAP_WORD
			row.add_child(info)

			var buy_btn := Button.new()
			buy_btn.text = "Buy"
			buy_btn.custom_minimum_size = Vector2(80, 28)
			var lock_reason := GameState.get_market_lock_reason(item)
			buy_btn.disabled = lock_reason != "" or GameState.gold < display_cost
			var captured_item := item
			buy_btn.pressed.connect(func(_i: ItemData = captured_item): _on_market_buy_pressed(_i))
			row.add_child(buy_btn)

			if lock_reason != "":
				var lock_label := Label.new()
				lock_label.text = lock_reason
				lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD
				lock_label.custom_minimum_size = Vector2(430, 0)
				lock_label.add_theme_color_override("font_color", GameTheme.LEATHER)
				wrapper.add_child(lock_label)

	# --- SELL ---
	var equipped_set: Array[ItemData] = []
	for soldier in GameState.soldiers:
		if soldier.weapon_1 != null: equipped_set.append(soldier.weapon_1)
		if soldier.weapon_2 != null: equipped_set.append(soldier.weapon_2)
		if soldier.armor != null: equipped_set.append(soldier.armor)

	var sell_weapons: Array[ItemData] = []
	var sell_armors: Array[ItemData] = []
	for item in GameState.owned_items:
		if item.item_type == ItemData.ItemType.WEAPON or item.item_type == ItemData.ItemType.SHIELD:
			sell_weapons.append(item)
		elif item.item_type == ItemData.ItemType.ARMOR:
			sell_armors.append(item)

	if sell_weapons.is_empty() and sell_armors.is_empty():
		var no_items_lbl := Label.new()
		no_items_lbl.text = "No unequipped items to sell."
		no_items_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		sell_vbox.add_child(no_items_lbl)
	else:
		if not sell_weapons.is_empty():
			var wep_hdr := Label.new()
			wep_hdr.text = "Weapons & Shields"
			wep_hdr.add_theme_color_override("font_color", GameTheme.LEATHER)
			wep_hdr.add_theme_font_size_override("font_size", 13)
			sell_vbox.add_child(wep_hdr)
			for item in sell_weapons:
				sell_vbox.add_child(_make_sell_row(item, equipped_set))

		if not sell_armors.is_empty():
			if not sell_weapons.is_empty():
				sell_vbox.add_child(HSeparator.new())
			var arm_hdr := Label.new()
			arm_hdr.text = "Armor"
			arm_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
			arm_hdr.add_theme_font_size_override("font_size", 13)
			sell_vbox.add_child(arm_hdr)
			for item in sell_armors:
				sell_vbox.add_child(_make_sell_row(item, equipped_set))

func _make_sell_row(item: ItemData, equipped_set: Array[ItemData]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var is_equipped := equipped_set.has(item)
	var sell_price := ceili(item.gold_cost * 0.5)

	row.add_child(_make_quality_badge(item.quality))

	var info := Label.new()
	info.text = "%s  |  %s" % [item.item_name, item.get_stats_display()]
	info.custom_minimum_size = Vector2(260, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	if is_equipped:
		info.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	row.add_child(info)

	if is_equipped:
		var eq_lbl := Label.new()
		eq_lbl.text = "Equipped"
		eq_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		eq_lbl.custom_minimum_size = Vector2(90, 0)
		row.add_child(eq_lbl)
	else:
		var sell_btn := Button.new()
		sell_btn.text = "Sell  +%dg" % sell_price
		sell_btn.custom_minimum_size = Vector2(100, 28)
		var captured_item := item
		sell_btn.pressed.connect(func(_i: ItemData = captured_item):
			if GameState.sell_item(_i):
				_refresh_info_market()
		)
		row.add_child(sell_btn)

	return row

func _on_market_buy_pressed(item: ItemData) -> void:
	if GameState.buy_market_item(item):
		SFX.play("coin")
		_refresh_info_market()
	else:
		SFX.play("denied")

# ---------------------------------------------------------------------------
# Info tab — House
# ---------------------------------------------------------------------------
func _refresh_info_house() -> void:
	var page: VBoxContainer = _tab_pages.get("Workers", null)
	if page == null:
		return
	_clear_page(page)

	var recruits := GameState.house_recruits_this_turn
	var house_level := GameState.get_building_level("House")
	var max_r: int = GameState._get_house_max_recruits()
	var gold_cost := GameState.HOUSE_RECRUIT_GOLD_COST
	var food_cost := GameState.HOUSE_RECRUIT_FOOD_COST
	var house_data := GameState.get_building_data("House")
	var cap_at_level: int = (
		house_data.get_stat_at_level(house_data.soldier_capacity_by_level, house_level, 0)
		if house_data != null else 0
	)

	var info_lbl := Label.new()
	info_lbl.text = (
		"Workforce: %d / %d (cap)\n" +
		"Recruits this turn: %d / %d\n" +
		"House L%d: +%d workforce cap, %d recruit/turn\n\n" +
		"Each new worker costs %d Gold + %d Food."
	) % [
		GameState.workforce_total, GameState.workforce_cap,
		recruits, max_r,
		house_level, cap_at_level, max_r,
		gold_cost, food_cost,
	]
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_lbl.custom_minimum_size = Vector2(480, 0)
	page.add_child(info_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(460, 42)
	var check := GameState.can_recruit_worker()
	btn.disabled = not check.can
	if check.can:
		btn.text = "Recruit Worker  (%d/%d this turn)  -%d Gold  -%d Food" % [
			recruits, max_r, gold_cost, food_cost
		]
	else:
		btn.text = check.reason
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn.pressed.connect(func():
		if GameState.recruit_worker():
			_refresh_info_house()
	)
	page.add_child(btn)

# ---------------------------------------------------------------------------
# Info tab — Training Grounds
# ---------------------------------------------------------------------------
func _refresh_info_training_grounds() -> void:
	var page: VBoxContainer = _tab_pages.get("Trainers", null)
	if page == null:
		return
	_clear_page(page)

	var level := GameState.get_building_level("Training Grounds")
	var slots := GameState.get_training_slots()
	var trainers := GameState.training_soldiers
	var tg_data := GameState.get_building_data("Training Grounds")
	var base_xp: int = (
		tg_data.get_stat_at_level(tg_data.base_xp_by_level, level, tg_data.training_xp_per_worker)
		if tg_data != null else 0
	)

	var slot_lbl := Label.new()
	slot_lbl.text = "Trainers: %d / %d slots" % [trainers.size(), slots]
	slot_lbl.add_theme_font_size_override("font_size", 13)
	page.add_child(slot_lbl)

	if not trainers.is_empty():
		for trainer in trainers.duplicate():
			var trainer_xp: int = base_xp + trainer.dexterity * 2 + trainer.level * 3
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var name_lbl := Label.new()
			name_lbl.text = "  %s  -  gives ~%d XP to trainees this turn" % [trainer.soldier_name, trainer_xp]
			name_lbl.custom_minimum_size = Vector2(330, 0)
			row.add_child(name_lbl)
			var remove_btn := Button.new()
			remove_btn.text = "Remove"
			remove_btn.custom_minimum_size = Vector2(80, 26)
			var captured_trainer: SoldierData = trainer
			remove_btn.pressed.connect(func(_t = captured_trainer):
				GameState.unassign_trainer(_t)
				_refresh_info_training_grounds()
			)
			row.add_child(remove_btn)
			page.add_child(row)
	else:
		var none_lbl := Label.new()
		none_lbl.text = "  (none assigned)"
		none_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		page.add_child(none_lbl)

	page.add_child(HSeparator.new())

	var avail_hdr := Label.new()
	avail_hdr.text = "Assign Trainer:"
	avail_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	page.add_child(avail_hdr)

	var any_eligible := false
	for s in GameState.soldiers:
		if not s.is_alive():
			continue
		if trainers.has(s):
			continue
		if DungeonState.soldiers_in_dungeon.has(s) or DungeonState.pending_soldiers.has(s):
			continue
		any_eligible = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_lbl := Label.new()
		# Preview the XP this soldier would grant per turn if assigned, using
		# the same formula as the assigned-trainer rows above.
		var candidate_xp: int = base_xp + s.dexterity * 2 + s.level * 3
		name_lbl.text = "%s  Lv.%d  (would give ~%d XP/turn)" % [s.soldier_name, s.level, candidate_xp]
		name_lbl.custom_minimum_size = Vector2(330, 0)
		row.add_child(name_lbl)
		var assign_btn := Button.new()
		assign_btn.text = "Assign"
		assign_btn.custom_minimum_size = Vector2(80, 26)
		assign_btn.disabled = not GameState.can_assign_trainer(s)
		var captured_s := s
		assign_btn.pressed.connect(func(_sol = captured_s):
			GameState.assign_trainer(_sol)
			_refresh_info_training_grounds()
		)
		row.add_child(assign_btn)
		page.add_child(row)

	if not any_eligible:
		var no_lbl := Label.new()
		no_lbl.text = "  (no eligible soldiers available)"
		no_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		page.add_child(no_lbl)

# ---------------------------------------------------------------------------
# Info tab — Weapon Forge
# ---------------------------------------------------------------------------
func _refresh_info_weapon_forge() -> void:
	var craft_page: VBoxContainer = _tab_pages.get("Craft", null)
	var queue_page: VBoxContainer = _tab_pages.get("Queue", null)
	if craft_page == null or queue_page == null:
		return
	_clear_page(craft_page)
	_clear_page(queue_page)

	var forge_level := GameState.get_building_level("Blacksmith")
	var forge_workers: int = GameState.building_workers.get("Blacksmith", 0)
	var queue := GameState.weapon_forge_queue

	# --- QUEUE TAB: worker row, L3 bonus note, crafting queue list ---
	var worker_reduction: int = maxi(0, forge_workers - 1)
	var bonus_text := "  |  Worker bonus: -%d turn(s)" % worker_reduction
	queue_page.add_child(_build_worker_row("Blacksmith", func(): _refresh_info_weapon_forge(), bonus_text))

	if forge_level >= 3:
		var bonus_lbl := Label.new()
		bonus_lbl.text = "L3 bonus: 15% chance to upgrade quality on completion"
		bonus_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
		queue_page.add_child(bonus_lbl)

	queue_page.add_child(HSeparator.new())

	var queue_hdr := Label.new()
	queue_hdr.text = "Crafting Queue (%d):" % queue.size()
	queue_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	queue_page.add_child(queue_hdr)

	if queue.is_empty():
		var empty_q := Label.new()
		empty_q.text = "  (empty)"
		empty_q.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		queue_page.add_child(empty_q)
	else:
		# Group identical orders (same item, quality, turns left) into one
		# "xN" line so a stacked queue can never crowd out the craft list.
		var groups: Dictionary = {}
		var group_order: Array[String] = []
		for entry in queue:
			var key := "%s|%d|%d" % [entry.item_name, entry.quality, entry.turns_remaining]
			if not groups.has(key):
				groups[key] = {"entry": entry, "count": 0}
				group_order.append(key)
			groups[key]["count"] += 1
		for key in group_order:
			var entry = groups[key]["entry"]
			var count: int = groups[key]["count"]
			var q_lbl := Label.new()
			q_lbl.text = "  %s [%s]%s  -  %d turn%s remaining" % [
				entry.item_name,
				GameState.QUALITY_NAMES[entry.quality],
				"  x%d" % count if count > 1 else "",
				entry.turns_remaining,
				"s" if entry.turns_remaining != 1 else ""
			]
			queue_page.add_child(q_lbl)

	# --- CRAFT TAB: craftable items, single scroll ---
	var craft_hdr := Label.new()
	craft_hdr.text = "Craft Item:"
	craft_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
	craft_page.add_child(craft_hdr)

	var craftable_weapons: Array[ItemData] = []
	var craftable_armors: Array[ItemData] = []
	var craftable_shields: Array[ItemData] = []
	for d in ItemData.get_all_craftable_weapons():
		var req: int = d.get("craft_forge_level_required", 1)
		if req <= forge_level:
			craftable_weapons.append(ItemData.make_from_dict(d))
	for d in ItemData.get_all_craftable_armors():
		var req: int = d.get("craft_forge_level_required", 1)
		if req <= forge_level:
			craftable_armors.append(ItemData.make_from_dict(d))
	for d in ItemData.get_all_craftable_shields():
		var req: int = d.get("craft_forge_level_required", 1)
		if req <= forge_level:
			craftable_shields.append(ItemData.make_from_dict(d))

	if craftable_weapons.is_empty() and craftable_armors.is_empty() and craftable_shields.is_empty():
		var no_items_lbl := Label.new()
		no_items_lbl.text = "  (no craftable items available at this forge level)"
		no_items_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		craft_page.add_child(no_items_lbl)
		return

	var quality_names := GameState.QUALITY_NAMES
	var base_turns_arr := GameState.CRAFT_BASE_TURNS

	var _add_craft_row = func(item: ItemData) -> void:
		var item_row := VBoxContainer.new()
		item_row.add_theme_constant_override("separation", 3)

		var cost_parts: Array[String] = []
		for res in item.craft_resource_cost:
			cost_parts.append("%d %s" % [item.craft_resource_cost[res], res])
		var cost_str := ", ".join(cost_parts) if not cost_parts.is_empty() else "Free"

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		item_row.add_child(name_row)
		var icon_path := ItemData.get_icon_path(item)
		if icon_path != "" and ResourceLoader.exists(icon_path, "Texture2D"):
			var icon_tex := load(icon_path) as Texture2D
			if icon_tex:
				var icon_rect := TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(28, 28)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				name_row.add_child(icon_rect)
		var item_info_lbl := Label.new()
		item_info_lbl.text = "%s  |  %s  |  %s" % [item.item_name, item.get_stats_display(), cost_str]
		item_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		item_info_lbl.custom_minimum_size = Vector2(440, 0)
		name_row.add_child(item_info_lbl)

		var quality_row := HBoxContainer.new()
		quality_row.add_theme_constant_override("separation", 6)
		for qi in 3:
			if qi >= 2 and forge_level < 2:
				continue
			var base_t: int = base_turns_arr[qi]
			var actual_t: int = maxi(1, base_t - maxi(0, forge_workers - 1))
			var q_btn := Button.new()
			q_btn.text = "%s  (%d turn%s)" % [quality_names[qi], actual_t, "s" if actual_t != 1 else ""]
			q_btn.custom_minimum_size = Vector2(140, 30)

			var can_afford := forge_workers > 0
			for res in item.craft_resource_cost:
				if GameState._get_resource_value(res) < item.craft_resource_cost[res]:
					can_afford = false
					break
			q_btn.disabled = not can_afford

			var captured_name: String = item.item_name
			var captured_qi: int = qi
			q_btn.pressed.connect(func(_n: String = captured_name, _q: int = captured_qi):
				var result := GameState.start_crafting(_n, _q)
				if not result.ok:
					craft_hdr.text = "Craft Item: [%s]" % result.reason
					craft_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
				else:
					_refresh_info_weapon_forge()
			)
			quality_row.add_child(q_btn)

		item_row.add_child(quality_row)
		craft_page.add_child(item_row)

	if not craftable_weapons.is_empty():
		var w_hdr := Label.new()
		w_hdr.text = "--- Weapons ---"
		w_hdr.add_theme_color_override("font_color", GameTheme.LEATHER)
		craft_page.add_child(w_hdr)
		for item in craftable_weapons:
			_add_craft_row.call(item)

	if not craftable_armors.is_empty():
		var a_hdr := Label.new()
		a_hdr.text = "--- Armor ---"
		a_hdr.add_theme_color_override("font_color", GameTheme.CRIMSON)
		craft_page.add_child(a_hdr)
		for item in craftable_armors:
			_add_craft_row.call(item)

	if not craftable_shields.is_empty():
		var s_hdr := Label.new()
		s_hdr.text = "--- Shields ---"
		s_hdr.add_theme_color_override("font_color", GameTheme.MOSS)
		craft_page.add_child(s_hdr)
		for item in craftable_shields:
			_add_craft_row.call(item)

# ---------------------------------------------------------------------------
# Destroyed building — rebuild section (outside tabs)
# ---------------------------------------------------------------------------
func _refresh_rebuild() -> void:
	for child in rebuild_section.get_children():
		child.queue_free()

	var data := GameState.get_building_data(current_building)

	var status_lbl := Label.new()
	status_lbl.text = "This building lies in ruins."
	status_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
	status_lbl.add_theme_font_size_override("font_size", 14)
	rebuild_section.add_child(status_lbl)

	var cost_hdr := Label.new()
	cost_hdr.text = "Rebuild cost:"
	rebuild_section.add_child(cost_hdr)

	if data != null:
		var rebuild_cost_entries: Array = []
		if data.cost_gold > 0:
			rebuild_cost_entries.append(["Gold", data.cost_gold, GameState.gold >= data.cost_gold])
		if data.cost_wood > 0:
			rebuild_cost_entries.append(["Wood", data.cost_wood, GameState.wood >= data.cost_wood])
		if data.cost_stone > 0:
			rebuild_cost_entries.append(["Stone", data.cost_stone, GameState.stone >= data.cost_stone])

		if rebuild_cost_entries.is_empty():
			var free_lbl := Label.new()
			free_lbl.text = "  Free to rebuild!"
			free_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
			rebuild_section.add_child(free_lbl)
		else:
			rebuild_section.add_child(_build_cost_pills_row(rebuild_cost_entries))

		if data.increases_population > 0:
			var reward_lbl := Label.new()
			reward_lbl.text = "Reward: +%d Workforce (permanent)" % data.increases_population
			reward_lbl.add_theme_color_override("font_color", GameTheme.MOSS)
			rebuild_section.add_child(reward_lbl)

	var check := GameState.can_rebuild(current_building)
	var rebuild_btn := Button.new()
	rebuild_btn.custom_minimum_size = Vector2(480, 40)
	rebuild_btn.disabled = not check.can
	if check.can:
		rebuild_btn.text = "Rebuild"
	else:
		rebuild_btn.text = "Cannot rebuild - missing: %s" % check.missing
	rebuild_btn.pressed.connect(func():
		if GameState.rebuild_building(current_building):
			SFX.play("build")
			GameState.menu_open = false
			call_deferred("show_building", current_building, "")
		else:
			SFX.play("denied")
	)
	rebuild_section.add_child(rebuild_btn)

# ---------------------------------------------------------------------------
# Upgrade tab — shared for ALL buildings
# ---------------------------------------------------------------------------
func _fill_upgrade_vbox(upgrade_vbox: VBoxContainer, b_name: String) -> void:
	for child in upgrade_vbox.get_children():
		child.queue_free()

	var data := GameState.get_building_data(b_name)
	if data == null:
		return
	var level := GameState.get_building_level(b_name)

	if level <= 0:
		var not_built_lbl := Label.new()
		not_built_lbl.text = "Build this building first."
		not_built_lbl.add_theme_color_override("font_color", GameTheme.INK_SOFT)
		upgrade_vbox.add_child(not_built_lbl)
		return

	if level >= data.max_level:
		var max_lbl := Label.new()
		max_lbl.text = "This building is at maximum level."
		max_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
		max_lbl.add_theme_font_size_override("font_size", 16)
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		upgrade_vbox.add_child(max_lbl)
		return

	var idx := level - 1
	var title_lbl := Label.new()
	title_lbl.text = "Upgrade to Lvl %d" % (level + 1)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
	upgrade_vbox.add_child(title_lbl)

	upgrade_vbox.add_child(HSeparator.new())

	var cost_hbox := HBoxContainer.new()
	cost_hbox.add_theme_constant_override("separation", 8)
	upgrade_vbox.add_child(cost_hbox)
	var cost_prefix := Label.new(); cost_prefix.text = "Cost:  "
	cost_hbox.add_child(cost_prefix)

	var cost_entries: Array = []
	if idx < data.upgrade_cost_gold.size() and data.upgrade_cost_gold[idx] > 0:
		cost_entries.append(["Gold", data.upgrade_cost_gold[idx], GameState.gold >= data.upgrade_cost_gold[idx]])
	if idx < data.upgrade_cost_wood.size() and data.upgrade_cost_wood[idx] > 0:
		cost_entries.append(["Wood", data.upgrade_cost_wood[idx], GameState.wood >= data.upgrade_cost_wood[idx]])
	if idx < data.upgrade_cost_stone.size() and data.upgrade_cost_stone[idx] > 0:
		cost_entries.append(["Stone", data.upgrade_cost_stone[idx], GameState.stone >= data.upgrade_cost_stone[idx]])
	if idx < data.upgrade_cost_iron.size() and data.upgrade_cost_iron[idx] > 0:
		cost_entries.append(["Iron", data.upgrade_cost_iron[idx], GameState.iron >= data.upgrade_cost_iron[idx]])
	if idx < data.upgrade_cost_steel.size() and data.upgrade_cost_steel[idx] > 0:
		cost_entries.append(["Steel", data.upgrade_cost_steel[idx], GameState.steel >= data.upgrade_cost_steel[idx]])

	if cost_entries.is_empty():
		var free_lbl := Label.new(); free_lbl.text = "Free"
		cost_hbox.add_child(free_lbl)
	else:
		cost_hbox.add_child(_build_cost_pills_row(cost_entries))

	upgrade_vbox.add_child(HSeparator.new())

	var changes: Array[String] = []
	var resource_labels: Array[String] = ["Food", "Gold", "Wood", "Stone", "Iron", "Steel"]
	var arrays_by_resource: Array = [
		data.food_by_level, data.gold_by_level, data.wood_by_level,
		data.stone_by_level, data.iron_by_level, data.steel_by_level
	]
	for ri in resource_labels.size():
		var arr: PackedInt32Array = arrays_by_resource[ri]
		var cur_val := data.get_stat_at_level(arr, level, 0)
		var next_val := data.get_stat_at_level(arr, level + 1, 0)
		if cur_val != next_val:
			var diff := next_val - cur_val
			var sign_s := "+" if diff >= 0 else ""
			changes.append("%s/worker: %d -> %d (%s%d)" % [resource_labels[ri], cur_val, next_val, sign_s, diff])

	var cur_morale := data.get_stat_at_level(data.morale_flat_by_level, level, 0)
	var next_morale := data.get_stat_at_level(data.morale_flat_by_level, level + 1, 0)
	if cur_morale != next_morale:
		var diff := next_morale - cur_morale
		var sign_s := "+" if diff >= 0 else ""
		changes.append("Morale/turn: %d -> %d (%s%d)" % [cur_morale, next_morale, sign_s, diff])

	if data.base_xp_by_level.size() > 0:
		var cur_xp := data.get_stat_at_level(data.base_xp_by_level, level, 0)
		var next_xp := data.get_stat_at_level(data.base_xp_by_level, level + 1, 0)
		if cur_xp != next_xp:
			var diff := next_xp - cur_xp
			var sign_s := "+" if diff >= 0 else ""
			changes.append("Base XP/trainer: %d -> %d (%s%d)" % [cur_xp, next_xp, sign_s, diff])

	if idx < data.upgrade_notes.size() and data.upgrade_notes[idx] != "":
		changes.append(data.upgrade_notes[idx])

	if not changes.is_empty():
		var what_lbl := Label.new()
		what_lbl.text = "What changes at Lvl %d:" % (level + 1)
		what_lbl.add_theme_color_override("font_color", GameTheme.CRIMSON)
		upgrade_vbox.add_child(what_lbl)
		for line in changes:
			var line_lbl := Label.new()
			line_lbl.text = "  • %s" % line
			line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			line_lbl.custom_minimum_size = Vector2(440, 0)
			upgrade_vbox.add_child(line_lbl)

	var check := GameState.can_upgrade_building(b_name)
	var upgrade_btn := Button.new()
	upgrade_btn.custom_minimum_size = Vector2(200, 36)
	upgrade_btn.disabled = not check.can
	if check.can:
		upgrade_btn.text = "Upgrade Building"
		upgrade_btn.add_theme_color_override("font_color", GameTheme.LEATHER)
	else:
		upgrade_btn.text = "Cannot upgrade - %s" % check.missing
		upgrade_btn.autowrap_mode = TextServer.AUTOWRAP_WORD
	upgrade_btn.pressed.connect(func():
		if GameState.upgrade_building(b_name):
			SFX.play("build")
			GameState.menu_open = false
			call_deferred("show_building", b_name, "")
		else:
			SFX.play("denied")
	)
	upgrade_vbox.add_child(upgrade_btn)

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
func _get_building_texture(b_name: String) -> Texture2D:
	var path := BuildingData.get_texture_path(b_name)
	if path == "":
		return null
	return load(path) as Texture2D

func _close_popup() -> void:
	GameState.menu_open = false
	hide()

func blocks_screen_position(screen_position: Vector2) -> bool:
	if not visible or not is_instance_valid(popup_panel):
		return false
	return popup_panel.get_global_rect().has_point(screen_position)
