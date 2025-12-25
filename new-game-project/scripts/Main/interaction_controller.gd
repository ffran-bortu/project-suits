"""
FILE: interaction_controller.gd
PURPOSE: Manages player interaction, input, and cursor logic.
OVERVIEW:
Extracts interaction responsibilities from Main.gd. Handles cursor selection, movement,
action menu requests, and targeting state.
"""
extends Node
class_name InteractionController

# Dependencies
var unit_manager: UnitManager
var combat_manager: Node
var phase_manager: Node
var grid_3d: Node3D
var cursor_controller: Node  # CursorController class doesn't have class_name
var action_menu: Panel
var inventory_menu: InventoryMenu # Added
var target_selector: Node
var game_state: GameStateManager
var level_manager: LevelManager
var camera_controller: Node3D
var units_container: Node3D # Added for spawning units

# State Tracking
# State Tracking
var hovered_enemy_unit: Unit = null
var _pending_attack_pos: Vector2i = Vector2i(-1, -1)
var deployment_spawn_tiles: Array[Vector2i] = []

# Dependencies Injection
func set_dependencies(
	_unit_manager: UnitManager,
	_combat_manager: Node,
	_phase_manager: Node,
	_grid_3d: Node3D,
	_cursor_controller: Node,
	_action_menu: Panel,
	_inventory_menu: InventoryMenu, # Added
	_target_selector: Node,
	_game_state: GameStateManager,
	_level_manager: LevelManager,
	_camera_controller: Node3D
) -> void:
	unit_manager = _unit_manager
	combat_manager = _combat_manager
	phase_manager = _phase_manager
	grid_3d = _grid_3d
	cursor_controller = _cursor_controller
	action_menu = _action_menu
	inventory_menu = _inventory_menu # Added
	target_selector = _target_selector
	game_state = _game_state
	level_manager = _level_manager
	camera_controller = _camera_controller
	
	_connect_signals()

func set_units_container(container: Node3D) -> void:
	units_container = container

# --- Input Handling ---

func _input(event: InputEvent) -> void:
	if not game_state.is_input_allowed():
		return
		
	if event.is_action_pressed("rotate_camera_left"):
		if camera_controller and camera_controller.has_method("rotate_camera_counterclockwise"):
			camera_controller.rotate_camera_counterclockwise()
	elif event.is_action_pressed("rotate_camera_right"):
		if camera_controller and camera_controller.has_method("rotate_camera_clockwise"):
			camera_controller.rotate_camera_clockwise()

func _connect_signals() -> void:
	# Cursor signals
	if cursor_controller:
		if not cursor_controller.cursor_selected.is_connected(_on_cursor_selected):
			cursor_controller.cursor_selected.connect(_on_cursor_selected)
		if not cursor_controller.cursor_moved.is_connected(_on_cursor_moved):
			cursor_controller.cursor_moved.connect(_on_cursor_moved)
		if not cursor_controller.cursor_cancelled.is_connected(_on_cursor_cancelled):
			cursor_controller.cursor_cancelled.connect(_on_cursor_cancelled)
	
	# Action Menu signals
	if action_menu:
		if not action_menu.attack_selected.is_connected(_on_attack_selected):
			action_menu.attack_selected.connect(_on_attack_selected)
		if not action_menu.pair_selected.is_connected(_on_pair_selected):
			action_menu.pair_selected.connect(_on_pair_selected)
		if not action_menu.split_selected.is_connected(_on_split_selected):
			action_menu.split_selected.connect(_on_split_selected)
		if not action_menu.item_selected.is_connected(_on_action_menu_item_selected): # Added
			action_menu.item_selected.connect(_on_action_menu_item_selected)
		if not action_menu.end_turn_selected.is_connected(_on_end_turn_selected):
			action_menu.end_turn_selected.connect(_on_end_turn_selected)
		if not action_menu.menu_closed.is_connected(_on_menu_closed):
			action_menu.menu_closed.connect(_on_menu_closed)

	# Inventory Menu signals
	if inventory_menu:
		if not inventory_menu.item_selected.is_connected(_on_inventory_item_selected):
			inventory_menu.item_selected.connect(_on_inventory_item_selected)
		if not inventory_menu.menu_closed.is_connected(_on_inventory_menu_closed):
			inventory_menu.menu_closed.connect(_on_inventory_menu_closed)

	# Target Selector signals
	if target_selector:
		if not target_selector.target_confirmed.is_connected(_on_target_confirmed):
			target_selector.target_confirmed.connect(_on_target_confirmed)
		if not target_selector.targeting_cancelled.is_connected(_on_targeting_cancelled):
			target_selector.targeting_cancelled.connect(_on_targeting_cancelled)
			
	# SignalBus
	if not SignalBus.action_menu_requested.is_connected(_on_action_menu_requested):
		SignalBus.action_menu_requested.connect(_on_action_menu_requested)
		
	# GameState signals
	if game_state and not game_state.attack_targeting_started.is_connected(_on_attack_targeting_started):
		game_state.attack_targeting_started.connect(_on_attack_targeting_started)

	# Deployment Signals
	if not SignalBus.deployment_started.is_connected(_on_deployment_started):
		print("InteractionController: Connecting to deployment_started signal")
		SignalBus.deployment_started.connect(_on_deployment_started)
	else:
		print("InteractionController: Already connected to deployment_started signal")

