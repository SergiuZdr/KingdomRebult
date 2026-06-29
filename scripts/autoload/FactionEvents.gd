# res://scripts/autoload/FactionEvents.gd
# Autoload — holds all faction event definitions, tracks which have fired,
# manages diplomacy-action cooldowns, and queues one event per turn for the
# hub screen to display via a popup.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
## Emitted when a faction event has been queued and is ready to display.
signal faction_event_ready(event: Dictionary)

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
var _fired_ids: Array[String] = []
var _action_cooldowns: Dictionary = {}    # action_id (String) -> turn_when_last_used (int)
var _pending: Array[Dictionary] = []      # at most one event lives here between turns

# ---------------------------------------------------------------------------
# Faction colors (used by the popup)
# ---------------------------------------------------------------------------
const FACTION_COLORS: Dictionary = {
	"wardens":     Color(0.3, 0.8, 0.4),
	"iron_legion": Color(0.7, 0.7, 0.9),
	"pale_court":  Color(0.85, 0.75, 0.35),
	"cross":       Color(0.9, 0.5, 0.3),
	"king_aldric": Color(0.95, 0.82, 0.45),
}

# ---------------------------------------------------------------------------
# Diplomacy action definitions
# ---------------------------------------------------------------------------
const DIPLOMACY_ACTIONS: Array = [
	{
		"id":      "warden_offering",
		"faction": "wardens",
		"label":   "Honor the Old Rites",
		"cost":    {"gold": 25, "food": 10},
		"effects": [{"type": "faction", "target": "wardens", "delta": 8}],
		"preview": "Wardens +8",
		"flavor":  "Gifts of food and coin earn trust with the forest people.",
	},
	{
		"id":      "warden_dungeon_share",
		"faction": "wardens",
		"label":   "Share Dungeon Findings",
		"cost":    {"gold": 0},
		"requires": "dungeon_2",
		"effects": [
			{"type": "faction", "target": "wardens",    "delta": 12},
			{"type": "faction", "target": "pale_court", "delta": 3},
		],
		"preview": "Wardens +12, Pale Court +3",
		"flavor":  "What you have found below interests Otava more than you might expect.",
	},
	{
		"id":      "warden_council",
		"faction": "wardens",
		"label":   "Invite Otava to Council",
		"cost":    {},
		"requires": "wardens_60",
		"effects": [
			{"type": "faction", "target": "wardens",     "delta": 15},
			{"type": "faction", "target": "iron_legion", "delta": -8},
		],
		"preview": "Wardens +15, Iron Legion -8",
		"flavor":  "Boran will hear of this. He always does.",
		"cooldown": 5,
	},
	{
		"id":      "legion_tribute",
		"faction": "iron_legion",
		"label":   "Pay Tribune",
		"cost":    {"gold": 60},
		"effects": [{"type": "faction", "target": "iron_legion", "delta": 8}],
		"preview": "Iron Legion +8",
		"flavor":  "Coin soothes even military pride.",
	},
	{
		"id":      "legion_patrol_share",
		"faction": "iron_legion",
		"label":   "Share Patrol Routes",
		"cost":    {},
		"effects": [
			{"type": "faction", "target": "iron_legion", "delta": 10},
			{"type": "faction", "target": "wardens",     "delta": -5},
		],
		"preview": "Iron Legion +10, Wardens -5",
		"flavor":  "The Legion appreciates intelligence. Otava does not.",
	},
	{
		"id":      "legion_garrison",
		"faction": "iron_legion",
		"label":   "Pledge Wall Support",
		"cost":    {"gold": 30},
		"requires": "iron_legion_60",
		"effects": [{"type": "faction", "target": "iron_legion", "delta": 15}],
		"preview": "Iron Legion +15",
		"flavor":  "A formal pledge carries weight with Boran's command.",
		"cooldown": 5,
	},
	{
		"id":      "pale_purchase",
		"faction": "pale_court",
		"label":   "Purchase Information",
		"cost":    {"gold": 40},
		"effects": [{"type": "faction", "target": "pale_court", "delta": 6}],
		"preview": "Pale Court +6",
		"flavor":  "Aldous always has something worth buying.",
	},
	{
		"id":      "pale_samples",
		"faction": "pale_court",
		"label":   "Send Mineral Samples",
		"cost":    {"iron": 10, "steel": 5},
		"effects": [{"type": "faction", "target": "pale_court", "delta": 12}],
		"preview": "Pale Court +12",
		"flavor":  "Red-veined stone is worth more to Aldous than you expect.",
	},
	{
		"id":      "pale_assessment",
		"faction": "pale_court",
		"label":   "Allow an Assessment",
		"cost":    {"gold": 20},
		"requires": "pale_court_40",
		"effects": [
			{"type": "faction",  "target": "pale_court", "delta": 14},
			{"type": "resource", "target": "morale",     "delta": -5},
		],
		"preview": "Pale Court +14, Army Morale -5",
		"flavor":  "Aldous's examinations are thorough. The men do not enjoy them.",
		"cooldown": 5,
	},
]

