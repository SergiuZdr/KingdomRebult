extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var label_gold: Label = $UI/HUD/ResourceBar/TopRow/LabelGold
@onready var label_wood: Label = $UI/HUD/ResourceBar/TopRow/LabelWood
@onready var label_stone: Label = $UI/HUD/ResourceBar/TopRow/LabelStone
@onready var label_iron: Label = $UI/HUD/ResourceBar/TopRow/LabelIron
@onready var label_steel: Label = $UI/HUD/ResourceBar/TopRow/LabelSteel
@onready var label_food: Label = $UI/HUD/ResourceBar/TopRow/LabelFood
@onready var label_morale: Label = $UI/HUD/ResourceBar/TopRow/LabelMorale
@onready var label_pep: Label = $UI/HUD/ResourceBar/TopRow/LabelPep
@onready var label_turn: Label = $UI/HUD/ResourceBar/TopRow/LabelTurn
@onready var label_threat: Label = $UI/HUD/ResourceBar/LabelThreat
@onready var combat_scene = $CombatScene
@onready var soldier_menu: Control = null
@onready var combat_transition = $CombatTransition
@onready var pre_combat_screen = $PreCombatScreen

const CAMERA_SPEED: float = 400.0

func _ready() -> void:
	GameState.in_city_view = true
	_update_resource_display()
	_update_threat_display()
	GameState.resources_changed.connect(_update_resource_display)
	GameState.threat_updated.connect(_update_threat_display)
	GameState.combat_started_from_turn.connect(_on_combat_started)

func _on_combat_started() -> void:
	$UI.visible = false
	print("Combat started, enemies: ", CombatState.enemies.size())
	print("PreCombatScreen visible: ", pre_combat_screen.visible)
	pre_combat_screen.selection_confirmed.connect(_on_soldiers_selected, CONNECT_ONE_SHOT)
	pre_combat_screen.open(CombatState.enemies)
	print("After open, PreCombatScreen visible: ", pre_combat_screen.visible)
	
func _on_soldiers_selected(soldiers: Array) -> void:
	CombatState.allies = soldiers
	combat_transition.play(CombatState.enemies)
	combat_transition.transition_finished.connect(
		func(): CombatState.begin_after_selection()
		, CONNECT_ONE_SHOT
	)
	
func _process(delta: float) -> void:
	_handle_camera(delta)

func _handle_camera(delta: float) -> void:
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	camera.position += direction * CAMERA_SPEED * delta

func _update_resource_display() -> void:
	label_gold.text = "Gold: %d" % GameState.gold
	label_wood.text = "Wood: %d" % GameState.wood
	label_stone.text = "Stone: %d" % GameState.stone
	label_iron.text = "Iron: %d" % GameState.iron
	label_steel.text = "Steel: %d" % GameState.steel
	label_turn.text = "Turn: %d" % GameState.current_turn
	label_food.text = "Food: %d" % GameState.food
	label_morale.text = "Morale: %d" % GameState.morale
	label_pep.text = "People: %d" % GameState.workforce_total

func _update_threat_display() -> void:
	label_threat.text = GameState.get_threat_forecast_text()

func _on_btn_end_turn_pressed() -> void:
	GameState.end_turn()

func _on_scene_exit() -> void:
	GameState.in_city_view = false
	$UI.visible = false

func _on_btn_soldiers_pressed() -> void:
	if soldier_menu == null:
		soldier_menu = preload("res://scenes/management/soldier_menu.tscn").instantiate()
		add_child(soldier_menu)
	$UI.visible = false
	soldier_menu.open()
func _on_btn_save_pressed() -> void:
	_show_save_panel()

var save_panel: Control = null

func _show_save_panel() -> void:
	if save_panel != null:
		save_panel.queue_free()

	save_panel = PanelContainer.new()
	save_panel.position = Vector2(440, 200)
	save_panel.custom_minimum_size = Vector2(400, 280)
	add_child(save_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	save_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Save Game"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	for i in range(1, SaveManager.MAX_SLOTS + 1):
		var info = SaveManager.get_slot_info(i)
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if info.get("empty", true):
			info_lbl.text = "Slot %d — Empty" % i
		else:
			info_lbl.text = "Slot %d — Turn %d | %s" % [
				i, info.get("turn", 0), info.get("timestamp", "")
			]
		hbox.add_child(info_lbl)

		var save_btn = Button.new()
		save_btn.text = "Save"
		save_btn.custom_minimum_size = Vector2(80, 34)
		save_btn.pressed.connect(func():
			SaveManager.save_game(i)
			save_panel.queue_free()
			save_panel = null
		)
		hbox.add_child(save_btn)

	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(func():
		save_panel.queue_free()
		save_panel = null
	)
	vbox.add_child(close_btn)

	GameState.menu_open = true
	save_panel.tree_exited.connect(func(): GameState.menu_open = false)
func _on_btn_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
