extends PanelContainer

@onready var label_title: Label = $MarginContainer/VBoxContainer/LabelTitle
@onready var building_list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/BuildingList

func set_title(title: String) -> void:
	label_title.text = title

func clear_items() -> void:
	for child in building_list.get_children():
		child.queue_free()

func add_item(item: Control) -> void:
	building_list.add_child(item)
