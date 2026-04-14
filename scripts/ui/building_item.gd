extends PanelContainer

@onready var label_name: Label = $MarginContainer/VBoxContainer/LabelName
@onready var label_cost: Label = $MarginContainer/VBoxContainer/LabelCost
@onready var btn_build: Button = $MarginContainer/VBoxContainer/BtnBuild

signal build_pressed

func _ready() -> void:
	btn_build.pressed.connect(func(): emit_signal("build_pressed"))

func set_display(name_text: String, cost_text: String, button_text: String = "Build") -> void:
	label_name.text = name_text
	label_cost.text = cost_text
	btn_build.text = button_text
