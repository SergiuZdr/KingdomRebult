class_name DungeonRoom
extends RefCounted

enum RoomType {
	SPAWN,
	MONSTER,
	ELITE,
	BOSS,
	FOUNTAIN,
	EMPTY,
	MARKET_TRAIT,
	MARKET_GEAR,
}

var room_id: int = 0
var room_type: RoomType = RoomType.EMPTY
var grid_pos: Vector2i = Vector2i.ZERO  # (col, row) — row 0 = top

var cleared: bool = false
var visited: bool = false

var enemies: Array[EnemyData] = []
var loot_gold: int = 0
var loot_items: Array[ItemData] = []

# For dead-soldier remains events (placed by DungeonMap on generation)
var has_remains: bool = false
var remains_soldier_name: String = ""
var remains_items: Array = []  # Array[ItemData]

func get_display_label() -> String:
	match room_type:
		RoomType.SPAWN:        return "START"
		RoomType.MONSTER:      return "MON"
		RoomType.ELITE:        return "ELITE"
		RoomType.BOSS:         return "BOSS"
		RoomType.FOUNTAIN:     return "FOUNT"
		RoomType.EMPTY:        return "EMPTY"
		RoomType.MARKET_TRAIT: return "SHOP-T"
		RoomType.MARKET_GEAR:  return "SHOP-G"
	return "?"

func get_display_color() -> Color:
	match room_type:
		RoomType.SPAWN:        return Color(0.3, 0.85, 0.4)
		RoomType.MONSTER:      return Color(0.85, 0.3, 0.3)
		RoomType.ELITE:        return Color(0.9, 0.5, 0.1)
		RoomType.BOSS:         return Color(0.8, 0.1, 0.1)
		RoomType.FOUNTAIN:     return Color(0.3, 0.6, 0.95)
		RoomType.EMPTY:        return Color(0.55, 0.55, 0.6)
		RoomType.MARKET_TRAIT: return Color(0.85, 0.8, 0.2)
		RoomType.MARKET_GEAR:  return Color(0.6, 0.85, 0.3)
	return Color(0.5, 0.5, 0.5)
