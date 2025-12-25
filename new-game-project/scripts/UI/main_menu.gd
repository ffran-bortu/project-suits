"""
FILE: main_menu.gd
PURPOSE: Main menu title screen with buttons for New Game, Load Game, Options, and Quit.

OVERVIEW:
Extends Control to provide the game's entry point UI. Shows difficulty selection overlay when starting new game,
emits signals for all actions (zero dependencies),  instances DifficultySelect scene dynamically, connects/disconnects
signals properly, and lets parent handle navigation. Follows best practices: preload constants, signal-based communication,
set properties before adding to tree.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects button signals, disables load initially, hides difficulty container
   - Uses: Initialization
   - Returns: void

2. _on_new_game_pressed()
   - What it does: Calls show_difficulty_selection()
   - Uses: Player clicks New Game
   - Returns: void

3. _on_load_game_pressed()
   - What it does: Emits load_game_pressed signal
   - Uses: Player clicks Load Game
   - Returns: void

4. _on_options_pressed()
   - What it does: Emits options_pressed signal
   - Uses: Player clicks Options
   - Returns: void

5. _on_quit_pressed()
   - What it does: Emits quit_pressed signal
   - Uses: Player clicks Quit
   - Returns: void

6. show_difficulty_selection()
   - What it does: Instances DifficultySelect, adds to container, connects signals  
   - Uses: Starting new game
   - Returns: void

7. _on_difficulty_selected(difficulty)
   - What it does: Cleans up difficulty overlay, emits new_game_started(difficulty) signal
   - Uses: Player selects difficulty
   - Returns: void

8. _on_difficulty_cancelled()
   - What it does: Cleans up difficulty overlay, returns to main menu
   - Uses: Player cancels difficulty selection
   - Returns: void

NOTES:
- Extends Control
- Signals: new_game_started(Difficulty.Level), load_game_pressed, options_pressed, quit_pressed
- Preloads DIFFICULTY_SELECT_SCENE for dynamic instantiation
- load_game_button disabled initially (no saves)
- difficulty_container initially hidden
- Instances difficulty selector in container when needed
- Cleans up difficulty selector with queue_free() after selection
- Fallback: emits NORMAL difficulty if container missing
- Parent scene connects to signals to handle navigation
"""

extends Control
## Main menu screen with difficulty selection
##
## BEST PRACTICE: Zero external dependencies, communicates via signals
## Parent scene connects to signals to handle menu navigation

## Emitted when player starts new game
## @param difficulty: Selected difficulty level
signal new_game_started(difficulty: Difficulty.Level)

## Emitted when player wants to load game
signal load_game_pressed

## Emitted when player wants to open options
signal options_pressed

## Emitted when player wants to quit
signal quit_pressed

## Preloaded scenes (Best practice: utilize GameConfig for paths)
# const DIFFICULTY_SELECT_SCENE = preload("res://scenes/ui/difficulty_select.tscn") # Legacy

## Node references
@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var new_game_button = $Panel/VBoxContainer/ButtonContainer/NewGameButton
@onready var load_game_button = $Panel/VBoxContainer/ButtonContainer/LoadGameButton
@onready var options_button = $Panel/VBoxContainer/ButtonContainer/OptionsButton
@onready var quit_button = $Panel/VBoxContainer/ButtonContainer/QuitButton
@onready var difficulty_container = $DifficultyContainer

func _ready():
	# Connect button signals (BEST PRACTICE: connect in _ready)
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Disable load game initially (no saves yet)
	load_game_button.disabled = true
	
	# Hide difficulty selection
	if difficulty_container:
		difficulty_container.hide()

func _on_new_game_pressed():
	# Show difficulty selection
	show_difficulty_selection()

func _on_load_game_pressed():
	load_game_pressed.emit()

func _on_options_pressed():
	options_pressed.emit()

func _on_quit_pressed():
	quit_pressed.emit()

## Show difficulty selection overlay
func show_difficulty_selection():
	if not difficulty_container:
		push_warning("MainMenu: DifficultyContainer not found")
		# Fallback: start with normal difficulty
		new_game_started.emit(Difficulty.Level.NORMAL)
		return
	
	# Instance difficulty selector
	var difficulty_select = SceneLoader.instantiate_scene(GameConfig.ui.difficulty_select)
	
	# Set properties BEFORE adding to tree (BEST PRACTICE)
	difficulty_select.name = "DifficultySelect"
	
	# Add to container
	difficulty_container.add_child(difficulty_select)
	difficulty_container.show()
	
	# Connect signals (BEST PRACTICE: signal-based communication)
	difficulty_select.difficulty_selected.connect(_on_difficulty_selected)
	difficulty_select.cancelled.connect(_on_difficulty_cancelled)

func _on_difficulty_selected(difficulty: Difficulty.Level):
	# Clean up difficulty selector
	if difficulty_container:
		for child in difficulty_container.get_children():
			child.queue_free()
		difficulty_container.hide()
	
	# Emit signal to parent (BEST PRACTICE: let parent handle navigation)
	new_game_started.emit(difficulty)

func _on_difficulty_cancelled():
	# Clean up and return to menu
	if difficulty_container:
		for child in difficulty_container.get_children():
			child.queue_free()
		difficulty_container.hide()
