# StoryManager.gd — autoload
# Delivers lore letters from King Aldric and NPCs based on gameplay milestones.
# Each letter is also surfaced as an interactive popup event with choices.
extends Node

signal new_letter_received(letter: Dictionary)
signal story_event_popup_ready(event: Dictionary)

var letters: Array[Dictionary] = []
var _sent_milestone_ids: Array[String] = []
var _morale_low_sent: bool = false

const LETTER_CONTENT: Dictionary = {
	"turn_1": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "When you read this",
		"body": "My son,\n\nBy the time these words reach you, you will have seen the walls. I know what they look like. I rode through that gate once, when it still had a gate. Do not let the silence frighten you — silence can be worked with. It is the screaming that breaks men.\n\nI would have come. My knees would not let me, and my council would not let my knees. So I send you, which is worse, and I will carry that.\n\nDo not try to be me there. Be patient. Listen to the old ones before you listen to the maps. A ruin remembers more than a scribe.\n\nEat. Sleep when you can. The crown can wait a night.\n\nYour father,\nAldric",
	},
	"first_building_rebuilt": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "One stone at a time",
		"body": "My son,\n\nWord came that a roof stands again under your hand. A small thing, the heralds said. They are fools. The first roof is never small.\n\nNow listen. Men who work without rest grow into men who work without thinking, and a city of tired men is a city that burns twice. Feed them before you feed yourself. Pay them in coin if you have it, in bread if you do not, in honest words if you have neither.\n\nA worker who trusts you will lift a beam two men could not. Remember that before you remember any law I taught you.\n\nThe summer here is dry. The orchards are thin. Do not send for grain yet — I will know when you need to ask.\n\nYour father,\nAldric",
	},
	"first_combat_victory": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "You are still breathing",
		"body": "My son,\n\nThey told me there was blood at the wall. They told me afterward that it was not yours. I made them say it twice.\n\nA first fight is a strange thing. You will feel taller for a week and then you will not sleep for a month. Both are normal. Drink water. Do not drink wine alone.\n\nWhatever came at you first was the smallest thing the dark had to spare. The next will be larger, and the one after that will have learned from the last. Build your watches now, while you still have the hands to spare. Walls are cheaper than widows.\n\nI am proud. I will not write it twice, so read it slowly.\n\nYour father,\nAldric",
	},
	"turn_5": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "A short question",
		"body": "My son,\n\nFive turns of the moon, and the road between us has not grown shorter. Forgive an old man for counting.\n\nTell me of your stores. Grain, salt, iron — the unromantic things. A prince who knows his granary by the sack outlives a prince who knows his banner by the thread. I taught you that once. I will teach you again until one of us is finished.\n\nAre you eating. Write the answer plainly. Do not dress it up for me, I have read enough dressed-up letters to last a reign.\n\nThe hound you raised has gone deaf in one ear. He still sits at the door each evening. I think he is waiting for the wrong man, but I let him wait.\n\nYour father,\nAldric",
	},
	"wave_3_survived": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "Commander",
		"body": "My son,\n\nThree waves. Three. I have generals in this castle who have not held a line three times in a season, and they wear more steel than sense.\n\nI will speak to you now as I speak to the men who hold my borders. Your decisions are yours. I will not second-guess a captain from four hundred leagues away — that is how good captains are lost.\n\nTrust the ones who stood beside you in the third wave more than the ones who counsel you between them. Battle reveals loyalty in a way feasts never will.\n\nKeep a list of the dead. Read it on quiet nights. A commander who forgets the cost becomes the cost.\n\nYour father,\nAldric",
	},
	"city_morale_low": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "Look at their faces",
		"body": "My son,\n\nI hear the streets are quiet in the wrong way. Do not write back to deny it. I have ears that do not lie to me, and I would not insult you by pretending otherwise.\n\nA king who lets his people sink learns later that he was standing on them. You are not tired enough yet to be excused. There are men in your walls who have buried more than you have ever owned, and they still rose this morning. Match them.\n\nWalk the city. Be seen. Eat at a common table, not your own. Listen to one drunkard's complaint all the way through. It costs nothing and it buys more than gold.\n\nSpirit is a harvest. You sow it daily or you starve.\n\nYour father,\nAldric",
	},
	"first_dungeon_complete": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "What you brought up",
		"body": "My son,\n\nYour men came back. Most of them. I am told you sent them down and not yourself, and for that small mercy I will not write the letter I had begun.\n\nI do not like the deep places. No king who has read his own histories does. What is buried was buried by someone, and that someone usually had reasons we are too late to ask.\n\nIf you must send them down again — and I suspect you must — send them rested, send them paid, and send them with someone who can count the steps back. A man who knows the way out fights twice as well as a man who does not.\n\nWhatever you found, do not wear it until I have seen it.\n\nYour father,\nAldric",
	},
	"turn_10": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "I have seen the smoke",
		"body": "My son,\n\nI have scouts on the ridge above you. I will not pretend otherwise any longer. They have watched you these ten turns, and what they bring back I read twice and then burn.\n\nThere is smoke from chimneys now. Not from fires. From hearths. Do you understand the difference an old man feels in that.\n\nWhen I sent you, I did not know if I was sending a son to a grave or to a throne of his own making. I tell you now, plainly, because I am running short of the years in which to tell you anything plainly — I was wrong to doubt which it would be.\n\nThe winters here are colder than they used to be. Or I am. Likely both.\n\nCome home one day. Not yet. But one day.\n\nYour father,\nAldric",
	},
	"turn_15": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "Before the cold",
		"body": "My son,\n\nThe air on the north wall has changed this week. The hounds know it before the men do. Winter is coming earlier than the almanacs swore it would, and the almanacs have not been honest with me in years.\n\nI am putting a caravan together against the spring. Salt pork, oil, seed grain, wool. Practical things. It will not move until the roads clear — only a fool sends carts into a mountain winter, and I have buried enough fools. Do not count on it before the thaw. Plan as though it will not come, and be glad when it does.\n\nMy scouts return more slowly now. Two have not returned at all. I am told the roads are bad. I am told many things. I am keeping a quiet ledger of what I am told versus what I am shown.\n\nWhatever stores you have, stretch them. A city that eats as though help is coming is a city that starves the week before it does.\n\nKeep warm. Keep watch.\n\nYour father,\nAldric",
	},
	"turn_20": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "The Iron Legion has noticed you",
		"body": "My son,\n\nA word, and not a pleasant one. The Iron Legion has been asking after your city. Not loudly. Quietly, which is worse. Quiet questions are the kind a man asks before he draws a map he intends to use.\n\nThe Legion does not ride out for ruined cities. They do not waste a column on rubble. If they are circling you, it is because something there is worth a column. You know your own ground better than I do — ask yourself what they could possibly want from it.\n\nI will say this once, and you will not like it. Do not refuse them at the gate. Do not invite them through it either. Stand on the threshold and make them speak first. Whatever they ask for, they have wanted longer than they will admit.\n\nIf an officer comes in white plate, send word the same day. The same day, Edric.\n\nYour father,\nAldric",
	},
	"turn_25": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "A small letter",
		"body": "My son,\n\nForgive the hand. The scribe offered to copy this for me and I sent him out. Some words must be in a man's own ink, even when the ink wanders.\n\nI am well. The physicians fuss. I tell them what I told my father's physicians and they look at me as if I am a child who does not understand his own bones. Perhaps I am. The bones are older than the boy who lives in them.\n\nTell me — and answer plainly, I am too tired for ornament — have you heard strange things from below. From under the stones. From the wells, from the deep places your men go down into. Do not write yes to please me. Do not write no to spare me. Write what is true.\n\nI ask because of an old book I have begun reading again. A book I should have read more carefully thirty years ago.\n\nYour father,\nAldric",
	},
	"turn_30": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "What I did not tell you",
		"body": "My son,\n\nI knew. Read that line again before you read any other.\n\nI knew about the Veiled. I knew what sleeps beneath that city. I knew before I sent you there, and I sent you anyway, and there is no soft word in any language that makes that an honest thing.\n\nMy own father showed me the book when I was younger than you are now. He told me that one day a son of our house would have to stand above the Sevet again. He hoped it would not be his. He hoped it would not be mine. We are very good, in this family, at hoping a thing onto the next man.\n\nI told myself I was sending a prince to rebuild a city. I told the council the same. I have lived with that lie for two years and it has eaten more of me than the physicians have.\n\nThe truth is smaller and worse. I sent you because I believed you would not break. Not because you were ready. Because you were the one I could not bear to watch break here, under my own roof, where I would have to look at it every morning.\n\nForgive me, or do not. Both are within your right. But do not stop. Whatever is under those stones, it has waited longer than our line has held the crown. It will not wait kindly.\n\nI love you. I should have said it on the day you rode out. I am saying it now, in case the days remaining to me will not stretch to another letter.\n\nYour father,\nAldric",
	},
	"dungeon_level_2": {
		"sender": "Otava of the Wardens",
		"sender_tag": "wardens",
		"subject": "You Have Gone Too Deep",
		"body": "Boy,\n\nI came to your gate two mornings past. Your guards did not know my face. They were not wrong to turn me away. I was not angry. I am leaving this with a salt merchant who owes me a kindness.\n\nYour men came up from the first level alive. Good. I felt them go down. I felt them come back. The stone there still echoes the way ruins echo. That is why they came back.\n\nGo deeper and it changes. The next level down does not echo like a ruin. It echoes the way a room echoes when someone is still standing in it. Those will not be ruins, child. Those rooms are still occupied, and the ones who occupy them have been patient a long time. Patience is not peace. Learn that word before you learn any other from me.\n\nVeliv. Say it out loud once. In the Warden tongue it means the weight of listening. You have not listened yet. You have only dug.\n\nDo not send them down again before you understand what you are sending them into. I am near your walls. I will be near them for some days yet. If you want to understand, find me. I am not hard to find for a boy who is looking. I am only hard to find for one who is not.\n\nThe step is yours, child. It always was.\n\nOtava",
	},
	"dungeon_level_3": {
		"sender": "Otava of the Wardens",
		"sender_tag": "wardens",
		"subject": "The Sevet Is Stirring",
		"body": "Boy,\n\nI am inside your walls. Do not ask how. Do not send men to look. If I wanted to be found I would stand in your square.\n\nYour men reached the second level. I felt the Sevet stir. The Seal is not broken. Hear me — not broken. But it has begun to wake, and a thing that was asleep yesterday is half-awake today. Go one level deeper, to the third, and it will know you. It will know the shape of your boots, the weight of your torches, the names you call each other in the dark. That is what awake means, and you do not want it awake.\n\nMy people have held this Seal for longer than your house has held its crown. We cannot hold it alone any longer. We are too few. The last shaman before me was my mother and she went into the ground with half the words still in her mouth.\n\nI am not asking permission anymore, child. I am telling you. Do not let your men touch the third level until you and I have spoken. I am inside your walls and I will stay a while longer. Send word that you are ready to listen, and I will come to you. Otra holds while you decide. It does not hold forever.\n\nCome to it honest, or do not come at all. That much is yours to choose.\n\nOtava",
	},
	"wave_5_survived": {
		"sender": "Boran, Warden of the Iron Legion",
		"sender_tag": "iron_legion",
		"subject": "A Warning, Not a Threat",
		"body": "Prince Edric,\n\nThe Legion has watched your excavations for some time. Longer than you have been counting. The Warden writes this himself, so you understand it is not a clerk's letter.\n\nWe have an interest in what lies below your city. The interest is older than your reign and older than mine. I will not explain it here. A letter is the wrong place for that kind of explaining.\n\nStop the deep expeditions. Pull your men back to the upper levels. Do this within the month, or the Legion will ensure stability by other means. I will not pretend that phrase is gentle. It is not meant to be.\n\nYou have held five waves. The Warden noted this. Five is not common. There is, in this letter, a respect that the Legion as a body would not permit me to write down. I am writing it anyway.\n\nThis is not what I would choose. But I am not what chooses.\n\nBoran, son of Tudor\nWarden of the Iron Legion",
	},
	"first_dungeon_level_5": {
		"sender": "Boran, Warden of the Iron Legion",
		"sender_tag": "iron_legion",
		"subject": "We Need to Talk",
		"body": "Prince Edric,\n\nThis letter is not from the Legion. The Legion did not see it written and will not see it sent. A man I trust will put it in your hand.\n\nSince your men reached the fifth level, the armor has been hurting me in a way it did not hurt before. Not the slow hurt I am used to — a sharper thing, as if it is listening for something that is closer now than it has been in years. I do not sleep. The murmur in my chest speaks faster.\n\nI think you may know something that could help me. Not save me. I am past saving and I have made my peace with the road my feet are on. But you have stood in rooms I have not been allowed near, and you have come back, and you have come back twice.\n\nI would speak with you. Not as Warden and Prince. As two men who would rather not be what they are.\n\nThe man who carries this letter knows how to reach me without the Legion knowing. Send word through him when you are willing. I am not going far. The armor will not let me.\n\nWhen you are ready is when we speak. Not before. I have waited longer than this for less.\n\nI would like, before the end, to be called Boran by one person who is not afraid of me.\n\nBoran",
	},
	"turn_8_vintila": {
		"sender": "Aldous, of the Pale Court",
		"sender_tag": "pale_court",
		"subject": "A Proposition of Mutual Benefit",
		"body": "Your Highness,\n\nPray forgive the intrusion. I am Aldous, commercial representative of the Pale Court, and I write with the warmest regards of the Court and its principals, who have followed the remarkable progress of your reconstruction with no small degree of admiration.\n\nThe Court is, as you may know, an institution of considerable resource and refined taste. We have found, over the years, that proximity to ambitious men tends to reward all parties. We would be most pleased to extend certain courtesies — goods, introductions, perhaps a modest sum to ease the burden of rebuilding — as a gesture of goodwill, asking nothing in return but the pleasure of your acquaintance.\n\nI am already in the region on other business. A brief audience, whenever it suits Your Highness, would be a delight.\n\nOne small matter, purely out of professional curiosity — my principals have heard rumours of unusual stone in the deeper excavations. Red-veined, they say, almost luminous. Surely nothing of consequence to a prince engaged in grander work. Still, if your diggers have turned up anything of that description, I would be most grateful to know of it. For the purposes of, shall we say, accurate cartography.\n\nYours with the deepest esteem,\n\nAldous\nCommercial Representative, the Pale Court",
	},
	"kings_return": {
		"sender": "King Aldric",
		"sender_tag": "king_aldric",
		"subject": "I am coming",
		"body": "My son,\n\nI am coming.\n\nNot in a season. Not when the roads clear. I am coming now, with what I can gather in a week, and I am done waiting for a better time because I have learned — too late, in the way old men learn things — that there is no better time. There is only time, and what you choose to do with it.\n\nYou rebuilt it. I did not believe you would, and I am ashamed of that, and I am telling you because you deserve to know. A prince who rebuilds from nothing deserves at least the honest account of his father’s doubt.\n\nSend word of which road is safest. Keep your men ready — I do not travel quietly, and what follows me will have noticed I am moving. One last battle, if the road is honest with me, and then I will walk through your gate.\n\nHold until I arrive.\n\nYour father,\nAldric",
	},
}

