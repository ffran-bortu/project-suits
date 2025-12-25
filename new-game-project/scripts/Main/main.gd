"""
FILE: main.gd
PURPOSE: Core game coordinator - entry point orchestrating all systems, managers, UI, and game flow.

OVERVIEW:
The main game scene controller. Extends Node3D to coordinate GridManager, UnitManager, PhaseManager, CombatManager, BattleManager,
CameraController, CursorController, ActionMenu, TargetSelector, and all UI systems. Handles initialization sequence, signal routing,
map loading (from file or default setup), unit creation via UnitFactory, battle objectives, turn flow, combat forecast display,
level-up UI, victory/defeat screens, and game state management. Central hub connecting all subsystems.

KEY RESPONSIBILITIES: System initialization, dependency injection, signal orchestration, map setup, battle initialization, UI management,
event handling (cursor, camera, units, combat, turns, menus), state transitions, scene coordination.

MAJOR FUNCTIONS: _ready, _validate_required_nodes, _initialize_core_systems, _setup_ui_systems, _setup_camera_system,
_connect_all_signals, _setup_target_selector, show_map_selection, show_prep_screen, _load_map_from_file, _load_map_from_data, _setup_default_map,
initialize_battle, _start_game_sequence, cursor/combat/action handlers, level-up handlers, victory/defeat handlers - 50+ functions total.

NOTES: Entry point for game. Adds to "main" group for cursor_controller lookup. Preloads UI scenes (LevelUpUI, CombatForecast).
Teams: 0=player, 1=enemy. Validates all required nodes on startup. Handles both .txt map loading and programmatic map creation.
"""


extends Node3D

# Add to group so cursor_controller can find us
func _enter_tree():
	add_to_group("main")

# --- Constants ---
const DEFAULT_START_POS := Vector2i(2, 3)
const DEFAULT_ENEMY_POS := Vector2i(5, 4)
const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const SOLO_UNIT_SCENE_PATH := "res://scenes/solo_unit.tscn"

# --- Node References ---
@onready var cursor_controller: Node = $World/Cursor/CursorController
@onready var units_container: Node3D = $World/Units
@onready var unit_manager: UnitManager = $GameManager/UnitManager
@onready var grid_3d: Node3D = $World/Grid/Grid3D
@onready var game_state: Node = get_node("/root/GlobalGameState")
@onready var camera_3d: Camera3D = $CameraController/Camera3D
@onready var camera_controller: Node3D = $CameraController
@onready var action_menu: Panel = $UICanvas/ActionMenu
@onready var phase_manager: PhaseManager = $GameManager/PhaseManager
@onready var combat_manager: CombatManager = $GameManager/CombatManager
@onready var battle_manager: Node = $GameManager/BattleManager
@onready var victory_screen: Control = $UICanvas/VictoryScreen
@onready var defeat_screen: Control = $UICanvas/DefeatScreen
@onready var level_up_system: Node = $GameManager/LevelUpSystem
@onready var ui_canvas: CanvasLayer = $UICanvas
@onready var game_manager: Node = $GameManager

# --- Scene/Script References ---
# Loaded dynamically from GameConfig
var level_up_ui_scene: PackedScene
var combat_forecast_scene: PackedScene
var prep_screen_scene: PackedScene
var enemy_ai_script: Script

# --- State Variables ---
var level_up_ui: Control = null
var combat_forecast: Control = null
var prep_screen: Control = null
var character_status_panel: CharacterStatusPanel = null  # Bottom hover info panel
var target_selector: Node = null  # Modular target selection system
var level_manager: LevelManager = null
var interaction_controller: InteractionController = null
var map_selection_dialog: AcceptDialog = null
var use_duo_system: bool = true  # Toggle between duo and legacy unit systems


