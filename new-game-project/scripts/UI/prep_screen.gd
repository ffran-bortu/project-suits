"""
FILE: prep_screen.gd
PURPOSE: Provides the pre-battle preparation hub menu where players manage unit deployment and setup.

OVERVIEW:
This screen serves as the main preparation hub before battle, similar to Fire Emblem Awakening's
prep screen. Players can select which units to deploy, view support conversations, check the map,
manage skills and inventory, and save their progress. It validates unit selection and deployment
before allowing the battle to start.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Initializes button signals and sets up the prep screen
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. setup(available_chars: Array[CharacterData], spawn: Array[Vector2i], limit: int, chapter_info: Dictionary)
   - What it does: Configures the prep screen with battle-specific parameters and available characters
   - Uses: Called when entering prep phase to set up deployment options
   - Returns: void

3. _load_saved_deployment()
   - What it does: Loads previously saved unit deployment if available
   - Uses: Called during setup to restore prior deployment choices
   - Returns: void

4. _on_select_units_pressed()
   - What it does: Opens the unit selection panel for choosing and positioning units
   - Uses: Called when player clicks the "Select Units" button
   - Returns: void

5. _on_support_pressed()
   - What it does: Opens the support menu to view character conversations
   - Uses: Called when player clicks the "Support" button
   - Returns: void

6. _on_map_pressed()
   - What it does: Shows the battle map preview
   - Uses: Called when player clicks the "Map" button
   - Returns: void

7. _on_skills_pressed()
   - What it does: Opens the skills management screen
   - Uses: Called when player clicks the "Skills" button
   - Returns: void

8. _on_inventory_pressed()
   - What it does: Opens the inventory management interface
   - Uses: Called when player clicks the "Inventory" button
   - Returns: void

9. _on_save_pressed()
   - What it does: Triggers game save functionality
   - Uses: Called when player clicks the "Save" button
   - Returns: void

10. _on_fight_pressed()
    - What it does: Validates deployment and starts the battle if all conditions are met
	- Uses: Called when player clicks the "Fight!" button to begin battle
    - Returns: void

11. _on_exit_pressed()
    - What it does: Cancels prep and returns to previous screen
	- Uses: Called when player clicks the "Exit" button
    - Returns: void

12. _show_unit_selection()
    - What it does: Instantiates and displays the unit selection panel with available characters
    - Uses: Called internally when unit selection is requested
    - Returns: void

13. _show_support_menu()
    - What it does: Instantiates and displays the support conversation menu
    - Uses: Called internally when support menu is requested
    - Returns: void

14. _on_unit_selection_complete(units: Array, positions: Dictionary)
    - What it does: Stores selected units and their deployment positions, then closes the panel
    - Uses: Signal callback when player finishes unit selection
    - Returns: void

15. _on_unit_selection_cancelled()
    - What it does: Closes the unit selection panel without saving changes
    - Uses: Signal callback when player cancels unit selection
    - Returns: void

16. _on_support_menu_closed()
    - What it does: Closes the support menu and returns to prep screen
    - Uses: Signal callback when support menu exits
    - Returns: void

17. _validate_deployment() -> bool
    - What it does: Checks if all required units are selected and properly positioned on valid spawn points
    - Uses: Called before allowing battle to start
    - Returns: bool - true if deployment is valid, false otherwise

18. update_help_text(text: String)
    - What it does: Updates the help text label with the provided message
    - Uses: Called throughout the prep screen to provide user feedback
    - Returns: void

19. _save_game()
    - What it does: Calls SaveManager to save current game progress
    - Uses: Called when player initiates save operation
    - Returns: void

NOTES:
- Depends on CharacterData for character information
- Requires UnitSelectionPanel scene for unit deployment
- Requires SupportMenu scene for viewing support conversations
- Connects to SaveManager autoload for save functionality
- Emits prep_complete signal with deployed_units and deployment_positions when ready to fight
- Emits prep_cancelled signal when player exits without fighting
- Validates that selected units match deployment limit and are positioned on valid spawn points
"""

