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

## Preloaded scenes (BEST PRACTICE: preload for constants)
const DIFFICULTY_SELECT_SCENE = preload("res://scenes/ui/difficulty_select.tscn")

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
	
	# Instance difficulty selector (BEST PRACTICE: instance scenes as needed)
	var difficulty_select = DIFFICULTY_SELECT_SCENE.instantiate()
	
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
