# main.gd - Root script for the game (3D version)
extends Node3D

@onready var cursor_controller = $World/Cursor/CursorController  # The cursor controller script
@onready var units_container = $World/Units
@onready var unit_manager = $GameManager/UnitManager
@onready var grid_3d = $World/Grid/Grid3D
@onready var game_state = get_node("/root/GameStateManager")
@onready var camera_3d = $CameraController/Camera3D
@onready var camera_controller = $CameraController
@onready var action_menu: Panel = $UICanvas/ActionMenu
@onready var phase_manager = $GameManager/PhaseManager
@onready var combat_manager = $GameManager/CombatManager
@onready var battle_manager = $GameManager/BattleManager
@onready var victory_screen = $UICanvas/VictoryScreen
@onready var defeat_screen = $UICanvas/DefeatScreen
@onready var combat_forecast_scene = preload("res://scenes/ui/combat_forecast.tscn")
var combat_forecast = null
var hovered_enemy_unit = null  # Track which enemy unit is currently being hovered
var map_selection_dialog: AcceptDialog = null

func _ready():
	print("=== GAME STARTING ===")
	
	# Initialize GameConfig materials
	GameConfig.init_materials()
	print("GameConfig materials initialized")
	
	# Validate all @onready node references
	var validation_failed = false
	
	if not cursor_controller:
		push_error("Main: CursorController node not found at $World/Cursor/CursorController")
		validation_failed = true
	
	if not units_container:
		push_error("Main: Units container not found at $World/Units")
		validation_failed = true
	
	if not unit_manager:
		push_error("Main: UnitManager not found at $GameManager/UnitManager")
		validation_failed = true
	
	if not grid_3d:
		push_error("Main: Grid3D not found at $World/Grid/Grid3D")
		validation_failed = true
	
	if not camera_3d:
		push_error("Main: Camera3D not found at $CameraController/Camera3D")
		validation_failed = true
	
	if not camera_controller:
		push_error("Main: CameraController not found at $CameraController")
		validation_failed = true
	
	if not action_menu:
		push_error("Main: ActionMenu not found at $UICanvas/ActionMenu")
		validation_failed = true
	
	if not phase_manager:
		push_error("Main: PhaseManager not found at $GameManager/PhaseManager")
		validation_failed = true
	
	if not combat_manager:
		push_error("Main: CombatManager not found at $GameManager/CombatManager")
		validation_failed = true
	
	if not game_state:
		push_error("Main: GameStateManager autoload not found!")
		validation_failed = true
	
	if validation_failed:
		push_error("Main: Critical node references missing! Check scene structure.")
		return
	
	# Instantiate Forecast UI
	combat_forecast = combat_forecast_scene.instantiate()
	$UICanvas.add_child(combat_forecast)
	combat_forecast.hide()
	combat_forecast.confirmed.connect(_on_forecast_confirmed)
	combat_forecast.cancelled.connect(_on_forecast_cancelled)
	
	# Connect CombatManager signals
	combat_manager.combat_forecast_requested.connect(_on_combat_forecast_requested)
	
	# 1. CRITICAL: Initialize GridManager dependencies
	GridManager.unit_manager = unit_manager
	
	# 2. CRITICAL: Initialize UnitManager dependencies
	unit_manager.set_grid_3d(grid_3d)
	
	# 3. Ensure grid is properly sized
	print("Grid size: ", GridManager.grid_size)
	print("Cell size: ", GridManager.cell_size)
	print("3D test: Grid (2,3) -> ", GridManager.grid_to_world_3d(Vector2i(2, 3)))
	
	setup_camera()
	
	# Load EnemyAI script and add to GameManager
	var enemy_ai_script = preload("res://scripts/Managers/enemy_ai.gd")
	var enemy_ai = Node.new()
	enemy_ai.name = "EnemyAI"
	enemy_ai.set_script(enemy_ai_script)
	$GameManager.add_child(enemy_ai)
	
	# Initialize managers with dependencies
	phase_manager.set_dependencies(grid_3d, action_menu, combat_manager)
	combat_manager.set_dependencies(grid_3d, phase_manager)
	action_menu.unit_manager = unit_manager
	
	# Initialize enemy AI
	if enemy_ai.has_method("set_dependencies"):
		enemy_ai.set_dependencies(unit_manager, combat_manager)
	
	# Connect signals
	connect_battle_signals()
	
	# Set camera controller reference in cursor (dependency injection)
	if cursor_controller and camera_controller:
		cursor_controller.set_camera_controller(camera_controller)
	
	# Show map selection dialog (will call setup_initial_state after selection)
	show_map_selection()
	
	print("=== GAME READY ===")

