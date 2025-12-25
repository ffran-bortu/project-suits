"""
FILE: duo_factory.gd
PURPOSE: Factory for creating and instantiating duo and solo units with proper scene setup.

OVERVIEW:
This static factory class handles the complex creation process for units: loading scenes, instantiating,
setting up character data, positioning on grid, adding to scene tree, and registering with UnitManager.
Using the factory pattern ensures consistent unit creation and prevents scattered instantiation logic.
Supports creating duo units (two characters), solo units (one character), and converting between types.

FUNCTIONS IN THIS FILE:

1. create_duo(char_a, char_b, a_is_front, grid_pos, team, parent, unit_manager)
   - What it does: Creates a duo unit, sets up both characters, adds to scene, registers with manager
   - Uses: When spawning duo units at battle start or as reinforcements
   - Returns: DuoUnit

2. create_solo(character_data, in_frontline, grid_pos, team, parent, unit_manager)
   - What it does: Creates a solo unit, sets up character, adds to scene, registers with manager
   - Uses: When spawning solo units or when duo splits
   - Returns: SoloUnit

3. convert_to_duo(unit, char_a, char_b, a_is_front)
   - What it does: Converts an existing unit to a duo unit (copies position/team)
   - Uses: For testing or migration scenarios
   - Returns: DuoUnit (note: does NOT automatically add to scene)

NOTES:
- Static class (all functions static, use DuoFactory.create_duo() directly)
- Follows best practice: set properties BEFORE adding to scene tree
- Uses preload() for performance (scenes loaded at compile time)
- Automatically converts grid position to world position via GridManager
- Registers created units with UnitManager for tracking
- Depends on: GridManager (for positioning), DebugLog (for logging)
- Scene paths: res://scenes/duo_unit.tscn, res://scenes/solo_unit.tscn
"""

class_name DuoFactory
extends RefCounted
## Factory for creating duo and solo units
##
## BEST PRACTICE: Factory pattern for complex object creation

const DUO_SCENE: PackedScene = preload("res://scenes/duo_unit.tscn")
const SOLO_SCENE: PackedScene = preload("res://scenes/solo_unit.tscn")

## Create a duo unit and add to scene
##
## @param char_a: First character data
## @param char_b: Second character data
## @param a_is_front: Whether char_a is frontliner
## @param grid_pos: Grid position
## @param team: Team number (0=player, 1=enemy)
## @param parent: Parent node to add unit to
## @param unit_manager: UnitManager reference
## @return: Created DuoUnit
static func create_duo(
	char_a: CharacterData,
	char_b: CharacterData,
	a_is_front: bool,
	grid_pos: Vector2i,
	team: int,
	parent: Node,
	unit_manager: Node
) -> DuoUnit:
	# Load DuoUnit scene (inherits from unit.tscn)
	var duo = DUO_SCENE.instantiate()
	
	# Set properties BEFORE adding to tree (BEST PRACTICE)
	duo.setup_duo(char_a, char_b, a_is_front)
	duo.grid_position = grid_pos
	duo.team = team
	duo.position = GridManager.grid_to_world_3d(grid_pos)
	
	# Add to scene tree
	parent.add_child(duo)
	
	# Register with manager
	if unit_manager:
		unit_manager.register_unit(duo)
	
	DebugLog.success("Duo created: " + duo.unit_name)
	return duo

## Create a solo unit and add to scene
##
## @param character_data: Character data
## @param in_frontline: Whether to use frontline class
## @param grid_pos: Grid position
## @param team: Team number
## @param parent: Parent node
## @param unit_manager: UnitManager reference
## @return: Created SoloUnit
static func create_solo(
	character_data: CharacterData,
	in_frontline: bool,
	grid_pos: Vector2i,
	team: int,
	parent: Node,
	unit_manager: Node
) -> SoloUnit:
	# Load SoloUnit scene (inherits from unit.tscn)
	var solo = SOLO_SCENE.instantiate()
	
	# Set properties BEFORE adding to tree
	solo.setup_solo(character_data, in_frontline)
	solo.grid_position = grid_pos
	solo.team = team
	solo.position = GridManager.grid_to_world_3d(grid_pos)
	
	# Add to scene tree
	parent.add_child(solo)
	
	# Register with manager
	if unit_manager:
		unit_manager.register_unit(solo)
	
	DebugLog.success("Solo created: " + solo.unit_name)
	return solo

## Convert existing Unit to DuoUnit (for testing/migration)
##
## @param unit: Existing Unit
## @param char_a: First character
## @param char_b: Second character
## @param a_is_front: Position
## @return: New DuoUnit with same position/settings
static func convert_to_duo(
	unit: Unit,
	char_a: CharacterData,
	char_b: CharacterData,
	a_is_front: bool
) -> DuoUnit:
	var duo = DUO_SCENE.instantiate()
	
	# Copy properties from old unit
	duo.setup_duo(char_a, char_b, a_is_front)
	duo.grid_position = unit.grid_position
	duo.team = unit.team
	duo.position = unit.position
	
	return duo
