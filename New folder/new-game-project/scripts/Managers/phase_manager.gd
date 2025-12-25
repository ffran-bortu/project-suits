# phase_manager.gd - Simplified and fixed
extends Node

@onready var unit_manager = get_node("../UnitManager")
@onready var game_state = get_node("/root/GameStateManager")

var grid_3d: Node = null
var action_menu: Panel = null
var combat_manager: Node = null

func set_dependencies(grid_node: Node, menu: Panel, combat_mgr: Node):
	grid_3d = grid_node
	action_menu = menu
	combat_manager = combat_mgr

func _ready():
	# Connect to game state signals
	game_state.player_turn_started.connect(_on_player_turn_started)
	game_state.enemy_turn_started.connect(_on_enemy_turn_started)

func _on_player_turn_started():
	print("=== PLAYER TURN STARTED ===")
	
	# Reset ALL player units
	var player_units = unit_manager.get_units_by_team(0)
	for unit in player_units:
		if unit.is_alive():
			unit.reset_turn_state()
			print("Reset unit: ", unit.unit_name)
		else:
			print("Skipping dead unit: ", unit.unit_name)
	
	# Hide action menu if visible
	if action_menu:
		action_menu.hide()
	
	# Clear any highlights
	if grid_3d:
		grid_3d.clear_attack_highlights()
		grid_3d.clear_path()
	
	print("=== READY FOR PLAYER INPUT ===")

func _on_enemy_turn_started():
	print("=== ENEMY TURN STARTED ===")
	
	# Reset enemy units
	var enemy_units = unit_manager.get_units_by_team(1)
	for unit in enemy_units:
		if unit.is_alive():
			unit.reset_turn_state()
	
	print("Found ", enemy_units.size(), " enemy units")
	
	if enemy_units.size() == 0:
		print("No enemy units, skipping enemy turn")
		_end_enemy_turn()
		return
	
	# Process each enemy one by one
	await _process_enemy_actions(enemy_units)
	
	_end_enemy_turn()

func _process_enemy_actions(enemy_units: Array):
	for enemy in enemy_units:
		if not enemy.is_alive():
			continue
		
		print("Enemy ", enemy.unit_name, " taking turn")
		
		# Find closest player
		var target = unit_manager.find_closest_player_unit(enemy)
		
		if target and target.is_alive():
			# Move toward target if possible
			var move_pos = unit_manager.get_best_move_towards_target(enemy, target.grid_position)
			
			if move_pos != enemy.grid_position:
				print(enemy.unit_name, " moving to ", move_pos)
				unit_manager.move_unit_to(enemy, move_pos)
				await enemy.movement_finished
			else:
				print(enemy.unit_name, " cannot move")
			
			# After movement, check if can attack
			if target.is_alive():
				var attack_cells = GridManager.get_attack_range(enemy.grid_position, enemy.attack_range)
				if target.grid_position in attack_cells:
					print(enemy.unit_name, " attacking ", target.unit_name)
					combat_manager.perform_attack(enemy, target)
					await get_tree().create_timer(1.0).timeout  # Wait for attack
			
			enemy.mark_as_acted()
		else:
			print(enemy.unit_name, " has no target, ending turn")
			enemy.mark_as_acted()
		
		# Small pause between enemy actions
		await get_tree().create_timer(0.5).timeout

func _end_enemy_turn():
	print("=== ENEMY TURN FINISHED ===")
	# Wait a moment then start player turn
	await get_tree().create_timer(1.0).timeout
	game_state.finish_enemy_turn()

func end_current_unit_turn():
	print("=== ENDING CURRENT UNIT TURN ===")
	
	var current_unit = unit_manager.selected_unit
	
	if current_unit:
		print("Unit ", current_unit.unit_name, " ending turn")
		
		# Mark unit as done (both moved and acted)
		current_unit.mark_as_moved()
		current_unit.mark_as_acted()
	
	# Clean up UI
	unit_manager.deselect_current_unit()
	
	if action_menu:
		action_menu.hide()
	
	if grid_3d:
		grid_3d.clear_attack_highlights()
		grid_3d.clear_path()
	
	# Check if all player units have completed their turns
	_check_all_player_units_completed()

func _check_all_player_units_completed():
	var player_units = unit_manager.get_units_by_team(0)
	var all_completed = true
	
	for unit in player_units:
		if unit.is_alive() and not unit.has_acted:
			all_completed = false
			break
	
	if all_completed:
		print("=== ALL PLAYER UNITS HAVE COMPLETED TURNS ===")
		print("Starting enemy turn...")
		game_state.start_enemy_turn()
	else:
		print("=== MORE PLAYER UNITS CAN ACT ===")
		game_state.end_unit_turn()
