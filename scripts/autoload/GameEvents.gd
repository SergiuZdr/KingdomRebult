# res://scripts/autoload/GameEvents.gd
# Autoload — owns the EVENTS catalog and all event resolution logic.
# GameState remains the source of truth for all resource/soldier/threat vars;
# this node reads and mutates them via GameState.varname references.
extends Node

const EVENT_CHANCE: float = 0.40

const EVENTS: Array = [
	{
		id = "wandering_merchant",
		faction = "",
		title = "Wandering Merchant",
		body = "A traveling merchant has stopped at the city gate, cart laden with goods. He passes through twice a year and has heard this city is on the mend. He is willing to trade at fair prices or, for a sweetener, share routes to markets further south.",
		requires = ["pale_court_40"],
		choices = [
			{
				label = "Buy his stock at fair prices.",
				preview = "+25 Gold",
				effects = [{"type": "resource", "target": "Gold", "delta": 25}],
			},
			{
				label = "Offer him a formal trade arrangement — pay more now, get his network later.",
				preview = "+15 Gold, Pale Court +5",
				effects = [
					{"type": "resource", "target": "Gold",        "delta": 15},
					{"type": "faction",  "target": "pale_court", "delta": 5},
				],
			},
			{
				label = "Turn him away. You do not need outside commerce yet.",
				preview = "No effect",
				effects = [],
			},
		],
	},
	{
		id = "good_harvest",
		faction = "",
		title = "Good Harvest",
		body = "Favorable weather has blessed the fields this season. The farmers are pleased, the granary is full, and the city smells, for once, more of bread than ash. Your steward suggests you could share the surplus or store it against leaner turns.",
		requires = ["farm_built"],
		choices = [
			{
				label = "Keep the surplus in the granary.",
				preview = "+25 Food",
				effects = [{"type": "resource", "target": "Food", "delta": 25}],
			},
			{
				label = "Distribute food to the workers and soldiers. Morale matters more than reserves.",
				preview = "+15 Food, Soldiers Morale +5",
				effects = [
					{"type": "resource",        "target": "Food", "delta": 15},
					{"type": "all_soldier_morale", "delta": 5},
				],
			},
			{
				label = "Send a portion to the Wardens as a gesture of goodwill.",
				preview = "+10 Food, Wardens +5",
				effects = [
					{"type": "resource", "target": "Food",    "delta": 10},
					{"type": "faction",  "target": "wardens", "delta": 5},
				],
			},
		],
	},
	{
		id = "found_supplies",
		faction = "",
		title = "Found Supplies",
		body = "Workers excavating the old eastern quarter turned up a sealed chamber — pre-war stores, dry and largely intact. Timber, cut stone, a few iron fittings. Whoever buried them expected to come back. They did not.",
		requires = [],
		choices = [
			{
				label = "Bring everything to the city stockpile.",
				preview = "+30 Wood, +10 Stone, +5 Iron",
				effects = [
					{"type": "resource", "target": "Wood",  "delta": 30},
					{"type": "resource", "target": "Stone", "delta": 10},
					{"type": "resource", "target": "Iron",  "delta": 5},
				],
			},
			{
				label = "Use the stone to reinforce the outer wall and take the timber.",
				preview = "+30 Wood, Iron +5, Walls +1",
				effects = [
					{"type": "resource", "target": "Wood", "delta": 30},
					{"type": "walls",                      "delta": 1},
					{"type": "resource", "target": "Iron", "delta": 4},
				],
			},
			{
				label = "Report the find to the Wardens — old sealed chambers may be their concern.",
				preview = "+15 Wood, Wardens +6",
				effects = [
					{"type": "resource", "target": "Wood",    "delta": 15},
					{"type": "faction",  "target": "wardens", "delta": 6},
				],
			},
		],
	},
	{
		id = "morale_boost",
		faction = "",
		title = "Inspiring Victory",
		body = "News of the prince's resilience has spread further than expected. A balladeer arrived this morning and has been singing in the square since dawn — crowds gather, workers leave the site briefly to listen. Your captain says the soldiers' morale is visibly up.",
		requires = ["waves_2"],
		choices = [
			{
				label = "Commission the balladeer and hold a small feast — spend gold to spend morale well.",
				preview = "Soldiers Morale +15, -25 Gold",
				effects = [
					{"type": "all_soldier_morale", "delta": 15},
					{"type": "resource", "target": "Gold", "delta": -25},
				],
			},
			{
				label = "Redirect workers back to the site — there is no time for songs.",
				preview = "Soldiers Morale +5",
				effects = [{"type": "all_soldier_morale", "delta": 5}],
			},
		],
	},
	{
		id = "king_gift",
		faction = "king_aldric",
		title = "Royal Dispatch",
		body = "A royal courier arrived with a sealed crate and a brief letter from the king's own hand: 'A small thing. Do not read into it.' Inside: coin and timber, enough to matter. He also included a commendation letter for your garrison commander.",
		requires = ["turn_5"],
		choices = [
			{
				label = "Accept the supplies gratefully.",
				preview = "+50 Gold, +50 Wood",
				effects = [
					{"type": "resource", "target": "Gold", "delta": 50},
					{"type": "resource", "target": "Wood", "delta": 50},
				],
			},
			{
				label = "Accept the supplies and share the commendation publicly — good for soldiers' morale.",
				preview = "+20 Gold, +40 Wood, Soldiers Morale +8",
				effects = [
					{"type": "resource",        "target": "Gold", "delta": 20},
					{"type": "resource",        "target": "Wood", "delta": 40},
					{"type": "all_soldier_morale", "delta": 8},
				],
			},
			{
				label = "Send half the coin back with a note that the city is managing.",
				preview = "+15 Gold, Soldiers Morale +10",
				effects = [
					{"type": "resource",        "target": "Gold", "delta": 15},
					{"type": "all_soldier_morale",                "delta": 10},
				],
			},
		],
	},
	{
		id = "bandit_raid",
		faction = "",
		title = "Bandit Raid",
		body = "Bandits struck the city outskirts overnight and made off with coin from the outer quartermaster's post. Your guards found the door broken and one man with a bruised jaw. The trail leads north into the woods. A fast pursuit party could recover some of the gold — but it would thin the wall.",
		requires = ["gold_gt_50"],
		choices = [
			{
				label = "Accept the loss. Chasing bandits is not worth weakening the wall.",
				preview = "-50 Gold",
				effects = [{"type": "resource", "target": "Gold", "delta": -50}],
			},
			{
				label = "Send soldiers to pursue them — recover what you can.",
				preview = "Soldiers engage the raiders. Gold recovered on victory.",
				lock_condition = "no_soldiers",
				lock_reason = "No soldiers available to send",
				effects = [],
				special_action = "raid_pursuit",
			},
			{
				label = "Send a patrol with Legion backing — recover everything and make an example.",
				preview = "-10 Gold, Iron Legion +5",
				lock_condition = "iron_legion_40",
				lock_reason = "Requires Iron Legion standing 40+ (Legion patrols cover the northern road)",
				effects = [
					{"type": "resource", "target": "Gold",   "delta": -10},
					{"type": "faction",  "target": "iron_legion", "delta": 5},
				],
			},
		],
	},
	{
		id = "crop_blight",
		faction = "",
		title = "Crop Blight",
		body = "A fungal blight has swept through the eastern fields, rotting a significant portion of stored grain. The farmers are shaken. Your steward lays out the options: take the loss quietly, impose rationing, or appeal to the Wardens — they have knowledge of land-sickness your scholars lack.",
		requires = ["food_gt_20", "farm_built"],
		choices = [
			{
				label = "Accept the loss and adjust quietly.",
				preview = "-20 Food",
				effects = [{"type": "resource", "target": "Food", "delta": -20}],
			},
			{
				label = "Impose rationing — hurt morale but preserve some reserve.",
				preview = "-10 Food, Soldiers Morale -8",
				effects = [
					{"type": "resource",        "target": "Food", "delta": -10},
					{"type": "all_soldier_morale", "delta": -8},
				],
			},
			{
				label = "Ask the Wardens for a remedy.",
				preview = "-5 Food, Wardens +5",
				lock_condition = "wardens_40",
				lock_reason = "Requires Wardens standing 40+ (they will not help strangers)",
				effects = [
					{"type": "resource", "target": "Food",    "delta": -5},
					{"type": "faction",  "target": "wardens", "delta": 5},
				],
			},
		],
	},
	{
		id = "fire",
		faction = "",
		title = "Workshop Fire",
		body = "A fire broke out in the lumber yard before dawn — a poorly banked forge, most likely. Half the seasoned timber stockpile is ash. No one died. Your workers are shaken.",
		requires = ["wood_gt_50"],
		choices = [
			{
				label = "Absorb the loss and continue.",
				preview = "-25 Wood",
				effects = [{"type": "resource", "target": "Wood", "delta": -25}],
			},
			{
				label = "Emergency resupply — pay the merchant rate.",
				preview = "-50 Gold",
				effects = [
					{"type": "resource", "target": "Gold", "delta": -50},
				],
			},
		],
	},
	{
		id = "desertion",
		faction = "",
		title = "Desertion",
		body = "The night watch found empty bunks before dawn. Soldiers whose spirit has broken entirely have slipped away — or are on the verge of it. The men who remain are watching to see what you do.",
		requires = ["soldiers_low_morale"],
		choices = [
			{
				label = "Let them go. Men who do not want to be here cannot be kept.",
				preview = "Deserters removed from army, remaining soldiers Morale -10",
				effects = [],
				special_action = "desertion_let_go",
			},
			{
				label = "Call in the Iron Legion — they will find the deserters and send them back. They will return next turn, but marked.",
				preview = "Deserters return next turn with Deserter trait (-6 POW, -6 SPD, morale capped at 80)",
				lock_condition = "iron_legion_60",
				lock_reason = "Requires Iron Legion standing Friendly (60+)",
				effects = [],
				special_action = "desertion_legion_retrieve",
			},
			{
				label = "Pay each loyal soldier 20 gold — loyalty deserves reward.",
				preview = "Cost: 20 Gold per remaining soldier, each gains Morale +5",
				effects = [],
				special_action = "desertion_pay_gold",
			},
		],
	},
	{
		id = "monster_scout",
		faction = "",
		title = "Monster Scouts Spotted",
		body = "Your wall watch spotted figures at the edge of the tree line — not human. They did not attack. They observed, then withdrew into the dark. Your captain says they were measuring the walls, timing the patrols. The next wave will come prepared.",
		requires = [],
		choices = [
			{
				label = "Reinforce the walls and wait. Let them come.",
				preview = "Threat +30",
				effects = [{"type": "threat", "delta": 30}],
			},
			{
				label = "Send the two strongest soldiers to scatter the scouts — they will return next turn.",
				preview = "Threat +15, 2 soldiers unavailable for 1 turn (auto-battle: difficulty 2-3)",
				lock_condition = "no_soldiers",
				lock_reason = "No soldiers available to send",
				effects = [],
				special_action = "scout_pursuit",
			},
			{
				label = "Hire the Wardens to neutralise the scouts — they know the wood.",
				preview = "Threat +10, -25 Gold",
				lock_condition = "wardens_40",
				lock_reason = "Requires Wardens standing 40+ (they will not work for you yet)",
				effects = [
					{"type": "threat",   "delta": 10},
					{"type": "resource", "target": "Gold", "delta": -25},
				],
			},
		],
	},
	{
		id = "refugees",
		faction = "",
		title = "Refugees Arrive",
		body = "A group of survivors from a burned village to the south have appeared at the gate. They have children with them. They ask only to shelter inside the walls. Your workers are watching to see what you do.",
		requires = [],
		choices = [
			{
				label = "Take them in — some will find work in the city.",
				preview = "Soldiers Morale +8, +2 Workers",
				lock_condition = "workers_at_max",
				lock_reason = "No housing available for more workers",
				effects = [
					{"type": "all_soldier_morale", "delta": 8},
					{"type": "workers",  "delta": 2},
				],
			},
			{
				label = "Feed them from your stores. They will move on after, but repay the kindness.",
				preview = " -10 Food, +20 Gold (they leave)",
				effects = [
					{"type": "resource", "target": "Food", "delta": -10},
					{"type": "resource", "target": "Gold", "delta": 20},
				],
			},
			{
				label = "Turn them away. You cannot feed more mouths.",
				preview = "Soldiers Morale -5",
				effects = [{"type": "all_soldier_morale", "delta": -5}],
			},
		],
	},
	{
		id = "strange_traveler",
		faction = "",
		title = "Strange Traveler",
		body = "A hooded figure passed through the city gate at dusk, bought nothing, spoke to no one, and left a small leather pouch at the guard post with no note. Inside: gold coins, old mint, pre-war. Your guard asks what to do with them.",
		requires = [],
		choices = [
			{
				label = "Keep the coin — whoever left it did not want it back.",
				preview = "+20 Gold",
				effects = [{"type": "resource", "target": "Gold", "delta": 20}],
			},
			{
				label = "Ask the Wardens if they recognise the mint — old coin has history.",
				preview = "+15 Gold, Wardens +4",
				effects = [
					{"type": "resource", "target": "Gold",    "delta": 15},
					{"type": "faction",  "target": "wardens", "delta": 4},
				],
			},
			{
				label = "The prince distributes the coin as a small gift to the soldiers.",
				preview = "Soldiers Morale +8",
				effects = [
					{"type": "all_soldier_morale", "delta": 8},
				],
			},
		],
	},
	{
		id = "iron_cache",
		faction = "",
		title = "Iron Cache Discovered",
		body = "A collapsed section of the old eastern wall has revealed a hidden cache of raw iron bars pre-war military stores, still serviceable. Your smith examines them and nods. They would feed the forge for weeks.",
		requires = ["iron_mine_built"],
		choices = [
			{
				label = "Bring the iron to the forge immediately.",
				preview = "+20 Iron , +20 Stone ",
				effects = [
					{"type": "resource", "target": "Iron", "delta": 20},
					{"type": "resource", "target": "Stone", "delta": 20}
					],
			},
			{
				label = "Split the cache — iron for the forge, stone chips for wall repair.",
				preview = "+12 Iron, Walls +1",
				effects = [
					{"type": "resource", "target": "Iron", "delta": 12},
					{"type": "walls",                       "delta": 1},
				],
			},
			{
				label = "Offer the surplus bars to the Iron Legion as a gesture.",
				preview = "+10 Iron, +20 Stone, Iron Legion +5",
				effects = [
					{"type": "resource", "target": "Iron",        "delta": 10},
					{"type": "resource", "target": "Stone",       "delta": 20},
					{"type": "faction",  "target": "iron_legion", "delta": 5},
				],
			},
		],
	},
	{
		id = "plague_warning",
		faction = "",
		title = "Plague Warning",
		body = "A traveling healer arrived at the gate with an urgent warning: a fever is moving north from burned settlements to the south. 'It travels with rats and wet cloth,' she said. 'You have a day, maybe two, before it reaches your walls.' Your soldiers are exposed.",
		requires = ["has_soldiers"],
		choices = [
			{
				label = "Pay for city-wide quarantine — seal the sick quarters, burn the grain sacks.",
				preview = "-30 Gold (soldiers protected)",
				effects = [{"type": "resource", "target": "Gold", "delta": -30}],
			},
			{
				label = "Leave it to chance. The men are tough and the city cannot stop.",
				preview = "All soldiers can lose up to 15 HP",
				effects = [],
				special_action = "plague_ignored",
			},
			{
				label = "Send word to the Pale Court — Aldous has contacts who know remedies.",
				preview = "-15 Gold, Pale Court +5",
				lock_condition = "pale_court_40",
				lock_reason = "Requires Pale Court standing 40+ (Aldous will not help strangers)",
				effects = [
					{"type": "resource", "target": "Gold",       "delta": -15},
					{"type": "faction",  "target": "pale_court", "delta": 5},
				],
			},
		],
	},
	{
		id = "mercenary_offer",
		faction = "",
		title = "Mercenary Offer",
		body = "A small company of veterans arrived at the city gate — five men and a woman, worn kit but clean weapons. Their leader said they were passing through and had heard this city was 'the kind of place that pays on time.' They offered their swords for the season at a flat rate.",
		requires = ["gold_gt_50", "soldiers_below_max"],
		choices = [
			{
				label = "Hire one of them. This city needs more swords.",
				preview = "-50 Gold, +1 experienced soldier (leaves after 8 turns)",
				effects = [],
				special_action = "hire_mercenary",
			},
			{
				label = "Decline. City's soldiers are more than enough to manage it's deffense.",
				preview = "Soldiers Morale +5",
				effects = [{"type": "all_soldier_morale", "delta": +5}],
			},
			{
				label = "Report their presence to the Iron Legion — they may be deserters.",
				preview = "Iron Legion +5, +20 Gold, Soldiers Morale -5",
				effects = [
					{"type": "faction",  "target": "iron_legion", "delta": 5},
					{"type": "resource", "target": "Gold",        "delta": 10},
					{"type": "all_soldier_morale", "delta": -5},

				],
			},
		],
	},
	{
		id = "collapsed_mine",
		faction = "",
		title = "Collapsed Mine Shaft",
		body = "Workers breached an old mine tunnel in the eastern ruins. The timbers are rotted, the shaft unstable — but the glint of iron ore is visible from the opening. Your foreman says it could be worked. Or it could come down on the first man in.",
		requires = ["iron_mine_built"],
		choices = [
			{
				label = "Send workers in now. The ore is worth the risk.",
				preview = "+20 Iron, +10 Stone (50% chance: -1 Worker)",
				effects = [],
				special_action = "mine_explore",
			},
			{
				label = "Seal it off safely and salvage the entrance stone.",
				preview = "+5 Stone",
				effects = [{"type": "resource", "target": "Stone", "delta": 5}],
			},
			{
				label = "Invite the Wardens to investigate — they know old underground spaces.",
				preview = "+10 Iron, Wardens +5",
				lock_condition = "wardens_30",
				lock_reason = "Requires Wardens standing 30+ (they will not help strangers underground)",
				effects = [
					{"type": "resource", "target": "Iron",    "delta": 10},
					{"type": "faction",  "target": "wardens", "delta": 5},
				],
			},
		],
	},
	{
		id = "spy_caught",
		faction = "",
		title = "Spy Caught",
		body = "Guards caught a figure in the warehouse district before dawn — no weapons, but a detailed sketch of the city's supply routes was found in their boot. They are not talking. Your captain gives you three options before the shift changes.",
		requires = [],
		choices = [
			{
				label = "Execute them publicly. Let whoever sent them know you are watching.",
				preview = "Threat -10, Pale Court -15",
				effects = [
					{"type": "threat",  "delta": -10},
					{"type": "faction", "target": "pale_court", "delta": -15},
				],
			},
			{
				label = "Interrogate them, then release with a warning. Information is worth more than an example.",
				preview = "Threat -20",
				effects = [{"type": "threat", "delta": -20}],
			},
			{
				label = "Hand them to the Iron Legion — let them deal with their own problems.",
				preview = "Iron Legion +8, Pale Court -8",
				effects = [
					{"type": "faction", "target": "iron_legion", "delta": 8},
					{"type": "faction", "target": "pale_court",  "delta": -8},
				],
			},
		],
	},
	{
		id = "old_war_monument",
		faction = "",
		title = "Old War Monument",
		body = "Workers uncovered a pre-war monument in the western quarter — names carved in basalt, soldiers from the last great war. It survived everything the city could not. Your captain stood in front of it for a long time before calling you over.",
		requires = [],
		choices = [
			{
				label = "Commission its full restoration. The city deserves to remember.",
				preview = "-30 Gold, Soldiers Morale +10",
				effects = [
					{"type": "resource",           "target": "Gold", "delta": -30},
					{"type": "all_soldier_morale", "delta": 10},
				],
			},
			{
				label = "Salvage it for materials — stone and iron do more good in the walls.",
				preview = "+20 Wood, +20 Stone, Soldiers Morale -8",
				effects = [
					{"type": "resource",           "target": "Wood",  "delta": 20},
					{"type": "resource",           "target": "Stone", "delta": 20},
					{"type": "all_soldier_morale", "delta": -8},
				],
			},
			{
				label = "Leave it untouched. It has survived this long without you.",
				preview = "oldiers Morale -4",
				effects = [{"type": "all_soldier_morale", "delta": -4}],
			},
		],
	},
	{
		id = "legion_deserter",
		faction = "iron_legion",
		title = "Iron Legion Deserter",
		body = "A man arrived at the gate before dawn with full Legion kit, no insignia. He said he had walked two days and was not going back. He was not asking for forgiveness, only work. Your captain says he is well-trained. The Legion will notice he is gone.",
		requires = [],
		choices = [
			{
				label = "Take him in. A trained soldier is a trained soldier.",
				preview = "Iron Legion -10, +1 experienced soldier",
				effects = [],
				special_action = "legion_deserter_shelter",
			},
			{
				label = "Turn him over to the Iron Legion. You cannot afford their suspicion.",
				preview = "Iron Legion +8",
				effects = [{"type": "faction", "target": "iron_legion", "delta": 8}],
			},
			{
				label = "Offer him civilian work — he can stay, but not as a soldier.",
				preview = "Iron Legion -4, +1 Worker",
				lock_condition = "workers_at_max",
				lock_reason = "No room for more workers",
				effects = [
					{"type": "faction", "target": "iron_legion", "delta": -4},
					{"type": "workers", "delta": 1},
				],
			},
		],
	},
	{
		id = "pale_court_tonic",
		faction = "pale_court",
		title = "Pale Court Tonic",
		body = "Aldous arrived carrying a small glass vial, sealed with black wax. 'For one worthy soldier,' he said. 'The formula is old. Results are reliable.' He left before you could ask what 'reliable' meant. The vial sits on your desk.",
		requires = ["has_soldiers", "pale_court_40"],
		choices = [
			{
				label = "Give it to your strongest soldier. Aldous rarely gives without reason.",
				preview = "Strongest soldier gains POW +3 permanently, Pale Court +5",
				effects = [],
				special_action = "pale_court_tonic_give",
			},
			{
				label = "Pay a physician to analyze it first — the tonic is consumed in the process.",
				preview = "-15 Gold, Pale Court +2",
				effects = [
					{"type": "resource", "target": "Gold",       "delta": -15},
					{"type": "faction",  "target": "pale_court", "delta": 2},
				],
			},
			{
				label = "Refuse it. Nothing from the Pale Court comes without cost.",
				preview = "Pale Court -5",
				effects = [{"type": "faction", "target": "pale_court", "delta": -5}],
			},
		],
	},
	# --- Faction events ---
	{
		id = "legion_tax_demand",
		faction = "iron_legion",
		title = "Legion Tax Demand",
		body = "An Iron Legion assessor arrived with a laminated copy of a regional compact: your city owes a tithe for 'peacekeeping services rendered in the surrounding territory.' Your steward confirms it is technically valid. The amount is not small.",
		requires = [],
		choices = [
			{
				label = "Pay in full. It is a debt and debts should be honored.",
				preview = "-60 Gold, Iron Legion +10",
				effects = [
					{"type": "resource", "target": "Gold",        "delta": -60},
					{"type": "faction",  "target": "iron_legion", "delta": 10},
				],
			},
			{
				label = "Negotiate — the compact is old and its terms are debatable.",
				preview = "-30 Gold, Iron Legion +3",
				effects = [
					{"type": "resource", "target": "Gold",        "delta": -30},
					{"type": "faction",  "target": "iron_legion", "delta": 3},
				],
			},
			{
				label = "Refuse outright. The city never signed this contract.",
				preview = "Iron Legion -15, Threat +15",
				effects = [
					{"type": "faction", "target": "iron_legion", "delta": -15},
					{"type": "threat",  "delta": 15},
				],
			},
		],
	},
	{
		id = "warden_forest_gift",
		faction = "wardens",
		title = "Warden Forest Gift",
		body = "A Warden scout left a cache at the city's eastern gate before dawn — timber from the deep wood, dried herbs and grain, and a carved stone talisman etched with old markings. No note. Otava's people do not explain their kindness.",
		requires = ["wardens_30"],
		choices = [
			{
				label = "Accept everything gratefully.",
				preview = "+25 Wood, +15 Food, Wardens +5",
				effects = [
					{"type": "resource", "target": "Wood",    "delta": 25},
					{"type": "resource", "target": "Food",    "delta": 15},
					{"type": "faction",  "target": "wardens", "delta": 5},
				],
			},
			{
				label = "Accept, but return half as a gesture of equal exchange.",
				preview = "+12 Wood, +8 Food, Wardens +12",
				effects = [
					{"type": "resource", "target": "Wood",    "delta": 12},
					{"type": "resource", "target": "Food",    "delta": 8},
					{"type": "faction",  "target": "wardens", "delta": 12},
				],
			},
			{
				label = "Accept the materials — then sell the talisman to Aldous.",
				preview = "+25 Wood, +15 Food, +20 Gold, Wardens -8, Pale Court +10",
				effects = [
					{"type": "resource", "target": "Wood",       "delta": 25},
					{"type": "resource", "target": "Food",       "delta": 15},
					{"type": "resource", "target": "Gold",       "delta": 20},
					{"type": "faction",  "target": "wardens",    "delta": -8},
					{"type": "faction",  "target": "pale_court", "delta": 5},
				],
			},
		],
	},
	{
		id = "pale_court_warehouse",
		faction = "pale_court",
		title = "Pale Court Warehouse",
		body = "Aldous arrived with a proposal — a small, secured warehouse inside the city walls for 'trade inventory.' He promises discretion. Your guards are less certain about what 'discretion' means when it comes from the Pale Court.",
		requires = ["pale_court_40"],
		choices = [
			{
				label = "Grant it. Aldous's goodwill is worth more than a warehouse.",
				preview = "Pale Court +12",
				effects = [{"type": "faction", "target": "pale_court", "delta": 12}],
			},
			{
				label = "Agree, but under strict conditions — guards posted, no locked rooms.",
				preview = "Pale Court +6",
				effects = [{"type": "faction", "target": "pale_court", "delta": 6}],
			},
			{
				label = "Refuse. Your walls are not Pale Court property.",
				preview = "Pale Court -10",
				effects = [{"type": "faction", "target": "pale_court", "delta": -10}],
			},
		],
	},
	{
		id = "legion_patrol_offer",
		faction = "iron_legion",
		title = "Legion Patrol Offer",
		body = "An Iron Legion officer arrived with a proposal: they will extend their patrol route to include the road leading to your city. Twice weekly, a column of soldiers will pass within hailing distance. 'Good for the region,' he said. The subtext was clear.",
		requires = ["iron_legion_40"],
		choices = [
			{
				label = "Accept. The patrols will discourage raiders and scouts.",
				preview = "Iron Legion +6, Threat -15",
				effects = [
					{"type": "faction", "target": "iron_legion", "delta": 6},
					{"type": "threat",  "delta": -15},
				],
			},
			{
				label = "Decline politely. You prefer to manage your own perimeter.",
				preview = "No effect",
				effects = [],
			},
			{
				label = "Accept, but ask for compensation — the road needs upkeep.",
				preview = "+25 Gold, Iron Legion -5",
				effects = [
					{"type": "resource", "target": "Gold",        "delta": 25},
					{"type": "faction",  "target": "iron_legion", "delta": -5},
				],
			},
		],
	},
	{
		id = "warden_apprentice",
		faction = "wardens",
		title = "Warden Apprentice",
		body = "A young Warden appeared at the gate this morning — no older than sixteen, carrying a carved staff and a letter from Otava. The letter says only: 'She needs to learn what cities are. Teach her.' She is waiting in the courtyard, watching everything.",
		requires = ["wardens_30"],
		choices = [
			{
				label = "Let her stay and observe freely.",
				preview = "Wardens +10, Soldiers Morale +3",
				effects = [
					{"type": "faction",           "target": "wardens", "delta": 10},
					{"type": "all_soldier_morale",                     "delta": 3},
				],
			},
			{
				label = "Put her to work — this city has no room for idle observers.",
				preview = "Wardens -8, +1 Worker",
				lock_condition = "workers_at_max",
				lock_reason = "No room for more workers",
				effects = [
					{"type": "faction",  "target": "wardens", "delta": -8},
					{"type": "workers",                       "delta": 1},
				],
			},
			{
				label = "Send her back to Otava with gifts and a kind word.",
				preview = "-20 Gold, Wardens +5",
				effects = [
					{"type": "resource", "target": "Gold",    "delta": -20},
					{"type": "faction",  "target": "wardens", "delta": 5},
				],
			},
		],
	},
	{
		id = "warden_burial_grounds",
		faction = "wardens",
		title = "Burial Grounds of the Old Guard",
		body = "A Warden elder approaches with a solemn request. A forgotten burial ground lies beneath one of your iron mines. She asks that you halt work there for a day and perform the proper rites — bread, silence, and a prayer to the earth. 'The dead remember those who honor them,' she says.",
		requires = ["wardens_30", "iron_mine_built"],
		choices = [
			{
				label = "Honor the rites. Halt the mine for one day.",
				preview = "-20 Food, Iron Mine loses 1 turn of production, Wardens +10",
				lock_condition = "iron_mine_has_workers",
				lock_reason = "Iron Mine must be built and have at least 1 worker assigned.",
				special_action = "warden_burial_rite",
			},
			{
				label = "Decline respectfully. The city needs iron.",
				preview = "Wardens -3",
				effects = [
					{"type": "faction", "target": "wardens", "delta": -3},
				],
			},
			{
				label = "Chase her off. Superstition has no place here.",
				preview = "Wardens -8",
				effects = [
					{"type": "faction", "target": "wardens", "delta": -8},
				],
			},
		],
	},
	{
		id = "pale_court_intel",
		faction = "pale_court",
		title = "Pale Court Intelligence",
		body = "Aldous stopped by with unusual urgency. A Pale Court informant inside the nearby monster warrens has marked the location of a staging area your next attackers will use. 'The information has a price,' he said, smiling. It always does.",
		requires = ["pale_court_40"],
		choices = [
			{
				label = "Buy the intelligence. Useful information saves lives.",
				preview = "-25 Gold, Threat -25, Pale Court +5",
				effects = [
					{"type": "resource", "target": "Gold",       "delta": -25},
					{"type": "threat",   "delta": -25},
					{"type": "faction",  "target": "pale_court", "delta": 5},
				],
			},
			{
				label = "Ignore it. Aldous's information always comes with strings.",
				preview = "No effect",
				effects = [],
			},
			{
				label = "Take the information and pass it to the Iron Legion instead.",
				preview = "Iron Legion +5, Pale Court -6, Threat -15",
				effects = [
					{"type": "faction", "target": "iron_legion", "delta": 5},
					{"type": "faction", "target": "pale_court",  "delta": -6},
					{"type": "threat",  "delta": -15},
				],
			},
		],
	},
]