func _ready() -> void:
	print("=== GAME STARTING ===")
	
	if not _validate_required_nodes():
		return
	
	_preload_assets()
	_initialize_game_config()
	_setup_ui_systems()
	_setup_target_selector()
	_initialize_managers()
	_initialize_controllers()
	_setup_camera_system()
	_connect_all_signals()
	_start_game_sequence()
	
	# Initialize GridManager now that scene is ready
	# Load tactical map data
	var map_data = load("res://maps/test_arena.tres") as TacticalMapData
	if map_data:
		GridManager.load_map(map_data)
	else:
		push_warning("Main: Could not load test_arena.tres, using default grid")
	
	GridManager.unit_manager = unit_manager
	GridManager.initialize()
	
	print("=== GAME READY ===")

## Validate required nodes exist
func _validate_required_nodes() -> bool:
	# All nodes are @onready, so they should exist at this point
	# Add any critical validation here if needed
	return true

## Initialize game configuration
func _initialize_game_config() -> void:
	# GameConfig is autoloaded, no initialization needed
	GameConfig.init_materials()

## Setup UI systems
func _setup_ui_systems() -> void:
	# Instantiate and add UI scenes
	if combat_forecast_scene:
		combat_forecast = combat_forecast_scene.instantiate()
		ui_canvas.add_child(combat_forecast)
		combat_forecast.visible = false
		combat_forecast.confirmed.connect(_on_forecast_confirmed)
		combat_forecast.cancelled.connect(_on_forecast_cancelled)

## Preload assets from GameConfig
func _preload_assets() -> void:
	level_up_ui_scene = load(GameConfig.assets.get("level_up_ui_scene", "res://scenes/ui/level_up_ui.tscn"))
	combat_forecast_scene = load(GameConfig.assets.get("combat_forecast_scene", "res://scenes/ui/combat_forecast.tscn"))
	prep_screen_scene = load(GameConfig.assets.get("prep_screen_scene", "res://scenes/ui/prep_screen.tscn"))
	enemy_ai_script = load(GameConfig.assets.get("enemy_ai_script", "res://scripts/Managers/enemy_ai.gd"))

## Initialize controllers with dependencies
func _initialize_controllers() -> void:
	# Instantiate Inventory Menu
	var inventory_menu = InventoryMenu.new()
	inventory_menu.name = "InventoryMenu"
	ui_canvas.add_child(inventory_menu)

	interaction_controller = InteractionController.new()
	interaction_controller.name = "InteractionController"
	add_child(interaction_controller)
	interaction_controller.set_dependencies(
		unit_manager, combat_manager, phase_manager, grid_3d,
		cursor_controller, action_menu, inventory_menu, target_selector, game_state,
		level_manager, camera_controller
	)
	interaction_controller.set_units_container(units_container)

func _initialize_managers() -> void:
	# Initialize UnitManager dependencies
	unit_manager.set_dependencies(grid_3d, game_state)
	
	# Create LevelManager
	level_manager = LevelManager.new()
	level_manager.name = "LevelManager"
	add_child(level_manager)
	level_manager.set_dependencies(unit_manager, grid_3d, units_container, cursor_controller)

	# Create and initialize Enemy AI FIRST (before PhaseManager checks for it)
	var enemy_ai := Node.new()
	enemy_ai.name = "EnemyAI"
	if enemy_ai_script:
		enemy_ai.set_script(enemy_ai_script)
	game_manager.add_child(enemy_ai)
	
	if enemy_ai.has_method("set_dependencies"):
		enemy_ai.set_dependencies(unit_manager, combat_manager)

	# --- Inventory Manager (New) ---
	var inventory_mgr_scene = load("res://scenes/managers/inventory/inventory_manager.tscn")
	if inventory_mgr_scene:
		var inventory_manager = inventory_mgr_scene.instantiate()
		game_manager.add_child(inventory_manager)
		# It adds itself to group "inventory_manager" in _ready
		print("Main: InventoryManager initialized")
	else:
		push_error("Main: Failed to load inventory_manager.tscn")
	
	# Setup manager dependencies with full injection
	# PhaseManager needs: grid_3d, action_menu, combat_manager, unit_manager, enemy_ai, game_state
	phase_manager.set_dependencies(grid_3d, action_menu, combat_manager, unit_manager, enemy_ai, game_state)
	
	# CombatManager needs: grid_3d, phase_manager, unit_manager, game_state
	combat_manager.set_dependencies(grid_3d, phase_manager, unit_manager, game_state)
	
	# ActionMenu dependency
	action_menu.unit_manager = unit_manager