const ACTION_COOLDOWN_TURNS: int = 3

# ---------------------------------------------------------------------------
# Event definitions
# ---------------------------------------------------------------------------
const EVENTS: Array = [
	{
		"id":      "warden_scout_caught",
		"title":   "A Face at the Treeline",
		"faction": "wardens",
		"trigger": {"min_turn": 6, "min_dungeon_level": 1},
		"body":    "Your guards brought in a man at dusk — slight, barefoot, with three black lines tattooed on his chin. He has not spoken. He carries nothing except a strip of bark carved with a single symbol your scholars cannot read. Your captain says he was found measuring the depth of the new excavation shaft with a knotted rope.\n\nHe does not look frightened. He looks like a man who expected to be caught.",
		"choices": [
			{
				"label":   "Release him. Send word to Otava that her people may observe — but not interfere.",
				"preview": "Wardens +10",
				"effects": [{"type": "faction", "target": "wardens", "delta": 10}],
			},
			{
				"label":   "Detain him. If the Wardens are watching your dig, you need to know why.",
				"preview": "Wardens -15  (you'll learn what he was measuring)",
				"effects": [{"type": "faction", "target": "wardens", "delta": -15}],
			},
			{
				"label":   "Release him — but double the perimeter watch.",
				"preview": "Wardens -5, Gold -20",
				"effects": [
					{"type": "faction",  "target": "wardens", "delta": -5},
					{"type": "resource", "target": "gold",    "delta": -20},
				],
			},
		],
	},
	{
		"id":      "legion_census",
		"title":   "The Legion's Ledger",
		"faction": "iron_legion",
		"trigger": {"min_turn": 9},
		"body":    "A Legion clerk arrived this morning with a leather satchel and a polite smile. He presents a form — standard regional census, he says, required of all settlements within the Legion's administrative sphere. It asks for your soldier count, their classes, their equipment quality, and the name of your ranking officer.\n\nHe mentions, without emphasis, that the last settlement that declined to file the census had a 'compliance audit' conducted by forty armed men.",
		"choices": [
			{
				"label":   "File the census truthfully. The Legion will find out eventually anyway.",
				"preview": "Iron Legion +12",
				"effects": [{"type": "faction", "target": "iron_legion", "delta": 12}],
			},
			{
				"label":   "File it — but underreport. List half your soldiers as 'civilian militia.'",
				"preview": "Iron Legion +3  (they may notice the discrepancy later)",
				"effects": [{"type": "faction", "target": "iron_legion", "delta": 3}],
			},
			{
				"label":   "Refuse. This city is neutral territory and not subject to Legion administration.",
				"preview": "Iron Legion -12, Threat +40%, Next wave harder",
				"effects": [
					{"type": "faction",              "target": "iron_legion", "delta": -12},
					{"type": "threat_percent",        "target": "",            "delta": 40},
					{"type": "next_wave_difficulty",  "target": "",            "delta": 2},
				],
			},
		],
	},
	{
		"id":      "pale_court_gift",
		"title":   "A Package from the South",
		"faction": "pale_court",
		"trigger": {"min_turn": 9, "max_pale_court": 39},
		"body":    "A courier arrived with a crate bearing the Pale Court's seal — a white hand on black wax. Inside: three books on metallurgical history, two bottles of wine from a southern vineyard, and a small glass vial sealed with silver wire. The vial is labeled in a careful hand: 'General Restorative — For the Prince's Household. With the warmest compliments of Aldous.'\n\nOtava, if she is present, would say the liquid inside moves wrong — too slow, like something thinking.",
		"choices": [
			{
				"label":   "Accept everything. Aldous deserves goodwill for the gesture.",
				"preview": "Pale Court +12, Army Morale +5, Wardens -8",
				"effects": [
					{"type": "faction",                        "target": "pale_court", "delta": 12},
					{"type": "all_soldier_morale",             "target": "",           "delta": 5},
					{"type": "faction",                        "target": "wardens",    "delta": -8},
					{"type": "pale_court_gift_death_pending",  "target": "",           "delta": 1},
				],
			},
			{
				"label":   "Accept the books and wine. Return the vial with thanks.",
				"preview": "Pale Court +5, All soldiers +50 XP",
				"effects": [
					{"type": "faction",        "target": "pale_court", "delta": 5},
					{"type": "all_soldier_xp", "target": "",           "delta": 50},
				],
			},
			{
				"label":   "Return everything. You do not accept gifts from people who want things from you.",
				"preview": "Pale Court -8, Wardens +8",
				"effects": [
					{"type": "faction", "target": "pale_court", "delta": -8},
					{"type": "faction", "target": "wardens",    "delta": 8},
				],
			},
		],
	},
	{
		"id":      "warden_ritual_request",
		"title":   "Otava's Price",
		"faction": "wardens",
		"trigger": {"min_dungeon_level": 2},
		"body":    "Otava came to the gate herself this time — no message, no intermediary. She stood in the road and waited until you came down.\n\n'The second level is awake,' she said. 'Not angry. Awake. There is a difference, and you do not have enough time left to learn it slowly. I can perform the Stilling — a three-day ritual on the lower entrance. It will not seal what is waking. But it will buy you a season before it remembers you are there. I need your men out of the lower shaft for those three days. All of them. No exceptions.'\n\nShe is asking you to go blind for seventy-two hours.",
		"choices": [
			{
				"label":   "Grant her the three days. Whatever she knows, she has earned the right to act on it.",
				"preview": "Wardens +15  (you will not be able to enter the dungeon for 3 turns — if you break the promise: Wardens -25)",
				"effects": [
					{"type": "faction",       "target": "wardens", "delta": 15},
					{"type": "warden_lockout","target": "",        "delta": 3},
				],
			},
			{
				"label":   "Refuse. Three days is too long. The dungeon does not stop because you need it to.",
				"preview": "Wardens -12, Iron Legion +5",
				"effects": [
					{"type": "faction", "target": "wardens",     "delta": -12},
					{"type": "faction", "target": "iron_legion", "delta": 5},
				],
			},
		],
	},
	{
		"id":      "legion_garrison_offer",
		"title":   "Eight Soldiers and a Flag",
		"faction": "iron_legion",
		"trigger": {"min_turn": 13},
		"body":    "The offer arrives in writing, signed by Boran himself. Eight Iron Legion soldiers, fully equipped, would be stationed at your outer gate 'in the spirit of regional cooperation.' They would help defend against raids, the letter says. They would ask for nothing except a small garrison room and the right to observe 'general reconstruction activities.'\n\nYou know what 'observe' means. You also know that eight trained Legion soldiers in a raid would save lives.",
		"choices": [
			{
				"label":   "Accept. Eight swords are eight swords.",
				"preview": "Iron Legion +15, Wardens -10, Food -25, 1 fewer enemy per non-boss wave until the next boss",
				"effects": [
					{"type": "faction",         "target": "iron_legion", "delta": 15},
					{"type": "faction",         "target": "wardens",     "delta": -10},
					{"type": "resource",        "target": "food",        "delta": -25},
					{"type": "legion_garrison", "target": "",            "delta": 0},
				],
			},
			{
				"label":   "Counter-offer: two soldiers at the outer gate, no access past the wall. They will handle one wave on their own.",
				"preview": "Iron Legion +6  (the garrison auto-defends the next non-boss wave — your soldiers earn nothing from it)",
				"effects": [
					{"type": "faction",          "target": "iron_legion", "delta": 6},
					{"type": "legion_solo_fight","target": "",            "delta": 0},
				],
			},
			{
				"label":   "Decline, respectfully. This city is neutral and your soldiers are strong enough to defend it.",
				"preview": "Iron Legion -8, Wardens +6, Army Morale +5",
				"effects": [
					{"type": "faction",           "target": "iron_legion", "delta": -8},
					{"type": "faction",           "target": "wardens",     "delta": 6},
					{"type": "all_soldier_morale","target": "",            "delta": 5},
				],
			},
		],
	},
	{
		"id":      "pale_court_volunteer",
		"title":   "A Medical Assessment",
		"faction": "pale_court",
		"trigger": {"min_turn": 15, "min_pale_court": 55},
		"body":    "Aldous's letter is short and very careful. He is conducting, he writes, a study of 'the physiological effects of proximity to deep mineral formations' — purely scientific, he assures you. He requires one willing soldier for a two-day assessment. Full pay. His personal guarantee of safe return.\n\nYour captain brings you the letter and says nothing. You have heard that the Legion lost three men to 'Pale Court medical studies' in the north. You have also heard that two of them came back stronger than before. The third one came back too, but he does not remember his wife's name.",
		"choices": [
			{
				"label":   "Allow it. Aldous gets your strongest soldier for two days.",
				"preview": "Pale Court +15  (strongest soldier unavailable 2 turns, all others -8 morale; 66% chance: +2 levels, 34% chance: amnesia — morale set to 25)",
				"effects": [
					{"type": "faction",              "target": "pale_court", "delta": 15},
					{"type": "pale_court_volunteer", "target": "",           "delta": 0},
				],
			},
			{
				"label":   "Refuse. Your soldiers are not test subjects.",
				"preview": "Pale Court -12, Army Morale +5",
				"effects": [
					{"type": "faction",           "target": "pale_court", "delta": -12},
					{"type": "all_soldier_morale","target": "",           "delta": 5},
				],
			},
		],
	},
	{
		"id":      "boran_personal_request",
		"title":   "Boran's Letter",
		"faction": "iron_legion",
		"trigger": {"min_iron_legion": 45, "min_dungeon_level": 3},
		"body":    "The letter has no Legion seal. It came through a private courier — a fisherman's boy, by the look of him.\n\n'I am writing this as Boran, not as the Warden. The armor began hurting me the night your men reached the third level. Not the slow ache I have learned to live with — sharper. As if something below is listening for something I am carrying.\n\nI am not asking you to stop for the Legion. I am asking you to slow down for me. Two weeks. Long enough for whatever is waking to forget the shape of what I wear.\n\nI have not asked anyone for anything in four years. I am asking now.'",
		"choices": [
			{
				"label":   "Honor his request. Pull back from levels 3+ for two weeks (2 turns).",
				"preview": "Iron Legion +20, Wardens +8",
				"effects": [
					{"type": "faction",       "target": "iron_legion", "delta": 20},
					{"type": "faction",       "target": "wardens",     "delta": 8},
					{"type": "legion_lockout","target": "",            "delta": 2},
				],
			},
			{
				"label":   "Write back with sympathy but continue. You cannot afford to stop.",
				"preview": "Iron Legion -5",
				"effects": [{"type": "faction", "target": "iron_legion", "delta": -5}],
			},
			{
				"label":   "Ignore the letter entirely.",
				"preview": "Iron Legion -15, Army Morale -4",
				"effects": [
					{"type": "faction",           "target": "iron_legion", "delta": -15},
					{"type": "all_soldier_morale","target": "",            "delta": -4},
				],
			},
		],
	},
	{
		"id":      "two_messengers",
		"title":   "The Same Gate, The Same Morning",
		"faction": "cross",
		"trigger": {"min_turn": 16, "min_wardens": 40, "min_iron_legion": 40},
		"body":    "They arrived within an hour of each other and neither one knows the other is waiting.\n\nIn the west courtyard: a Legion officer requesting that Otava be barred from your walls. 'She is inciting your workforce against legitimate regional authority,' he says. His tone is even. He has done this before.\n\nIn the east courtyard: Otava, requesting that the Legion officer be turned away. 'He is counting your dungeon soldiers and reporting to Boran,' she says. 'He has already sent two letters. I have read them.'\n\nBoth are probably right. You can only let one of them have what they want.",
		"choices": [
			{
				"label":   "Side with the Legion. Bar Otava from the city proper.",
				"preview": "Iron Legion +18, Wardens -22",
				"effects": [
					{"type": "faction", "target": "iron_legion", "delta": 18},
					{"type": "faction", "target": "wardens",     "delta": -22},
				],
			},
			{
				"label":   "Side with Otava. Turn the Legion officer away.",
				"preview": "Wardens +18, Iron Legion -22",
				"effects": [
					{"type": "faction", "target": "wardens",     "delta": 18},
					{"type": "faction", "target": "iron_legion", "delta": -22},
				],
			},
			{
				"label":   "Dismiss both. This is neutral ground and you answer to neither.",
				"preview": "Wardens -8, Iron Legion -8, Army Morale +8",
				"effects": [
					{"type": "faction",           "target": "wardens",     "delta": -8},
					{"type": "faction",           "target": "iron_legion", "delta": -8},
					{"type": "all_soldier_morale","target": "",            "delta": 8},
				],
			},
		],
	},
	{
		"id":      "pale_court_map_offer",
		"title":   "What He Already Knows",
		"faction": "pale_court",
		"trigger": {"min_dungeon_level": 3, "min_pale_court": 40},
		"body":    "The map Aldous sends is detailed enough to be disturbing. Levels four and five of your dungeon, drawn with architectural precision — room layouts, marked structural weaknesses, two locations circled in red with the notation 'mineral concentration, confirmed.'\n\nHe could not have drawn this from your reports. Either he has people who have been down there before you, or he has sources you have not identified.\n\n'I offer this freely,' the accompanying note reads, 'as a demonstration of the value of continued cooperation. In return — any red-veined stone your men bring to the surface. Standard sample weight. Nothing you would miss.'",
		"choices": [
			{
				"label":   "Accept. The map is worth more than the stone.",
				"preview": "Pale Court +14, Iron -8, Steel -4, Dungeon levels 4-5 revealed for your next 3 expeditions there",
				"effects": [
					{"type": "faction",                "target": "pale_court", "delta": 14},
					{"type": "resource",               "target": "iron",       "delta": -8},
					{"type": "resource",               "target": "steel",      "delta": -4},
					{"type": "dungeon_map_reveal_deep","target": "",           "delta": 0},
				],
			},
			{
				"label":   "Accept the map, agree to provide samples — and provide nothing.",
				"preview": "Pale Court -10  (Aldous will notice eventually), Dungeon levels 4-5 revealed for your next 3 expeditions there",
				"effects": [
					{"type": "faction",                "target": "pale_court", "delta": -10},
					{"type": "dungeon_map_reveal_deep","target": "",           "delta": 0},
				],
			},
			{
				"label":   "Decline everything. You do not want to know how he drew this map.",
				"preview": "Pale Court -10, Wardens +8",
				"effects": [
					{"type": "faction", "target": "pale_court", "delta": -10},
					{"type": "faction", "target": "wardens",    "delta": 8},
				],
			},
		],
	},
	{
		"id":      "pale_court_informant",
		"title":   "The Man in the Apothecary",
		"faction": "pale_court",
		"trigger": {"min_turn": 20, "max_pale_court": 45},
		"body":    "Your guard captain brings you a name: Petyr, a medicine merchant who has been in the city since the second month of reconstruction. Reliable. Friendly. Gives the soldiers good prices on salves.\n\nAlso, apparently, one of three Pale Court agents your captain has identified in the past week. He has been sending weekly reports — population counts, soldier names, dungeon depth, morale observations. He is very thorough.\n\nHe does not know that you know.",
		"choices": [
			{
				"label":   "Arrest him publicly. Make it clear to Aldous that you are watching.",
				"preview": "Pale Court -20, Army Morale -6, Wardens +5",
				"effects": [
					{"type": "faction",           "target": "pale_court", "delta": -20},
					{"type": "all_soldier_morale","target": "",           "delta": -6},
					{"type": "faction",           "target": "wardens",    "delta": 5},
				],
			},
			{
				"label":   "Turn him. Feed Aldous false information through the same channel.",
				"preview": "Pale Court +0 short-term  (Aldous won't notice for a while)",
				"effects": [],
			},
			{
				"label":   "Make an example of him. Poke his eye out and send Aldous a message — no spies, but information has a price.",
				"preview": "Pale Court -10, Army Morale +5",
				"effects": [
					{"type": "faction",           "target": "pale_court", "delta": -10},
					{"type": "all_soldier_morale","target": "",           "delta": 5},
				],
			},
		],
	},
]