# ... (Existing code) ...

func _on_action_menu_item_selected() -> void:
	if not unit_manager.selected_unit: return
	
	game_state.change_state(game_state.GameState.ITEM_SELECTION)
	if inventory_menu:
		inventory_menu.show_inventory(unit_manager.selected_unit)

func _on_inventory_item_selected(item: Resource, action_type: String) -> void:
	var unit = unit_manager.selected_unit
	if not unit: return
	
	if action_type == "use":
		if unit.has_method("use_item"):
			if unit.use_item(item):
				print("Item used: ", item.item_name)
				
				# End turn
				if phase_manager:
					phase_manager.end_current_unit_turn()
					
				# Close menu
				if inventory_menu: inventory_menu.hide()
				game_state.change_state(game_state.GameState.PLAYER_TURN)
				
	elif action_type == "equip":
		if unit.inventory:
			unit.inventory.equip_item(item)
			print("Equipped: ", item.weapon_name)
			# Don't end turn for equipping? Or maybe yes? FE usually allows free equip in menu.
			# For now, just refresh menu or close it. 
			# Let's keep menu open to see change.
			if inventory_menu: inventory_menu.show_inventory(unit)

func _on_inventory_menu_closed() -> void:
	# Return to Action Menu
	game_state.change_state(game_state.GameState.ACTION_SELECT)
	if unit_manager.selected_unit:
		var pos = GridManager.grid_to_world_3d(unit_manager.selected_unit.grid_position)
		SignalBus.action_menu_requested.emit(pos)

			

# --- Cursor Handlers ---

func _on_deployment_started(tiles: Array[Vector2i]) -> void:
	print("InteractionController: _on_deployment_started signal received!")
	print("InteractionController: Spawn tiles count: %d" % tiles.size())
	print("InteractionController: Tiles data: ", tiles)
	deployment_spawn_tiles = tiles
	
	if not grid_3d:
		push_error("InteractionController: grid_3d is NULL! Cannot highlight deployment tiles.")
		return
	
	if not grid_3d.has_method("highlight_deployment_tiles"):
		push_error("InteractionController: grid_3d does not have method 'highlight_deployment_tiles'!")
		return
	
	print("InteractionController: Calling grid_3d.highlight_deployment_tiles() with %d tiles" % tiles.size())
	grid_3d.highlight_deployment_tiles(tiles)
	print("InteractionController: grid_3d.highlight_deployment_tiles() completed")
	
	# Move cursor to first spawn tile if available
	if not tiles.is_empty() and cursor_controller:
		print("InteractionController: Moving cursor to first spawn tile: ", tiles[0])
		cursor_controller.set_position(tiles[0])

func _handle_deployment_selection(grid_pos: Vector2i) -> void:
	if grid_pos in deployment_spawn_tiles:
		print("InteractionController: Valid deployment tile clicked at ", grid_pos)
		SignalBus.deployment_tile_clicked.emit(grid_pos)
	else:
		print("InteractionController: Invalid deployment tile clicked at ", grid_pos)
		print("InteractionController: Current valid tiles: ", deployment_spawn_tiles)
		# Optional: Play error sound or feedback

