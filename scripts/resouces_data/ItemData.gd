# ItemData.gd
class_name ItemData
extends Resource

enum ItemType { WEAPON, ARMOR, SHIELD }
enum WeaponType { SWORD, AXE, BOW, DAGGER, SPEAR }

@export var item_name: String = "Item"
@export var item_type: ItemType = ItemType.WEAPON
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var description: String = ""
@export var gold_cost: int = 50

# Stat bonuses
@export var power_bonus: int = 0
@export var speed_bonus: int = 0
@export var dexterity_bonus: int = 0
@export var hp_bonus: int = 0

# Weapon specific
@export var damage_min: int = 5
@export var damage_max: int = 10
@export var hit_chance_bonus: float = 0.0

# Armor specific
@export var defense: int = 0         # reduce damage primit
@export var dodge_bonus: float = 0.0 # sansa sa eviti atacul

func get_stats_display() -> String:
	var parts = []
	if power_bonus != 0:     parts.append("POW %+d" % power_bonus)
	if speed_bonus != 0:     parts.append("SPD %+d" % speed_bonus)
	if dexterity_bonus != 0: parts.append("DEX %+d" % dexterity_bonus)
	if hp_bonus != 0:        parts.append("HP %+d" % hp_bonus)
	if defense != 0:         parts.append("DEF %+d" % defense)
	if damage_min != 0:      parts.append("DMG %d-%d" % [damage_min, damage_max])
	return ", ".join(parts) if not parts.is_empty() else "No bonuses"

# Fabrica de iteme
static func make_iron_sword() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Iron Sword"
	i.item_type = ItemType.WEAPON
	i.weapon_type = WeaponType.SWORD
	i.description = "A reliable iron sword."
	i.gold_cost = 80
	i.power_bonus = 3
	i.damage_min = 8
	i.damage_max = 14
	i.hit_chance_bonus = 0.05
	return i

static func make_steel_axe() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Steel Axe"
	i.item_type = ItemType.WEAPON
	i.weapon_type = WeaponType.AXE
	i.description = "Heavy but devastating."
	i.gold_cost = 120
	i.power_bonus = 6
	i.damage_min = 12
	i.damage_max = 20
	i.hit_chance_bonus = -0.05
	return i

static func make_shortbow() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Shortbow"
	i.item_type = ItemType.WEAPON
	i.weapon_type = WeaponType.BOW
	i.description = "Fast and accurate."
	i.gold_cost = 90
	i.dexterity_bonus = 2
	i.damage_min = 6
	i.damage_max = 10
	i.hit_chance_bonus = 0.10
	return i

static func make_dagger() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Dagger"
	i.item_type = ItemType.WEAPON
	i.weapon_type = WeaponType.DAGGER
	i.description = "Quick strikes."
	i.gold_cost = 50
	i.speed_bonus = 3
	i.damage_min = 4
	i.damage_max = 8
	i.hit_chance_bonus = 0.15
	return i

static func make_leather_armor() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Leather Armor"
	i.item_type = ItemType.ARMOR
	i.description = "Light protection."
	i.gold_cost = 60
	i.defense = 3
	i.speed_bonus = 1
	i.hp_bonus = 10
	return i

static func make_chainmail() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Chainmail"
	i.item_type = ItemType.ARMOR
	i.description = "Solid protection, a bit heavy."
	i.gold_cost = 150
	i.defense = 7
	i.speed_bonus = -1
	i.hp_bonus = 25
	return i

static func make_plate_armor() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Plate Armor"
	i.item_type = ItemType.ARMOR
	i.description = "Maximum protection."
	i.gold_cost = 280
	i.defense = 12
	i.speed_bonus = -2
	i.hp_bonus = 40
	return i
