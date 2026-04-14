# TraitLibrary.gd
class_name TraitLibrary

# Returneaza toate trait-urile disponibile
static func get_all() -> Array[TraitData]:
	return [
		# --- COMBAT TRAITS (hard to get) ---

		_make("bloodthirsty",
			"Bloodthirsty",
			"Has killed many in a single battle. Power surges with each kill.",
			TraitData.TraitTrigger.COMBAT,
			{power_bonus = 5, required_kills = 4}),

		_make("berserker",
			"Berserker",
			"Fought through extreme punishment. Hits harder when wounded.",
			TraitData.TraitTrigger.COMBAT,
			{power_bonus = 8, defense_bonus = -2, required_damage_taken = 60}),

		_make("iron_skin",
			"Iron Skin",
			"Has endured massive damage and hardened from it.",
			TraitData.TraitTrigger.COMBAT,
			{defense_bonus = 5, hp_bonus = 15, required_damage_taken = 80}),

		_make("ghost",
			"Ghost",
			"Survived on the edge of death. Moves like a shadow.",
			TraitData.TraitTrigger.COMBAT,
			{speed_bonus = 4, dodge_bonus = 0.08, survive_near_death = true}),

		_make("executioner",
			"Executioner",
			"Has ended many lives in one fight. Strikes with lethal precision.",
			TraitData.TraitTrigger.COMBAT,
			{hit_chance_bonus = 0.10, power_bonus = 3, required_kills = 3,
			 required_damage_dealt = 100}),

		_make("warhound",
			"Warhound",
			"A veteran of countless battles. Never misses.",
			TraitData.TraitTrigger.COMBAT,
			{hit_chance_bonus = 0.12, dexterity_bonus = 3,
			 required_kills = 3, required_damage_dealt = 120}),

		_make("tank",
			"Tank",
			"An immovable wall. Built to absorb punishment.",
			TraitData.TraitTrigger.COMBAT,
			{defense_bonus = 8, hp_bonus = 30, speed_bonus = -2,
			 required_damage_taken = 100}),

		# --- LEVEL UP TRAITS (hard to get) ---
		_make("swift",
			"Swift",
			"Reached level 3 with high speed. Strikes before others react.",
			TraitData.TraitTrigger.LEVEL_UP,
			{speed_bonus = 6, dexterity_bonus = 4, required_level = 3}),

		_make("veteran",
			"Veteran",
			"Reached level 5. A seasoned warrior.",
			TraitData.TraitTrigger.LEVEL_UP,
			{power_bonus = 4, defense_bonus = 2, required_level = 5}),

		_make("resilient",
			"Resilient",
			"Reached level 10. Has survived everything thrown at them.",
			TraitData.TraitTrigger.LEVEL_UP,
			{hp_bonus = 50, defense_bonus = 3, required_level = 10}),

		_make("elite",
			"Elite",
			"Reached level 15. One of the finest soldiers in the kingdom.",
			TraitData.TraitTrigger.LEVEL_UP,
			{power_bonus = 6, speed_bonus = 3, dexterity_bonus = 3,
			 required_level = 15}),

		_make("champion",
			"Champion",
			"Reached level 20. A living legend.",
			TraitData.TraitTrigger.LEVEL_UP,
			{power_bonus = 10, hp_bonus = 40, defense_bonus = 5,
			 hit_chance_bonus = 0.05, required_level = 20}),


		_make("resilient",
			"Resilient",
			"Reached level 6. Has survived everything thrown at them.",
			TraitData.TraitTrigger.LEVEL_UP,
			{hp_bonus = 50, defense_bonus = 3, required_level = 6}),
	]

static func _make(id: String, tname: String, desc: String,
				  trigger: TraitData.TraitTrigger, stats: Dictionary) -> TraitData:
	var t = TraitData.new()
	t.trait_id = id
	t.trait_name = tname
	t.description = desc
	t.trigger = trigger
	t.power_bonus       = stats.get("power_bonus", 0)
	t.speed_bonus       = stats.get("speed_bonus", 0)
	t.dexterity_bonus   = stats.get("dexterity_bonus", 0)
	t.hp_bonus          = stats.get("hp_bonus", 0)
	t.defense_bonus     = stats.get("defense_bonus", 0)
	t.hit_chance_bonus  = stats.get("hit_chance_bonus", 0.0)
	t.dodge_bonus       = stats.get("dodge_bonus", 0.0)
	t.required_kills         = stats.get("required_kills", 0)
	t.required_damage_dealt  = stats.get("required_damage_dealt", 0)
	t.required_damage_taken  = stats.get("required_damage_taken", 0)
	t.required_level         = stats.get("required_level", 0)
	t.survive_near_death     = stats.get("survive_near_death", false)
	return t