func check_milestones() -> void:
	_try_deliver("turn_1", GameState.current_turn == 1)
	_try_deliver("turn_5", GameState.current_turn == 5)
	_try_deliver("turn_8_vintila", GameState.current_turn >= 8)
	_try_deliver("turn_10", GameState.current_turn == 10)
	_try_deliver("turn_15", GameState.current_turn >= 15)
	_try_deliver("turn_20", GameState.current_turn >= 20)
	_try_deliver("turn_25", GameState.current_turn >= 25)
	_try_deliver("turn_30", GameState.current_turn >= 30)
	_try_deliver("dungeon_level_2", DungeonState.dungeon_level >= 3)
	_try_deliver("dungeon_level_3", DungeonState.dungeon_level >= 5)
	_try_deliver("first_dungeon_level_5", DungeonState.dungeon_level >= 5)
	_try_deliver("wave_5_survived", GameState.total_waves_won >= 5 and DungeonState.dungeon_level >= 3)
	_try_deliver("kings_return",
		GameState.win_condition_triggered
		and GameState._win_letter_turn >= 0
		and GameState.current_turn >= GameState._win_letter_turn)
	var _living := GameState.soldiers.filter(func(s): return s.hp_current > 0)
	var _sum_morale := 0
	for _s in _living:
		_sum_morale += _s.morale
	@warning_ignore("INTEGER_DIVISION")
	var _avg_morale := _sum_morale / _living.size() if not _living.is_empty() else 100
	if _avg_morale < 30 and not _morale_low_sent:
		if _try_deliver("city_morale_low", true):
			_morale_low_sent = true

