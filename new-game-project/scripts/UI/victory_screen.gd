"""
FILE: victory_screen.gd
PURPOSE: Displays the victory screen with battle statistics when the player wins.

OVERVIEW:
This screen appears after battle completion to show key statistics including turns taken, the MVP
(most valuable player), and number of units that survived. Players click continue to proceed to
the next stage or return to the world map.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects continue button signal and initializes screen as hidden
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. show_victory(stats: Dictionary)
   - What it does: Populates labels with battle statistics and displays the victory screen
   - Uses: Called by battle manager when player achieves victory
   - Returns: void

3. _on_continue_pressed()
   - What it does: Emits continue_pressed signal and hides the screen
   - Uses: Signal callback when player clicks continue button
   - Returns: void

NOTES:
- Accepts stats dictionary with keys: "turns", "mvp", "units_survived"
- Emits continue_pressed signal when player is ready to proceed
- TODO: Add victory music and sound effects
- Provides safe defaults for missing stat values (0 or "No MVP")
"""

"""
FILE: victory_screen.gd
PURPOSE: Victory screen displayed after winning battle - shows stats, rewards, MVP.
NOTES: Battle victory UI.
"""
extends Control
## Victory screen shown when player wins a battle
##
## Displays turns taken, MVP, and allows progression to next stage

@onready var turns_label = $Panel/VBoxContainer/TurnsLabel
@onready var mvp_label = $Panel/VBoxContainer/MVPLabel
@onready var survivors_label = $Panel/VBoxContainer/SurvivorsLabel
@onready var continue_button = $Panel/VBoxContainer/ContinueButton

signal continue_pressed

var battle_stats: Dictionary = {}

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	hide()

## Show victory screen with battle results
##
## @param stats: Dictionary with "turns", "mvp", "units_survived"
func show_victory(stats: Dictionary) -> void:
	battle_stats = stats
	
	# Update labels
	turns_label.text = "Turns: %d" % stats.get("turns", 0)
	mvp_label.text = "MVP: %s" % stats.get("mvp", "No MVP")
	survivors_label.text = "Units Survived: %d" % stats.get("units_survived", 0)
	
	show()
	
	# Play victory music/sound
	# TODO: Add sound effects

func _on_continue_pressed() -> void:
	continue_pressed.emit()
	hide()
