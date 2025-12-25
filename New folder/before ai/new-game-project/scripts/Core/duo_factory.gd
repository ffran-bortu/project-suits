class_name DuoFactory
extends RefCounted
## Factory for creating duo and solo units
##
## BEST PRACTICE: Factory pattern for complex object creation

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
	# Create duo unit instance
	var duo = DuoUnit.new()
	
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
## @param char: Character data
## @param in_frontline: Whether to use frontline class
## @param grid_pos: Grid position
## @param team: Team number
## @param parent: Parent node
## @param unit_manager: UnitManager reference
## @return: Created SoloUnit
static func create_solo(
	char: CharacterData,
	in_frontline: bool,
	grid_pos: Vector2i,
	team: int,
	parent: Node,
	unit_manager: Node
) -> SoloUnit:
	# Create solo unit instance
	var solo = SoloUnit.new()
	
	# Set properties BEFORE adding to tree
	solo.setup_solo(char, in_frontline)
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
	var duo = DuoUnit.new()
	
	# Copy properties from old unit
	duo.setup_duo(char_a, char_b, a_is_front)
	duo.grid_position = unit.grid_position
	duo.team = unit.team
	duo.position = unit.position
	
	return duo