func check_first_building_rebuilt() -> void:
	_try_deliver("first_building_rebuilt", true)

func check_first_combat_victory() -> void:
	_try_deliver("first_combat_victory", true)

func check_first_dungeon_complete() -> void:
	_try_deliver("first_dungeon_complete", true)

func check_wave_3_survived() -> void:
	_try_deliver("wave_3_survived", DungeonState.dungeon_level >= 2)

func mark_read(letter_id: String) -> void:
	for letter in letters:
		if letter.id == letter_id:
			letter.read = true
			return

func mark_all_read() -> void:
	for letter in letters:
		letter.read = true

func get_unread_count() -> int:
	var count := 0
	for letter in letters:
		if not letter.read:
			count += 1
	return count

# ---------------------------------------------------------------------------
# Save / load
# ---------------------------------------------------------------------------
func get_letters_for_save() -> Array:
	return letters.duplicate(true)

func restore_from_save(data: Array, morale_low_sent: bool) -> void:
	letters.clear()
	_sent_milestone_ids.clear()
	for d in data:
		letters.append(d)
		_sent_milestone_ids.append(d.get("id", ""))
	_morale_low_sent = morale_low_sent

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------
func _try_deliver(milestone_id: String, condition: bool) -> bool:
	if not condition:
		return false
	if milestone_id in _sent_milestone_ids:
		return false
	if not LETTER_CONTENT.has(milestone_id):
		return false
	_deliver_letter(milestone_id)
	return true

func _deliver_letter(milestone_id: String) -> void:
	var content: Dictionary = LETTER_CONTENT[milestone_id]
	var letter := {
		"id": milestone_id,
		"sender": content.get("sender", ""),
		"sender_tag": content.get("sender_tag", ""),
		"subject": content.get("subject", ""),
		"body": content.get("body", ""),
		"turn_received": GameState.current_turn,
		"read": false
	}
	letters.append(letter)
	_sent_milestone_ids.append(milestone_id)
	emit_signal("new_letter_received", letter)

	# Build popup event dict and queue it for display
	var popup_event := {
		"id": milestone_id,
		"type": "story",
		"faction": content.get("sender_tag", ""),
		"title": content.get("subject", ""),
		"body": content.get("body", ""),
		"choices": [{"label": "Close", "preview": ""}],
	}
	emit_signal("story_event_popup_ready", popup_event)
