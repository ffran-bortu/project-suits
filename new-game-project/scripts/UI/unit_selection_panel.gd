"""
FILE: unit_selection_panel.gd
PURPOSE: Manages unit selection and deployment positioning for pre-battle preparation.

OVERVIEW:
This panel allows players to choose which units to deploy for battle and assign them to spawn positions
on the map. It displays available characters, supports duo unit formation, shows unit details, and
manages the deployment limit. Players can select characters, form duo units from compatible pairs,
deploy units to specific spawn slots, and confirm their lineup before battle starts.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects all button signals and initializes button states
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. setup(characters: Array[CharacterData], spawns: Array[Vector2i], limit: int = 10)
   - What it does: Initializes panel with available characters, spawn positions, and deployment limit
   - Uses: Called by PrepScreen to configure the selection interface
   - Returns: void

3. _populate_unit_list()
   - What it does: Creates character card buttons for each available character
   - Uses: Called during setup to display the character roster
   - Returns: void

4. _create_character_card(character: CharacterData) -> Button
   - What it does: Creates a formatted button showing character name, level, and class
   - Uses: Called for each character when populating the list
   - Returns: Button - configured character selection button

5. _populate_spawn_grid()
   - What it does: Creates buttons for each spawn slot on the map
   - Uses: Called during setup to show available deployment positions
   - Returns: void

6. _on_character_card_pressed(character: CharacterData)
   - What it does: Selects a character and displays their detailed information
   - Uses: Signal callback when player clicks a character card
   - Returns: void

7. _show_character_details(character: CharacterData)
   - What it does: Updates detail panel with character's stats, portrait, and information
   - Uses: Called when a character is selected to show their attributes
   - Returns: void

8. _on_spawn_slot_pressed(slot_index: int)
   - What it does: Assigns selected unit to the chosen spawn position
   - Uses: Signal callback when player clicks a spawn slot button
   - Returns: void

9. _on_form_duo_pressed()
   - What it does: Adds selected character to duo formation list and creates duo when two are selected
   - Uses: Signal callback when player clicks "Form Duo" button
   - Returns: void

10. _create_duo_unit(char_a: CharacterData, char_b: CharacterData)
    - What it does: Creates a duo unit from two compatible characters
    - Uses: Called when two characters are selected for duo formation
    - Returns: void

11. _on_break_duo_pressed()
    - What it does: Separates a duo unit back into two individual characters
	- Uses: Signal callback when player clicks "Break Duo" button
    - Returns: void

12. _on_deploy_pressed()
    - What it does: Adds selected character to the deployment list
	- Uses: Signal callback when player clicks "Deploy" button
    - Returns: void

13. _on_remove_pressed()
    - What it does: Removes selected unit from deployment
	- Uses: Signal callback when player clicks "Remove" button
    - Returns: void

14. _on_back_pressed()
    - What it does: Emits selection_cancelled signal to return to prep screen
	- Uses: Signal callback when player clicks "Back" button
    - Returns: void

15. _update_deployment_count()
	- What it does: Updates the "Deployed: X/Y" label showing current vs maximum units
    - Uses: Called whenever deployment changes to keep count accurate
    - Returns: void

16. _update_button_states()
    - What it does: Enables or disables buttons based on current selection state
    - Uses: Called after selection changes to ensure valid button states
    - Returns: void

17. _is_duo(unit) -> bool
    - What it does: Checks if a unit is a duo by testing for frontline character method
    - Uses: Helper to determine if duo-specific operations are available
    - Returns: bool - true if unit is a duo, false otherwise

NOTES:
- Depends on CharacterData for character information
- Uses CharacterData.StatType enum for stat access
- Emits selection_complete signal with deployed_units array and positions dictionary when confirmed
- Emits selection_cancelled signal when player exits without confirming
- Supports duo unit formation with compatibility checking (TODO: validate one frontline, one backline)
PURPOSE: Unit selection UI for choosing units for deployment.
NOTES: Unit selection/deployment UI.
"""
extends Control
class_name UnitSelectionPanel
## Unit selection and deployment positioning subpanel
##
## Allows player to choose which units deploy and where they spawn on the map

signal selection_complete(deployed_units: Array, positions: Dictionary)
signal selection_cancelled

# --- State ---
var available_characters: Array[CharacterData] = []
var available_spawns: Array[Vector2i] = []
var deployment_limit: int = 10
var deployed_units: Array[CharacterData] = [] # List of selected characters
var spawn_assignments: Dictionary[String, int] = {} # character_id -> spawn_index
var spawn_slots: Array[Vector2i] = []
# var deployment_limit: int = 10 # This was a duplicate, removed.

# Constants
const CARD_SIZE = Vector2(200, 80)
const SLOT_SIZE = Vector2(80, 80)

# Selected units for duo formation
var selected_for_duo: Array[CharacterData] = []

# UI references
@onready var unit_list_container = $HSplitContainer/AvailablePanel/VBoxContainer/ScrollContainer/UnitListContainer
@onready var deployment_count_label = $HSplitContainer/AvailablePanel/VBoxContainer/DeploymentLabel
@onready var spawn_grid = $HSplitContainer/DeploymentPanel/VBoxContainer/SpawnGrid
@onready var unit_details_panel = $UnitDetailsPanel
@onready var unit_portrait = $UnitDetailsPanel/Portrait
@onready var unit_name_label = $UnitDetailsPanel/NameLabel
@onready var unit_stats_label = $UnitDetailsPanel/StatsLabel
@onready var form_duo_button = $Controls/FormDuoButton
@onready var break_duo_button = $Controls/BreakDuoButton
@onready var deploy_button = $Controls/DeployButton
@onready var remove_button = $Controls/RemoveButton
@onready var back_button = $Controls/BackButton

