# res://scripts/autoload/SFX.gd
# Sound-effects manager (autoload). Plays short one-shots from a pool of players
# so they can overlap. Auto-attaches a click to every Button in the game, and
# listens to combat for hit/miss sounds. Missing files are silently skipped.
extends Node

const VOLUME_DB: float = -7.0
const POOL_SIZE: int = 12
const PITCH_VARIANCE: float = 0.06   # slight random pitch so repeats don't feel robotic
const SFX_DIR: String = "res://assets/audio/sfx/"

# Logical name → candidate files under assets/audio/sfx/. For multi-file keys
# (combat_hit/miss) a random one plays for variety; for the rest the first
# existing file wins (see PREFER_FIRST), so a drop-in custom file takes priority.
# To add/replace a sound, just drop a file named like the first candidate.
const SOUNDS: Dictionary = {
	# core UI & economy
	"ui_click":    ["interface/click.wav"],
	"worker_tick": ["worker_tick.wav", "worker_tick.ogg", "worker_tick.mp3"],
	"coin":        ["rpg/handle_coins.wav"],
	"build":       ["build.wav", "build.ogg", "build.mp3"],
	# combat
	"combat_hit":  ["battle/hit1.wav", "battle/hit2.wav", "battle/hit3.wav", "battle/hit4.wav", "battle/hit5.wav"],
	"combat_miss": ["battle/swing1.wav", "battle/swing2.wav", "battle/swing3.wav", "battle/swing4.wav", "battle/swing5.wav"],
	"skill_cast":  ["skill_cast.wav", "skill_cast.ogg", "skill_cast.mp3", "battle/hit1.wav", "battle/hit2.wav"],
	"wall_lost":   ["impact/wall_colapse.wav"],
	"victory":     ["victory.wav", "victory.ogg", "victory.mp3"],
	"defeat":      ["defeat.wav", "defeat.ogg", "defeat.mp3"],
	# event cues — drop a file named like the key into assets/audio/sfx/ to enable
	"end_turn":    ["end_turn.wav", "end_turn.ogg", "end_turn.mp3", "interface/click.wav"],
	"wave_alarm":  ["wave_alarm.wav", "wave_alarm.ogg", "wave_alarm.mp3"],
	"level_up":    ["level_up.wav", "level_up.ogg", "level_up.mp3"],
	"letter":      ["letter.wav", "letter.ogg", "letter.mp3"],
	"denied":      ["denied.wav", "denied.ogg", "denied.mp3"],
}

# Keys whose candidates are tried in order (first existing file wins) instead of
# randomly — so a custom drop-in file always takes priority over any fallback.
const PREFER_FIRST: Array = [
	"worker_tick", "build", "defeat", "victory", "skill_cast",
	"end_turn", "wave_alarm", "level_up", "letter", "denied",
]

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}   # absolute path → AudioStream


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # e.g. Resume click while paused
		add_child(p)
		_pool.append(p)

	# Click on every button, present and future.
	get_tree().node_added.connect(_on_node_added)

	# Combat feedback.
	if CombatState.has_signal("unit_acted"):
		CombatState.unit_acted.connect(_on_unit_acted)
	if CombatState.has_signal("combat_ended"):
		CombatState.combat_ended.connect(_on_combat_ended)
	if CombatState.has_signal("dungeon_combat_ended"):
		CombatState.dungeon_combat_ended.connect(_on_combat_ended)
	if CombatState.has_signal("spectator_combat_ended"):
		CombatState.spectator_combat_ended.connect(_on_combat_ended)

	# Narrative: a letter arrives.
	if StoryManager.has_signal("new_letter_received"):
		StoryManager.new_letter_received.connect(func(_letter): play("letter"))


# Play a registered sound by logical name.
func play(key: String) -> void:
	var paths: Array = SOUNDS.get(key, [])
	if paths.is_empty():
		return
	var stream: AudioStream = null
	if key in PREFER_FIRST:
		# First existing candidate wins (custom drop-in over fallback).
		for p in paths:
			stream = _load_cached(SFX_DIR + p)
			if stream != null:
				break
	else:
		stream = _load_cached(SFX_DIR + paths[randi() % paths.size()])
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	p.play()


func _load_cached(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var s := load(path)
	_cache[path] = s
	return s


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var b := node as BaseButton
		# Buttons in this group provide their own sound (e.g. worker steppers).
		if b.is_in_group("no_ui_click"):
			return
		if not b.pressed.is_connected(_ui_click):
			b.pressed.connect(_ui_click)


func _ui_click() -> void:
	play("ui_click")


func _on_combat_ended(victory: bool) -> void:
	play("victory" if victory else "defeat")
	# A reward chime if anyone leveled up in a won fight.
	if victory and CombatState.leveled_up_soldiers != null and not CombatState.leveled_up_soldiers.is_empty():
		play("level_up")


func _on_unit_acted(log_line: String) -> void:
	var l := log_line.to_lower()
	if "miss" in l or "dodge" in l:
		play("combat_miss")
	elif "uses" in l or "casts" in l:
		play("skill_cast")
	elif "dmg" in l or "damage" in l or "hits" in l or "strike" in l or "cleave" in l:
		play("combat_hit")