# ---------------------------------------------------------------------------
# check_and_queue — called by GameState.end_turn() each turn
# ---------------------------------------------------------------------------
func check_and_queue() -> void:
	# Never stack events — if one is already waiting, don't queue another
	if not _pending.is_empty():
		return

	var turn: int       = GameState.current_turn
	var dlevel: int     = DungeonState.dungeon_level
	var wardens: int    = FactionState.wardens_standing
	var legion: int     = FactionState.iron_legion_standing
	var pale: int       = FactionState.pale_court_standing

	# Separate eligible events by priority: cross-faction first, then single-faction
	var cross_eligible: Array[Dictionary] = []
	var single_eligible: Array[Dictionary] = []

	for event: Dictionary in EVENTS:
		var event_id: String = event["id"]
		if _fired_ids.has(event_id):
			continue
		if not _check_trigger(event.get("trigger", {}), turn, dlevel, wardens, legion, pale):
			continue
		var faction: String = event.get("faction", "")
		if faction == "cross":
			cross_eligible.append(event)
		else:
			single_eligible.append(event)

	var pool: Array[Dictionary] = cross_eligible if not cross_eligible.is_empty() else single_eligible
	if pool.is_empty():
		return

	# Pick one at random from eligible pool
	var chosen: Dictionary = pool[randi_range(0, pool.size() - 1)]
	_pending.append(chosen)
	emit_signal("faction_event_ready", chosen)