func connect_battle_signals():
	## Connect battle manager signals for victory/defeat
	if battle_manager:
		battle_manager.battle_won.connect(_on_battle_won)
		battle_manager.battle_lost.connect(_on_battle_lost)
	
	if victory_screen:
		victory_screen.continue_pressed.connect(_on_victory_continue)
	
	if defeat_screen:
		defeat_screen.retry_pressed.connect(_on_defeat_retry)
		defeat_screen.quit_pressed.connect(_on_defeat_quit)

func _on_battle_won(stats: Dictionary):
	DebugLog.success("Battle won! Turns: %d, MVP: %s" % [stats.turns, stats.mvp])
	if victory_screen:
		victory_screen.show_victory(stats)

func _on_battle_lost(reason: String):
	DebugLog.error("Battle lost: " + reason)
	if defeat_screen:
		defeat_screen.show_defeat(reason)

func _on_victory_continue():
	# TODO: Go to world map or next battle
	DebugLog.log("Victory continue pressed - implement world map transition", "cyan")
	get_tree().reload_current_scene()

func _on_defeat_retry():
	# Restart current battle
	get_tree().reload_current_scene()

func _on_defeat_quit():
	# Return to main menu
	# TODO: Implement main menu scene
	get_tree().quit()


func setup_camera():
	# Camera is now controlled by CameraController
	camera_3d.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera_3d.fov = 50.0
	camera_3d.near = 0.1
	camera_3d.far = 1000.0
	camera_controller.setup_camera_position()
	
	# Connect camera direction changes to cursor controller
	camera_controller.camera_direction_changed.connect(_on_camera_direction_changed)

func _on_camera_direction_changed(new_direction):
	# Notify cursor controller of camera change
	if cursor_controller:
		cursor_controller.on_camera_direction_changed()

func show_map_selection():
	# Create simple selection dialog
	map_selection_dialog = AcceptDialog.new()
	map_selection_dialog.title = "Select Map"
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = "Choose a map to load:"
	vbox.add_child(label)
	
	var default_btn = Button.new()
	default_btn.text = "Default Map (Current)"
	default_btn.custom_minimum_size = Vector2(250, 40)
	default_btn.pressed.connect(func(): _on_map_selected(false))
	vbox.add_child(default_btn)
	
	var test_btn = Button.new()
	test_btn.text = "Test Map (maps/test_map.txt)"
	test_btn.custom_minimum_size = Vector2(250, 40)
	test_btn.pressed.connect(func(): _on_map_selected(true))
	vbox.add_child(test_btn)
	
	# Add padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(vbox)
	
	map_selection_dialog.add_child(margin)
	add_child(map_selection_dialog)
	map_selection_dialog.popup_centered(Vector2i(300, 200))
	
	# Remove the default OK button since we have custom buttons
	map_selection_dialog.get_ok_button().visible = false

func _on_map_selected(use_test_map: bool):
	if map_selection_dialog:
		map_selection_dialog.queue_free()
		map_selection_dialog = null
	
	if use_test_map:
		_load_map_from_file("res://maps/test_map.txt")
	else:
		_setup_default_map()
	
	# Setup initial state after map is loaded
	setup_initial_state()
	
	# Initialize cursor highlight at starting position
	if cursor_controller:
		grid_3d.highlight_cursor_position(cursor_controller.get_position())

func _setup_default_map():
	# Your existing setup - keep current hardcoded map
	setup_units()
	# Regenerate grid visualization if needed
	if grid_3d:
		grid_3d.regenerate_grid()

