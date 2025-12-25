"""
FILE: level_up_ui.gd
PURPOSE: Simple level up UI panel showing character name, new level, and stat gains.

OVERVIEW:
Extends Control to display level up results after gaining experience. Shows character name, new level number,
and lists all stat gains (only non-zero gains displayed). Dynamically creates Labels for each stat increase,
waits for player to press Continue button, then closes and emits signal. Minimal, straightforward feedback.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects continue_button signal, hides panel
   - Uses: Initialization
   - Returns: void

2. show_level_up(character_name, new_level, stat_gains)
   - What it does: Sets labels, clears old stats, creates new stat Labels for gains > 0, shows panel
   - Uses: Character levels up
   - Returns: void

3. _on_continue()
   - What it does: Hides panel, emits level_up_closed signal
   - Uses: Player presses Continue
   - Returns: void

NOTES:
- Extends Control
- Signal: level_up_closed
- Shows character name, "Level X!", and stat gains
- stat_gains is Dictionary { "stat_name": gain_value }
- Only shows stats with gain > 0
- Dynamically creates Label nodes for each stat
- Clears stats_container children before adding new ones
- Format: "STAT_NAME +X" (e.g., "STR +2")
- Continue button closes panel
- Starts hidden, shown by show_level_up()
"""

extends Control
## Simple level up UI

signal level_up_closed

@onready var character_name_label = $Panel/VBoxContainer/CharacterName
@onready var level_label = $Panel/VBoxContainer/LevelLabel
@onready var stats_container = $Panel/VBoxContainer/StatsContainer
@onready var continue_button = $Panel/VBoxContainer/ContinueButton

func _ready():
	if continue_button:
		continue_button.pressed.connect(_on_continue)
	
	SignalBus.level_up.connect(_on_signal_bus_level_up)
	
	hide()


func _on_signal_bus_level_up(character: Resource, new_level: int, stat_gains: Dictionary) -> void:
	# character is Resource, usually has 'character_name'. 
	# The generic resource might not have it exposed to static type check, so we cast or safe get.
	var char_name = "Unknown"
	if "character_name" in character:
		char_name = character.character_name
	elif character.has_method("get_name"):
		char_name = character.get_name()
		
	show_level_up(char_name, new_level, stat_gains)

func show_level_up(character_name: String, new_level: int, stat_gains: Dictionary):
	if character_name_label:
		character_name_label.text = character_name
	if level_label:
		level_label.text = "Level %d!" % new_level
	
	# Clear previous stats
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()
		
		# Show stat gains
		for stat_name in stat_gains:
			var gain = stat_gains[stat_name]
			if gain > 0:
				var label = Label.new()
				label.text = "%s +%d" % [stat_name.to_upper(), gain]
				stats_container.add_child(label)
	
	show()

func _on_continue():
	hide()
	level_up_closed.emit()
