# recap_screen.gd
extends CanvasLayer

@onready var title_label: Label = $Panel/Title
@onready var recap_list: VBoxContainer = $Panel/ScrollContainer/RecapList
@onready var btn_continue: Button = $Panel/BtnContinue

func _ready() -> void:
	btn_continue.pressed.connect(_on_continue)
	GameState.recap_ready.connect(_on_recap_ready)
	hide()

func _on_recap_ready() -> void:
	_populate(GameState.turn_recap)
	show()
	GameState.menu_open = true

func _populate(lines: Array) -> void:
	for child in recap_list.get_children():
		child.queue_free()

	for line in lines:
		var label = Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(520, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Colorează liniile speciale
		if line.contains("==="):
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		elif line.contains("Level"):
			label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		elif line.contains("No production"):
			label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))

		recap_list.add_child(label)

func _on_continue() -> void:
	GameState.menu_open = false
	get_tree().get_root().find_child("CityView", true, false).get_node("UI").visible = true
	hide()
