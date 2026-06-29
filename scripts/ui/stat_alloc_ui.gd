# stat_alloc_ui.gd
# Shared builder for the manual attribute-allocation block (the "+" buttons).
# Used by both the Army tab (hub_screen) and the dungeon Party Info panel so the
# behaviour stays identical in both places.
class_name StatAllocUI

# UI label -> SoldierData stat key
const STATS := [
	["STRENGTH", "power"],
	["INITIATIVE", "speed"],
	["CUNNING", "dexterity"],
	["HEALTH", "hp"],
]

## Self-contained attribute block. Spending a point updates this panel's own
## labels/rows in place (no external rebuild), avoiding the one-frame flicker
## and scroll-reset that a full overlay teardown would cause.
class StatAllocPanel extends VBoxContainer:
	var soldier: SoldierData
	var pts_label: Label
	var rows_box: VBoxContainer
	## Called after this panel refreshes itself, so the caller can update other
	## widgets that show these stats (e.g. the overlay's stats text block and
	## the roster card chips). Optional — may be an invalid Callable.
	var on_changed: Callable

	func refresh() -> void:
		pts_label.text = "Points: %d" % soldier.unspent_stat_points
		pts_label.add_theme_color_override("font_color",
			GameTheme.LEATHER if soldier.unspent_stat_points > 0 else GameTheme.INK_SOFT)

		# remove_child (not queue_free) so the old rows are gone from the tree
		# immediately — queue_free alone would leave them visible alongside the
		# new rows until the end of the frame, causing a one-frame flicker.
		for child in rows_box.get_children():
			rows_box.remove_child(child)
			child.queue_free()
		for entry in STATS:
			rows_box.add_child(StatAllocUI._make_row(soldier, entry[0], entry[1], self))
		if soldier.unspent_stat_points == 0:
			rows_box.add_child(StatAllocUI._make_hint())

		if on_changed.is_valid():
			on_changed.call()

# Builds the attribute block. `on_changed` is called after a point is spent so the
# caller can refresh other widgets (overlay stats text, roster card chips). This
# panel updates its own labels/rows in place — no external rebuild needed.
static func build(soldier: SoldierData, on_changed: Callable = Callable()) -> StatAllocPanel:
	var box := StatAllocPanel.new()
	box.soldier = soldier
	box.on_changed = on_changed
	box.add_theme_constant_override("separation", 4)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)

	var title := Label.new()
	title.text = "Attributes"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", GameTheme.CRIMSON)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)

	var pts := Label.new()
	pts.text = "Points: %d" % soldier.unspent_stat_points
	pts.add_theme_font_size_override("font_size", 14)
	pts.add_theme_color_override("font_color",
		Color("#B8893C") if soldier.unspent_stat_points > 0 else Color(0.6, 0.6, 0.6))
	head.add_child(pts)
	box.pts_label = pts

	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 4)
	box.add_child(rows_box)
	box.rows_box = rows_box

	for entry in STATS:
		rows_box.add_child(_make_row(soldier, entry[0], entry[1], box))

	if soldier.unspent_stat_points == 0:
		rows_box.add_child(_make_hint())

	return box

static func _make_hint() -> Label:
	var hint := Label.new()
	hint.text = "Gain points by leveling up, or train them at the dungeon Skill Trainer."
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", GameTheme.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	return hint

static func _make_row(soldier: SoldierData, label: String, key: String, panel: StatAllocPanel) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var fav := soldier.is_favored(key)
	var has_points := soldier.unspent_stat_points > 0

	# The "+" button is ALWAYS present so the row height/spacing never changes
	# between the can-upgrade and nothing-to-spend states — only the button's
	# enabled/disabled (greyed) look differs, per design.
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(32, 28)
	plus.disabled = not has_points
	plus.tooltip_text = "+%d %s" % [soldier.point_value(key), label]
	plus.pressed.connect(func():
		if soldier.spend_stat_point(key):
			panel.refresh()
	)
	row.add_child(plus)

	var name_lbl := Label.new()
	name_lbl.text = label + ("  ★" if fav else "")
	name_lbl.custom_minimum_size = Vector2(140, 0)
	name_lbl.add_theme_font_size_override("font_size", 13)
	if fav:
		# Dark gold — readable on the bright parchment panel (the old bright
		# yellow washed out).
		name_lbl.add_theme_color_override("font_color", GameTheme.LEATHER)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%d" % _stat_value(soldier, key)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", GameTheme.INK)
	val_lbl.custom_minimum_size = Vector2(56, 0)
	row.add_child(val_lbl)

	# Gain hint only when there are points to spend; same height as the value
	# label so it never shifts the row.
	var gain := Label.new()
	gain.text = "(+%d)" % soldier.point_value(key) if has_points else ""
	gain.add_theme_font_size_override("font_size", 12)
	gain.add_theme_color_override("font_color", GameTheme.MOSS)
	gain.custom_minimum_size = Vector2(40, 0)
	row.add_child(gain)

	return row

## Shows effective (gear-included) totals so this block matches the summary lines.
## The "+" buttons still allocate into the base stat under the hood.
static func _stat_value(soldier: SoldierData, key: String) -> int:
	match key:
		"power": return soldier.get_total_power()
		"speed": return soldier.get_total_speed()
		"dexterity": return soldier.get_total_dexterity()
		"hp": return soldier.hp_max
	return 0
