# res://scripts/autoload/MusicManager.gd
# Crossfading background-music manager (autoload). Screens request a track by key
# (e.g. "hub", "combat") and this fades smoothly between them. Every load is
# guarded, so missing files just mean silence — never an error.
extends Node

const VOLUME_DB: float = -8.0
const SILENT_DB: float = -60.0
const FADE_SECONDS: float = 1.2

# Each key lists candidate paths in priority order (.ogg → .mp3 → .wav).
const TRACKS: Dictionary = {
	"menu": [
		"res://assets/audio/music/menu_theme.ogg",
		"res://assets/audio/music/menu_theme.mp3",
		"res://assets/audio/music/menu_theme.wav",
	],
	"hub": [
		"res://assets/audio/music/hub_theme.ogg",
		"res://assets/audio/music/hub_theme.mp3",
		"res://assets/audio/music/hub_theme.wav",
	],
	"dungeon": [
		"res://assets/audio/music/dungeon_theme.ogg",
		"res://assets/audio/music/dungeon_theme.mp3",
		"res://assets/audio/music/dungeon_theme.wav",
	],
	"combat": [
		"res://assets/audio/music/combat_theme.ogg",
		"res://assets/audio/music/combat_theme.mp3",
		"res://assets/audio/music/combat_theme.wav",
	],
}

# After a fight ends, MusicManager returns to whichever non-combat track was
# playing before combat started (hub or dungeon).
var _pre_combat_key: String = "hub"

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current_key: String = ""
var _fade: Tween


func _ready() -> void:
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT_DB
		p.bus = "Music"
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # keep playing while the game is paused
		add_child(p)
		_players.append(p)

	# Combat is an overlay (no scene change), so switch on signals. Remember the
	# track playing before the fight so we can return to it afterward.
	if CombatState.has_signal("combat_started"):
		CombatState.combat_started.connect(func():
			if _current_key == "hub" or _current_key == "dungeon":
				_pre_combat_key = _current_key
			play("combat")
		)
	if CombatState.has_signal("combat_ended"):
		CombatState.combat_ended.connect(func(_v): play(_pre_combat_key))
	if CombatState.has_signal("dungeon_combat_ended"):
		CombatState.dungeon_combat_ended.connect(func(_v): play(_pre_combat_key))
	if CombatState.has_signal("spectator_combat_ended"):
		CombatState.spectator_combat_ended.connect(func(_v): play(_pre_combat_key))


# Crossfade to the track registered under `key`. No-op if it's already playing.
func play(key: String) -> void:
	if key == _current_key and _players[_active].playing:
		return
	var stream := _load_first_existing(TRACKS.get(key, []))
	if stream == null:
		return
	_loop_stream(stream)
	_current_key = key

	var idle := 1 - _active
	var incoming := _players[idle]
	var outgoing := _players[_active]

	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()

	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(incoming, "volume_db", VOLUME_DB, FADE_SECONDS)
	_fade.tween_property(outgoing, "volume_db", SILENT_DB, FADE_SECONDS)
	_fade.set_parallel(false)
	_fade.tween_callback(outgoing.stop)

	_active = idle


func stop() -> void:
	_current_key = ""
	for p in _players:
		p.stop()


func _load_first_existing(paths: Array) -> AudioStream:
	for p in paths:
		if ResourceLoader.exists(p):
			var res := load(p)
			if res is AudioStream:
				return res
	return null


func _loop_stream(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in stream:
		stream.set("loop", true)