func _check_trigger(trigger: Dictionary, turn: int, dlevel: int,
		wardens: int, legion: int, pale: int) -> bool:
	if trigger.has("min_turn") and turn < int(trigger["min_turn"]):
		return false
	if trigger.has("min_dungeon_level") and dlevel < int(trigger["min_dungeon_level"]):
		return false
	if trigger.has("min_wardens") and wardens < int(trigger["min_wardens"]):
		return false
	if trigger.has("min_iron_legion") and legion < int(trigger["min_iron_legion"]):
		return false
	if trigger.has("min_pale_court") and pale < int(trigger["min_pale_court"]):
		return false
	if trigger.has("max_pale_court") and pale > int(trigger["max_pale_court"]):
		return false
	return true

# ---------------------------------------------------------------------------
# resolve — called when the player picks a choice in the popup
# ---------------------------------------------------------------------------
func resolve(event_id: String, choice_index: int) -> void:
	# Remove from pending regardless of outcome
	for i in range(_pending.size() - 1, -1, -1):
		if _pending[i].get("id", "") == event_id:
			_pending.remove_at(i)

	# Find the event definition
	var event: Dictionary = {}
	for e in EVENTS:
		if e["id"] == event_id:
			event = e
			break

	if event.is_empty():
		return

	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return

	_apply_effects(choices[choice_index].get("effects", []))

	if event_id == "pale_court_volunteer" and choice_index == 0:
		var strongest: SoldierData = null
		for s in GameState.soldiers:
			if s.is_alive():
				if strongest == null or s.get_total_power() > strongest.get_total_power():
					strongest = s
		if strongest != null:
			strongest.unavailable_turns = 2
			for s in GameState.soldiers:
				if s.is_alive() and s != strongest:
					s.morale = clampi(s.morale - 8, 0, s.get_max_morale())
			if randf() < 0.66:
				strongest.level += 1
				strongest.xp_to_next_level = int(strongest.xp_to_next_level * 1.5)
			else:
				strongest.morale = 25
			GameState.emit_signal("soldiers_changed")

	_fired_ids.append(event_id)

