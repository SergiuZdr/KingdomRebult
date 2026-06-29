# skill_loadout_ui.gd
# Shared builder for the 3-slot skill loadout (equip / unequip / swap).
# Used by the Army tab (hub_screen) and the dungeon Party Info panel.
# Combat only uses a soldier's EQUIPPED skills; the rest are learned at the
# dungeon Skill Trainer and benched until slotted here.
class_name SkillLoadoutUI

static func build(soldier: SoldierData, on_refresh: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Skills  (%d / %d equipped)" % [soldier.equipped_skills.size(), soldier.max_skill_slots()]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", GameTheme.CRIMSON)
	box.add_child(title)

	var max_slots := soldier.max_skill_slots()
	for i in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		if i >= max_slots:
			var locked := Label.new()
			locked.text = "Slot %d (unlocks at level %d)" % [i + 1, SoldierData.SLOT_LEVELS[i]]
			locked.add_theme_font_size_override("font_size", 11)
			locked.add_theme_color_override("font_color", GameTheme.INK_SOFT)
			row.add_child(locked)
		elif i < soldier.equipped_skills.size():
			var sk: SkillData = soldier.equipped_skills[i]
			var info := Label.new()
			info.text = "Slot %d: [%s] %s (%s)" % [i + 1, _type_str(sk), sk.skill_name, sk.get_stats_display()]
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.autowrap_mode = TextServer.AUTOWRAP_WORD
			info.custom_minimum_size = Vector2(360, 0)
			info.add_theme_font_size_override("font_size", 12)
			info.add_theme_color_override("font_color", GameTheme.INK)
			row.add_child(info)
			var rem := Button.new()
			rem.text = "Unequip"
			rem.custom_minimum_size = Vector2(86, 28)
			rem.pressed.connect(func():
				if soldier.unequip_skill(sk) and on_refresh.is_valid():
					on_refresh.call())
			row.add_child(rem)
		else:
			var empty := Label.new()
			empty.text = "Slot %d: (empty)" % (i + 1)
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", GameTheme.INK_SOFT)
			row.add_child(empty)

	# Learned but not equipped — can be slotted
	var bench: Array = []
	for sk in soldier.unlocked_skills:
		if not soldier.is_equipped(sk.skill_id):
			bench.append(sk)
	if not bench.is_empty():
		var bh := Label.new()
		bh.text = "Learned (Equip to fill a slot):"
		bh.add_theme_font_size_override("font_size", 11)
		bh.add_theme_color_override("font_color", GameTheme.LEATHER)
		box.add_child(bh)
		for sk in bench:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			box.add_child(row)
			var info := Label.new()
			info.text = "[%s] %s (%s)" % [_type_str(sk), sk.skill_name, sk.get_stats_display()]
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.autowrap_mode = TextServer.AUTOWRAP_WORD
			info.custom_minimum_size = Vector2(360, 0)
			info.add_theme_font_size_override("font_size", 12)
			info.add_theme_color_override("font_color", GameTheme.INK)
			row.add_child(info)
			var eq := Button.new()
			eq.text = "Equip"
			eq.custom_minimum_size = Vector2(86, 28)
			eq.disabled = soldier.equipped_skills.size() >= soldier.max_skill_slots()
			eq.pressed.connect(func():
				if soldier.equip_skill(sk) and on_refresh.is_valid():
					on_refresh.call())
			row.add_child(eq)

	# Learnable at the dungeon trainer (info only)
	var header_added := false
	for sk in SkillLibrary.get_class_skills(soldier.soldier_class):
		if soldier.has_skill(sk.skill_id):
			continue
		if not header_added:
			var lh := Label.new()
			lh.text = "Learn at the Dungeon Skill Trainer:"
			lh.add_theme_font_size_override("font_size", 11)
			lh.add_theme_color_override("font_color", GameTheme.LEATHER)
			box.add_child(lh)
			header_added = true
		var ok := soldier.meets_skill_conditions(sk)
		var lbl := Label.new()
		lbl.text = "%s %s (%s)" % [("[ready]" if ok else "[locked]"), sk.skill_name, sk.get_unlock_description()]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", GameTheme.MOSS if ok else GameTheme.INK_SOFT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.custom_minimum_size = Vector2(460, 0)
		box.add_child(lbl)

	return box

static func _type_str(sk: SkillData) -> String:
	if sk.skill_type == SkillData.SkillType.PASSIVE:
		return "Passive"
	return "Active CD:%d" % sk.cooldown_turns