## Setup camera system
func _setup_camera_system() -> void:
	_configure_camera_params()
	
	# Set camera controller reference in cursor
	if cursor_controller and camera_controller:
		cursor_controller.set_camera_controller(camera_controller)
		
	# DISGAEA: Inject cursor reference into camera for height tracking
	if camera_controller and cursor_controller:
		camera_controller.set_cursor_reference(cursor_controller)
	
	# Connect cursor hover signals to character status panel
	_setup_status_panel()


func _configure_camera_params() -> void:
	# Delegate configuration to the camera controller (handles Isometric/Orthogonal setup)
	camera_controller.setup_camera_position()
	
	# Connect camera direction changes to cursor controller
	if not camera_controller.camera_direction_changed.is_connected(_on_camera_direction_changed):
		camera_controller.camera_direction_changed.connect(_on_camera_direction_changed)


## Connect all signal listeners
func _connect_all_signals() -> void:
	# Battle signals
	_connect_battle_signals()
	
	# Combat signals
	# Combat signals
	if not combat_manager.attack_completed.is_connected(_on_attack_completed):
		combat_manager.attack_completed.connect(_on_attack_completed)
		combat_manager.turn_end_requested.connect(_on_combat_turn_end_requested)
	
	# Level up signals - handled via SignalBus
	# if level_up_system and level_up_system.has_signal("level_up"):
	# 	level_up_system.level_up.connect(_on_character_level_up)
		
	# Connect cursor signals
	# cursor_controller signals handled by InteractionController
	
	# Connect game state signals
	game_state.state_changed.connect(_on_game_state_changed)
	# attack_targeting_started handled by InteractionController
	
	# Action flow signals
	# SignalBus.action_menu_requested handled by InteractionController
	
	# Action menu signals
	# specific signals handled by InteractionController


## Setup modular target selector
func _setup_target_selector() -> void:
	target_selector = TargetSelector.new()
	target_selector.name = "TargetSelector"
	add_child(target_selector)
	
	# Connect signals
	target_selector.target_confirmed.connect(_on_target_confirmed)
	target_selector.targeting_cancelled.connect(_on_targeting_cancelled)


func _connect_battle_signals() -> void:
	if battle_manager:
		battle_manager.battle_won.connect(_on_battle_won)
		battle_manager.battle_lost.connect(_on_battle_lost)
	
	if victory_screen:
		victory_screen.continue_pressed.connect(_on_victory_continue)
	
	if defeat_screen:
		defeat_screen.retry_pressed.connect(_on_defeat_retry)
		defeat_screen.quit_pressed.connect(_on_defeat_quit)


## Start the game sequence (map selection, etc.)
func _start_game_sequence() -> void:
	show_map_selection()


# --- Deleted Input Handling (moved to InteractionController) ---


# --- Target Selector Signal Handlers ---

func _on_target_confirmed(_target) -> void:
	# Handled by InteractionController
	pass

func _on_targeting_cancelled() -> void:
	# Handled by InteractionController
	pass


# --- Signal Handlers: Battle & Game Flow ---

func _on_battle_won(stats: Dictionary) -> void:
	DebugLog.success("Battle won! Turns: %d, MVP: %s" % [stats.get("turns", 0), stats.get("mvp", "None")])
	if victory_screen:
		victory_screen.show_victory(stats)


func _on_battle_lost(reason: String) -> void:
	DebugLog.error("Battle lost: " + reason)
	if defeat_screen:
		defeat_screen.show_defeat(reason)


func _on_victory_continue() -> void:
	DebugLog.log("Victory continue pressed - reloading scene", "cyan")
	get_tree().reload_current_scene()


func _on_defeat_retry() -> void:
	get_tree().reload_current_scene()


func _on_defeat_quit() -> void:
	get_tree().quit()