# ---------------------------------------------------------------------------
# resolve_diplomacy_action — called by hub_screen when the player clicks a
# diplomacy button in the Story panel
# ---------------------------------------------------------------------------
func resolve_diplomacy_action(action_id: String) -> bool:
	var action: Dictionary = {}
	for a in DIPLOMACY_ACTIONS:
		if a["id"] == action_id:
			action = a
			break

	if action.is_empty():
		return false

	# Cooldown check
	if is_action_on_cooldown(action_id):
		return false

	# Per-turn action limit
	if not FactionState.can_use_diplomatic_action():
		return false

	# Affordability check
	var cost: Dictionary = action.get("cost", {})
	if not _can_afford(cost):
		return false

	# Deduct resources
	_deduct_cost(cost)

	# Apply effects
	_apply_effects(action.get("effects", []))

	FactionState.record_diplomatic_action_used()

	# Record cooldown — use current_turn BEFORE end_turn increments it,
	# so the cooldown expires after exactly ACTION_COOLDOWN_TURNS turns.
	_action_cooldowns[action_id] = GameState.current_turn

	GameState.emit_signal("resources_changed")
	return true

func _get_action_cooldown(action_id: String) -> int:
	for a in DIPLOMACY_ACTIONS:
		if a["id"] == action_id:
			return a.get("cooldown", ACTION_COOLDOWN_TURNS)
	return ACTION_COOLDOWN_TURNS

