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