# _on_character_level_up moved to SignalBus/UI


func _on_level_up_closed() -> void:
	DebugLog.log("Level up UI closed", "cyan")


func _on_camera_direction_changed(_new_direction: int) -> void:
	if cursor_controller:
		cursor_controller.on_camera_direction_changed()


# --- Map & Setup System ---

func show_map_selection() -> void:
	map_selection_dialog = AcceptDialog.new()
	map_selection_dialog.title = "Select Map"
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var label := Label.new()
	label.text = "Choose a map to load:"
	vbox.add_child(label)
	
	var default_btn := Button.new()
	default_btn.text = "Default Map (Current)"
	default_btn.custom_minimum_size = Vector2(250, 40)
	default_btn.pressed.connect(func(): _on_map_selected(false))
	vbox.add_child(default_btn)
	
	var test_btn := Button.new()
	test_btn.text = "Test Map (maps/test_map.txt)"
	test_btn.custom_minimum_size = Vector2(250, 40)
	test_btn.pressed.connect(func(): _on_map_selected(true))
	vbox.add_child(test_btn)
	
	# Add padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(vbox)
	
	map_selection_dialog.add_child(margin)
	add_child(map_selection_dialog)
	map_selection_dialog.popup_centered(Vector2i(300, 200))
	
	map_selection_dialog.get_ok_button().visible = false


func _on_map_selected(use_test_map: bool) -> void:
	if map_selection_dialog:
		map_selection_dialog.queue_free()
		map_selection_dialog = null
	
	if use_test_map:
		_load_map_from_file("res://maps/test_map.txt")
	else:
		_setup_default_map()
	
	# Show Prep Screen instead of starting immediately
	show_prep_screen()

func show_prep_screen() -> void:
	if not prep_screen_scene:
		push_error("Prep Screen scene not loaded! Starting directly.")
		setup_initial_state()
		return

	prep_screen = prep_screen_scene.instantiate()
	ui_canvas.add_child(prep_screen)
	
	# Create dummy character data for existing units since we don't have full persistence yet
	var characters: Array[CharacterData] = []
	var player_units = unit_manager.get_units_by_team(TEAM_PLAYER)
	var spawns: Array[Vector2i] = []
	
	for unit in player_units:
		spawns.append(unit.grid_position)
		
		# Extract real CharacterData if available
		if "character" in unit and unit.character:
			# SoloUnit
			characters.append(unit.character)
		elif "frontliner" in unit and unit.frontliner and "backliner" in unit and unit.backliner:
			# DuoUnit - Add both characters to roster
			characters.append(unit.frontliner)
			characters.append(unit.backliner)
		else:
			# Fallback for generic units (though units should be Solo or Duo now)
			var c = CharacterData.new()
			c.character_name = unit.unit_name
			c.character_id = unit.name
			c.current_hp = unit.current_health
			c.max_hp = unit.max_health
			# Assign a placeholder class to prevent UI "No class" errors
			if unit.unit_class:
				# If Unit has a class associated, try to use it
				# We might need to cast or wrap it, but for now let's leave it null
				# character_data.gd expects primary_class to be set
				pass 
			characters.append(c)

	# Fallback: If no units exist, generate test data for deployment
	if characters.is_empty():
		print("Main: No existing units. Loading test roster from character data files.")
		
		# Load character data from files (linking to actual character identities)
		var lyn_data = load("res://data/characters/lyn.tres") as CharacterData
		var eliwood_data = load("res://data/characters/eliwood.tres") as CharacterData  
		var hector_data = load("res://data/characters/hector.tres") as CharacterData
		var florina_data = load("res://data/characters/florina.tres") as CharacterData
		
		# Assign classes for testing (using ExampleContent for now)
		var warrior_class = ExampleContent.create_warrior_class()
		var mage_class = ExampleContent.create_mage_class()
		
		if lyn_data:
			lyn_data.primary_class = warrior_class  # Knight
			characters.append(lyn_data)
		if eliwood_data:
			eliwood_data.primary_class = mage_class  # Mage
			characters.append(eliwood_data)
		if hector_data:
			hector_data.primary_class = warrior_class  # Archer (temp)
			characters.append(hector_data)
		if florina_data:
			florina_data.primary_class = mage_class  # Fourth unit
			characters.append(florina_data)
		
		# Default spawn positions for test map
		spawns = [Vector2i(2,3), Vector2i(1,2), Vector2i(3,2), Vector2i(2,2), Vector2i(3,3)]

	# Note: PrepScreen expects chapter_info with spawn_positions
	var chapter_info = {
		"spawn_positions": spawns,
		"deployment_limit": characters.size()
	}

	if prep_screen.has_method("setup"):
		prep_screen.setup(characters, chapter_info, unit_manager)
	
	if prep_screen.has_signal("prep_complete"):
		prep_screen.prep_complete.connect(_on_prep_complete)
	if prep_screen.has_signal("prep_cancelled"):
		prep_screen.prep_cancelled.connect(_on_prep_cancelled)
	if prep_screen.has_signal("unit_placement_requested"):
		prep_screen.unit_placement_requested.connect(_on_unit_placement_requested)

