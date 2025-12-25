"""
FILE: action_menu.gd
PURPOSE: Unit action menu UI for selecting attack, pair, split, or wait actions during tactical gameplay.

OVERVIEW:
Extends Panel to provide a context menu displayed next to the selected unit. Shows available actions (Attack,
Pair, Split, Wait) as buttons, dynamically enables/disables based on unit state (moved/acted), handles keyboard
and mouse input (Z to confirm, X to cancel, arrows to navigate), and positions itself onscreen converted from
3D world position. Validates attack targets, checks for adjacent allies for pairing, and adjacent empty spaces
for splitting duos.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Gets button references, creates Pair/Split buttons if missing, connects signals, sets "Wait" text
   - Uses: Initialization when menu enters scene tree  
   - Returns: void

2. _notification(what)
   - What it does: Enables/disables input processing based on visibility
   - Uses: Called automatically on visibility changes
   - Returns: void

3. show_at_position(world_position)
   - What it does: Converts 3D unit position to screen coords, positions menu, shows it, grabs focus
   - Uses: Displaying menu next to selected unit
   - Returns: void

4. _on_attack_pressed()
   - What it does: Emits attack_selected signal, hides menu
   - Uses: Player clicks Attack button
   - Returns: void

5. _on_pair_pressed()
   - What it does: Emits pair_selected signal, hides menu
   - Uses: Player clicks Pair button (solo units adjacent to allies)
   - Returns: void

6. _on_split_pressed()
   - What it does: Emits split_selected signal, hides menu
   - Uses: Player clicks Split button (duo units with empty adjacent space)
   - Returns: void

7. _on_end_turn_pressed()
   - What it does: Emits end_turn_selected signal, hides menu
   - Uses: Player clicks Wait button
   - Returns: void

8. _input(event)
   - What it does: Handles Z (confirm), X (cancel), arrow keys (navigation), outside clicks
   - Uses: Keyboard/mouse control while menu visible
   - Returns: void (sets input as handled)

9. update_actions(_unit_has_moved, unit_has_acted)
   - What it does: Enables/disables buttons based on unit state and validates targets/adjacencies
   - Uses: Called when showing menu to set available actions
   - Returns: void

10. _has_adjacent_solo_ally(unit)
    - What it does: Checks 4 adjacent cells for friendly SoloUnit
    - Uses: Determining if Pair button should show
    - Returns: bool

11. _has_empty_adjacent_space(unit)
    - What it does: Checks 4 adjacent cells for empty valid grid position
    - Uses: Determining if Split button should show
    - Returns: bool

12. show_as_map_menu(world_position)
    - What it does: Configures menu for empty tile interaction (End Turn only) and shows it
    - Uses: InteractionController when clicking empty space
    - Returns: void

NOTES:
- Extends Panel (Control node)
- Signals: attack_selected, pair_selected, split_selected, end_turn_selected, menu_closed
- Attack button disabled if no valid targets or unit has acted
- Pair button visible only for SoloUnit with adjacent solo ally, disabled if acted
- Split button visible only for DuoUnit with empty adjacent space, disabled if acted
- Wait button always enabled
- Uses "@export" for button references (defined in scene)
- Pair/Split buttons created programmatically if not in scene
- Input actions: "select" (Z), "cancel" (X), arrow keys
- Clicking outside menu emits menu_closed and hides
- focus_mode = FOCUS_ALL required for input handling
- mouse_filter = MOUSE_FILTER_STOP blocks clicks to nodes below
- Grays out disabled buttons (modulate 0.6)
- Requires unit_manager reference for target/ally checks
"""

# action_menu.gd - UI for unit actions
extends Panel

signal attack_selected
signal pair_selected
signal split_selected
signal item_selected
signal end_turn_selected
signal menu_closed

@onready var attack_button: Button = $VBoxContainer/AttackButton
var pair_button: Button = null  # Created programmatically in _ready
var split_button: Button = null  # Created programmatically in _ready
var item_button: Button = null   # Created programmatically in _ready
@onready var end_turn_button: Button = $VBoxContainer/EndTurnButton

var unit_manager: UnitManager = null