# Called from GameState.end_turn() via _phase_events().
func _phase_events() -> void:
	if randf() > EVENT_CHANCE:
		return

	# Filter to events whose requires conditions are all satisfied.
	var eligible: Array = []
	for e in EVENTS:
		if _event_requirements_met(e):
			eligible.append(e)

	if eligible.is_empty():
		return

	var event: Dictionary = eligible[randi_range(0, eligible.size() - 1)]

	# Build a popup dict compatible with faction_event_popup.gd and route via deferred queue.
	var popup_event := {
		"id":      event.get("id", ""),
		"type":    "game_event",
		"faction": event.get("faction", ""),
		"title":   event.get("title", ""),
		"body":    event.get("body", ""),
		"choices": event.get("choices", []).duplicate(true),
	}
	GameState.game_event_popup_ready.emit(popup_event)

# Returns true when every condition in the event's "requires" array is satisfied.
func _event_requirements_met(event: Dictionary) -> bool:
	var reqs: Array = event.get("requires", [])
	for condition in reqs:
		match condition:
			"food_gt_0":         if GameState.food <= 0:                                          return false
			"food_gt_20":        if GameState.food <= 20:                                         return false
			"gold_gt_50":        if GameState.gold <= 50:                                         return false
			"wood_gt_50":        if GameState.wood < 50:                                          return false
			"has_soldiers":      if GameState.soldiers.size() <= 0:                               return false
			"workers_below_max": if GameState.workforce_total >= GameState.workforce_cap:          return false
			"dungeon_cleared":   if DungeonState.dungeon_level < 2:                               return false
			"iron_legion_40":    if FactionState.iron_legion_standing < 40:                       return false
			"wardens_30":        if FactionState.wardens_standing < 30:                           return false
			"pale_court_40":     if FactionState.pale_court_standing < 40:                        return false
			"farm_built":        if not GameState.is_building_built("Farm"):                      return false
			"iron_mine_built":   if not GameState.is_building_built("Iron Mine"):                 return false
			"waves_2":           if GameState.total_waves_won < 2:                                return false
			"turn_5":            if GameState.current_turn < 5:                                   return false
			"soldiers_below_max": if GameState.soldiers.size() >= GameState.max_soldiers:         return false
			"soldiers_low_morale":
				var _has_low: bool = GameState.soldiers.any(func(s): return s.is_alive() and s.morale < 10)
				if not _has_low: return false
	return true

