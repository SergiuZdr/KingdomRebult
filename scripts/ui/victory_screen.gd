# res://scripts/ui/victory_screen.gd
extends CanvasLayer

func _ready() -> void:
	$Background.theme = GameTheme.get_theme()
	# Lighter parchment window frame (matches the recap) — readable, less heavy.
	var frame_sb := PixelUI.parchment_window_stylebox(20)
	if frame_sb != null:
		$Background/Center/Panel.add_theme_stylebox_override("panel", frame_sb)

func show_ending(ending_faction: String) -> void:
	$Background/Center/Panel/VBox/Title.text = "The City Stands"

	var body := ""
	match ending_faction:
		"iron_legion":
			body = "The Iron Legion rode in two days before your father. Boran's men held the northern road open and said nothing about why. The king arrived to find soldiers he did not recognize standing at ease in his son's city, and the look he gave them was a long one.\n\nHe did not ask. You did not explain. Some alliances are better understood than named.\n\nThe city stands. The walls are taller than they were. The people have learned to stop flinching at shadows. Your father put his hand on your shoulder and kept it there longer than he meant to, and you let him.\n\nYou built it. It holds."
		"wardens":
			body = "Otava was at the gate when your father arrived. She did not bow. She has not bowed to any king in forty years and your father is not the one who will change that. She looked at him for a long moment and said: 'Your son has learned to listen.'\n\nYour father did not know what that meant. You do.\n\nThe city is alive in a way it was not when you came. Not just rebuilt — returned. The walls breathe differently in the early morning. The wells have not run dry. The old families who fled are beginning to come back, drawn by something they cannot name.\n\nYou built it. It remembers."
		"pale_court":
			body = "Aldous was in the city before your father. Of course he was.\n\nHe found you in the hall the night before the king arrived and said, very quietly, that the Court considered the arrangement satisfactory. He did not specify which arrangement. You did not ask.\n\nYour father walked through the gate the next morning and called it a miracle. He is not wrong. He simply does not know which parts of the miracle had a price.\n\nThe city stands. The Pale Court has roots in it now, thin ones, patient ones. You will be managing that for years. You knew this when you made the choice. You made it anyway.\n\nYou built it. The cost is still being counted."
		_:  # neutral ending
			body = "No faction rode in with your father. No letters came ahead of him. Just the king, older than you remembered, on a horse that was also older than you remembered, with a smaller escort than a king should have.\n\nHe walked through the gate without ceremony and stood in the square for a long time, looking at what you had made from what he had left.\n\nThen he said: 'I should have come sooner.'\n\nYou said nothing. There was nothing to say that the city had not already said.\n\nYou built it. Alone. It stands."

	$Background/Center/Panel/VBox/Body.text = body

	var stats_text := "Waves survived: %d  |  Turns: %d  |  Dungeon level: %d" % [
		GameState.total_waves_won,
		GameState.current_turn,
		DungeonState.dungeon_level,
	]
	$Background/Center/Panel/VBox/Stats.text = stats_text
	UIKit.fade_in($Background/Center/Panel)

func _on_menu_button_pressed() -> void:
	GameState.menu_open = false
	SceneFader.change_scene("res://scenes/ui/main_menu.tscn")
