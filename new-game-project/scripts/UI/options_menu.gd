"""
FILE: options_menu.gd
PURPOSE: UI Controller for the Settings Menu. Handles sliders, toggles, and data binding to SettingsManager.

OVERVIEW:
Provides a tabbed interface for adjusting game settings including Audio (volume controls),
Video (window mode, vsync), and Gameplay (text speed). All changes are immediately applied
and persisted via SettingsManager. Emits 'closed' signal when user exits the menu.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Loads current settings values and connects all UI signals
   - Uses: Initialization
   - Returns: void

2. _load_current_values()
   - What it does: Populates UI controls with current settings from SettingsManager
   - Uses: Initial setup, ensuring UI matches saved state
   - Returns: void

3. _connect_signals()
   - What it does: Connects all slider/checkbox/button signals to their handlers
   - Uses: Setup input handling
   - Returns: void

4. _on_master_vol_changed(value)
   - What it does: Updates master volume setting
   - Uses: Audio slider callback
   - Returns: void

5. _on_music_vol_changed(value)
   - What it does: Updates music volume setting
   - Uses: Audio slider callback
   - Returns: void

6. _on_sfx_vol_changed(value)
   - What it does: Updates SFX volume setting
   - Uses: Audio slider callback
   - Returns: void

7. _on_window_mode_selected(index)
   - What it does: Updates window mode (windowed/fullscreen)
   - Uses: Video option callback
   - Returns: void

8. _on_vsync_toggled(pressed)
   - What it does: Updates VSync setting
   - Uses: Video checkbox callback
   - Returns: void

9. _on_text_speed_changed(value)
   - What it does: Updates text speed setting
   - Uses: Gameplay slider callback
   - Returns: void

10. _on_save_pressed()
    - What it does: Saves settings to disk and closes menu
    - Uses: Save button callback
    - Returns: void

11. _on_close_pressed()
    - What it does: Closes menu (changes already applied)
    - Uses: Close button callback
    - Returns: void

NOTES:
- Extends Control
- Exports node references for easy scene setup
- Changes are applied immediately (real-time feedback)
- Waits one frame in _ready to ensure SettingsManager is initialized
- Emits 'closed' signal for parent cleanup
"""

extends Control

# --- Node References (Assumes standard UI structure) ---
# Tab Container should be child of this node
@export var tab_container: TabContainer

# Audio Sliders
@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider

# Video Controls
@export var window_mode_opt: OptionButton
@export var vsync_check: CheckBox

# Gameplay Controls
@export var text_speed_slider: HSlider

# UI Controls
@export var save_button: Button
@export var close_button: Button

# --- Signals ---
signal closed

func _ready() -> void:
	# Wait for SettingsManager to be ready
	await get_tree().process_frame
	_load_current_values()
	_connect_signals()
	
	DebugLog.log("OptionsMenu ready", "cyan")

func _load_current_values() -> void:
	if not SettingsManager: 
		return

	# Audio
	if master_slider: master_slider.value = SettingsManager.get_value("audio", "master_vol", 1.0)
	if music_slider: music_slider.value = SettingsManager.get_value("audio", "music_vol", 0.8)
	if sfx_slider: sfx_slider.value = SettingsManager.get_value("audio", "sfx_vol", 1.0)
	
	# Video
	if window_mode_opt: 
		# Map window mode constant to index if needed, for now assume 1:1 match for simplicity
		# Or find the index that matches the current mode
		var current_mode = SettingsManager.get_value("video", "window_mode", 0)
		# window_mode_opt.selected = ... (needs logic)
		pass
		
	if vsync_check: vsync_check.button_pressed = SettingsManager.get_value("video", "vsync", true)

	# Gameplay
	if text_speed_slider: text_speed_slider.value = SettingsManager.get_value("gameplay", "text_speed", 1.0)

func _connect_signals() -> void:
	# Audio
	if master_slider: master_slider.value_changed.connect(_on_master_vol_changed)
	if music_slider: music_slider.value_changed.connect(_on_music_vol_changed)
	if sfx_slider: sfx_slider.value_changed.connect(_on_sfx_vol_changed)
	
	# Video
	if window_mode_opt: window_mode_opt.item_selected.connect(_on_window_mode_selected)
	if vsync_check: vsync_check.toggled.connect(_on_vsync_toggled)
	
	# Gameplay
	if text_speed_slider: text_speed_slider.value_changed.connect(_on_text_speed_changed)

	# UI
	if save_button: save_button.pressed.connect(_on_save_pressed)
	if close_button: close_button.pressed.connect(_on_close_pressed)

# --- Callbacks ---

func _on_master_vol_changed(value: float) -> void:
	SettingsManager.set_value("audio", "master_vol", value)

func _on_music_vol_changed(value: float) -> void:
	SettingsManager.set_value("audio", "music_vol", value)

func _on_sfx_vol_changed(value: float) -> void:
	SettingsManager.set_value("audio", "sfx_vol", value)

func _on_window_mode_selected(index: int) -> void:
	# Map index back to DisplayServer constants if needed
	var mode = DisplayServer.WINDOW_MODE_WINDOWED
	match index:
		0: mode = DisplayServer.WINDOW_MODE_WINDOWED
		1: mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		2: mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	
	SettingsManager.set_value("video", "window_mode", mode)

func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.set_value("video", "vsync", pressed)

func _on_text_speed_changed(value: float) -> void:
	SettingsManager.set_value("gameplay", "text_speed", value)

func _on_save_pressed() -> void:
	SettingsManager.save_settings()
	closed.emit()
	
func _on_close_pressed() -> void:
	# Revert changes? Or just close?
	# For now just close, as changes are applied immediately in this implementation
	closed.emit()