# Called by hub_screen when the player picks a choice in a game event popup.
func resolve_game_event(event_id: String, choice_index: int) -> void:
	var event: Dictionary = {}
	for e in EVENTS:
		if e.get("id", "") == event_id:
			event = e
			break
	if event.is_empty():
		return

	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return

	var choice: Dictionary = choices[choice_index]
	if choice.get("lock_condition", "") != "" and _is_choice_locked(choice.get("lock_condition", "")):
		return

	# Special actions bypass normal effect processing.
	var special: String = choice.get("special_action", "")
	match special:
		"raid_pursuit":
			GameState.gold = maxi(0, GameState.gold - 20)
			GameState.emit_signal("resources_changed")
			GameState.raid_pursuit_triggered.emit()
			return
		"desertion_let_go":
			var deserters: Array = GameState.soldiers.filter(func(s): return s.is_alive() and s.morale < 10)
			for s in deserters:
				GameState.soldiers.erase(s)
				GameState.turn_recap.append("  %s deserted — gone for good." % s.soldier_name)
			for s in GameState.soldiers:
				if s.is_alive():
					s.morale = clampi(s.morale - 10, 0, s.get_max_morale())
			GameState.emit_signal("soldiers_changed")
			return
		"desertion_legion_retrieve":
			var deserters: Array = GameState.soldiers.filter(func(s): return s.is_alive() and s.morale < 10)
			for s in deserters:
				GameState.soldiers.erase(s)
				GameState.pending_deserter_return.append({soldier = s, turns_remaining = 1})
				GameState.turn_recap.append("  %s is being retrieved by the Iron Legion." % s.soldier_name)
			GameState.emit_signal("soldiers_changed")
			return
		"desertion_pay_gold":
			var alive: Array = GameState.soldiers.filter(func(s): return s.is_alive())
			var cost: int = alive.size() * 20
			GameState.gold = maxi(0, GameState.gold - cost)
			for s in alive:
				s.morale = clampi(s.morale + 5, 0, s.get_max_morale())
			GameState.emit_signal("resources_changed")
			GameState.emit_signal("soldiers_changed")
			return
		"plague_ignored":
			for _s in GameState.soldiers:
				if _s.is_alive():
					_s.hp_current = maxi(1, _s.hp_current - 15)
			GameState.emit_signal("soldiers_changed")
			return
		"hire_mercenary":
			var _merc_names := ["Daren", "Bolgon", "Svet", "Kravin", "Ulf", "Tomas", "Reld", "Mira", "Aldov"]
			var _merc := SoldierData.new()
			_merc.soldier_name = _merc_names[randi() % _merc_names.size()] + " (Merc)"
			_merc.soldier_class = "warrior"
			_merc.level = randi_range(1, 2)
			_merc.power = randi_range(12, 18)
			_merc.speed = randi_range(4, 8)
			_merc.dexterity = randi_range(4, 7)
			_merc.hp_max = randi_range(90, 115)
			_merc.hp_current = _merc.hp_max
			_merc.morale = randi_range(50, 70)
			_merc.xp_to_next_level = 100
			_merc.temp_soldier_turns = 8
			GameState.gold = maxi(0, GameState.gold - 50)
			GameState.soldiers.append(_merc)
			GameState.emit_signal("resources_changed")
			GameState.emit_signal("soldiers_changed")
			return
		"mine_explore":
			GameState.iron  = maxi(0, GameState.iron  + 20)
			GameState.stone = maxi(0, GameState.stone + 10)
			if randf() < 0.5 and GameState.workforce_total > 1:
				GameState.workforce_total    = maxi(1, GameState.workforce_total    - 1)
				GameState.workforce_available = maxi(0, GameState.workforce_available - 1)
				GameState.turn_recap.append("  A worker was injured in the mine shaft collapse.")
			GameState.emit_signal("resources_changed")
			return
		"legion_deserter_shelter":
			var _def_names := ["Edrak", "Vorn", "Castian", "Brek", "Halvard", "Oryn", "Maret"]
			var _def := SoldierData.new()
			_def.soldier_name = _def_names[randi() % _def_names.size()] + " (Defector)"
			_def.soldier_class = "warrior"
			_def.level = randi_range(2, 3)
			_def.power = randi_range(14, 20)
			_def.speed = randi_range(5, 9)
			_def.dexterity = randi_range(5, 8)
			_def.hp_max = randi_range(100, 130)
			_def.hp_current = _def.hp_max
			_def.morale = randi_range(40, 60)
			_def.xp_to_next_level = 100 + (_def.level - 1) * 50
			GameState.soldiers.append(_def)
			FactionState.change_iron_legion(-12)
			GameState.emit_signal("soldiers_changed")
			return
		"warden_burial_rite":
			GameState.building_workers["Iron Mine"] -= 1
			GameState.pending_iron_mine_worker_restore = true
			GameState.food = maxi(0, GameState.food - 20)
			FactionState.change_wardens(10)
			GameState.emit_signal("resources_changed")
			return
		"pale_court_tonic_give":
			var _strongest: SoldierData = null
			for _s in GameState.soldiers:
				if _s.is_alive():
					if _strongest == null or _s.get_total_power() > _strongest.get_total_power():
						_strongest = _s
			if _strongest != null:
				_strongest.power += 3
				GameState.turn_recap.append("  %s's power permanently increased by 3." % _strongest.soldier_name)
			FactionState.change_pale_court(5)
			GameState.emit_signal("soldiers_changed")
			return
		"scout_pursuit":
			GameState.threat = clampi(GameState.threat + 15, 0, 150)
			GameState.emit_signal("threat_updated")
			var available: Array = GameState.soldiers.filter(func(s): return s.is_alive() and s.unavailable_turns <= 0)
			available.sort_custom(func(a, b): return a.get_total_power() > b.get_total_power())
			var scouts: Array = available.slice(0, mini(2, available.size()))
			for s in scouts:
				s.unavailable_turns = 1
			var wave: Array = EnemyData.make_random_wave(randi_range(2, 3))
			var enemies: Array = wave.slice(0, mini(4, wave.size()))
			var result: Dictionary = DungeonState.auto_resolve_city_defense(scouts, enemies)
			result["scout_names"] = scouts.map(func(s): return s.soldier_name)
			result["wave_source"] = "Monster Scouts"
			GameState.last_scout_combat_result = result
			GameState.scout_combat_result_ready.emit(result)
			GameState.emit_signal("soldiers_changed")
			return

	for effect in choice.get("effects", []):
		var effect_type: String = effect.get("type", "")
		var delta: int = int(effect.get("delta", 0))
		match effect_type:
			"resource":
				var target: String = effect.get("target", "")
				GameState._apply_resource_delta(target, delta)
			"workers":
				# Grant workers up to cap — same logic as recruit_worker but free.
				var space: int = GameState.workforce_cap - GameState.workforce_total
				var granted: int = mini(delta, space)
				if granted > 0:
					GameState.workforce_total += granted
					GameState.workforce_available += granted
					GameState.emit_signal("resources_changed")
			"faction":
				var target: String = effect.get("target", "")
				match target:
					"wardens":     FactionState.change_wardens(delta)
					"iron_legion": FactionState.change_iron_legion(delta)
					"pale_court":  FactionState.change_pale_court(delta)
			"threat":
				GameState.threat = clampi(GameState.threat + delta, 0, 150)
				GameState.emit_signal("threat_updated")
			"threat_rate":
				GameState.threat_gain_rate = maxi(1, GameState.threat_gain_rate + delta)
				GameState.emit_signal("threat_updated")
			"all_soldier_morale":
				GameState.apply_army_morale(delta)
				GameState.emit_signal("soldiers_changed")
			"walls":
				GameState.reinforce_walls(delta)
	GameState.emit_signal("resources_changed")

func _is_choice_locked(condition: String) -> bool:
	match condition:
		"iron_legion_40": return FactionState.iron_legion_standing < 40
		"iron_legion_60": return FactionState.iron_legion_standing < 60
		"wardens_30":     return FactionState.wardens_standing < 30
		"wardens_40":     return FactionState.wardens_standing < 40
		"pale_court_40":  return FactionState.pale_court_standing < 40
		"iron_mine_has_workers": return not GameState.is_building_built("Iron Mine") or GameState.building_workers.get("Iron Mine", 0) <= 0
		"gold_100":       return GameState.gold < 100
		"dungeon_3":      return DungeonState.dungeon_level < 3
		"no_soldiers":    return GameState.soldiers.size() <= 0
		"workers_at_max": return GameState.workforce_total >= GameState.workforce_cap
	return false