func _on_unit_placement_requested(character: CharacterData, grid_pos: Vector2i) -> void:
	print("Main: Requesting unit placement logic for %s at %s" % [character.character_name, grid_pos])
	
	# Check if this character is already deployed elsewhere
	var existing_unit = null
	var existing_pos: Vector2i = Vector2i(-1, -1)
	for u in unit_manager.get_all_units():
		if "character" in u and u.character == character:
			existing_unit = u
			existing_pos = u.grid_position
			break
	
	# Check if target position occupied
	var occupant = unit_manager.get_unit_at_position(grid_pos)
	
	# Handle different scenarios
	if existing_unit and occupant:
		# SWAP: Character already deployed, target has occupant
		if existing_unit == occupant:
			print("Main: Unit already at target position")
			return
		
		print("Main: Swapping %s at %s with %s at %s" % [
			existing_unit.unit_name, existing_pos,
			occupant.unit_name, grid_pos
		])
		
		# Swap positions
		if existing_unit.has_method("set_grid_position"):
			existing_unit.set_grid_position(grid_pos)
		else:
			existing_unit.grid_position = grid_pos
		existing_unit.position = GridManager.grid_to_world_3d(grid_pos)
		
		if occupant.has_method("set_grid_position"):
			occupant.set_grid_position(existing_pos)
		else:
			occupant.grid_position = existing_pos
		occupant.position = GridManager.grid_to_world_3d(existing_pos)
		
	elif existing_unit and not occupant:
		# MOVE: Character already deployed, target is empty
		print("Main: Moving %s from %s to %s" % [existing_unit.unit_name, existing_pos, grid_pos])
		
		if existing_unit.has_method("set_grid_position"):
			existing_unit.set_grid_position(grid_pos)
		else:
			existing_unit.grid_position = grid_pos
		existing_unit.position = GridManager.grid_to_world_3d(grid_pos)
		
	elif not existing_unit and occupant:
		# REPLACE: New character, target has occupant - remove occupant and spawn new
		print("Main: Replacing %s at %s with new unit %s" % [occupant.unit_name, grid_pos, character.character_name])
		
		unit_manager.remove_unit(occupant)
		if occupant.is_inside_tree():
			occupant.queue_free()
		
		# Spawn new unit
		_spawn_deployment_unit(character, grid_pos)
		
	else:
		# SPAWN: New character, empty tile
		print("Main: Spawning new unit %s at %s" % [character.character_name, grid_pos])
		_spawn_deployment_unit(character, grid_pos)

