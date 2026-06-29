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
	LORE,
}

var room_id: int = 0
var room_type: RoomType = RoomType.EMPTY
var grid_pos: Vector2i = Vector2i.ZERO  # (col, row) — row 0 = top

var cleared: bool = false
var visited: bool = false
## True once the party has been adjacent to this room (passed by). Persists, so the
## room's type stays revealed on the map even after the party moves away.
var seen: bool = false

var enemies: Array[EnemyData] = []
var loot_gold: int = 0
var loot_items: Array[ItemData] = []

# For dead-soldier remains events (placed by DungeonMap on generation)
var has_remains: bool = false
var remains_soldier_name: String = ""
var remains_items: Array = []  # Array[ItemData]

# Lore room content (only populated when room_type == LORE)
var lore_title: String = ""
var lore_text: String = ""

## Short atmospheric description shown when entering any room for the first time.
## EMPTY rooms get a level-themed line; LORE rooms get the opening sentence.
var flavor_text: String = ""

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
		RoomType.LORE:         return "LORE"
	return "?"

## Full human-readable room name for hover tooltips and overlays.
func get_display_name() -> String:
	match room_type:
		RoomType.SPAWN:        return "Entrance"
		RoomType.MONSTER:      return "Monsters"
		RoomType.ELITE:        return "Elite"
		RoomType.BOSS:         return "Boss"
		RoomType.FOUNTAIN:     return "Fountain"
		RoomType.EMPTY:        return "Empty Room"
		RoomType.MARKET_TRAIT: return "Skill Trainer"
		RoomType.MARKET_GEAR:  return "Gear Market"
		RoomType.LORE:         return "Inscription"
	return "Unknown"

## Returns true for both market types so callers can check re-enterability
## without enumerating room types at the call site.
func is_shop() -> bool:
	return room_type == RoomType.MARKET_GEAR or room_type == RoomType.MARKET_TRAIT

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
		RoomType.LORE:         return Color(0.7, 0.5, 0.9)
	return Color(0.5, 0.5, 0.5)
