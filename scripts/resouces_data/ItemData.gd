# ItemData.gd
class_name ItemData
extends Resource

enum ItemType { WEAPON, ARMOR, SHIELD }
enum WeaponType { SWORD, AXE, BOW, DAGGER, SPEAR }
enum HandType { ONE_HAND, TWO_HAND }

@export var item_name: String = "Item"
@export var item_type: ItemType = ItemType.WEAPON
@export var weapon_type: WeaponType = WeaponType.SWORD
## Whether this weapon requires both hands (blocks weapon_2 slot)
@export var hand_type: HandType = HandType.ONE_HAND
@export var description: String = ""
@export var gold_cost: int = 50

## Quality tier: 0=Common, 1=Uncommon, 2=Rare
@export var quality: int = 0
## Resource costs for crafting at the Weapon Forge: {"Wood": 4, "Iron": 2}
@export var craft_resource_cost: Dictionary = {}
## Minimum forge level required to craft this item: 1, 2, or 3
@export var craft_available_at_forge_level: int = 1
## Soldier classes that can equip this item (empty = any class)
@export var classes: Array[String] = []

# Stat bonuses
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
	i.damage_min = 11
	i.damage_max = 17
	i.hit_chance_bonus = 0.05
	return i

static func make_steel_axe() -> ItemData:
	var i = ItemData.new()
	i.item_name = "Steel Axe"
	i.item_type = ItemType.WEAPON
	i.weapon_type = WeaponType.AXE
	i.description = "Heavy but devastating."
	i.gold_cost = 120
	i.damage_min = 18
	i.damage_max = 26
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

# --- CATALOG HELPERS ---

