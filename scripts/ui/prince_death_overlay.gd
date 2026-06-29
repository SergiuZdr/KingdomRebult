extends CanvasLayer

var _ready_to_exit: bool = false

func _ready() -> void:
	$Center.theme = GameTheme.get_theme()
	UIKit.fade_in($Center, 0.6)
	await get_tree().create_timer(0.5).timeout
	_ready_to_exit = true

func _input(event: InputEvent) -> void:
	if not _ready_to_exit:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		SceneFader.change_scene("res://scenes/ui/main_menu.tscn")
