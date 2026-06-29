# res://scripts/autoload/SceneFader.gd
# Autoload — fades to black, swaps the active scene, then fades back in.
# Used for every scene transition so changes never feel like a hard cut.
extends CanvasLayer

const FADE_DURATION: float = 0.35

var _overlay: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_overlay = ColorRect.new()
	_overlay.color = GameTheme.NIGHT
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)


## Fade to black, change to `scene_path`, then fade back in. Re-entry safe —
## a second call while a fade is already running is ignored.
func change_scene(scene_path: String, dur: float = FADE_DURATION) -> void:
	if _busy:
		return
	_busy = true

	# Never carry the pause overlay (and its tree-paused state) into the next
	# scene — ESC can open it during the fade-out window before the scene swap.
	PauseMenu.close()

	var tw_out := create_tween()
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.tween_property(_overlay, "modulate:a", 1.0, dur)
	await tw_out.finished

	# Safety: never leave the tree paused across a scene change.
	get_tree().paused = false

	get_tree().change_scene_to_file(scene_path)

	# Let the new scene's first frames settle before fading back in.
	await get_tree().process_frame
	await get_tree().process_frame

	var tw_in := create_tween()
	tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_in.tween_property(_overlay, "modulate:a", 0.0, dur)
	await tw_in.finished

	_busy = false
