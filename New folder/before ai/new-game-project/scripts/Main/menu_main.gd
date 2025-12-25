extends Node
## Main menu root scene - entry point for the game
##
## BEST PRACTICE: Acts as coordinator, delegates to child scenes

## Preloaded scenes (BEST PRACTICE)
const BATTLE_SCENE = preload("res://scenes/main.tscn")

@onready var main_menu_ui = $MainMenu

func _ready():
	# Connect menu signals (BEST PRACTICE: signal-based communication)
	if main_menu_ui:
		main_menu_ui.new_game_started.connect(_on_new_game_started)
		main_menu_ui.load_game_pressed.connect(_on_load_game)
		main_menu_ui.options_pressed.connect(_on_options)
		main_menu_ui.quit_pressed.connect(_on_quit)
	
	DebugLog.log("Main Menu Ready", "green")

func _on_new_game_started(difficulty: Difficulty.Level):
	DebugLog.success("Starting new game on " + Difficulty.get_level_name(difficulty))
	
	# Transition to battle scene
	get_tree().change_scene_to_packed(BATTLE_SCENE)

func _on_load_game():
	DebugLog.log("Load game - Not yet implemented", "yellow")
	# TODO: Implement save/load system

func _on_options():
	DebugLog.log("Options - Not yet implemented", "yellow")
	# TODO: Implement options menu

func _on_quit():
	DebugLog.log("Quitting game", "cyan")
	get_tree().quit()