func _on_cursor_selected(grid_pos: Vector2i) -> void:
	match game_state.current_state:
		game_state.GameState.PLAYER_TURN:
			_handle_player_turn_selection(grid_pos)
			
		game_state.GameState.DEPLOYMENT:
			_handle_deployment_selection(grid_pos)
		
		game_state.GameState.UNIT_SELECTED:
			_handle_unit_move_confirmation(grid_pos)
		
		game_state.GameState.ATTACK_TARGETING:
			if unit_manager.selected_unit and combat_manager:
				print("InteractionController: Cursor selected in ATTACK_TARGETING at ", grid_pos)
				
			if unit_manager.selected_unit and combat_manager:
				print("InteractionController: Cursor selected in ATTACK_TARGETING at ", grid_pos)
				
				# Delegate entirely to Combat Forecast UI
				# We no longer double-check _pending_attack_pos here.
				# Clicking a target simply updates/shows the forecast.
				# The actual attack is triggered by the 'confirmed' signal from CombatForecast (handled in Main.gd).
				
				combat_manager.handle_attack_target_selection(grid_pos, unit_manager.selected_unit)
				
				# Lock cursor to target if valid? 
				# Actually, handle_attack_target_selection just calculates stats and emits signal.
				# If we want to "lock" the camera or selection visually, we can do it,
				# but for now letting the Forecast take focus and handle Z/X is correct.
				
				# Just updated pending to current for consistency if needed by other systems, 
				# though we aren't using it for confirmation anymore.
				if combat_manager.current_target and combat_manager.current_target.grid_position == grid_pos:
					_pending_attack_pos = grid_pos
				else:
					_pending_attack_pos = Vector2i(-1, -1)

func _handle_player_turn_selection(grid_pos: Vector2i) -> void:
	var unit: Unit = unit_manager.get_unit_at_position(grid_pos)
	if unit:
		if unit.team == UnitManager.TEAM_PLAYER and unit.is_alive():
			if not unit.has_acted:
				unit_manager.select_unit(unit)
			else:
				print("Unit has already acted")
	else:
		# Empty tile -> Show Map Menu (End Turn)
		if action_menu:
			print("InteractionController: Empty tile clicked, showing Map Menu")
			game_state.change_state(game_state.GameState.ACTION_SELECT)
			var world_pos = GridManager.grid_to_world_3d(grid_pos)
			action_menu.show_as_map_menu(world_pos)

func _handle_unit_move_confirmation(grid_pos: Vector2i) -> void:
	var selected_unit: Unit = unit_manager.selected_unit
	if not selected_unit:
		game_state.cancel_unit_selection()
		return
	
	if grid_pos == selected_unit.grid_position:
		# Clicked on self -> Go to action menu
		game_state.transition_to_action_select()
		await get_tree().process_frame
		var unit_world_pos: Vector3 = GridManager.grid_to_world_3d(selected_unit.grid_position)
		SignalBus.action_menu_requested.emit(unit_world_pos)
	else:
		unit_manager.move_selected_unit_to(grid_pos)

func _on_cursor_moved(grid_pos: Vector2i) -> void:
	if camera_controller and camera_controller.has_method("focus_on_position"):
		camera_controller.focus_on_position(grid_pos)
	
	if grid_3d:
		grid_3d.highlight_cursor_position(grid_pos)
	
	# Manage Enemy HP Bar Hover logic
	var unit_at_pos: Unit = unit_manager.get_unit_at_position(grid_pos)
	_update_hovered_unit_ui(unit_at_pos)
	
	# Update Attack Forecast if targeting
	if game_state.current_state == game_state.GameState.ATTACK_TARGETING:
		if unit_manager.selected_unit and combat_manager:
			# Update forecast (visual only, doesn't lock target)
			combat_manager.handle_attack_target_selection(grid_pos, unit_manager.selected_unit)
			# Reset pending confirmation if we moved cursor so we enforce "click to select, click to confirm"
			_pending_attack_pos = Vector2i(-1, -1)
	
	# Show path preview if enabled
	if game_state.current_state == game_state.GameState.UNIT_SELECTED:
		if unit_manager.selected_unit and unit_manager.is_position_in_movement_range(grid_pos):
			var path: Array[Vector2i] = unit_manager.get_path_to_target(grid_pos)
			if not path.is_empty() and grid_3d:
				grid_3d.draw_path(path)
		elif grid_3d:
			grid_3d.clear_path()