func setup_units():
	print("Setting up units...")
	
	# Create player unit using UnitFactory
	var player_grid_pos = Vector2i(2, 3)
	var player_unit = UnitFactory.create_unit(
		null,  # Class resource
		"Player Knight", 
		0,     # Team 0
		player_grid_pos,
		units_container, # Required dependency
		unit_manager     # Required dependency
	)
	
	# Manually override stats for testing (if needed, or let Factory handle defaults)
	player_unit.max_health = 20
	player_unit.current_health = 20
	
	# Create enemy unit using UnitFactory
	var enemy_grid_pos = Vector2i(5, 4)
	var enemy_unit = UnitFactory.create_unit(
		null,  # Class resource
		"Enemy Soldier", 
		1,     # Team 1
		enemy_grid_pos,
		units_container, # Required dependency
		unit_manager     # Required dependency
	)
	
	enemy_unit.max_health = 15
	enemy_unit.current_health = 15
	
	print("Units placed:")
	print("  Player at grid: ", player_grid_pos, " world: ", GridManager.grid_to_world_3d(player_grid_pos))
	print("  Enemy at grid: ", enemy_grid_pos, " world: ", GridManager.grid_to_world_3d(enemy_grid_pos))
	
	# Initialize battle (NEW)
	initialize_battle(player_unit)

func initialize_battle(main_character: Unit):
	## Setup battle objectives and start battle manager
	if not battle_manager:
		push_warning("BattleManager not found - battle conditions disabled")
		return
	
	# Create simple objectives for this battle
	var objectives = BattleObjectives.new()
	objectives.win_conditions = [BattleObjectives.WinConditionType.DEFEAT_ALL_ENEMIES]
	objectives.lose_conditions = [
		BattleObjectives.LoseConditionType.ALL_UNITS_DIE
	]
	
	# Start battle
	battle_manager.start_battle(objectives, main_character)
	DebugLog.log("Battle initialized - Win: Defeat All Enemies", "cyan")

func _load_map_from_file(file_path: String):
	var map_data = MapLoader.load_map_file(file_path)
	if map_data.has("grid_size") and map_data.grid_size != Vector2i.ZERO:
		_load_map_from_data(map_data)
	else:
		push_error("Main: Failed to load map from file, using default")
		_setup_default_map()

func _load_map_from_data(map_data: Dictionary):
	# Set grid size
	GridManager.grid_size = map_data.grid_size
	
	# Reinitialize height map
	GridManager.initialize_height_map()
	
	# Apply height values
	var height_map = map_data.height_map
	for y in range(height_map.size()):
		for x in range(height_map[y].size()):
			var height = height_map[y][x]
			GridManager.set_height(Vector2i(x, y), height)
	
	# Clear existing units
	for unit in unit_manager.units.duplicate():
		unit_manager.remove_unit(unit)
		unit.queue_free()
	
	# Spawn players using UnitFactory
	for pos in map_data.players:
		var p_unit = UnitFactory.create_unit(
			null,
			"Player Knight", 
			0, # Team 0
			pos,
			units_container,
			unit_manager
		)
		p_unit.max_health = 20
		p_unit.current_health = 20
	
	# Spawn enemies using UnitFactory
	for pos in map_data.enemies:
		var e_unit = UnitFactory.create_unit(
			null,
			"Enemy Soldier", 
			1, # Team 1
			pos,
			units_container,
			unit_manager
		)
		e_unit.max_health = 15
		e_unit.current_health = 15
	
	# Regenerate grid visualization
	if grid_3d:
		grid_3d.regenerate_grid()
	
	# Position cursor at first player unit
	if map_data.players.size() > 0:
		cursor_controller.set_position(map_data.players[0])

# Helper function removed - using UnitFactory instead

func setup_initial_state():
	# Position cursor - will be set based on map
	# If no player units, use default position
	var player_units = unit_manager.get_units_by_team(0)
	if player_units.size() > 0:
		cursor_controller.set_position(player_units[0].grid_position)
	else:
		cursor_controller.set_position(Vector2i(2, 3))
	game_state.change_state(game_state.GameState.PLAYER_TURN, true)

func connect_signals():
	# Connect cursor signals
	cursor_controller.cursor_selected.connect(_on_cursor_selected)
	cursor_controller.cursor_moved.connect(_on_cursor_moved)
	cursor_controller.cursor_cancelled.connect(_on_cursor_cancelled)
	
	# Connect game state signals
	game_state.state_changed.connect(_on_game_state_changed)
	# Action flow signals
	SignalBus.action_menu_requested.connect(_on_action_menu_requested)
	game_state.attack_targeting_started.connect(_on_attack_targeting_started)
	
	# Action menu UI
	action_menu.attack_selected.connect(_on_attack_selected)
	action_menu.end_turn_selected.connect(_on_end_turn_selected)
	action_menu.menu_closed.connect(_on_menu_closed)
	
	# Combat manager signals
	combat_manager.attack_completed.connect(_on_attack_completed)

