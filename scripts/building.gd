# building.gd
extends Area2D

@export var building_name: String = "Building"
@export var building_description: String = "A building."
@export var is_built: bool = true

@onready var name_label: Label = $NameLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	name_label.text = building_name
	input_pickable = true

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if GameState.menu_open:
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