func _update_hovered_unit_ui(unit: Unit) -> void:
	# Validate existing hovered unit
	if hovered_enemy_unit and not is_instance_valid(hovered_enemy_unit):
		hovered_enemy_unit = null

	if unit and unit.team == UnitManager.TEAM_ENEMY:
		if hovered_enemy_unit != unit:
			# Hide old
			if hovered_enemy_unit:
				_toggle_hp_bar(hovered_enemy_unit, false)
			# Show new
			hovered_enemy_unit = unit
			_toggle_hp_bar(hovered_enemy_unit, true)
	else:
		# Hide existing if we moved off an enemy
		if hovered_enemy_unit:
			_toggle_hp_bar(hovered_enemy_unit, false)
			hovered_enemy_unit = null

func _toggle_hp_bar(unit: Unit, show_hp_bar: bool) -> void:
	if unit and unit.has_node("HPBar3D"):
		var hp_bar = unit.get_node("HPBar3D")
		if show_hp_bar and hp_bar.has_method("show_hp_bar"):
			hp_bar.show_hp_bar()
		elif not show_hp_bar and hp_bar.has_method("hide_hp_bar"):
			hp_bar.hide_hp_bar()

func _on_cursor_cancelled() -> void:
	_pending_attack_pos = Vector2i(-1, -1)
	
	if hovered_enemy_unit:
		_toggle_hp_bar(hovered_enemy_unit, false)
		hovered_enemy_unit = null
	
	match game_state.current_state:
		game_state.GameState.UNIT_SELECTED:
			unit_manager.deselect_current_unit()
			if grid_3d:
				grid_3d.clear_path()
		
		game_state.GameState.ATTACK_TARGETING:
			if grid_3d:
				grid_3d.clear_attack_highlights()
			
			# Clear cursor targets
			cursor_controller.valid_targets.clear()
			cursor_controller.current_target_index = 0
			
			# Snap cursor back to unit position
			if unit_manager.selected_unit:
				cursor_controller.grid_position = unit_manager.selected_unit.grid_position
				cursor_controller.update_cursor_position()
			
			game_state.transition_to_action_select()
			if unit_manager.selected_unit:
				var unit_world_pos: Vector3 = GridManager.grid_to_world_3d(unit_manager.selected_unit.grid_position)
				SignalBus.action_menu_requested.emit(unit_world_pos)
		
		game_state.GameState.ACTION_SELECT:
			unit_manager.deselect_current_unit()
			if action_menu:
				action_menu.hide()
				# Return to player turn explicitly
				game_state.change_state(game_state.GameState.PLAYER_TURN)

# --- Action Menu Handlers ---

func _on_action_menu_requested(unit_world_pos: Vector3) -> void:
	if unit_manager.selected_unit:
		action_menu.update_actions(
			unit_manager.selected_unit.has_moved,
			unit_manager.selected_unit.has_acted
		)
		action_menu.show_at_position(unit_world_pos)

func _on_attack_selected() -> void:
	print("InteractionController: Attack selected. Calling start_attack_targeting()")
	game_state.start_attack_targeting()

func _on_end_turn_selected() -> void:
	if unit_manager.selected_unit:
		# Unit Action: Wait
		if phase_manager:
			phase_manager.end_current_unit_turn()
	else:
		# Map Action: End Player Turn
		print("InteractionController: Ending Player Turn via Map Menu")
		if phase_manager and phase_manager.has_method("end_player_turn"):
			phase_manager.end_player_turn()
		else:
			# Fallback if method missing
			print("PhaseManager missing end_player_turn, forcing turn switch")
			game_state.change_state(game_state.GameState.ENEMY_TURN)
			SignalBus.enemy_turn_started.emit()

func _on_menu_closed() -> void:
	if game_state.current_state == game_state.GameState.ACTION_SELECT:
		# Don't end turn on cancel. 
		# Restore unit to previous position and deselect
		if unit_manager and unit_manager.selected_unit:
			# Revert visual and grid position
			# Assuming unit has 'previous_grid_position' or similar logic in UnitManager
			unit_manager.revert_selected_unit_movement()
			
			# Also snap cursor and camera back to unit
			if cursor_controller:
				# Force update cursor position
				cursor_controller.grid_position = unit_manager.selected_unit.grid_position
				if cursor_controller.has_method("update_cursor_position"):
					cursor_controller.update_cursor_position()
			
			if camera_controller and camera_controller.has_method("focus_on_position"):
				print("InteractionController: Snapping camera to %s" % unit_manager.selected_unit.grid_position)
				camera_controller.focus_on_position(unit_manager.selected_unit.grid_position)
			
		unit_manager.deselect_current_unit()
		game_state.change_state(game_state.GameState.PLAYER_TURN)
		print("InteractionController: Menu closed, unit movement reverted (Turn preserved)")