func _input(event):
	# Handle camera rotation
	if event.is_action_pressed("rotate_camera_left"):
		camera_controller.rotate_camera_counterclockwise()
	elif event.is_action_pressed("rotate_camera_right"):
		camera_controller.rotate_camera_clockwise()

func _on_cursor_selected(grid_pos: Vector2i):
	match game_state.current_state:
		game_state.GameState.PLAYER_TURN:
			var unit = unit_manager.get_unit_at_position(grid_pos)
			if unit and unit.team == 0 and unit.is_alive():
				# Check if unit can still act this turn
				if not unit.has_acted:
					unit_manager.select_unit(unit)
				else:
					print("Unit has already acted")
					return
			
			# If unit was successfully selected (UnitManager handles state usage)
			# We don't need to do anything else here as UnitManager sets UNIT_SELECTED state
			pass
		
		game_state.GameState.UNIT_SELECTED:
			# Verify click on unit again (confirm)
			var selected_unit = unit_manager.selected_unit
			if not selected_unit:
				game_state.cancel_unit_selection()
				return
			
			if grid_pos == selected_unit.grid_position:
				# Clicked on self - skip movement, go to action menu
				game_state.transition_to_action_select()
				await get_tree().process_frame
				var unit_world_pos = GridManager.grid_to_world_3d(selected_unit.grid_position)
				SignalBus.action_menu_requested.emit(unit_world_pos)
			else:
				# Try to move
				unit_manager.move_selected_unit_to(grid_pos)
		
		game_state.GameState.ATTACK_TARGETING:
			if unit_manager.selected_unit and combat_manager:
				combat_manager.handle_attack_target_selection(grid_pos, unit_manager.selected_unit)

func _on_cursor_moved(grid_pos: Vector2i):
	# Always highlight cursor position with light yellow layer
	grid_3d.highlight_cursor_position(grid_pos)
	
	# Handle enemy HP bar hover (works in all states)
	var unit_at_pos = unit_manager.get_unit_at_position(grid_pos)
	if unit_at_pos and unit_at_pos.team == 1:  # Enemy unit (team 1)
		# Show enemy HP bar if hovering over enemy
		if hovered_enemy_unit != unit_at_pos:
			# Hide previous hovered enemy HP bar
			if hovered_enemy_unit and hovered_enemy_unit.has_node("HPBar3D"):
				var prev_hp_bar = hovered_enemy_unit.get_node("HPBar3D")
				if prev_hp_bar and prev_hp_bar.has_method("hide_hp_bar"):
					prev_hp_bar.hide_hp_bar()
			# Show new hovered enemy HP bar
			hovered_enemy_unit = unit_at_pos
			if hovered_enemy_unit.has_node("HPBar3D"):
				var hp_bar = hovered_enemy_unit.get_node("HPBar3D")
				if hp_bar and hp_bar.has_method("show_hp_bar"):
					hp_bar.show_hp_bar()
	else:
		# Hide enemy HP bar if not hovering over enemy
		if hovered_enemy_unit:
			if hovered_enemy_unit.has_node("HPBar3D"):
				var hp_bar = hovered_enemy_unit.get_node("HPBar3D")
				if hp_bar and hp_bar.has_method("hide_hp_bar"):
					hp_bar.hide_hp_bar()
			hovered_enemy_unit = null
	
	# Show path preview if in UNIT_SELECTED state
	if game_state.current_state == game_state.GameState.UNIT_SELECTED:
		if unit_manager.selected_unit and unit_manager.is_position_in_movement_range(grid_pos):
			# Get and display path
			var path = unit_manager.get_path_to_target(grid_pos)
			if path.size() > 0:
				grid_3d.draw_path(path)
		else:
			# Clear path if not reachable
			grid_3d.clear_path()

