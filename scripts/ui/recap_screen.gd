# recap_screen.gd
extends CanvasLayer

@onready var title_label: Label = $Panel/Title
@onready var recap_list: VBoxContainer = $Panel/ScrollContainer/RecapList
@onready var btn_continue: Button = $Panel/BtnContinue

var summary_label: Label

func _ready() -> void:
	_ensure_summary_label()
	btn_continue.pressed.connect(_on_continue)
	GameState.recap_ready.connect(_on_recap_ready)
	hide()

func _ensure_summary_label() -> void:
	if summary_label != null:
		return

	summary_label = Label.new()
	summary_label.position = Vector2(20, 28)
	summary_label.size = Vector2(560, 28)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	$Panel.add_child(summary_label)

func _on_recap_ready() -> void:
	title_label.text = "Turn %d Recap" % GameState.current_turn
	summary_label.text = _build_summary_text()
	_populate(GameState.turn_recap)
	show()
	GameState.menu_open = true

func _build_summary_text() -> String:
	var deltas = GameState.last_turn_resource_deltas
	var parts: Array[String] = []
	for res in ["Gold", "Food", "Wood", "Stone", "Morale"]:
		var d = int(deltas.get(res, 0))
		if d != 0:
			parts.append("%s %s%d" % [res, "+" if d > 0 else "", d])
	if parts.is_empty():
		return "No net resource change this turn."
	return "Net: " + "  |  ".join(parts)

func _populate(lines: Array) -> void:
	for child in recap_list.get_children():
		child.queue_free()

	for line in lines:
		if line == "":
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(520, 10)
			recap_list.add_child(spacer)
			continue

		var label = Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(520, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_apply_line_style(label, line)
		recap_list.add_child(label)

func _apply_line_style(label: Label, line: String) -> void:
	if line.begins_with("==="):
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		return

	if line.begins_with("---"):
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
		return

	if line.begins_with("Resources:") or line.begins_with("Net resources gain:"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
		return

	if line.begins_with("[+]"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
		return

	if line.begins_with("[!]"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return

	if line.begins_with("[~]"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.45))
		return

	if line.contains("shortage") or line.contains("unfed") or line.contains("underfed"):
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		return

	if line.contains("Morale -") or line.contains("Morale -%"):
		label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2))
		return

	if line.contains("Threat:") or line.contains("arrives!") or line.contains("arrived!"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.32))
		return

	if line.contains("Level"):
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		return

	if line.contains("Low Morale"):
		label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
		return

	if line.contains("High Morale"):
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.55))
		return

	if line.contains("No production") or line.contains("No training") or line.contains("No soldiers"):
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		return

	if line.find("(") != -1 and line.find("workers") != -1:
		label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
		return

	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))

func _on_continue() -> void:
	GameState.menu_open = false
	var city_view = get_tree().get_root().find_child("CityView", true, false)
	if city_view != null:
		city_view.get_node("UI").visible = true
	hide()
	if not GameState._pending_event_data.is_empty():
		_show_event_popup(GameState._pending_event_data.duplicate())
		GameState._pending_event_data.clear()

func _show_event_popup(event: Dictionary) -> void:
	GameState.menu_open = true
	var overlay = CanvasLayer.new()
	overlay.layer = 80
	get_tree().get_root().add_child(overlay)

	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel = PanelContainer.new()
	panel.position = Vector2(440, 200)
	panel.custom_minimum_size = Vector2(400, 260)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var category = event.get("category", "neutral")
	var prefix_color = Color(0.3, 1.0, 0.55) if category == "good" else (Color(1.0, 0.35, 0.35) if category == "bad" else Color(0.85, 0.78, 0.45))

	var title_lbl = Label.new()
	title_lbl.text = event.get("title", "Event")
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", prefix_color)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = event.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(360, 0)
	desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	vbox.add_child(desc_lbl)

	for effect in event.get("effects", []):
		var amt = int(effect.get("amount", 0))
		var eff_lbl = Label.new()
		eff_lbl.text = "%s %s%d" % [effect.get("resource", ""), "+" if amt >= 0 else "", amt]
		eff_lbl.add_theme_color_override("font_color", prefix_color)
		eff_lbl.add_theme_font_size_override("font_size", 16)
		eff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(eff_lbl)

	var dismiss_btn = Button.new()
	dismiss_btn.text = "Continue"
	dismiss_btn.custom_minimum_size = Vector2(360, 40)
	dismiss_btn.add_theme_font_size_override("font_size", 14)
	dismiss_btn.pressed.connect(func():
		GameState.menu_open = false
		overlay.queue_free()
	)
	vbox.add_child(dismiss_btn)
