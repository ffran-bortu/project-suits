"""
FILE: difficulty_select.gd
PURPOSE: Difficulty selection overlay with Easy/Normal/Hard/Lunatic buttons and descriptions.

OVERVIEW:
Self-contained Control panel for choosing difficulty level. Shows 4 difficulty buttons with descriptions on hover
(pulled from Difficulty autoload). Sets Difficulty.current_level on selection, emits signal. Zero dependencies,
pure signal-based communication. Updates description label on mouse hover.

FUNCTIONS: _ready(), _on_difficulty_pressed(difficulty), _on_cancel_pressed(), _on_difficulty_hovered(difficulty),
_update_description(difficulty) - 5 total

NOTES: Extends Control, signals: difficulty_selected(Difficulty.Level), cancelled. Uses Difficulty autoload for  
get_level_name() and get_level_description(). Connects button hover signals to show descriptions. Logs difficulty
selection via DebugLog.
"""

extends Control
## Difficulty selection UI
##
## BEST PRACTICE: Self-contained, zero dependencies, communicates via signals

## Emitted when difficulty is selected
## @param difficulty: Chosen difficulty level
signal difficulty_selected(difficulty: Difficulty.Level)

## Emitted when selection is cancelled
signal cancelled

## Node references
@onready var easy_button = $Panel/VBoxContainer/ButtonsContainer/EasyButton
@onready var normal_button = $Panel/VBoxContainer/ButtonsContainer/NormalButton
@onready var hard_button = $Panel/VBoxContainer/ButtonsContainer/HardButton
@onready var lunatic_button = $Panel/VBoxContainer/ButtonsContainer/LunaticButton
@onready var cancel_button = $Panel/VBoxContainer/CancelButton
@onready var description_label = $Panel/VBoxContainer/DescriptionLabel

## Currently hovered difficulty
var hovered_difficulty: Difficulty.Level = Difficulty.Level.NORMAL

func _ready():
	# Connect button signals
	easy_button.pressed.connect(_on_difficulty_pressed.bind(Difficulty.Level.EASY))
	normal_button.pressed.connect(_on_difficulty_pressed.bind(Difficulty.Level.NORMAL))
	hard_button.pressed.connect(_on_difficulty_pressed.bind(Difficulty.Level.HARD))
	lunatic_button.pressed.connect(_on_difficulty_pressed.bind(Difficulty.Level.LUNATIC))
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Connect hover signals for descriptions
	easy_button.mouse_entered.connect(_on_difficulty_hovered.bind(Difficulty.Level.EASY))
	normal_button.mouse_entered.connect(_on_difficulty_hovered.bind(Difficulty.Level.NORMAL))
	hard_button.mouse_entered.connect(_on_difficulty_hovered.bind(Difficulty.Level.HARD))
	lunatic_button.mouse_entered.connect(_on_difficulty_hovered.bind(Difficulty.Level.LUNATIC))
	
	# Show normal description by default
	_update_description(Difficulty.Level.NORMAL)

func _on_difficulty_pressed(difficulty: Difficulty.Level):
	# Set difficulty (BEST PRACTICE: update state before emitting)
	Difficulty.current_level = difficulty
	
	DebugLog.log("Difficulty selected: " + Difficulty.get_level_name(difficulty), "cyan")
	
	# Emit signal
	difficulty_selected.emit(difficulty)

func _on_cancel_pressed():
	cancelled.emit()

func _on_difficulty_hovered(difficulty: Difficulty.Level):
	hovered_difficulty = difficulty
	_update_description(difficulty)

func _update_description(difficulty: Difficulty.Level):
	if description_label:
		description_label.text = Difficulty.get_level_description(difficulty)