func _on_pair_selected() -> void:
	if not unit_manager or not unit_manager.selected_unit:
		return
	
	var acting_unit = unit_manager.selected_unit
	if not acting_unit is SoloUnit:
		return
	
	# Find adjacent solo allies
	var adjacent_allies = []
	var adjacent_offsets = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for offset in adjacent_offsets:
		var cell = acting_unit.grid_position + offset
		var other = unit_manager.get_unit_at_position(cell)
		if other and other is SoloUnit and other.team == acting_unit.team:
			adjacent_allies.append(other)
	
	if adjacent_allies.is_empty():
		return
	
	if action_menu:
		action_menu.hide()
	
	game_state.change_state(game_state.GameState.PAIR_TARGETING)
	
	if grid_3d and grid_3d.has_method("highlight_attack_range"):
		var target_positions: Array[Vector2i] = []
		for ally in adjacent_allies:
			target_positions.append(ally.grid_position)
		grid_3d.highlight_attack_range(target_positions)
	
	target_selector.start_targeting(adjacent_allies, cursor_controller)

func _on_split_selected() -> void:
	if not unit_manager or not unit_manager.selected_unit:
		return
	
	var acting_unit = unit_manager.selected_unit
	if not acting_unit is DuoUnit:
		return
	
	var empty_cells = []
	var adjacent_offsets = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for offset in adjacent_offsets:
		var cell = acting_unit.grid_position + offset
		if GridManager.is_within_grid(cell):
			var other = unit_manager.get_unit_at_position(cell)
			if not other:
				empty_cells.append(cell)
	
	if empty_cells.is_empty():
		return
	
	if action_menu:
		action_menu.hide()
	
	game_state.change_state(game_state.GameState.SPLIT_TARGETING)
	
	if grid_3d and grid_3d.has_method("highlight_attack_range"):
		grid_3d.highlight_attack_range(empty_cells)
	
	target_selector.start_targeting(empty_cells, cursor_controller)

func _on_target_confirmed(target) -> void:
	var current_state = game_state.current_state
	
	if grid_3d and grid_3d.has_method("clear_attack_highlights"):
		grid_3d.clear_attack_highlights()
	
	if current_state == game_state.GameState.PAIR_TARGETING:
		var target_unit = target if target is Unit else unit_manager.get_unit_at_position(target)
		if target_unit:
			_execute_pair(target_unit)
			
	elif current_state == game_state.GameState.SPLIT_TARGETING:
		var target_pos = target if target is Vector2i else Vector2i.ZERO
		if target_pos != Vector2i.ZERO:
			_execute_split(target_pos)
	
	# Return to player turn
	if game_state.current_state != game_state.GameState.ENEMY_TURN:
		game_state.change_state(game_state.GameState.PLAYER_TURN)

## Execute pair with selected ally
func _execute_pair(target_ally: Node) -> void:
	if not unit_manager or not unit_manager.selected_unit:
		return
	
	var acting_unit = unit_manager.selected_unit
	var other = target_ally
	
	# Store data before removal
	var duo_pos = other.grid_position
	var duo_team = acting_unit.team
	var char_a = acting_unit.character
	var char_b = other.character
	
	# Unregister both solos FIRST
	unit_manager.remove_unit(acting_unit)
	unit_manager.remove_unit(other)
	
	# Create duo from scene
	var duo_scene = load("res://scenes/duo_unit.tscn")
	var duo = duo_scene.instantiate()
	duo.team = duo_team
	duo.grid_position = duo_pos
	duo.position = GridManager.grid_to_world_3d(duo_pos)
	
	# Add to scene
	if units_container:
		units_container.add_child(duo)
	else:
		push_error("InteractionController: units_container not set! Cannot spawn duo.")
		return
	
	# Setup duo
	duo.setup_duo(char_a, char_b, true)
	
	# Manual visual setup
	duo.setup_visual(3.0, duo_team == 0)
	duo.visible = true # Ensure visible (Player team defaults to hidden)
	
	# Register
	unit_manager.register_unit(duo)
	
	# Remove solos
	acting_unit.queue_free()
	other.queue_free()
	
	# End turn
	duo.has_acted = true
	duo.has_moved = true
	
	print("Paired into: %s" % duo.unit_name)
	
	# Check turn end
	if phase_manager and phase_manager.has_method("_check_all_player_units_completed"):
		phase_manager._check_all_player_units_completed()

