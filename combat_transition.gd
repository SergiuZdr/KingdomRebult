# combat_transition.gd
extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var enemy_label: Label = $Overlay/VBoxContainer/EnemyLabel
@onready var flavor_label: Label = $Overlay/VBoxContainer/FlavorLabel

const FLAVOR_TEXTS = [
	"The monsters smell blood...",
	"No retreat. No mercy.",
	"Steel yourself, soldier.",
	"They come in the night.",
	"The city must not fall.",
	"For the kingdom. For the king.",
	"Death walks among them.",
]

signal transition_finished

func _ready() -> void:
	hide()

func play(enemy_wave: Array) -> void:
	var enemy_names = {}
	for e in enemy_wave:
		var base_name = e.enemy_name.split(" #")[0]
		enemy_names[base_name] = enemy_names.get(base_name, 0) + 1

	var parts = []
	for name in enemy_names:
		var count = enemy_names[name]
		if count > 1:
			parts.append("%d %ss" % [count, name])
		else:
			parts.append(name)

	enemy_label.text = " + ".join(parts)
	flavor_label.text = FLAVOR_TEXTS[randi_range(0, FLAVOR_TEXTS.size() - 1)]

	overlay.modulate = Color(0, 0, 0, 0)
	show()

	var tween = create_tween()
	# Fade in nero
	tween.tween_property(overlay, "modulate", Color(0.844, 0.0, 0.0, 1.0), 0.6)
	# Tine negru cu text vizibil
	tween.tween_interval(3.0)
	# Fade out
	tween.tween_callback(func():
		emit_signal("transition_finished")
		# Asteapta un frame ca combat scene sa apara, apoi ascunde overlay
		await get_tree().process_frame
		await get_tree().process_frame
		hide()
		overlay.modulate = Color(0, 0, 0, 1.0)
	)
