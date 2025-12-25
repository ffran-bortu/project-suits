"""
FILE: audio_manager.gd
PURPOSE: Centralized audio management for music, SFX, and UI sounds.
DEPENDENCIES: project.godot (Autoload), default_bus_layout.tres

FUNCTIONS:
1. play_music(stream, fade_time) -> void
2. play_sfx(stream, pitch_variance) -> void
3. play_ui_click() -> void
4. set_bus_volume(bus_name, linear_volume) -> void
"""

extends Node

# --- Constants ---
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_VOICE := "Voice"

const DEFAULT_FADE_TIME: float = 1.0
const MIN_DB: float = -80.0

# --- Assets ---
# Preload common UI sounds for performance
var ui_click_sound: AudioStream

# --- State ---
var _music_player_1: AudioStreamPlayer
var _music_player_2: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_player: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer

var _sfx_pool_size: int = 10
var _current_sfx_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Audio should work in pause menu
	
	_setup_audio_players()
	_load_default_assets()
	
	DebugLog.log("AudioManager initialized", "green")

func _setup_audio_players() -> void:
	# create music players for cross-fading
	_music_player_1 = AudioStreamPlayer.new()
	_music_player_1.bus = BUS_MUSIC
	add_child(_music_player_1)
	
	_music_player_2 = AudioStreamPlayer.new()
	_music_player_2.bus = BUS_MUSIC
	add_child(_music_player_2)
	
	_active_music_player = _music_player_1
	
	# Create SFX pool
	for i in range(_sfx_pool_size):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_players.append(player)
		
	# UI Player
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = BUS_UI
	add_child(_ui_player)

func _load_default_assets() -> void:
	# Helper to load from GameConfig if available, otherwise default
	var path = GameConfig.assets.get("ui_click_sound", "res://assets/audio/ui_click.wav")
	if ResourceLoader.exists(path):
		ui_click_sound = load(path)

## Play music with crossfade
## @param stream: AudioStream to play
## @param fade_time: Time in seconds to crossfade
func play_music(stream: AudioStream, fade_time: float = DEFAULT_FADE_TIME) -> void:
	if _active_music_player.stream == stream and _active_music_player.playing:
		return
		
	var next_player = _music_player_2 if _active_music_player == _music_player_1 else _music_player_1
	next_player.stream = stream
	next_player.volume_db = MIN_DB
	next_player.play()
	
	# Tween crossfade
	var tween = create_tween()
	tween.parallel().tween_property(_active_music_player, "volume_db", MIN_DB, fade_time)
	tween.parallel().tween_property(next_player, "volume_db", 0.0, fade_time)
	
	await tween.finished
	_active_music_player.stop()
	_active_music_player = next_player
	
	DebugLog.log("Music changed to: " + (stream.resource_path if stream else "None"), "cyan")

## Play a sound effect
## @param stream: AudioStream resource
## @param pitch_variance: Random pitch adjustment (e.g. 0.1 for +/- 10%)
func play_sfx(stream: AudioStream, pitch_variance: float = 0.0) -> void:
	if not stream:
		return
		
	var player = _sfx_players[_current_sfx_index]
	player.stream = stream
	
	if pitch_variance > 0:
		player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	else:
		player.pitch_scale = 1.0
		
	player.play()
	
	_current_sfx_index = (_current_sfx_index + 1) % _sfx_pool_size

## Play standard UI click sound
func play_ui_click() -> void:
	if ui_click_sound:
		_ui_player.stream = ui_click_sound
		_ui_player.play()

## Set bus volume
## @param bus_name: Name of the bus (Master, Music, SFX, UI)
## @param linear_value: Volume from 0.0 to 1.0
func set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_error("AudioManager: Bus not found: " + bus_name)
		return
		
	var db = linear_to_db(clamp(linear_value, 0.0, 1.0))
	AudioServer.set_bus_volume_db(bus_idx, db)
	AudioServer.set_bus_mute(bus_idx, linear_value <= 0.01)

## Get current bus volume (linear 0-1)
func get_bus_volume(bus_name: String) -> float:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 0.0
	
	if AudioServer.is_bus_mute(bus_idx):
		return 0.0
		
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))
