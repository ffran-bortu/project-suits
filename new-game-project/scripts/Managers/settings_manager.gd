"""
FILE: settings_manager.gd
PURPOSE: Manages persistent game settings (Video, Audio, Gameplay, Controls).
DEPENDENCIES: AudioManager, ConfigFile

FUNCTIONS:
1. load_settings() -> void
2. save_settings() -> void
3. apply_video_settings() -> void
4. apply_audio_settings() -> void
5. set_resolution_scale(scale_index) -> void
6. set_window_mode(mode_index) -> void
7. set_vsync(enabled) -> void
"""

extends Node

const SETTINGS_PATH := "user://settings.cfg"

# --- Defaults ---
var _settings := {
	"video": {
		"window_mode": DisplayServer.WINDOW_MODE_WINDOWED,
		"resolution_index": 2, # 1920x1080 default
		"vsync": true,
		"scale": 1.0
	},
	"audio": {
		"master_vol": 1.0,
		"music_vol": 0.8,
		"sfx_vol": 1.0,
		"ui_vol": 1.0,
		"voice_vol": 1.0
	},
	"gameplay": {
		"text_speed": 1.0,
		"auto_end_turn": false,
		"grid_opacity": 1.0
	}
}

# --- Signals ---
signal settings_changed(section: String, key: String, value: Variant)
signal settings_saved

func _ready() -> void:
	load_settings()
	apply_all_settings()

## Load settings from disk or use defaults
func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err == OK:
		for section in _settings.keys():
			if config.has_section(section):
				for key in _settings[section].keys():
					if config.has_section_key(section, key):
						_settings[section][key] = config.get_value(section, key)
		DebugLog.log("Settings loaded from disk", "green")
	else:
		DebugLog.log("No settings file found, using defaults", "yellow")
		save_settings()

## Save current settings to disk
func save_settings() -> void:
	var config = ConfigFile.new()
	
	for section in _settings:
		for key in _settings[section]:
			config.set_value(section, key, _settings[section][key])
			
	config.save(SETTINGS_PATH)
	settings_saved.emit()
	DebugLog.log("Settings saved", "green")

## Apply all settings
func apply_all_settings() -> void:
	apply_video_settings()
	apply_audio_settings()
	# Gameplay settings are pulled on demand

## Apply Video Settings
func apply_video_settings() -> void:
	var v_config = _settings.video
	
	# Window Mode
	DisplayServer.window_set_mode(v_config.window_mode)
	
	# VSync
	if v_config.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
	# Resolution (Simple implementation)
	# Ideally this maps to a list of supported resolutions
	pass

## Apply Audio Settings via AudioManager
func apply_audio_settings() -> void:
	if not AudioManager:
		push_warning("SettingsManager: AudioManager not found")
		return
		
	var a_config = _settings.audio
	AudioManager.set_bus_volume("Master", a_config.master_vol)
	AudioManager.set_bus_volume("Music", a_config.music_vol)
	AudioManager.set_bus_volume("SFX", a_config.sfx_vol)
	AudioManager.set_bus_volume("UI", a_config.ui_vol)
	AudioManager.set_bus_volume("Voice", a_config.voice_vol)

# --- Public Setters ---

func set_value(section: String, key: String, value: Variant) -> void:
	if section in _settings and key in _settings[section]:
		_settings[section][key] = value
		settings_changed.emit(section, key, value)
		
		# Immediate apply for some settings
		if section == "audio":
			apply_audio_settings()
		elif section == "video":
			apply_video_settings()
	else:
		push_error("SettingsManager: Invalid setting %s/%s" % [section, key])

func get_value(section: String, key: String, default = null) -> Variant:
	if section in _settings and key in _settings[section]:
		return _settings[section][key]
	return default
