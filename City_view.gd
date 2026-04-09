extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var label_gold:   Label = $UI/HUD/ResourceBar/LabelGold
@onready var label_wood:   Label = $UI/HUD/ResourceBar/LabelWood
@onready var label_stone:  Label = $UI/HUD/ResourceBar/LabelStone
@onready var label_iron:   Label = $UI/HUD/ResourceBar/LabelIron
@onready var label_steel:  Label = $UI/HUD/ResourceBar/LabelSteel
@onready var label_food:   Label = $UI/HUD/ResourceBar/LabelFood
@onready var label_morale: Label = $UI/HUD/ResourceBar/LabelMorale
@onready var label_pep:    Label = $UI/HUD/ResourceBar/LabelPep
@onready var combat_scene = $CombatScene

const CAMERA_SPEED: float = 400.0

func _ready() -> void:
	GameState.in_city_view = true
	_update_resource_display()
	GameState.resources_changed.connect(_update_resource_display)
	GameState.combat_started_from_turn.connect(_on_combat_started)
	
func _on_combat_started() -> void:
	$UI.visible = false
func _process(delta: float) -> void:
	_handle_camera(delta)

func _handle_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	camera.position += direction * CAMERA_SPEED * delta

func _update_resource_display() -> void:
	label_gold.text   = "Gold: %d"   % GameState.gold
	label_wood.text   = "Wood: %d"   % GameState.wood
	label_stone.text  = "Stone: %d"  % GameState.stone
	label_iron.text   = "Iron: %d"   % GameState.iron
	label_steel.text  = "Steel: %d"  % GameState.steel
	label_food.text   = "Food: %d"   % GameState.food
	label_morale.text = "Morale: %d" % GameState.morale
	label_pep.text    = "People: %d" % GameState.workforce_total

func _on_btn_end_turn_pressed() -> void:
	GameState.end_turn()
@onready var soldier_menu: Control = null

func _on_scene_exit() -> void:
	GameState.in_city_view = false
	$UI.visible = false
	
func _on_btn_soldiers_pressed() -> void:
	if soldier_menu == null:
		soldier_menu = preload("res://scenes/management/soldier_menu.tscn").instantiate()
		add_child(soldier_menu)
	$UI.visible = false
	soldier_menu.open()