func _spawn_deployment_unit(character: CharacterData, grid_pos: Vector2i) -> void:
	"""Helper to spawn a new deployment unit with proper initialization order"""
	var solo_scene = load(SOLO_UNIT_SCENE_PATH)
	var new_unit = solo_scene.instantiate()
	
	# Add to tree first (standard Godot pattern)
	units_container.add_child(new_unit)
	
	# THEN setup character data (_ready already ran, but we can reconfigure)
	new_unit.setup_solo(character, true)
	new_unit.team = TEAM_PLAYER
	new_unit.grid_position = grid_pos
	
	# Recalculate world position now that grid_position changed
	# (_ready() calculated it with default grid_position)
	var offset: float = GameConfig.visual.get("ground_offset", 0.01)
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	new_unit.position = Vector3(world_pos.x, world_pos.y + offset, world_pos.z)
	
	# Make visible (since _ready hides player units by default)
	new_unit.visible = true
	
	# Explicitly refresh visuals now that character data is set
	# This ensures the sprite reflects the correct character
	if new_unit.has_method("setup_visual"):
		new_unit.setup_visual(2.0, true)
	
	# Register with manager
	unit_manager.register_unit(new_unit)

func _on_prep_complete(_deployed_units: Array, _positions: Dictionary) -> void:
	print("Prep Complete! Starting Battle.")
	if prep_screen:
		prep_screen.queue_free()
		prep_screen = null
		
	setup_initial_state()

func _on_prep_cancelled() -> void:
	if prep_screen:
		prep_screen.queue_free()
		prep_screen = null
	show_map_selection()


func setup_units() -> void:
	print("Setting up units...")
	if use_duo_system:
		setup_duo_units()
	else:
		setup_legacy_units()


func setup_duo_units() -> void:
	# Use test scenario for clean separation of test data
	var main_unit = TestScenario.create_standard_test_units(units_container, unit_manager)
	initialize_battle(main_unit)


func setup_legacy_units() -> void:
	var player_unit = UnitFactory.create_unit(
		null, "Player Knight", TEAM_PLAYER, DEFAULT_START_POS, units_container, unit_manager
	)
	player_unit.max_health = 20
	player_unit.current_health = 20
	
	var enemy_unit = UnitFactory.create_unit(
		null, "Enemy Soldier", TEAM_ENEMY, DEFAULT_ENEMY_POS, units_container, unit_manager
	)
	enemy_unit.max_health = 15
	enemy_unit.current_health = 15
	
	print("Legacy units placed")
	initialize_battle(player_unit)


func initialize_battle(main_character: Node) -> void:
	if not battle_manager:
		push_warning("BattleManager not found - battle conditions disabled")
		return
	
	var objectives = BattleObjectives.new()
	var win_conds: Array[BattleObjectives.WinConditionType] = [BattleObjectives.WinConditionType.DEFEAT_ALL_ENEMIES]
	var lose_conds: Array[BattleObjectives.LoseConditionType] = [BattleObjectives.LoseConditionType.ALL_UNITS_DIE]
	objectives.win_conditions = win_conds
	objectives.lose_conditions = lose_conds
	
	battle_manager.start_battle(objectives, main_character)
	DebugLog.log("Battle initialized - Win: Defeat All Enemies", "cyan")


func _load_map_from_file(file_path: String) -> void:
	if level_manager:
		level_manager.load_map_from_file(file_path)

func _setup_default_map() -> void:
	if level_manager:
		level_manager.setup_default_map()


func setup_initial_state() -> void:
	var player_units: Array = unit_manager.get_units_by_team(TEAM_PLAYER)
	if player_units.size() > 0:
		cursor_controller.set_position(player_units[0].grid_position)
	else:
		cursor_controller.set_position(DEFAULT_START_POS)
	game_state.change_state(game_state.GameState.PLAYER_TURN, true)


# --- Deleted cursor handlers (moved to InteractionController) ---


func _on_game_state_changed(new_state: int) -> void:
	# Visibility logic
	var show_cursor := true
	
	match new_state:
		game_state.GameState.PLAYER_TURN, game_state.GameState.UNIT_SELECTED, game_state.GameState.ATTACK_TARGETING:
			show_cursor = true
		game_state.GameState.UNIT_MOVING, game_state.GameState.ACTION_SELECT, game_state.GameState.ENEMY_TURN:
			show_cursor = false
			
	cursor_controller.get_parent().visible = show_cursor
	grid_3d.clear_path()


