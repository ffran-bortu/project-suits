"""
FILE: menu_main.gd
PURPOSE: Main menu coordinator - delegates to MainMenu UI child and handles scene transitions.
FUNCTIONS: _ready, _setup_signal_connections, _on_new_game_started, _on_load_game, _on_options, _on_options_closed, _on_quit, _set_menu_input_blocked - 8 total
NOTES: Preloads WORLD_MAP_SCENE. Prevents rapid clicks (_is_transitioning flag). Instantiates options menu as overlay.
"""

extends Node
## Main menu root scene - entry point for the game
##
## BEST PRACTICE: Acts as coordinator, delegates to child scenes

# --- Constants ---
## Debug log color constants
const COLOR_SUCCESS := "green"
const COLOR_WARNING := "yellow"
const COLOR_INFO := "cyan"

## Preloaded scenes (BEST PRACTICE: typed for compile-time checking)
# Loaded dynamically from GameConfig in _on_new_game_started to ensure config is ready

# --- Node References ---
@onready var main_menu_ui: Control = $MainMenu

# --- State Tracking ---
var _is_transitioning: bool = false


func _ready() -> void:
	_setup_signal_connections()
	DebugLog.log("Main Menu Ready", COLOR_SUCCESS)


## Setup all signal connections with safety checks
func _setup_signal_connections() -> void:
	if not main_menu_ui:
		push_error("MenuMain: MainMenu node not found!")
		return
	
	# Connect menu signals (BEST PRACTICE: signal-based communication)
	if main_menu_ui.has_signal("new_game_started"):
		main_menu_ui.new_game_started.connect(_on_new_game_started)
	
	if main_menu_ui.has_signal("load_game_pressed"):
		main_menu_ui.load_game_pressed.connect(_on_load_game)
	
	if main_menu_ui.has_signal("options_pressed"):
		main_menu_ui.options_pressed.connect(_on_options)
	
	if main_menu_ui.has_signal("quit_pressed"):
		main_menu_ui.quit_pressed.connect(_on_quit)


## Handle new game start with difficulty selection
## @param difficulty: Selected difficulty level
func _on_new_game_started(difficulty: Difficulty.Level) -> void:
	# Prevent multiple rapid clicks
	if _is_transitioning:
		return
	
	DebugLog.success("Starting new game on %s" % Difficulty.get_level_name(difficulty))
	
	# Validate scene before transition
	var world_map_path: String = GameConfig.assets.get("world_map_scene", "res://scenes/world_map_visual.tscn")
	if not ResourceLoader.exists(world_map_path):
		push_error("MenuMain: WORLD_MAP_SCENE not found at %s" % world_map_path)
		return
	
	_is_transitioning = true
	
	# Block input during transition
	_set_menu_input_blocked(true)
	
	# Transition to world map for chapter selection
	var error := get_tree().change_scene_to_file(world_map_path)
	if error != OK:
		push_error("MenuMain: Failed to change scene! Error code: %d" % error)
		_is_transitioning = false
		_set_menu_input_blocked(false)


## Handle load game request
func _on_load_game() -> void:
	DebugLog.log("Load game - Not yet implemented", COLOR_WARNING)
	# TODO: Implement save/load system


## Handle options menu request
func _on_options() -> void:
	if _is_transitioning:
		return
	
	DebugLog.log("Opening Options menu", COLOR_INFO)
	
	# Validate scene path
	var options_path: String = GameConfig.ui.get("options_menu", "res://scenes/ui/options_menu.tscn")
	if not ResourceLoader.exists(options_path):
		push_error("MenuMain: Options menu scene not found at %s" % options_path)
		return
	
	# Instantiate options menu
	var options_menu = SceneLoader.instantiate_scene(options_path)
	if not options_menu:
		push_error("MenuMain: Failed to instantiate options menu")
		return
	
	# Add to scene tree
	add_child(options_menu)
	
	# Connect close signal
	if options_menu.has_signal("closed"):
		options_menu.closed.connect(_on_options_closed.bind(options_menu))
	else:
		push_warning("MenuMain: Options menu doesn't have 'closed' signal")


## Handle options menu closed
func _on_options_closed(options_menu: Node) -> void:
	if options_menu and is_instance_valid(options_menu):
		options_menu.queue_free()
	DebugLog.log("Options menu closed", COLOR_INFO)


## Handle quit game request
func _on_quit() -> void:
	DebugLog.log("Quitting game", COLOR_INFO)
	get_tree().quit()


## Block or unblock menu input during transitions
## @param blocked: Whether to block input
func _set_menu_input_blocked(blocked: bool) -> void:
	if main_menu_ui and main_menu_ui.has_method("set_input_blocked"):
		main_menu_ui.set_input_blocked(blocked)
	elif main_menu_ui:
		# Fallback: directly set process_mode
		main_menu_ui.process_mode = Node.PROCESS_MODE_DISABLED if blocked else Node.PROCESS_MODE_INHERIT
