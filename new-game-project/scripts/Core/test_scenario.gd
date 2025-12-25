"""
FILE: test_scenario.gd
PURPOSE: Creates standard 3v3 test battle composition with mix of duo and solo units.

OVERVIEW:
This static utility creates a predefined battle scenario for testing: 3 player units (1 duo + 2 solo)
vs 3 enemy units (1 duo + 2 solo) at specific grid positions. Uses ExampleContent to generate classes
and characters, instantiates unit scenes, and registers all units with managers.

FUNCTIONS IN THIS FILE:

1. create_standard_test_units(units_container: Node3D, unit_manager: Node) -> Node
   - What it does: Creates 6 units total (3 player, 3 enemy) as mix of duo/solo, positions them on grid, registers with manager
   - Uses: Called at battle start for testing
   - Returns: Node - the player duo unit (for convenience)

NOTES:
- Static class (use TestScenario.create_standard_test_units() directly)
- Player team composition: Duo (Arden+Merric @ 2,3), Solo Hero (Lone Wolf @ 1,2), Solo Mage (@ 3,2)
- Enemy team composition: Duo (Bandit+Thug @ 5,4), Brigand (Lone Wolf @ 5,5), Rogue (@ 6,5)
- Important: Sets team BEFORE calling setup_duo/setup_solo for correct color tint
- Uses preloaded scenes: res://scenes/duo_unit.tscn, res://scenes/solo_unit.tscn
- Depends on: ExampleContent (character/class creation), GridManager (positioning), UnitManager (registration)
- Team constants: TEAM_PLAYER=0, TEAM_ENEMY=1
"""

# test_scenario.gd - Test unit compositions for battle testing
class_name TestScenario
extends Node

## Create standard test scenario: 3v3 with mix of duo and solo units
static func create_standard_test_units(
	units_container: Node3D,
	unit_manager: Node
) -> Node:
	print("=== CREATING TEST UNIT COMPOSITION ===")
	
	# Create example classes
	var warrior_class = ExampleContent.create_warrior_class()
	var mage_class = ExampleContent.create_mage_class()
	var commander_class = ExampleContent.create_commander_class()
	
	# const TEAM_PLAYER = 0
	const TEAM_ENEMY = 1
	
	var duo_scene = preload("res://scenes/duo_unit.tscn")
	var solo_scene = preload("res://scenes/solo_unit.tscn")
	
	# === PLAYER TEAM ===
	# Player units are now spawned only during Deployment via Prep Screen
	# Logic moved to Main.show_prep_screen() generation
	pass
#	# Player Duo Unit
#	var player_char1 = ExampleContent.create_character("Arden", warrior_class, mage_class)
#	var player_char2 = ExampleContent.create_character("Merric", warrior_class, mage_class)
#	
#	var duo_scene = preload("res://scenes/duo_unit.tscn")
#	var player_duo = duo_scene.instantiate()
#	player_duo.setup_duo(player_char1, player_char2, true)
#	player_duo.grid_position = Vector2i(2, 3)
#	player_duo.team = TEAM_PLAYER
#	player_duo.position = GridManager.grid_to_world_3d(Vector2i(2, 3))
#	units_container.add_child(player_duo)
#	unit_manager.register_unit(player_duo)
#	
#	# Player Solo Unit 1
#	var player_solo1_char = ExampleContent.create_character("Solo Hero", warrior_class, mage_class, ["Lone Wolf"])
#	var solo_scene = preload("res://scenes/solo_unit.tscn")
#	var player_solo1 = solo_scene.instantiate()
#	player_solo1.setup_solo(player_solo1_char, true)
#	player_solo1.grid_position = Vector2i(1, 2)
#	player_solo1.team = TEAM_PLAYER
#	player_solo1.position = GridManager.grid_to_world_3d(Vector2i(1, 2))
#	units_container.add_child(player_solo1)
#	unit_manager.register_unit(player_solo1)
#	
#	# Player Solo Unit 2
#	var player_solo2_char = ExampleContent.create_character("Solo Mage", commander_class, mage_class, ["Lone Wolf"])
#	var player_solo2 = solo_scene.instantiate()
#	player_solo2.setup_solo(player_solo2_char, true)
#	player_solo2.grid_position = Vector2i(3, 2)
#	player_solo2.team = TEAM_PLAYER
#	player_solo2.position = GridManager.grid_to_world_3d(Vector2i(3, 2))
#	units_container.add_child(player_solo2)
#	unit_manager.register_unit(player_solo2)
	
	# === ENEMY TEAM ===
	# Enemy Duo Unit
	var enemy_char1 = ExampleContent.create_character("Bandit", warrior_class, mage_class)
	var enemy_char2 = ExampleContent.create_character("Thug", warrior_class, mage_class)
	var enemy_duo = duo_scene.instantiate()
	enemy_duo.team = TEAM_ENEMY  # Set team BEFORE setup_duo for color tint
	enemy_duo.setup_duo(enemy_char1, enemy_char2, true)
	enemy_duo.grid_position = Vector2i(5, 4)
	enemy_duo.position = GridManager.grid_to_world_3d(Vector2i(5, 4))
	units_container.add_child(enemy_duo)
	unit_manager.register_unit(enemy_duo)
	
	# Enemy Solo Unit 1
	var enemy_solo1_char = ExampleContent.create_character("Brigand", warrior_class, mage_class, ["Lone Wolf"])
	var enemy_solo1 = solo_scene.instantiate()
	enemy_solo1.team = TEAM_ENEMY  # Set team BEFORE setup_solo for color tint
	enemy_solo1.setup_solo(enemy_solo1_char, true)
	enemy_solo1.grid_position = Vector2i(5, 5)
	enemy_solo1.position = GridManager.grid_to_world_3d(Vector2i(5, 5))
	units_container.add_child(enemy_solo1)
	unit_manager.register_unit(enemy_solo1)
	
	# Enemy Solo Unit 2
	var enemy_solo2_char = ExampleContent.create_character("Rogue", commander_class, mage_class, ["Lone Wolf"])
	var enemy_solo2 = solo_scene.instantiate()
	enemy_solo2.team = TEAM_ENEMY  # Set team BEFORE setup_solo for color tint
	enemy_solo2.setup_solo(enemy_solo2_char, true)
	enemy_solo2.grid_position = Vector2i(6, 5)
	enemy_solo2.position = GridManager.grid_to_world_3d(Vector2i(6, 5))
	units_container.add_child(enemy_solo2)
	unit_manager.register_unit(enemy_solo2)
	
	print("=== TEST UNITS CREATED: 3 Player (1 Duo + 2 Solo) | 3 Enemy (1 Duo + 2 Solo) ===")
	return null