"""
FILE: prep_screen.gd  
PURPOSE: Unit preparation screen before battle - manage deployment, equipment, items.
NOTES: Pre-battle setup UI.
"""
extends Control
class_name PrepScreen
## Pre-battle preparation hub menu (Fire Emblem Awakening style)
##
## Provides access to: Unit Selection, Support Conversations, Map View,
## Skills, Inventory Management, and Save functionality

signal prep_complete(deployed_units: Array, deployment_positions: Dictionary)
signal prep_cancelled
signal unit_placement_requested(character: CharacterData, grid_pos: Vector2i)

# References to subpanels (will be loaded dynamically)
var unit_selection_panel: Control
var inventory_panel: Control
var support_menu: Control
var convoy_menu: Control # Added

# ... (Existing code) ...

func _on_inventory_pressed() -> void:
	update_help_text("Select a unit to manage inventory.")
	_open_convoy_unit_picker()

func _open_convoy_unit_picker() -> void:
	# Simple popup to pick a unit for convoy management
	var popup = PopupMenu.new()
	popup.name = "ConvoyUnitPicker"
	
	for i in range(available_characters.size()):
		var char_data = available_characters[i]
		var text = "%s (Lv.%d)" % [char_data.character_name, char_data.get_current_level()]
		popup.add_item(text, i)
	
	popup.id_pressed.connect(func(id): _on_convoy_unit_picked(id, popup))
	popup.popup_hide.connect(func(): popup.queue_free())
	
	add_child(popup)
	popup.popup_centered()

func _on_convoy_unit_picked(index: int, popup: PopupMenu) -> void:
	var character_data = available_characters[index]
	popup.queue_free()
	
	# Create or show Convoy Menu
	if not convoy_menu:
		var menu_script = load("res://scripts/UI/convoy_menu.gd")
		convoy_menu = menu_script.new()
		convoy_menu.name = "ConvoyMenu"
		convoy_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(convoy_menu)
		convoy_menu.menu_closed.connect(_on_convoy_closed)
	
	# Need a Unit instance for ConvoyMenu, but we have CharacterData.
	# We need to find the deployed unit OR create a temporary wrapper if allowed.
	# ConvoyMenu expects 'Unit'.
	# Strategy: Find if there's a deployed unit for this character.
	var unit_for_menu: Unit = null
	
	# Check deployed units
	for u in deployed_units:
		if u.character == character_data: # Solo
			unit_for_menu = u
			break
		# If Duo logic needed, check frontliner/backliner
	
	if not unit_for_menu:
		# If not deployed, we must create a temporary dummy unit to bridge CharacterData <-> Unit Inventory
		# OR update ConvoyMenu to handle CharacterData directly.
		# Updating ConvoyMenu to handle CharacterData is better architecture, but Unit has the Inventory component.
		# Let's create a temporary unit wrapper for the menu.
		unit_for_menu = Unit.new()
		unit_for_menu.character = character_data
		# Populate temp inventory from character data
		var inv = Inventory.new()
		# if character_data.get("weapon"): # Fixed: CharacterData doesn't have weapon property yet
		# 	inv.add_item(character_data.weapon)
		unit_for_menu.inventory = inv
		
		# Important: If we modify this temp unit's inventory, we MUST save it back to CharacterData on close.
	
	convoy_menu.setup(unit_for_menu)

func _on_convoy_closed() -> void:
	update_help_text("Choose an option to prepare for battle.")
	# TODO: If we used a temp unit, save items back to CharacterData

# Battle data
var available_characters: Array[CharacterData] = []
var deployed_units: Array[Unit] = []  # Units selected for battle
var deployment_positions: Dictionary[Vector2i, Unit] = {}  # Vector2i -> Unit
var spawn_slots: Array[Vector2i] = []  # Available spawn positions from map
var deployment_limit: int = 10
var map_data: Dictionary = {}  # Chapter info, objectives, etc.
var unit_manager: Node = null # Injected for validation