## Returns true when the action is unavailable due to cooldown.
func is_action_on_cooldown(action_id: String) -> bool:
	if not _action_cooldowns.has(action_id):
		return false
	var used_on: int = int(_action_cooldowns[action_id])
	return (GameState.current_turn - used_on) < _get_action_cooldown(action_id)

## Returns the number of turns remaining on a cooldown (0 = available).
func get_cooldown_remaining(action_id: String) -> int:
	if not _action_cooldowns.has(action_id):
		return 0
	var used_on: int = int(_action_cooldowns[action_id])
	var elapsed: int = GameState.current_turn - used_on
	return maxi(0, _get_action_cooldown(action_id) - elapsed)

## Resource costs an event choice would spend, as {ResourceName: amount}.
## Derived from its negative resource effects (e.g. delta -20 Gold -> 20 Gold).
func get_choice_resource_cost(choice: Dictionary) -> Dictionary:
	var costs: Dictionary = {}
	for e in choice.get("effects", []):
		if e.get("type", "") == "resource":
			var d: int = int(e.get("delta", 0))
			if d < 0:
				var res: String = _capitalize_resource(e.get("target", ""))
				costs[res] = costs.get(res, 0) - d
	return costs

## "Not enough Gold (have 5, need 20)" for the first unaffordable cost, else "".
func choice_afford_reason(choice: Dictionary) -> String:
	var costs: Dictionary = get_choice_resource_cost(choice)
	for res in costs:
		var have: int = GameState.get_resource_amount(res)
		var need: int = int(costs[res])
		if have < need:
			return "Not enough %s (have %d, need %d)" % [res, have, need]
	return ""