func _on_cursor_cancelled():
	# Clear hovered enemy HP bar
	if hovered_enemy_unit:
		if hovered_enemy_unit.has_node("HPBar3D"):
			var hp_bar = hovered_enemy_unit.get_node("HPBar3D")
			if hp_bar and hp_bar.has_method("hide_hp_bar"):
				hp_bar.hide_hp_bar()
		hovered_enemy_unit = null
	
	if game_state.current_state == game_state.GameState.UNIT_SELECTED:
		unit_manager.deselect_current_unit()
		grid_3d.clear_path()
	elif game_state.current_state == game_state.GameState.ATTACK_TARGETING:
		grid_3d.clear_attack_highlights()
		game_state.transition_to_action_select()
		# Show action menu again
		if unit_manager.selected_unit:
			var unit_world_pos = GridManager.grid_to_world_3d(unit_manager.selected_unit.grid_position)
			SignalBus.action_menu_requested.emit(unit_world_pos)
	elif game_state.current_state == game_state.GameState.ACTION_SELECT:
		# If we cancel action select, we should revert movement if possible or just deselect
		# For now, let's treat it as cancelling the whole action -> Revert to Player Turn, Unit Deselected
		print("Cancelling Action Menu -> Deselecting Unit")
		unit_manager.deselect_current_unit()
		action_menu.hide()

func _on_game_state_changed(new_state: int):
	# Handle visual changes based on state
	match new_state:
		game_state.GameState.PLAYER_TURN:
			# Ensure cursor is visible and active
			cursor_controller.get_parent().visible = true
			grid_3d.clear_path()
		
		game_state.GameState.UNIT_MOVING:
			# Hide cursor during movement
			cursor_controller.get_parent().visible = false
			grid_3d.clear_path()
		
		game_state.GameState.UNIT_SELECTED:
			# Cursor remains visible
			cursor_controller.get_parent().visible = true
		
		game_state.GameState.ACTION_SELECT:
			# Hide cursor during action menu (menu handles input)
			cursor_controller.get_parent().visible = false
			grid_3d.clear_path()
		
		game_state.GameState.ATTACK_TARGETING:
			# Show cursor for attack targeting
			cursor_controller.get_parent().visible = true
		
		game_state.GameState.ENEMY_TURN:
			# Hide cursor during enemy turn
			cursor_controller.get_parent().visible = false
			grid_3d.clear_path()



# === Action Menu / Action Flow ===

func _on_action_menu_requested(unit_world_pos: Vector3):
	if unit_manager.selected_unit:
		action_menu.update_actions(
			unit_manager.selected_unit.has_moved,
			unit_manager.selected_unit.has_acted
		)
		action_menu.show_at_position(unit_world_pos)

func _on_attack_selected():
	print("Attack selected, starting targeting")
	game_state.start_attack_targeting()

func _on_end_turn_selected():
	if phase_manager:
		phase_manager.end_current_unit_turn()

func _on_menu_closed():
	# If menu closed without selection, end turn for now
	if game_state.current_state == game_state.GameState.ACTION_SELECT and phase_manager:
		phase_manager.end_current_unit_turn()

func _on_attack_targeting_started():
	if not unit_manager.selected_unit:
		if phase_manager:
			phase_manager.end_current_unit_turn()
		return
	
	# Show attack range
	var unit = unit_manager.selected_unit
	var min_range = 1
	var max_range = unit.attack_range
	if unit.has_method("get_attack_range_min"):
		min_range = unit.get_attack_range_min()
	if unit.has_method("get_attack_range_max"):
		max_range = unit.get_attack_range_max()
		
	var attack_cells = GridManager.get_attack_range(unit.grid_position, max_range, min_range)
	grid_3d.highlight_attack_range(attack_cells)
	
	# Show cursor
	cursor_controller.get_parent().visible = true



func _on_attack_completed(attacker, target, damage):
	print("Attack completed: ", attacker.unit_name, " -> ", target.unit_name)
	# Attack completion is handled in combat_manager, which calls phase_manager.end_current_unit_turn()

# === Combat Forecast Signal Handlers ===

func _on_combat_forecast_requested(attacker, defender, stats):
	print("Showing forecast for: ", attacker.unit_name, " vs ", defender.unit_name)
	combat_forecast.setup(attacker, defender, stats)
	combat_forecast.show_forecast()
	# State remains ATTACK_TARGETING - user can confirm or cancel

func _on_forecast_confirmed():
	print("Forecast confirmed. Executing attack.")
	if combat_manager.current_attacker and combat_manager.current_target:
		combat_manager.perform_attack(combat_manager.current_attacker, combat_manager.current_target)
	else:
		print("Error: No cached attacker/target for confirmed attack")

func _on_forecast_cancelled():
	print("Forecast cancelled.")
	combat_manager.cleanup()
	game_state.change_state(game_state.GameState.ATTACK_TARGETING)