# --- Deleted Action Menu / Action Flow handlers (moved to InteractionController) ---




func _on_attack_completed(attacker: Node, target: Node, _damage: int) -> void:
	print("Attack completed: %s -> %s" % [attacker.unit_name, target.unit_name])


func _on_combat_turn_end_requested(_unit: Node) -> void:
	if phase_manager:
		phase_manager.end_current_unit_turn()


# --- Combat Forecast ---
# Handled via SignalBus in combat_forecast.gd


func _on_forecast_confirmed() -> void:
	print("Forecast confirmed. Executing attack.")
	if combat_manager.current_attacker and combat_manager.current_target:
		combat_manager.perform_attack(combat_manager.current_attacker, combat_manager.current_target)
	else:
		push_error("Error: No cached attacker/target for confirmed attack")


func _on_forecast_cancelled() -> void:
	print("Forecast cancelled.")
	combat_manager.cleanup()
	game_state.change_state(game_state.GameState.ATTACK_TARGETING)

# --- Deleted targeting handlers (moved to InteractionController) ---



## Execute pair with selected ally
func _execute_pair(target_ally: Node) -> void:
	if not unit_manager or not unit_manager.selected_unit:
		return
	
	var acting_unit = unit_manager.selected_unit
	var other = target_ally
	
	# Store data before removal
	var duo_pos = other.grid_position  # FIXED: Use target's position, not acting unit's
	var duo_team = acting_unit.team
	var char_a = acting_unit.character
	var char_b = other.character
	
	# Unregister both solos FIRST
	unit_manager.remove_unit(acting_unit)
	unit_manager.remove_unit(other)
	
	# Create duo from scene
	var duo_scene = preload("res://scenes/duo_unit.tscn")
	var duo = duo_scene.instantiate()
	duo.team = duo_team
	duo.grid_position = duo_pos
	duo.position = GridManager.grid_to_world_3d(duo_pos)
	
	# Add to scene (runs _ready)
	units_container.add_child(duo)
	
	# Setup duo
	duo.setup_duo(char_a, char_b, true)
	
	# Manual visual setup
	duo.setup_visual(3.0, duo_team == 0)
	duo.visible = true
	
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
	units_container.add_child(solo1)
	units_container.add_child(solo2)
	
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
## Setup character status panel and connect hover signals
func _setup_status_panel() -> void:
	# Load and instantiate status panel
	var status_panel_scene = load("res://scenes/UI/character_status_panel.tscn")
	if not status_panel_scene:
		push_warning("Main: Could not load character_status_panel.tscn")
		return
	
	character_status_panel = status_panel_scene.instantiate()
	if not character_status_panel:
		push_error("Main: Failed to instantiate character_status_panel")
		return
	
	# Add to UI canvas
	var ui_canvas_node = get_node_or_null("UICanvas")
	if ui_canvas_node:
		ui_canvas_node.add_child(character_status_panel)
	else:
		push_error("Main: UICanvas not found!")
		return
	
	# Connect cursor hover signals
	if cursor_controller:
		if not cursor_controller.unit_hovered.is_connected(_on_unit_hovered):
			cursor_controller.unit_hovered.connect(_on_unit_hovered)
		if not cursor_controller.unit_unhovered.is_connected(_on_unit_unhovered):
			cursor_controller.unit_unhovered.connect(_on_unit_unhovered)


## Handle cursor hovering over a unit
func _on_unit_hovered(unit: Unit) -> void:
	if character_status_panel and is_instance_valid(unit):
		# Create temporary CharacterData from unit stats
		var temp_char_data = CharacterData.new()
		temp_char_data.character_name = unit.unit_name
		temp_char_data.character_id = unit.unit_name.to_lower()
		
		# Show panel with unit info
		character_status_panel.show_character_info(temp_char_data, unit)


## Handle cursor leaving a unit
func _on_unit_unhovered() -> void:
	if character_status_panel:
		character_status_panel.hide_panel()