## Returns true when the action's prerequisite condition is satisfied (or there is none).
func is_action_requirement_met(action_id: String) -> bool:
	var action: Dictionary = {}
	for a in DIPLOMACY_ACTIONS:
		if a["id"] == action_id:
			action = a
			break
	var req: String = action.get("requires", "")
	if req.is_empty():
		return true
	match req:
		"dungeon_2":      return DungeonState.dungeon_level >= 2
		"wardens_60":     return FactionState.wardens_standing >= 60
		"iron_legion_60": return FactionState.iron_legion_standing >= 60
		"pale_court_40":  return FactionState.pale_court_standing >= 40
	return true

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
func _apply_effects(effects: Array) -> void:
	for effect in effects:
		var effect_type: String = effect.get("type", "")
		var target: String      = effect.get("target", "")
		var delta: int          = int(effect.get("delta", 0))
		match effect_type:
			"faction":
				match target:
					"wardens":     FactionState.change_wardens(delta)
					"iron_legion": FactionState.change_iron_legion(delta)
					"pale_court":  FactionState.change_pale_court(delta)
					_: pass
			"resource":
				GameState._apply_resource_delta(_capitalize_resource(target), delta)
				GameState.emit_signal("resources_changed")
			"all_soldier_morale":
				GameState.apply_army_morale(delta)
				GameState.emit_signal("soldiers_changed")
			"all_soldier_xp":
				for s in GameState.soldiers:
					if s.is_alive():
						s.experience += delta
						while s.experience >= s.xp_to_next_level:
							s.experience -= s.xp_to_next_level
							s.level += 1
							s.xp_to_next_level = int(s.xp_to_next_level * 1.5)
				GameState.emit_signal("soldiers_changed")
			"threat_percent":
				var increase := int(GameState.threat * float(delta) / 100.0)
				GameState.threat = clampi(GameState.threat + increase, 0, 150)
				GameState.emit_signal("threat_updated")
			"next_wave_difficulty":
				GameState.next_wave_difficulty_bonus = maxi(GameState.next_wave_difficulty_bonus, delta)
			"pale_court_gift_death_pending":
				GameState.pale_court_gift_death_pending = true
				GameState.call_deferred("_trigger_veil_death")
			"legion_garrison":
				GameState.legion_garrison_active = true
			"legion_solo_fight":
				GameState.legion_solo_fight_pending = true
			"warden_lockout":
				DungeonState.warden_lockout_turns = delta
			"legion_lockout":
				DungeonState.legion_lockout_turns = delta
			"dungeon_map_reveal_deep":
				DungeonState.dungeon_map_reveal_charges = DungeonState.MAP_REVEAL_EXPEDITIONS
			"pale_court_volunteer":
				pass
			_:
				pass

