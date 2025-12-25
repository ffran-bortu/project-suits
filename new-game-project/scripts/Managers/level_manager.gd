"""
FILE: level_manager.gd
PURPOSE: Manages map loading, level setup, and unit placement.
OVERVIEW:
Extracts level management responsibilities from Main.gd. Handles loading maps from files or data,
setting up the default map, and spawning units via UnitFactory.
"""
extends Node
class_name LevelManager

# Dependencies
var unit_manager: UnitManager
var grid_3d: Node3D
var units_container: Node
var cursor_controller: Node  # CursorController class doesn't have class_name

# Properties
var use_duo_system: bool = true

# Default spawn positions (from main.gd)
const DEFAULT_START_POS := Vector2i(2, 3)
const DEFAULT_ENEMY_POS := Vector2i(5, 4)

# Dependencies Injection
func set_dependencies(
	_unit_manager: UnitManager, 
	_grid_3d: Node3D, 
	_units_container: Node,
	_cursor_controller: Node  # CursorController
) -> void:
	unit_manager = _unit_manager
	grid_3d = _grid_3d
	units_container = _units_container
	cursor_controller = _cursor_controller

# --- Map Loading ---

func load_map_from_file(file_path: String) -> void:
	var map_data = MapLoader.load_map_file(file_path)
	if map_data.has("grid_size") and map_data.grid_size != Vector2i.ZERO:
		_load_map_from_data(map_data)
	else:
		push_error("LevelManager: Failed to load map from file, using default")
		setup_default_map()

func _load_map_from_data(map_data: Dictionary) -> void:
	if not unit_manager:
		push_error("LevelManager: UnitManager not initialized")
		return
		
	GridManager.grid_size = map_data.grid_size
	GridManager.initialize_height_map()
	
	var height_map: Array = map_data.height_map
	for y in range(height_map.size()):
		for x in range(height_map[y].size()):
			GridManager.set_height(Vector2i(x, y), height_map[y][x])
	
	# Clear existing units
	for unit in unit_manager.units.duplicate():
		unit_manager.remove_unit(unit)
		unit.queue_free()
	
	# Spawn players
	for pos in map_data.players:
		var p_unit = UnitFactory.create_unit(
			null, "Player Knight", UnitManager.TEAM_PLAYER, pos, units_container, unit_manager
		)
		if p_unit:
			p_unit.max_health = 20
			p_unit.current_health = 20
	
	# Spawn enemies
	for pos in map_data.enemies:
		var e_unit = UnitFactory.create_unit(
			null, "Enemy Soldier", UnitManager.TEAM_ENEMY, pos, units_container, unit_manager
		)
		if e_unit:
			e_unit.max_health = 15
			e_unit.current_health = 15
	
	if grid_3d:
		grid_3d.regenerate_grid()
	
	if map_data.players.size() > 0 and cursor_controller:
		cursor_controller.set_position(map_data.players[0])

func setup_default_map() -> void:
	if unit_manager:
		unit_manager.clear_all_units()
	setup_units()
	if grid_3d:
		grid_3d.regenerate_grid()

func setup_units() -> void:
	print("Setting up units...")
	if use_duo_system:
		_setup_duo_units()
	else:
		_setup_legacy_units()

func _setup_duo_units() -> Unit:
	# Use test scenario for clean separation of test data
	var main_unit = TestScenario.create_standard_test_units(units_container, unit_manager)
	return main_unit

func _setup_legacy_units() -> Unit:
	# Player spawned via Deployment now
	var player_unit = null
#	var player_unit = UnitFactory.create_unit(
#		null, "Player Knight", UnitManager.TEAM_PLAYER, DEFAULT_START_POS, units_container, unit_manager
#	)
#	if player_unit:
#		player_unit.max_health = 20
#		player_unit.current_health = 20
	
	var enemy_unit = UnitFactory.create_unit(
		null, "Enemy Soldier", UnitManager.TEAM_ENEMY, DEFAULT_ENEMY_POS, units_container, unit_manager
	)
	if enemy_unit:
		enemy_unit.max_health = 15
		enemy_unit.current_health = 15
	
	print("Legacy units placed")
	return player_unit
