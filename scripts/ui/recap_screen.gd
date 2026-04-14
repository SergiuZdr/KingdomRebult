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
	return "Review this turn's production, training, and resource changes."

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

	if line.begins_with("Phase:"):
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
		return

	if line.begins_with("Resources:") or line.begins_with("Net resources gain:"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
		return

	if line.contains("Threat:") or line.contains("arrives!"):
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.32))
		return

	if line.contains("Level"):
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		return

	if line.contains("No production") or line.contains("No training"):
		label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		return

	if line.find("(") != -1 and line.find("workers") != -1:
		label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
		return

	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))

func _on_continue() -> void:
	GameState.menu_open = false
	get_tree().get_root().find_child("CityView", true, false).get_node("UI").visible = true
	hide()
