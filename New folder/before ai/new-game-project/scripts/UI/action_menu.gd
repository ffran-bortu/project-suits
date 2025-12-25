# action_menu.gd - UI for unit actions
extends Panel

signal attack_selected
signal end_turn_selected
signal menu_closed

@onready var attack_button: Button = $VBoxContainer/AttackButton
@onready var end_turn_button: Button = $VBoxContainer/EndTurnButton

var unit_manager = null

func _ready():
	# Validate buttons exist
	if not attack_button:
		push_error("ActionMenu: AttackButton not found!")
		return
	if not end_turn_button:
		push_error("ActionMenu: EndTurnButton not found!")
		return
	
	# Connect button signals
	attack_button.pressed.connect(_on_attack_pressed)
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

func show_at_position(world_position: Vector3):
	# Convert 3D world position to screen position
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		# Fallback: show at center of screen
		var viewport_size = get_viewport_rect().size
		position = viewport_size * 0.5 - size * 0.5
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
	screen_pos.y -= menu_size.y * 0.5  # Center vertically on unit
	
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

func _on_end_turn_pressed():
	end_turn_selected.emit()
	hide()

func _input(event):
	# Input processing is automatically disabled when not visible via _notification
	# Handle Z key to confirm focused button
	if event.is_action_pressed("select"):
		var focused = get_viewport().gui_get_focus_owner()
		# If no button has focus, focus the attack button first
		if focused == null or (focused != attack_button and focused != end_turn_button):
			if attack_button and not attack_button.disabled:
				attack_button.grab_focus()
				get_viewport().set_input_as_handled()
				return
			elif end_turn_button:
				end_turn_button.grab_focus()
				get_viewport().set_input_as_handled()
				return
		
		if focused == attack_button and not attack_button.disabled:
			_on_attack_pressed()
			get_viewport().set_input_as_handled()
		elif focused == end_turn_button and not end_turn_button.disabled:
			_on_end_turn_pressed()
			get_viewport().set_input_as_handled()
	
	# Handle X key to cancel
	if event.is_action_pressed("cancel"):
		menu_closed.emit()
		hide()
		get_viewport().set_input_as_handled()
	
	# Handle arrow keys for navigation
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
			var current_focus = get_viewport().gui_get_focus_owner()
			if current_focus == attack_button:
				end_turn_button.grab_focus()
			elif current_focus == end_turn_button:
				attack_button.grab_focus()
			get_viewport().set_input_as_handled()
	
	# Close menu if clicked outside (only on left mouse button press)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if not get_global_rect().has_point(mouse_pos):
			menu_closed.emit()
			hide()
			get_viewport().set_input_as_handled()

func update_actions(unit_has_moved: bool, unit_has_acted: bool):
	# Enable/disable buttons based on unit state
	# Attack is available if unit hasn't acted yet AND has valid targets
	var can_attack = false
	if not unit_has_acted and unit_manager and unit_manager.selected_unit:
		var unit = unit_manager.selected_unit
		
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
	
	# End turn is always available
	end_turn_button.disabled = false
	
	# Visual feedback for disabled state
	if attack_button.disabled:
		attack_button.modulate = Color(0.6, 0.6, 0.6, 1.0)  # Gray out when disabled
	else:
		attack_button.modulate = Color.WHITE