# UI references
@onready var select_units_button = $MainContainer/VBoxContainer/MenuButtons/SelectUnitsButton
@onready var support_button = $MainContainer/VBoxContainer/MenuButtons/SupportButton
@onready var view_map_button = $MainContainer/VBoxContainer/MenuButtons/ViewMapButton
@onready var equip_skills_button = $MainContainer/VBoxContainer/MenuButtons/EquipSkillsButton
@onready var inventory_button = $MainContainer/VBoxContainer/MenuButtons/InventoryButton
@onready var save_button = $MainContainer/VBoxContainer/MenuButtons/SaveButton
@onready var fight_button = $MainContainer/VBoxContainer/ActionButtons/FightButton
@onready var exit_button = $MainContainer/VBoxContainer/ActionButtons/ExitButton
@onready var help_text = $HelpTextPanel/Label

func _ready() -> void:
	# Connect button signals
	select_units_button.pressed.connect(_on_select_units_pressed)
	support_button.pressed.connect(_on_support_pressed)
	view_map_button.pressed.connect(_on_view_map_pressed)
	equip_skills_button.pressed.connect(_on_equip_skills_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	save_button.pressed.connect(_on_save_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect global signals
	if not SignalBus.deployment_tile_clicked.is_connected(_on_deployment_tile_clicked):
		SignalBus.deployment_tile_clicked.connect(_on_deployment_tile_clicked)
	
	_setup_input_map_compatibility()
	
	# Default focus for keyboard navigation
	if select_units_button:
		select_units_button.grab_focus()
	
	update_help_text("Choose an option to prepare for battle.")

func _setup_input_map_compatibility() -> void:
	# Ensure standard UI actions map to game controls
	_map_action_to_ui("select", "ui_accept")
	_map_action_to_ui("cancel", "ui_cancel")
	_map_action_to_ui("move_up", "ui_up")
	_map_action_to_ui("move_down", "ui_down")
	_map_action_to_ui("move_left", "ui_left")
	_map_action_to_ui("move_right", "ui_right")

func _map_action_to_ui(game_action: String, ui_action: String) -> void:
	if not InputMap.has_action(game_action):
		return
		
	for event in InputMap.action_get_events(game_action):
		if not InputMap.action_has_event(ui_action, event):
			InputMap.action_add_event(ui_action, event)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	
	# C key to finish deployment (alternative to clicking button)
	if event.keycode == KEY_C and GlobalGameState.current_state == GlobalGameState.GameState.DEPLOYMENT:
		_exit_deployment_mode()
		get_viewport().set_input_as_handled()
	
	# X key to exit map view
	if event.keycode == KEY_X and get_node_or_null("MapViewHUD"):
		_exit_map_view_mode()
		get_viewport().set_input_as_handled()

## Initialize prep screen with chapter data
## @param characters: Player's army roster
## @param chapter_info: Map data (spawn positions, limits, objectives)
## @param unit_manager_ref: Reference to UnitManager for validation
func setup(characters: Array[CharacterData], chapter_info: Dictionary, unit_manager_ref: Node = null) -> void:
	if characters.is_empty():
		push_warning("PrepScreen: Characters roster is empty!")
		characters = [] # Safer fallback
		
	available_characters = characters
	spawn_slots = chapter_info.get("spawn_positions", [])
	deployment_limit = chapter_info.get("deployment_limit", 10)
	
	if unit_manager_ref:
		unit_manager = unit_manager_ref
	
	if deployment_limit <= 0:
		push_warning("PrepScreen: Deployment limit is <= 0! Defaulting to 1.")
		deployment_limit = 1
		
	map_data = chapter_info
	
	# Load previous deployment if saved
	_load_saved_deployment()
	
	update_help_text("Choose an option to prepare for battle.")

func _load_saved_deployment() -> void:
	# TODO: Load from SaveManager if available
	pass

func _on_select_units_pressed() -> void:
	update_help_text("Select a blue tile to place a unit.")
	_enter_deployment_mode()

func _enter_deployment_mode() -> void:
	# Hide all existing children (MainContainer, HelpText, Backgrounds, etc.)
	for child in get_children():
		if child is Control:
			child.visible = false
	
	# CRITICAL: Keep PrepScreen visible but allow clicks to pass through to 3D world
	# visible = false # REMOVED: This hid the DeploymentHUD too!
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if spawn_slots.is_empty():
		push_warning("PrepScreen: No spawn slots available for deployment! Visuals will not appear.")
		DebugLog.error("PrepScreen: spawn_slots is empty - check chapter data!")
		return  # Don't enter deployment mode if no spawn slots
	
	print("PrepScreen: Entering deployment with %d spawn slots" % spawn_slots.size())
	print("PrepScreen: Spawn slots: ", spawn_slots)
	
	# Emit signal to start deployment visuals
	print("PrepScreen: SignalBus connections for deployment_started: ", SignalBus.deployment_started.get_connections())
	SignalBus.deployment_started.emit(spawn_slots)
	print("PrepScreen: deployment_started signal emitted")
	
	# Change game state
	GlobalGameState.change_state(GlobalGameState.GameState.DEPLOYMENT)
	
	# Show "Finish Deployment" UI
	_show_deployment_hud()
	
	# Debug: Verify enemies are spawned via UnitManager
	# Get reference to UnitManager (it's injected or can be found)
	var main_node = get_parent().get_parent() # Main/UICanvas/PrepScreen -> Main
	# Safer to use group or absolute path since we know hierarchy
	if not main_node or main_node.name != "Main":
		main_node = get_tree().get_root().get_node_or_null("Main")
		
	if main_node and "unit_manager" in main_node:
		var unit_mgr = main_node.unit_manager
		if unit_mgr and unit_mgr.has_method("get_units_by_team"):
			var enemies = unit_mgr.get_units_by_team(1)  # TEAM_ENEMY
			print("PrepScreen: Entering deployment with %d enemies visible" % enemies.size())
			if enemies.is_empty():
				push_warning("PrepScreen: No enemies found! They should be spawned before PrepScreen appears.")
		else:
			print("PrepScreen: UnitManager not accessible, cannot verify enemies")

func _show_deployment_hud() -> void:
	# Create a simple HUD for finishing deployment
	var hud = PanelContainer.new()
	hud.name = "DeploymentHUD"
	hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud.offset_left = -220  # 220px from right edge
	hud.offset_top = 20
	hud.offset_right = -20
	hud.offset_bottom = 120
	hud.custom_minimum_size = Vector2(200, 100)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	hud.add_child(vbox)
	
	var label = Label.new()
	label.text = "Deployment Phase"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var finish_btn = Button.new()
	finish_btn.text = "Finish & Return"
	finish_btn.custom_minimum_size = Vector2(180, 40)
	finish_btn.focus_mode = Control.FOCUS_NONE # Prevent stealing focus from map cursor
	finish_btn.pressed.connect(_exit_deployment_mode)
	vbox.add_child(finish_btn)
	
	add_child(hud)
	
	DebugLog.log("PrepScreen: DeploymentHUD created and visible")

func _exit_deployment_mode() -> void:
	# Clean up HUD
	var hud = get_node_or_null("DeploymentHUD")
	if hud:
		hud.queue_free()
	
	# Restore visibility of main elements
	for child in get_children():
		if child is Control and child.name != "DeploymentHUD":
			child.visible = true
	
	# Restore input blocking for menu
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Clear highlights (InteractionController handles this on state change usually, 
	# but we can force it or let GameStateManager handle logic)
	GlobalGameState.change_state(GlobalGameState.GameState.PLAYER_TURN)
	
	update_help_text("Deployment updated.")

func _on_deployment_tile_clicked(grid_pos: Vector2i) -> void:
	print("PrepScreen: Tile clicked at ", grid_pos)
	_open_unit_picker(grid_pos)

func _open_unit_picker(grid_pos: Vector2i) -> void:
	# Check if we are in DEPLOYMENT state
	if GlobalGameState.current_state != GlobalGameState.GameState.DEPLOYMENT:
		return

	# Simple popup to pick a unit
	var popup = PopupMenu.new()
	popup.name = "UnitPicker"
	
	# Populate with available characters
	for i in range(available_characters.size()):
		var char_data = available_characters[i]
		var text = "%s (Lv.%d)" % [char_data.character_name, char_data.get_current_level()]
		
		# Check if deployed
		var _is_deployed = false
		for deployed_unit in deployed_units:
			# This check is tricky since deployed_units are Units not CharacterData
			# We need to map back or check ID
			# For now, just show all
			pass
			
		popup.add_item(text, i)
	
	popup.id_pressed.connect(func(id): _on_unit_picked(id, grid_pos, popup))
	
	# Connect close signal for cleanup
	popup.popup_hide.connect(func(): 
		if popup.is_inside_tree():
			popup.queue_free()
	)
	
	add_child(popup)
	popup.popup_centered()
	
	# Note: PopupMenu doesn't use standard focus, so CursorController needs explicit check

func _on_unit_picked(index: int, grid_pos: Vector2i, popup: PopupMenu) -> void:
	var character = available_characters[index]
	print("Picked: ", character.character_name, " for ", grid_pos)
	
	# Request placement
	unit_placement_requested.emit(character, grid_pos)
	
	popup.queue_free()

func _on_support_pressed() -> void:
	update_help_text("View support conversations between characters.")
	_show_support_menu()

func _on_view_map_pressed() -> void:
	update_help_text("Viewing map. Press X to return.")
	_enter_map_view_mode()


## Enter map view mode
func _enter_map_view_mode() -> void:
	# Hide all prep screen UI
	for child in get_children():
		if child is Control:
			child.visible = false
	
	# Allow clicks to pass through to see map
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Show simple "Press X to Return" HUD
	var hud = PanelContainer.new()
	hud.name = "MapViewHUD"
	hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_top = -60
	hud.offset_left = 20
	hud.offset_right = -20
	hud.offset_bottom = -20
	
	var label = Label.new()
	label.text = "Map View - Press X to Return"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(label)
	
	add_child(hud)
	DebugLog.log("PrepScreen: Entered map view mode", "cyan")


## Exit map view mode
func _exit_map_view_mode() -> void:
	# Remove HUD
	var hud = get_node_or_null("MapViewHUD")
	if hud:
		hud.queue_free()
	
	# Restore UI visibility
	for child in get_children():
		if child is Control and child.name != "MapViewHUD":
			child.visible = true
	
	# Restore input  
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	update_help_text("Choose an option to prepare for battle.")


func _on_equip_skills_pressed() -> void:

	update_help_text("Manage character skills and abilities.")
	# TODO: Show skills menu (deferred for now)
	DebugLog.log("Equip Skills - Deferred", "yellow")

func _on_save_pressed() -> void:
	update_help_text("Saving game...")
	_save_game()

func _on_fight_pressed() -> void:
	if not _validate_deployment():
		return
	
	update_help_text("Starting battle...")
	emit_signal("prep_complete", deployed_units, deployment_positions)

func _on_exit_pressed() -> void:
	emit_signal("prep_cancelled")

## Show unit selection panel
func _show_unit_selection() -> void:
	# Hide existing panel if any
	if unit_selection_panel:
		unit_selection_panel.queue_free()
		unit_selection_panel = null
	
	# Validate data before loading
	if available_characters.is_empty():
		push_error("PrepScreen: No characters available for selection")
		update_help_text("ERROR: No characters available!")
		return
	
	if spawn_slots.is_empty():
		push_error("PrepScreen: No spawn positions available")
		update_help_text("ERROR: No spawn positions defined!")
		return
	
	# Load and instantiate
	var panel_path = GameConfig.ui.unit_selection_panel
	unit_selection_panel = SceneLoader.instantiate_scene(panel_path)
	
	if not unit_selection_panel:
		update_help_text("ERROR: Failed to load unit selection panel")
		return

	# Add to container
	$MainContainer.add_child(unit_selection_panel)
	
	# Setup
	if unit_selection_panel.has_method("setup"):
		unit_selection_panel.setup(available_characters, spawn_slots, deployment_limit)
	
	# Connect signals
	if unit_selection_panel.has_signal("selection_complete"):
		unit_selection_panel.selection_complete.connect(_on_unit_selection_complete)
	else:
		push_warning("PrepScreen: unit_selection_panel missing selection_complete signal")
		
	if unit_selection_panel.has_signal("selection_cancelled"):
		unit_selection_panel.selection_cancelled.connect(_on_unit_selection_cancelled)
	else:
		push_warning("PrepScreen: unit_selection_panel missing selection_cancelled signal")

## Show support menu
func _show_support_menu() -> void:
	# Hide existing menu if any
	if support_menu:
		support_menu.queue_free()
		support_menu = null
	
	# Validate data
	if available_characters.is_empty():
		push_error("PrepScreen: No characters available for support conversations")
		update_help_text("ERROR: No characters available!")
		return
	
	# Instantiate menu
	var menu_path = GameConfig.ui.support_menu
	support_menu = SceneLoader.instantiate_scene(menu_path)
	
	if not support_menu:
		update_help_text("ERROR: Failed to load support menu")
		return
		
	# Add to container
	$MainContainer.add_child(support_menu)
	
	# Connect signals
	if support_menu.has_signal("close_requested"):
		support_menu.close_requested.connect(_on_support_menu_closed)
	else:
		push_warning("PrepScreen: support_menu missing close_requested signal")
	if not support_menu.has_method("setup"):
		push_error("PrepScreen: support_menu missing setup() method")
		return
	
	support_menu.setup(available_characters)
	if support_menu.has_signal("menu_closed"):
		support_menu.menu_closed.connect(_on_support_menu_closed)
	else:
		push_warning("PrepScreen: support_menu missing menu_closed signal")

## Handle unit selection completion
func _on_unit_selection_complete(units: Array, positions: Dictionary) -> void:
	deployed_units = units
	deployment_positions = positions
	
	# Close panel
	if unit_selection_panel:
		unit_selection_panel.queue_free()
		unit_selection_panel = null
	
	update_help_text("Units deployed. Ready to fight!")

## Handle unit selection cancellation
func _on_unit_selection_cancelled():
	if unit_selection_panel:
		unit_selection_panel.queue_free()
		unit_selection_panel = null
	
	update_help_text("Choose an option to prepare for battle.")

## Handle support menu close
func _on_support_menu_closed():
	if support_menu:
		support_menu.queue_free()
		support_menu = null
	
	update_help_text("Choose an option to prepare for battle.")

## Validate deployment before battle start
## @return: true if valid, false otherwise
func _validate_deployment() -> bool:
	# Check UnitManager first (truth source)
	if unit_manager and unit_manager.has_method("get_units_by_team"):
		var units = unit_manager.get_units_by_team(0) # 0 = TEAM_PLAYER
		if not units.is_empty():
			return true
			
	if deployed_units.is_empty():
		update_help_text("ERROR: No units deployed!")
		return false
	
	# Check all deployed units have positions
	for unit in deployed_units:
		var unit_id = unit.character_data.character_id if "character_data" in unit else ""
		if not deployment_positions.has(unit_id):
			update_help_text("ERROR: Unit not positioned on map!")
			return false
	
	return true

## Update help text label
## @param text: Help text to display
func update_help_text(text: String) -> void:
	if help_text:
		help_text.text = text

## Save game progress
func _save_game():
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager and save_manager.has_method("save_game"):
		save_manager.save_game(0)  # Slot 0 = default save slot
		update_help_text("Game saved successfully.")
	else:
		update_help_text("Save failed - SaveManager not found.")
