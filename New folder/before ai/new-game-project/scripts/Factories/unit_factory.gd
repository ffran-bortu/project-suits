# unit_factory.gd - Factory for creating units with UnitClass support
extends Node

class_name UnitFactory

# Create a unit with UnitClass support
# Parameters:
#   unit_class: UnitClass resource (optional - if null, uses defaults)
#   name: String - Unit name
#   team: int - Team ID (0 = player, 1 = enemy)
#   position: Vector2i - Grid position
#   stat_overrides: Dictionary - Optional stat overrides (e.g., {"str": 10, "max_health": 25})
#   units_container: Node3D - Container to add unit to
#   unit_manager: Node - UnitManager instance
# Returns: Node3D (the created unit)
static func create_unit(
	unit_class: Resource = null,
	name: String = "Soldier",
	team: int = 0,
	position: Vector2i = Vector2i.ZERO,
	units_container: Node3D = null,
	unit_manager: Node = null,
	stat_overrides: Dictionary = {}
) -> Node3D:
	
	# Validate required parameters
	if not units_container:
		push_error("UnitFactory: units_container is required")
		return null
	if not unit_manager:
		push_error("UnitFactory: unit_manager is required")
		return null
	
	# Load unit scene
	var unit_scene = preload("res://scenes/unit.tscn")
	var unit = unit_scene.instantiate()
	
	# Set basic properties
	unit.unit_name = name
	unit.team = team
	
	# Assign UnitClass if provided
	if unit_class:
		unit.unit_class = unit_class
		# Unit will initialize from class in _ready()
	
	# Apply stat overrides (these will override class defaults)
	for stat_name in stat_overrides:
		if stat_name == "max_health":
			unit.max_health = stat_overrides[stat_name]
			unit.current_health = stat_overrides[stat_name]  # Start at full HP
		elif stat_name == "current_health":
			unit.current_health = stat_overrides[stat_name]
		elif stat_name == "movement_range":
			unit.movement_range = stat_overrides[stat_name]
		elif stat_name == "attack_range":
			unit.attack_range = stat_overrides[stat_name]
		elif stat_name in ["str", "mag", "skill", "spd", "luck", "def", "res"]:
			unit.set(stat_name, stat_overrides[stat_name])
	
	# Set grid position
	unit.set_grid_position(position)
	
	# Convert grid to world position
	var world_pos = GridManager.grid_to_world_3d(position)
	unit.position = world_pos
	
	# Apply scaling
	var unit_scale = GridManager.get_unit_scale()
	unit.scale = unit_scale
	
	# Set enemy texture if enemy team
	if team == 1:  # Enemy
		if unit.has_node("Sprite3D"):
			unit.get_node("Sprite3D").texture = preload("res://assets/unit_enemy.png")
	
	# Add to container and manager
	units_container.add_child(unit)
	unit_manager.add_unit(unit)
	
	return unit

# Create a unit from a data dictionary (for map loading)
# Dictionary format:
#   {
#     "name": String,
#     "team": int,
#     "position": Vector2i,
#     "unit_class": UnitClass (optional),
#     "max_health": int (optional),
#     "current_health": int (optional),
#     "stat_overrides": Dictionary (optional)
#   }
static func create_unit_from_data(
	data: Dictionary,
	units_container: Node3D,
	unit_manager: Node
) -> Node3D:
	
	var unit_class = data.get("unit_class", null)
	var name = data.get("name", "Soldier")
	var team = data.get("team", 0)
	var position = data.get("position", Vector2i.ZERO)
	
	# Build stat_overrides from data
	var stat_overrides = {}
	if data.has("max_health"):
		stat_overrides["max_health"] = data["max_health"]
	if data.has("current_health"):
		stat_overrides["current_health"] = data["current_health"]
	if data.has("stat_overrides"):
		# Merge any additional stat overrides
		for key in data["stat_overrides"]:
			stat_overrides[key] = data["stat_overrides"][key]
	
	return create_unit(unit_class, name, team, position, units_container, unit_manager, stat_overrides)

