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

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)
	hide()

## Show victory screen with battle results
##
## @param stats: Dictionary with "turns", "mvp", "units_survived"
func show_victory(stats: Dictionary):
	battle_stats = stats
	
	# Update labels
	turns_label.text = "Turns: %d" % stats.get("turns", 0)
	mvp_label.text = "MVP: %s" % stats.get("mvp", "No MVP")
	survivors_label.text = "Units Survived: %d" % stats.get("units_survived", 0)
	
	show()
	
	# Play victory music/sound
	# TODO: Add sound effects

func _on_continue_pressed():
	continue_pressed.emit()
	hide()
