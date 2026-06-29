# res://scripts/autoload/Settings.gd
# Autoload — owns the "Music" and "SFX" audio buses and persists volume
# settings to user://settings.cfg. MUST be registered BEFORE MusicManager and
# SFX in project.godot so those buses exist when their AudioStreamPlayers are
# created (bus = "Music" / bus = "SFX" assignments would silently fall back to
# "Master" otherwise).
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const MIN_VOLUME := 0.0001  # avoid linear_to_db(0) == -inf

var music_volume: float = 0.8
var sfx_volume: float = 0.8


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_load_settings()
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)


## Creates the bus (routed to Master) if it doesn't already exist. Idempotent —
## safe to call every launch.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Music")
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(music_volume, MIN_VOLUME)))
		AudioServer.set_bus_mute(bus, music_volume <= 0.0)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("SFX")
	if bus != -1:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(sfx_volume, MIN_VOLUME)))
		AudioServer.set_bus_mute(bus, sfx_volume <= 0.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return  # no settings file yet — defaults stand
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
