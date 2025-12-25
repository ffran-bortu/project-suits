"""
FILE: defeat_screen.gd
PURPOSE: Defeat screen displayed when player loses a battle with retry/quit options.

OVERVIEW:
Simple Control extending Panel showing defeat reason and two buttons. Emits signals for retry or quit, hides self after
button press. Minimal defeat UI awaiting sound effects.

FUNCTIONS: _ready(), show_defeat(reason), _on_retry_pressed(), _on_quit_pressed() - 4 total

NOTES: Extends Control, signals: retry_pressed, quit_pressed, TODO: Add sound effects
"""

extends Control
## Defeat screen shown when player loses a battle
##
## Shows defeat reason and options to retry or quit

@onready var reason_label = $Panel/VBoxContainer/ReasonLabel
@onready var retry_button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var quit_button = $Panel/VBoxContainer/HBoxContainer/QuitButton

signal retry_pressed
signal quit_pressed

func _ready():
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	hide()

## Show defeat screen with reason
##
## @param reason: Why the player lost
func show_defeat(reason: String):
	reason_label.text = reason
	show()
	
	# Play defeat sound
	# TODO: Add sound effects

func _on_retry_pressed():
	retry_pressed.emit()
	hide()

func _on_quit_pressed():
	quit_pressed.emit()
	hide()