var selected_character: CharacterData = null
var selected_unit: Unit = null

func _ready() -> void:
	# Connect button signals
	form_duo_button.pressed.connect(_on_form_duo_pressed)
	break_duo_button.pressed.connect(_on_break_duo_pressed)
	deploy_button.pressed.connect(_on_deploy_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	_update_button_states()

## Setup panel with character roster and spawn positions
func setup(characters: Array[CharacterData], spawns: Array[Vector2i], limit: int = 10) -> void:
	# Validate inputs
	if characters.is_empty():
		push_error("UnitSelectionPanel: No characters provided")
		return
	
	if spawns.is_empty():
		push_warning("UnitSelectionPanel: No spawn positions provided")
	
	if limit <= 0:
		push_warning("UnitSelectionPanel: Invalid deployment limit %d, using default 10" % limit)
		limit = 10
	
	available_characters = characters
	spawn_slots = spawns
	deployment_limit = limit
	
	_populate_unit_list()
	_populate_spawn_grid()
	_update_deployment_count()

func _populate_unit_list() -> void:
	# Clear existing
	for child in unit_list_container.get_children():
		child.queue_free()
	
	# Create card for each character
	for character in available_characters:
		var card = _create_character_card(character)
		unit_list_container.add_child(card)

func _create_character_card(character: CharacterData) -> Button:
	if not character:
		push_error("UnitSelectionPanel: Null character provided")
		return null
	
	var button = Button.new()
	button.custom_minimum_size = CARD_SIZE
	
	# Format: "Name Lv.5 Knight"
	var level = character.get_current_level() if character.has_method("get_current_level") else 1
	var cls_name = character.primary_class.display_name if character.primary_class else "???"
	button.text = "%s Lv.%d\n%s" % [character.character_name, level, cls_name]
	
	button.pressed.connect(_on_character_card_pressed.bind(character))
	
	return button

func _populate_spawn_grid() -> void:
	# Clear existing
	for child in spawn_grid.get_children():
		child.queue_free()
	
	# Create button for each spawn slot
	for i in range(spawn_slots.size()):
		var slot_button = Button.new()
		slot_button.text = "Slot %d" % (i + 1)
		slot_button.custom_minimum_size = SLOT_SIZE
		slot_button.pressed.connect(_on_spawn_slot_pressed.bind(i))
		spawn_grid.add_child(slot_button)

func _on_character_card_pressed(character: CharacterData) -> void:
	selected_character = character
	_show_character_details(character)
	_update_button_states()

func _show_character_details(character: CharacterData):
	if not character:
		push_error("UnitSelectionPanel: Null character in _show_character_details")
		return
	
	unit_name_label.text = character.character_name
	
	# Show stats with validation
	if not character.has_method("get_all_stats"):
		push_error("UnitSelectionPanel: Character missing get_all_stats() method")
		unit_stats_label.text = "Stats unavailable"
		return
	
	var stats = character.get_all_stats(true)  # Frontline stats
	var hp = stats.get(GameTypes.StatType.HP, 0)
	var str_stat = stats.get(GameTypes.StatType.STR, 0)
	var mag = stats.get(GameTypes.StatType.MAG, 0)
	
	unit_stats_label.text = "HP: %d  STR: %d  MAG: %d" % [hp, str_stat, mag]
	
	# Show portrait if available
	if character.portrait:
		unit_portrait.texture = character.portrait

func _on_spawn_slot_pressed(_slot_index: int):
	# TODO: Assign selected unit to this spawn position
	pass

func _on_form_duo_pressed():
	if not selected_character:
		return
	
	# Add to duo formation list
	if selected_for_duo.size() < 2 and not selected_for_duo.has(selected_character):
		selected_for_duo.append(selected_character)
	
	# If we have 2, create the duo
	if selected_for_duo.size() == 2:
		_create_duo_unit(selected_for_duo[0], selected_for_duo[1])
		selected_for_duo.clear()
	
	_update_button_states()

func _create_duo_unit(char_a: CharacterData, char_b: CharacterData):
	# TODO: Validate compatibility (one frontline, one backline capable)
	# TODO: Actually create DuoUnit instance
	# For now, just log
	DebugLog.success("Duo formed: %s + %s" % [char_a.character_name, char_b.character_name])
	_update_deployment_count()

func _on_break_duo_pressed():
	# TODO: Break selected duo back into two solo units
	pass

func _on_deploy_pressed():
	if not selected_character:
		return
	
	# TODO: Add to deployed units
	_update_deployment_count()

func _on_remove_pressed():
	# TODO: Remove from deployment
	_update_deployment_count()

func _on_back_pressed():
	emit_signal("selection_cancelled")

func _update_deployment_count():
	var count = deployed_units.size()
	deployment_count_label.text = "Deployed: %d/%d" % [count, deployment_limit]

func _update_button_states():
	# Enable/disable buttons based on selection
	form_duo_button.disabled = selected_character == null
	deploy_button.disabled = selected_character == null
	remove_button.disabled = selected_unit == null
	break_duo_button.disabled = selected_unit == null or not _is_duo(selected_unit)

func _is_duo(unit: Unit) -> bool:
	return unit != null and unit.has_method("get_frontline_character")
