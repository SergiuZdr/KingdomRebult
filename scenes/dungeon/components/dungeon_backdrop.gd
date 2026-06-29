# res://scenes/dungeon/components/dungeon_backdrop.gd
class_name DungeonBackdrop
extends Control

## Atmospheric dungeon background built in-engine.
## Full-rect, mouse-ignore — place behind all other dungeon UI nodes.
##
## Clean, even dark cavern: solid base + tiled stone wall. Arch, pillars, and
## torches are hidden — the map board provides its own surface, and torch
## animation has been moved into the dungeon_map_scene header crest so the
## flames sit symmetrically beside the centered title label.

@onready var _base_rect: ColorRect   = $Base
@onready var _wall_tile: TextureRect = $WallTile
@onready var _vignette: TextureRect  = $Vignette
@onready var _arch: TextureRect      = $Arch
@onready var _pillar_l: TextureRect  = $PillarL
@onready var _pillar_r: TextureRect  = $PillarR

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for child in get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_static()

func _setup_static() -> void:
	_base_rect.color = UIPalette.STONE_DARKEST

	# Tiled wall (dim cool stone), even across the whole screen.
	var wall_tex := PixelUI.tex("res://assets/ui/dungeon/background/wall_tile.png")
	if wall_tex:
		_wall_tile.texture = wall_tex
	_wall_tile.stretch_mode = TextureRect.STRETCH_TILE
	_wall_tile.modulate = Color(0.34, 0.34, 0.40, 1.0)

	# No vignette — it produced the washed "white edges" look.
	_vignette.visible = false

	# Arch and pillars hidden — competed with map board readability.
	# Torches moved to the header crest in dungeon_map_scene.gd.
	_arch.visible     = false
	_pillar_l.visible = false
	_pillar_r.visible = false