static func make_from_dict(d: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.item_name = d.get("name", "Unknown")
	item.description = d.get("description", "")

	# Determine item type: explicit shield flag wins, then fallback on stat presence
	if d.get("shield", false):
		item.item_type = ItemType.SHIELD
	elif d.has("defense") and not d.has("damage_min"):
		item.item_type = ItemType.ARMOR
	else:
		item.item_type = ItemType.WEAPON

	item.gold_cost = d.get("gold_cost", 50)
	item.damage_min = d.get("damage_min", 0)
	item.damage_max = d.get("damage_max", 0)
	item.speed_bonus = d.get("speed_bonus", 0)
	item.hp_bonus = d.get("hp_bonus", 0)
	item.hit_chance_bonus = d.get("hit_chance_bonus", 0.0)
	item.defense = d.get("defense", 0)
	item.craft_resource_cost = d.get("craft_resource_cost", {})
	item.craft_available_at_forge_level = d.get("craft_forge_level_required", 1)
	item.classes = Array(d.get("classes", []), TYPE_STRING, "", null)
	item.quality = 0

	# hand_type: stored as string "TWO_HAND" or "ONE_HAND" in dict
	var ht_str: String = d.get("hand_type", "ONE_HAND")
	item.hand_type = HandType.TWO_HAND if ht_str == "TWO_HAND" else HandType.ONE_HAND

	return item

static func get_icon_path(item: ItemData) -> String:
	const BASE := "res://assets/icons/items/"
	if item == null:
		return ""
	const ICONS: Dictionary = {
		# Weapons
		"Ashen Blade": "ashen_blade.png",
		"Hearthguard Sword": "hearthguard_sword.png",
		"Reaver's Hatchet": "reavers_hatchet.png",
		"Widow's Maul": "widows_maul.png",
		"Mourner's Cleaver": "mourners_cleaver.png",
		"Gravewarden Axe": "gravewarden_axe.png",
		"Sundered Greatsword": "sundered_greatsword.png",
		"Oathkeeper": "oathkeeper.png",
		"Ironcrown Warhammer": "ironcrown_warhammer.png",
		"Banner-Bearer's Longsword": "banner_bearers_longsword.png",
		"Kingsward Greataxe": "kingsward_greataxe.png",
		"Hunter's Recurve": "hunters_recurve.png",
		"Ashwood Longbow": "ashwood_longbow.png",
		"Poacher's Crossbow": "poachers_crossbow.png",
		"Skinning Knife": "skinning_knife.png",
		"Trapper's Hatchet": "trappers_hatchet.png",
		"Widow-Maker Crossbow": "widow_maker_crossbow.png",
		"Greenhollow Bow": "greenhollow_bow.png",
		"Falconer's Longbow": "falconers_longbow.png",
		"Apprentice's Stave": "apprentices_stave.png",
		"Emberglass Wand": "emberglass_wand.png",
		"Grimoire of Ashes": "grimoire_of_ashes.png",
		"Scholar's Orb": "scholars_orb.png",
		"Runeward Stave": "runeward_stave.png",
		"Whisperwood Cane": "whisperwood_cane.png",
		"Pyre-Tender's Staff": "pyre_tenders_staff.png",
		"Codex of the Last Library": "codex_of_the_last_library.png",
		"Alleyman's Dirk": "alleymanss_dirk.png",
		"Cinderquick Daggers": "cinderquick_daggers.png",
		"Throwing Knives": "throwing_knives.png",
		"Gutterborn Shortsword": "gutterborn_shortsword.png",
		"Widow's Stiletto": "widows_stiletto.png",
		"Veiled Fang": "veiled_fang.png",
		"Twin Crows": "twin_crows.png",
		"Last Witness": "last_witness.png",
		# Armor
		"Ashcroft Leather": "ashcroft_leather.png",
		"Hunter's Jerkin": "hunters_jerkin.png",
		"Gutter Cloak": "gutter_cloak.png",
		"Hearthwarden Mail": "hearthwarden_mail.png",
		"Banded Veteran's Coat": "banded_veterans_coat.png",
		"Scholar's Robes": "scholars_robes.png",
		"Cindersilk Vestments": "cindersilk_vestments.png",
		"Oath-Sworn Cuirass": "oath_sworn_cuirass.png",
		"Shadowmail Harness": "shadowmail_harness.png",
		"Ironwake Brigandine": "ironwake_brigandine.png",
		"Gravewatch Plate": "gravewatch_plate.png",
		"Wardweave Mantle": "wardweave_mantle.png",
		"Crownbearer Plate": "crownbearer_plate.png",
		"Bastion Harness": "bastion_harness.png",
		"Last Wall Armor": "last_wall_armor.png",
		# Shields
		"Iron Buckler": "iron_buckler.png",
		"Ashwood Targe": "ashwood_targe.png",
		"Hearthguard Kite": "hearthguard_kite.png",
		"Wardwall Shield": "wardwall_shield.png",
		"Oathsworn Pavise": "oathsworn_pavise.png",
		"Crownguard Tower": "crownguard_tower.png",
		"Shadowveil Buckler": "shadowveil_buckler.png",
		"Gravewatch Aegis": "gravewatch_aegis.png",
	}
	var fname: String = ICONS.get(item.item_name, "")
	if fname != "":
		return BASE + fname
	# Fallback by type for any item not in the catalog (e.g. legacy saves)
	match item.item_type:
		ItemType.SHIELD: return BASE + "iron_buckler.png"
		ItemType.ARMOR:  return BASE + "ashcroft_leather.png"
		ItemType.WEAPON: return BASE + "hearthguard_sword.png"
	return ""


# Items from older saves predate class restrictions and carry an empty
# `classes` array (= usable by anyone). Backfill from the catalog by name so
# the equip UI can filter them correctly.
static func get_effective_classes(item: ItemData) -> Array:
	if not item.classes.is_empty():
		return item.classes
	for d in get_all_craftable_weapons() + get_all_craftable_armors() + get_all_craftable_shields():
		if String(d.get("name", "")) == item.item_name:
			return d.get("classes", [])
	return []

static func hand_label(item: ItemData) -> String:
	if item.item_type != ItemType.WEAPON:
		return ""
	return "Two-handed" if item.hand_type == HandType.TWO_HAND else "One-handed"

## Rebuilds an item from the catalog (or hardcoded starter makers) by its
## display name, applying the given quality tier. Returns null if no catalog
## entry or starter item matches `item_name` — callers should fall back to
## verbose reconstruction in that case.
static func make_by_name(p_name: String, p_quality: int = 0) -> ItemData:
	for d in get_all_craftable_weapons() + get_all_craftable_armors() + get_all_craftable_shields():
		if String(d.get("name", "")) == p_name:
			var it := make_from_dict(d)
			apply_quality(it, p_quality)
			return it

	var starter_makers: Array[Callable] = [
		make_iron_sword, make_steel_axe, make_shortbow, make_dagger,
		make_leather_armor, make_chainmail, make_plate_armor,
	]
	for maker in starter_makers:
		var it: ItemData = maker.call()
		if it.item_name == p_name:
			apply_quality(it, p_quality)
			return it

	return null

static func apply_quality(item: ItemData, q: int) -> void:
	var multipliers: Array[float] = [1.0, 1.15, 1.35]
	var m: float = multipliers[clamp(q, 0, 2)]
	item.quality = q
	if q == 0:
		return
	item.damage_min = roundi(item.damage_min * m)
	item.damage_max = roundi(item.damage_max * m)
	item.defense    = roundi(item.defense    * m)
	item.gold_cost  = roundi(item.gold_cost  * m)

# --- WEAPON CATALOG (35 entries) ---

static func get_all_craftable_weapons() -> Array[Dictionary]:
	return [
		{name="Ashen Blade",description="Forged in the embers of the fallen city. It remembers the fire.",classes=["Warrior","Knight"],damage_min=14,damage_max=20,speed_bonus=-1,hit_chance_bonus=0.05,gold_cost=80,craft_resource_cost={"Iron":8,"Wood":2},craft_forge_level_required=1},
		{name="Hearthguard Sword",description="Plain steel for plain duty. Most who carried one did not return.",classes=["Warrior"],damage_min=12,damage_max=18,speed_bonus=0,hit_chance_bonus=0.06,gold_cost=70,craft_resource_cost={"Iron":6,"Wood":2},craft_forge_level_required=1},
		{name="Reaver's Hatchet",description="A woodsman's axe that learned a darker trade.",classes=["Warrior"],damage_min=13,damage_max=21,speed_bonus=0,hit_chance_bonus=0.02,gold_cost=75,craft_resource_cost={"Iron":7,"Wood":3},craft_forge_level_required=1},
		{name="Widow's Maul",description="Named for the wives, not the wielder. It ends arguments quickly.",classes=["Warrior","Knight"],damage_min=18,damage_max=28,speed_bonus=-3,hit_chance_bonus=-0.04,gold_cost=110,craft_resource_cost={"Iron":6,"Wood":4,"Stone":4},craft_forge_level_required=1,hand_type="TWO_HAND"},
		{name="Mourner's Cleaver",description="Forged for the funerals that never came. The widow gave it to her son.",classes=["Warrior"],damage_min=15,damage_max=23,speed_bonus=-1,hit_chance_bonus=0.04,gold_cost=90,craft_resource_cost={"Iron":8,"Wood":2,"Stone":1},craft_forge_level_required=1},
		{name="Gravewarden Axe",description="Once carried by the men who buried the city. They had no time to clean it.",classes=["Warrior"],damage_min=17,damage_max=25,speed_bonus=-2,hit_chance_bonus=0.03,gold_cost=130,craft_resource_cost={"Steel":6,"Wood":3},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Sundered Greatsword",description="Reforged from a blade broken on the gates the night the city fell.",classes=["Knight","Warrior"],damage_min=21,damage_max=31,speed_bonus=-3,hit_chance_bonus=0.04,gold_cost=180,craft_resource_cost={"Steel":10,"Iron":4,"Wood":2},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Oathkeeper",description="A knight's blade. The oath etched on its hilt has outlived three kings.",classes=["Knight"],damage_min=19,damage_max=27,speed_bonus=-1,hit_chance_bonus=0.09,gold_cost=200,craft_resource_cost={"Steel":9,"Iron":3,"Wood":2},craft_forge_level_required=2},
		{name="Ironcrown Warhammer",description="Heavy as the duty it serves. Caves in helms and the men inside.",classes=["Knight"],damage_min=23,damage_max=33,speed_bonus=-4,hit_chance_bonus=-0.02,gold_cost=210,craft_resource_cost={"Steel":8,"Iron":4,"Wood":3,"Stone":3},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Banner-Bearer's Longsword",description="The blade that held the line at the Ashfall Gate.",classes=["Knight","Warrior"],damage_min=16,damage_max=24,speed_bonus=-1,hit_chance_bonus=0.08,gold_cost=160,craft_resource_cost={"Steel":7,"Wood":2},craft_forge_level_required=2},
		{name="Kingsward Greataxe",description="Crown steel. Crown weight. Only the oath-sworn lift it without flinching.",classes=["Knight","Warrior"],damage_min=22,damage_max=34,speed_bonus=-4,hit_chance_bonus=0.03,gold_cost=230,craft_resource_cost={"Steel":11,"Iron":3,"Wood":3},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Hunter's Recurve",description="Cut from yew that grew slow in cold winters. So did the hunter.",classes=["Archer"],damage_min=9,damage_max=15,speed_bonus=1,hit_chance_bonus=0.10,gold_cost=80,craft_resource_cost={"Wood":8,"Iron":2},craft_forge_level_required=1,hand_type="TWO_HAND"},
		{name="Ashwood Longbow",description="Tall as the woman who draws it. Patient as the woods she came from.",classes=["Archer"],damage_min=12,damage_max=19,speed_bonus=0,hit_chance_bonus=0.09,gold_cost=110,craft_resource_cost={"Wood":10,"Iron":2,"Stone":1},craft_forge_level_required=1,hand_type="TWO_HAND"},
		{name="Poacher's Crossbow",description="Built to drop a stag in one bolt. Soldiers fall the same way.",classes=["Archer"],damage_min=14,damage_max=22,speed_bonus=-2,hit_chance_bonus=0.08,gold_cost=120,craft_resource_cost={"Wood":6,"Iron":6},craft_forge_level_required=1,hand_type="TWO_HAND"},
		{name="Skinning Knife",description="Short, curved, honest. The hunter's first blade and often the last.",classes=["Archer","Rogue"],damage_min=7,damage_max=12,speed_bonus=2,hit_chance_bonus=0.09,gold_cost=55,craft_resource_cost={"Iron":3,"Wood":2},craft_forge_level_required=1},
		{name="Trapper's Hatchet",description="Splits kindling. Splits skulls. The archer does not distinguish.",classes=["Archer","Warrior"],damage_min=11,damage_max=17,speed_bonus=0,hit_chance_bonus=0.06,gold_cost=70,craft_resource_cost={"Iron":5,"Wood":3},craft_forge_level_required=1},
		{name="Widow-Maker Crossbow",description="The steel prods sing on the draw. The bolt does not.",classes=["Archer"],damage_min=18,damage_max=28,speed_bonus=-3,hit_chance_bonus=0.07,gold_cost=190,craft_resource_cost={"Steel":7,"Wood":4,"Iron":2},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Greenhollow Bow",description="Strung with sinew from a wolf the forest folk feared. They feared the archer more.",classes=["Archer"],damage_min=15,damage_max=23,speed_bonus=1,hit_chance_bonus=0.12,gold_cost=170,craft_resource_cost={"Steel":4,"Wood":9,"Iron":2},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Falconer's Longbow",description="Bound in raven feathers — black for the city, white for what little is left.",classes=["Archer"],damage_min=17,damage_max=25,speed_bonus=0,hit_chance_bonus=0.11,gold_cost=200,craft_resource_cost={"Steel":5,"Wood":8,"Iron":2},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Apprentice's Stave",description="Cut from the library's last oak. Its crystal still flickers at the smell of smoke.",classes=["Mage"],damage_min=6,damage_max=12,speed_bonus=0,hit_chance_bonus=0.08,gold_cost=65,craft_resource_cost={"Wood":6,"Stone":3},craft_forge_level_required=1},
		{name="Emberglass Wand",description="A shard of furnace-glass set in ash-wood. Warm to the touch even in winter.",classes=["Mage"],damage_min=8,damage_max=16,speed_bonus=1,hit_chance_bonus=0.07,gold_cost=90,craft_resource_cost={"Wood":4,"Stone":5,"Iron":1},craft_forge_level_required=1},
		{name="Grimoire of Ashes",description="Recovered half-charred from the burned library. Some pages still scream when turned.",classes=["Mage"],damage_min=10,damage_max=19,speed_bonus=0,hit_chance_bonus=0.09,gold_cost=130,craft_resource_cost={"Wood":5,"Stone":4,"Iron":3},craft_forge_level_required=1,hand_type="TWO_HAND"},
		{name="Scholar's Orb",description="Held by a librarian as the walls fell. It has not gone dark since.",classes=["Mage"],damage_min=11,damage_max=18,speed_bonus=0,hit_chance_bonus=0.10,gold_cost=160,craft_resource_cost={"Steel":3,"Stone":6,"Wood":2},craft_forge_level_required=2},
		{name="Runeward Stave",description="Steel cage around a forge-orange crystal. The runes were carved in a language no one teaches anymore.",classes=["Mage"],damage_min=13,damage_max=22,speed_bonus=-1,hit_chance_bonus=0.10,gold_cost=190,craft_resource_cost={"Steel":5,"Wood":4,"Stone":4},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Whisperwood Cane",description="Slim, dark, and always cold. The mage swears it speaks.",classes=["Mage","Rogue"],damage_min=9,damage_max=15,speed_bonus=2,hit_chance_bonus=0.11,gold_cost=140,craft_resource_cost={"Steel":2,"Wood":6,"Stone":2},craft_forge_level_required=2},
		{name="Pyre-Tender's Staff",description="Carried by the woman who burned the city's dead. The flame on its tip never went out.",classes=["Mage"],damage_min=15,damage_max=24,speed_bonus=-1,hit_chance_bonus=0.09,gold_cost=220,craft_resource_cost={"Steel":5,"Wood":6,"Stone":5},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Codex of the Last Library",description="The final grimoire pulled from the fire. Its margins are filled with one librarian's farewell.",classes=["Mage"],damage_min=16,damage_max=26,speed_bonus=0,hit_chance_bonus=0.10,gold_cost=250,craft_resource_cost={"Steel":4,"Wood":4,"Stone":5,"Iron":3},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Alleyman's Dirk",description="Cheap iron, cheap grip, cheap death. It does the work and asks no questions.",classes=["Rogue"],damage_min=7,damage_max=13,speed_bonus=2,hit_chance_bonus=0.10,gold_cost=55,craft_resource_cost={"Iron":3,"Wood":2},craft_forge_level_required=1},
		{name="Cinderquick Daggers",description="Paired blades, light as kindling, just as eager to catch.",classes=["Rogue"],damage_min=9,damage_max=14,speed_bonus=3,hit_chance_bonus=0.09,gold_cost=95,craft_resource_cost={"Iron":6,"Wood":2},craft_forge_level_required=1,hand_type="TWO_HAND"},
		{name="Throwing Knives",description="A rogue's secret is never how many they show, but how many they keep.",classes=["Rogue","Archer"],damage_min=8,damage_max=13,speed_bonus=2,hit_chance_bonus=0.12,gold_cost=75,craft_resource_cost={"Iron":5,"Wood":1,"Stone":1},craft_forge_level_required=1},
		{name="Gutterborn Shortsword",description="A blade for narrow streets and narrower mercies.",classes=["Rogue"],damage_min=11,damage_max=17,speed_bonus=1,hit_chance_bonus=0.08,gold_cost=100,craft_resource_cost={"Iron":7,"Wood":2},craft_forge_level_required=1},
		{name="Widow's Stiletto",description="Slim enough to slip between ribs. They say a duchess used it on her husband.",classes=["Rogue"],damage_min=10,damage_max=18,speed_bonus=2,hit_chance_bonus=0.13,gold_cost=150,craft_resource_cost={"Steel":4,"Wood":1},craft_forge_level_required=2},
		{name="Veiled Fang",description="Curved, blackened, silent. Forged by a smith who never asked who'd be wearing it last.",classes=["Rogue"],damage_min=13,damage_max=20,speed_bonus=2,hit_chance_bonus=0.11,gold_cost=175,craft_resource_cost={"Steel":5,"Wood":1,"Stone":1},craft_forge_level_required=2},
		{name="Twin Crows",description="Two short swords, named for the birds that came down on the city the morning after.",classes=["Rogue","Warrior"],damage_min=14,damage_max=21,speed_bonus=1,hit_chance_bonus=0.09,gold_cost=190,craft_resource_cost={"Steel":6,"Wood":2,"Iron":2},craft_forge_level_required=2,hand_type="TWO_HAND"},
		{name="Last Witness",description="A dagger pulled from the back of the city's last steward. The Rogue carries it and does not say where they got it.",classes=["Rogue"],damage_min=15,damage_max=23,speed_bonus=2,hit_chance_bonus=0.14,gold_cost=230,craft_resource_cost={"Steel":6,"Wood":1,"Stone":2},craft_forge_level_required=2},
	]

# --- ARMOR CATALOG (15 entries) ---

static func get_all_craftable_armors() -> Array[Dictionary]:
	return [
		{name="Ashcroft Leather",description="Cured in smoke from the city's last great fire. It smells of home, if home was a pyre.",classes=["Rogue","Archer"],defense=4,speed_bonus=0,gold_cost=60,craft_resource_cost={"Wood":4,"Stone":2},craft_forge_level_required=1},
		{name="Hunter's Jerkin",description="Patched, restitched, patched again. Each tear has a story the archer will not tell.",classes=["Archer"],defense=5,speed_bonus=0,gold_cost=75,craft_resource_cost={"Wood":5,"Iron":2,"Stone":1},craft_forge_level_required=1},
		{name="Gutter Cloak",description="Black wool, deep hood, weighted hem. A rogue's first home and their last.",classes=["Rogue"],defense=4,speed_bonus=1,gold_cost=80,craft_resource_cost={"Wood":3,"Iron":3,"Stone":1},craft_forge_level_required=1},
		{name="Hearthwarden Mail",description="Standard kingdom-issue chain, worn beneath a kingdom-sigil tabard. Plain. Reliable. Mourned in.",classes=["Warrior"],defense=7,speed_bonus=-1,gold_cost=100,craft_resource_cost={"Iron":8,"Wood":2},craft_forge_level_required=1},
		{name="Banded Veteran's Coat",description="Iron bands sewn into ox-hide. The veteran has not taken it off since.",classes=["Warrior","Archer"],defense=6,speed_bonus=0,gold_cost=95,craft_resource_cost={"Iron":6,"Wood":4},craft_forge_level_required=1},
		{name="Scholar's Robes",description="Grey wool, runic embroidery in aged gold. Smells faintly of old ink and older fear.",classes=["Mage"],defense=3,speed_bonus=1,gold_cost=70,craft_resource_cost={"Wood":5,"Stone":2},craft_forge_level_required=1},
		{name="Cindersilk Vestments",description="Layered cyan-grey robes lined with woven wire. A scholar's protection against more than weather.",classes=["Mage"],defense=5,speed_bonus=0,gold_cost=130,craft_resource_cost={"Iron":4,"Wood":5,"Stone":3},craft_forge_level_required=1},
		{name="Oath-Sworn Cuirass",description="Crimson cloak across one shoulder, kingdom sigil on the breast. The knight has not removed it since the city burned.",classes=["Knight"],defense=10,speed_bonus=-2,gold_cost=180,craft_resource_cost={"Iron":10,"Wood":2,"Stone":2},craft_forge_level_required=1},
		{name="Shadowmail Harness",description="Light steel rings, blackened in tallow. It does not catch the lantern light.",classes=["Rogue","Archer"],defense=7,speed_bonus=0,gold_cost=150,craft_resource_cost={"Steel":5,"Wood":2,"Stone":1},craft_forge_level_required=2},
		{name="Ironwake Brigandine",description="Plates riveted between layers of leather. Heavier than it looks. So is the man who built it.",classes=["Warrior","Rogue"],defense=9,speed_bonus=-1,gold_cost=170,craft_resource_cost={"Steel":5,"Iron":3,"Wood":2},craft_forge_level_required=2},
		{name="Gravewatch Plate",description="Half-plate scavenged from a battlefield no one names. The dents have not been hammered out.",classes=["Warrior"],defense=11,speed_bonus=-2,gold_cost=200,craft_resource_cost={"Steel":7,"Iron":4,"Wood":1},craft_forge_level_required=2},
		{name="Wardweave Mantle",description="Steel filaments stitched into silk. The mage wears it the way a soldier wears mail — without comment.",classes=["Mage","Rogue"],defense=7,speed_bonus=0,gold_cost=190,craft_resource_cost={"Steel":4,"Wood":4,"Stone":3},craft_forge_level_required=2},
		{name="Crownbearer Plate",description="Full plate, aged-gold pauldron trim. The dents are kept. The dents are remembered.",classes=["Knight"],defense=13,speed_bonus=-3,gold_cost=260,craft_resource_cost={"Steel":9,"Iron":4,"Stone":2},craft_forge_level_required=2},
		{name="Bastion Harness",description="Made for the men who hold doorways. Made for the men who do not return through them.",classes=["Knight","Warrior"],defense=12,speed_bonus=-3,gold_cost=230,craft_resource_cost={"Steel":8,"Iron":4,"Wood":1},craft_forge_level_required=2},
		{name="Last Wall Armor",description="Forged for the captains of the Ashfall Gate. Only one suit was recovered. The smith made twelve more.",classes=["Knight"],defense=14,speed_bonus=-3,gold_cost=300,craft_resource_cost={"Steel":10,"Iron":5,"Stone":3},craft_forge_level_required=2},
	]

# --- SHIELD CATALOG (8 entries) ---

static func get_all_craftable_shields() -> Array[Dictionary]:
	return [
		{name="Iron Buckler",description="Small enough to palm, solid enough to matter. The rogue does not fight fair — neither does the shield.",classes=["Rogue","Archer"],defense=3,speed_bonus=0,hp_bonus=5,gold_cost=55,craft_resource_cost={"Iron":3,"Wood":2},craft_forge_level_required=1,shield=true},
		{name="Ashwood Targe",description="Round and stubborn. Cut from the last old-growth oak before the forest burned.",classes=["Warrior","Rogue"],defense=5,speed_bonus=-1,hp_bonus=10,gold_cost=80,craft_resource_cost={"Wood":5,"Iron":3},craft_forge_level_required=1,shield=true},
		{name="Hearthguard Kite",description="Standard kingdom-issue. Most of the men who carried one never brought it home.",classes=["Warrior"],defense=7,speed_bonus=-1,hp_bonus=15,gold_cost=110,craft_resource_cost={"Iron":8,"Wood":2},craft_forge_level_required=1,shield=true},
		{name="Wardwall Shield",description="Heavy as a door, half as clever. It has held more than its share of gates.",classes=["Knight","Warrior"],defense=8,speed_bonus=-2,hp_bonus=20,gold_cost=140,craft_resource_cost={"Iron":10,"Stone":2},craft_forge_level_required=1,shield=true},
		{name="Oathsworn Pavise",description="A knight's shield, tall enough to kneel behind. The oath carved into its rim is not decoration.",classes=["Knight"],defense=11,speed_bonus=-3,hp_bonus=30,gold_cost=200,craft_resource_cost={"Steel":6,"Iron":4},craft_forge_level_required=2,shield=true},
		{name="Crownguard Tower",description="Built for the men who stood at the walls the night the crown nearly fell. Some of those men are still standing.",classes=["Knight"],defense=14,speed_bonus=-4,hp_bonus=40,gold_cost=280,craft_resource_cost={"Steel":9,"Iron":5,"Stone":2},craft_forge_level_required=2,shield=true},
		{name="Shadowveil Buckler",description="Dark-treated steel and whisper-quiet edges. The rogue moves first. The shield answers second.",classes=["Rogue","Archer"],defense=5,speed_bonus=0,hp_bonus=8,gold_cost=120,craft_resource_cost={"Steel":3,"Wood":2},craft_forge_level_required=2,shield=true},
		{name="Gravewatch Aegis",description="Forged by the men who guarded the city's dead. It never left the cemetery. Now it guards the living.",classes=["Warrior","Knight"],defense=10,speed_bonus=-2,hp_bonus=25,gold_cost=190,craft_resource_cost={"Steel":7,"Iron":3},craft_forge_level_required=2,shield=true},
	]