func _capitalize_resource(res: String) -> String:
	# GameState._apply_resource_delta expects "Gold", "Food", "Iron", "Steel", "Morale", etc.
	if res.is_empty():
		return res
	return res[0].to_upper() + res.substr(1)

func _can_afford(cost: Dictionary) -> bool:
	for resource in cost:
		var amount: int = int(cost[resource])
		match resource:
			"gold":  if GameState.gold  < amount: return false
			"food":  if GameState.food  < amount: return false
			"iron":  if GameState.iron  < amount: return false
			"steel": if GameState.steel < amount: return false
	return true

func _deduct_cost(cost: Dictionary) -> void:
	for resource in cost:
		var amount: int = int(cost[resource])
		GameState._apply_resource_delta(_capitalize_resource(resource), -amount)

# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------
func get_data_for_save() -> Dictionary:
	# Convert typed array to plain array for JSON serialization
	var fired_plain: Array = []
	for s in _fired_ids:
		fired_plain.append(s)
	return {
		"fired_ids":        fired_plain,
		"action_cooldowns": _action_cooldowns.duplicate(),
	}

func restore_from_save(data: Dictionary) -> void:
	_fired_ids.clear()
	_action_cooldowns.clear()
	_pending.clear()

	for s in data.get("fired_ids", []):
		_fired_ids.append(str(s))

	var cooldowns: Dictionary = data.get("action_cooldowns", {})
	for key in cooldowns:
		_action_cooldowns[str(key)] = int(cooldowns[key])