func _ready():
	# ... (VBox fetch logic remains same) ...
	var vbox = $VBoxContainer if has_node("VBoxContainer") else null
	
	# ... (Attack btn check) ...
	if not attack_button:
		push_error("ActionMenu: AttackButton not found!")
		return
	
	# Create Pair button if it doesn't exist
	if not has_node("VBoxContainer/PairButton") and vbox:
		pair_button = Button.new()
		pair_button.name = "PairButton"
		pair_button.text = "Pair"
		pair_button.custom_minimum_size = Vector2(100, 40)
		vbox.add_child(pair_button)
		vbox.move_child(pair_button, 1)  # After Attack button
	else:
		pair_button = $VBoxContainer/PairButton if has_node("VBoxContainer/PairButton") else null
	
	# Create Split button if it doesn't exist
	if not has_node("VBoxContainer/SplitButton") and vbox:
		split_button = Button.new()
		split_button.name = "SplitButton"
		split_button.text = "Split"
		split_button.custom_minimum_size = Vector2(100, 40)
		vbox.add_child(split_button)
		vbox.move_child(split_button, 2)  # After Pair button
	else:
		split_button = $VBoxContainer/SplitButton if has_node("VBoxContainer/SplitButton") else null

	# Create Item button if it doesn't exist
	if not has_node("VBoxContainer/ItemButton") and vbox:
		item_button = Button.new()
		item_button.name = "ItemButton"
		item_button.text = "Item"
		item_button.custom_minimum_size = Vector2(100, 40)
		vbox.add_child(item_button)
		vbox.move_child(item_button, 3) # After Split button
	else:
		item_button = $VBoxContainer/ItemButton if has_node("VBoxContainer/ItemButton") else null
		
	if not end_turn_button:
		push_error("ActionMenu: EndTurnButton not found!")
		return
	
	# Connect button signals
	attack_button.pressed.connect(_on_attack_pressed)
	if pair_button:
		pair_button.pressed.connect(_on_pair_pressed)
	if split_button:
		split_button.pressed.connect(_on_split_pressed)
	if item_button:
		item_button.pressed.connect(_on_item_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Update text to standard terminology
	end_turn_button.text = "Wait"
	
	# Start with input processing disabled
	set_process_input(false)
	
	# Hide by default
	hide()

# Override visibility handling to properly manage input processing
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		# Enable/disable input processing based on visibility
		set_process_input(visible)

func show_as_map_menu(world_position: Vector3):
	# Configure for map menu (End Turn only)
	if attack_button: attack_button.visible = false
	if pair_button: pair_button.visible = false
	if split_button: split_button.visible = false
	if item_button: item_button.visible = false
	
	if end_turn_button:
		end_turn_button.text = "End Turn"
		end_turn_button.disabled = false
	
	show_at_position(world_position)

func show_at_position(world_position: Vector3):
	# Convert 3D world position to screen position
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		# Fallback: show at center of screen
		var vp_size = get_viewport_rect().size
		position = vp_size * 0.5 - size * 0.5
		show()
		if attack_button:
			attack_button.grab_focus()
		return
	
	var screen_pos = camera.unproject_position(world_position)
	
	# Check if position is on screen and adjust if needed
	var viewport_size = get_viewport_rect().size
	var menu_size = size
	
	# Add offset to position menu to the right of unit
	screen_pos.x += 50
	screen_pos.y -= menu_size.y * 0.5  # Center vertically
	
	# Clamp to keep menu on screen
	screen_pos.x = clamp(screen_pos.x, 10, viewport_size.x - menu_size.x - 10)
	screen_pos.y = clamp(screen_pos.y, 10, viewport_size.y - menu_size.y - 10)
	
	# If unit is off-screen, show menu at center
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		screen_pos = viewport_size * 0.5 - menu_size * 0.5
	
	position = screen_pos
	show()
	
	# Wait a frame to ensure menu is fully visible before grabbing focus
	await get_tree().process_frame
	
	# Focus first available button
	if attack_button and not attack_button.disabled:
		attack_button.grab_focus()
	elif end_turn_button:
		end_turn_button.grab_focus()
	
	# Ensure we have focus - if not, try again next frame
	if get_viewport().gui_get_focus_owner() != attack_button and get_viewport().gui_get_focus_owner() != end_turn_button:
		await get_tree().process_frame
		if attack_button and not attack_button.disabled:
			attack_button.grab_focus()
		elif end_turn_button:
			end_turn_button.grab_focus()

func _on_attack_pressed():
	attack_selected.emit()
	hide()

func _on_pair_pressed():
	pair_selected.emit()
	hide()

func _on_split_pressed():
	split_selected.emit()
	hide()

func _on_end_turn_pressed():
	end_turn_selected.emit()
	hide()

func _on_item_pressed():
	item_selected.emit()
	hide()

func _input(event):
	# Input processing is automatically disabled when not visible via _notification
	# Handle Z key to confirm focused button
	if event is InputEventKey and event.pressed and event.keycode == KEY_Z:
		var focused = get_viewport().gui_get_focus_owner()
		
		# If no button has focus, focus the first visible button
		if focused == null:
			if attack_button and not attack_button.disabled:
				attack_button.grab_focus()
			elif pair_button and pair_button.visible and not pair_button.disabled:
				pair_button.grab_focus()
			elif split_button and split_button.visible and not split_button.disabled:
				split_button.grab_focus()
			elif end_turn_button:
				end_turn_button.grab_focus()
			get_viewport().set_input_as_handled()
			return
		
		# Confirm the focused button
		if focused == attack_button and not attack_button.disabled:
			_on_attack_pressed()
			get_viewport().set_input_as_handled()
		elif focused == pair_button and pair_button and not pair_button.disabled:
			_on_pair_pressed()
			get_viewport().set_input_as_handled()
		elif focused == split_button and split_button and not split_button.disabled:
			_on_split_pressed()
			get_viewport().set_input_as_handled()
		elif focused == end_turn_button and not end_turn_button.disabled:
			_on_end_turn_pressed()
			get_viewport().set_input_as_handled()
	
	# Handle X key to cancel (don't end turn, just close menu)
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		menu_closed.emit()
		hide()
		get_viewport().set_input_as_handled()
	
	# Handle arrow keys for navigation
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
			var current_focus = get_viewport().gui_get_focus_owner()
			
			# Build list of visible/enabled buttons
			var buttons = [attack_button]
			if pair_button and pair_button.visible and not pair_button.disabled:
				buttons.append(pair_button)
			if split_button and split_button.visible and not split_button.disabled:
				buttons.append(split_button)
			buttons.append(end_turn_button)
			
			# Find current index
			var current_index = -1
			for i in range(buttons.size()):
				if buttons[i] == current_focus:
					current_index = i
					break
			
			# Navigate
			if event.keycode == KEY_DOWN:
				var next_index = (current_index + 1) % buttons.size()
				buttons[next_index].grab_focus()
			elif event.keycode == KEY_UP:
				var prev_index = (current_index - 1 + buttons.size()) % buttons.size()
				buttons[prev_index].grab_focus()
			
			get_viewport().set_input_as_handled()
	
	# Close menu if clicked outside (only on left mouse button press)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if not get_global_rect().has_point(mouse_pos):
			menu_closed.emit()
			hide()
			get_viewport().set_input_as_handled()

func update_actions(_unit_has_moved: bool, unit_has_acted: bool):
	# Reset state from potential map menu mode
	if attack_button: attack_button.visible = true
	if end_turn_button: end_turn_button.text = "Wait"

	# Enable/disable buttons based on unit state
	# Attack is available if unit hasn't acted yet AND has valid targets
	var can_attack: bool = false
	if not unit_has_acted and unit_manager and unit_manager.selected_unit:
		var unit: Unit = unit_manager.selected_unit

		
		# Get attack range
		var min_range = 1
		var max_range = unit.attack_range
		if unit.has_method("get_attack_range_min"):
			min_range = unit.get_attack_range_min()
		if unit.has_method("get_attack_range_max"):
			max_range = unit.get_attack_range_max()
			
		var attack_cells = GridManager.get_attack_range(unit.grid_position, max_range, min_range)
		
		# Check if any enemy is in range
		for cell in attack_cells:
			var target = unit_manager.get_unit_at_position(cell)
			if target and target.team != unit.team and target.is_alive():
				can_attack = true
				break
	
	attack_button.disabled = not can_attack
	
	# Pair button: Show for Solo units with adjacent solo ally
	if pair_button and unit_manager and unit_manager.selected_unit:
		var unit: Unit = unit_manager.selected_unit
		pair_button.visible = unit is SoloUnit and _has_adjacent_solo_ally(unit)
		pair_button.disabled = unit_has_acted
	
	# Split button: Show for Duo units with empty adjacent space  
	if split_button and unit_manager and unit_manager.selected_unit:
		var unit: Unit = unit_manager.selected_unit
		split_button.visible = unit is DuoUnit and _has_empty_adjacent_space(unit)
		split_button.disabled = unit_has_acted
	
	# End turn is always available
	end_turn_button.disabled = false
	
	# Visual feedback for disabled state
	if attack_button.disabled:
		attack_button.modulate = GameConfig.get_color("ui_disabled")
	else:
		attack_button.modulate = Color.WHITE

## Check if unit has adjacent solo ally
func _has_adjacent_solo_ally(unit: Unit) -> bool:
	if not unit_manager:
		return false
	var adjacent = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for offset in adjacent:
		var cell = unit.grid_position + offset
		var other = unit_manager.get_unit_at_position(cell)
		if other and other is SoloUnit and other.team == unit.team:
			return true
	return false

## Check if unit has empty adjacent space
func _has_empty_adjacent_space(unit: Unit) -> bool:
	if not unit_manager:
		return false
	var adjacent = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for offset in adjacent:
		var cell = unit.grid_position + offset
		if GridManager.is_within_grid(cell):
			var other = unit_manager.get_unit_at_position(cell)
			if not other:
				return true
	return false