## Execute split to selected position
func _execute_split(target_pos: Vector2i) -> void:
	if not unit_manager or not unit_manager.selected_unit:
		return
	
	var acting_unit = unit_manager.selected_unit
	
	# Split duo
	var solos = acting_unit.split_duo(target_pos)
	var solo1 = solos[0]
	var solo2 = solos[1]
	
	# Add to scene
	if units_container:
		units_container.add_child(solo1)
		units_container.add_child(solo2)
	else:
		push_error("InteractionController: units_container not set! Cannot spawn solos.")
		return
	
	# Remove duo first
	unit_manager.remove_unit(acting_unit)
	
	# Manual visual setup
	solo1.setup_visual(2.0, solo1.team == 0)
	solo1.visible = true
	solo2.setup_visual(2.0, solo2.team == 0)
	solo2.visible = true
	
	# Register both
	unit_manager.register_unit(solo1)
	unit_manager.register_unit(solo2)
	
	# Ensure turn ended
	solo1.has_acted = true
	solo1.has_moved = true
	solo2.has_acted = true
	solo2.has_moved = true
	
	# Remove duo
	acting_unit.queue_free()
	
	print("Split into: %s and %s" % [solo1.unit_name, solo2.unit_name])
	
	# Check turn end
	if phase_manager and phase_manager.has_method("_check_all_player_units_completed"):
		phase_manager._check_all_player_units_completed()

func _on_targeting_cancelled() -> void:
	if grid_3d and grid_3d.has_method("clear_attack_highlights"):
		grid_3d.clear_attack_highlights()
	
	# Logic to return to action select or whatever was appropriate
	print("Targeting cancelled")
	game_state.change_state(game_state.GameState.ACTION_SELECT)
	if unit_manager.selected_unit:
		var unit_world_pos: Vector3 = GridManager.grid_to_world_3d(unit_manager.selected_unit.grid_position)
		SignalBus.action_menu_requested.emit(unit_world_pos)

func _on_attack_targeting_started() -> void:
	print("InteractionController: _on_attack_targeting_started()")
	if not unit_manager.selected_unit:
		print("InteractionController: No selected unit!")
		if phase_manager:
			phase_manager.end_current_unit_turn()
		return
	
	var unit: Unit = unit_manager.selected_unit
	var min_range: int = unit.get_attack_range_min() if unit.has_method("get_attack_range_min") else 1
	var max_range: int = unit.get_attack_range_max() if unit.has_method("get_attack_range_max") else unit.attack_range
	
	var attack_cells: Array[Vector2i] = GridManager.get_attack_range(unit.grid_position, max_range, min_range)
	if grid_3d:
		grid_3d.highlight_attack_range(attack_cells)
	
	# Find all valid enemy targets in attack range
	var valid_targets: Array[Vector2i] = []
	for cell in attack_cells:
		var unit_at_cell = unit_manager.get_unit_at_position(cell)
		if unit_at_cell and unit_at_cell.team != UnitManager.TEAM_PLAYER: # Assuming player is targeting non-player
			valid_targets.append(cell)
	
	# Auto-snap cursor to first valid target
	if valid_targets.size() > 0:
		if cursor_controller:
			var first_target_pos = valid_targets[0]
			cursor_controller.grid_position = first_target_pos
			cursor_controller.update_cursor_position()
			cursor_controller.valid_targets = valid_targets
			cursor_controller.current_target_index = 0
			cursor_controller.cursor_moved.emit(first_target_pos)
			cursor_controller.get_parent().visible = true
	else:
		# No valid targets - cancel attack targeting
		print("No valid targets in attack range, cancelling attack")
		game_state.cancel_attack_targeting()
