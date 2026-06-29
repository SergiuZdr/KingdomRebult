# building.gd
extends Area2D

@export var building_name: String = "Building"
@export var building_description: String = "A building."
@export var is_built: bool = true

@onready var name_label: Label = $NameLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	name_label.text = building_name
	input_pickable = true
	_load_sprite()
	_update_visual_state()
	GameState.resources_changed.connect(_update_visual_state)

func _load_sprite() -> void:
	var path := BuildingData.get_texture_path(building_name)
	if path == "":
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(2.0, 2.0)
	sprite.position = Vector2(0, 0)

func _update_visual_state() -> void:
	var level := GameState.get_building_level(building_name)
	if level >= 1:
		# Show only the building name on the world label — level is shown in the popup title
		name_label.text = building_name
		modulate = Color(1.0, 1.0, 1.0)
	else:
		name_label.text = building_name + "\n[Ruins]"
		modulate = Color(0.65, 0.5, 0.4)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if GameState.menu_open or CombatState.active:
		return
		
	var screen_mouse_pos = get_viewport().get_mouse_position()
	if BuildingPopup != null and BuildingPopup.blocks_screen_position(screen_mouse_pos):
		return

	var mouse_pos = get_global_mouse_position()
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results = space.intersect_point(query)
	for result in results:
		if result.collider == self:
			BuildingPopup.show_building(building_name, building_description)
			get_viewport().set_input_as_handled()
			return
