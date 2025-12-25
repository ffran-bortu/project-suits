"""
FILE: unit_factory.gd
PURPOSE: Factory class for creating Unit instances with UnitClass support and stat overrides.

OVERVIEW:
Static helper functions for unit creation. Instantiates unit scene, applies UnitClass stats, sets team/position, converts grid to world coords,
applies scaling, adds to container and UnitManager. Supports stat_overrides Dictionary for custom unit stats. Provides create_unit_from_data for map loading.

FUNCTIONS: create_unit (static), create_unit_from_data (static) - 2 total

NOTES:
- Uses GameConfig.assets for paths
- Team 0 = player, team 1 = enemy
- Applies GridManager scaling and positioning
"""

# unit_factory.gd - Factory for creating units with UnitClass support
class_name UnitFactory
extends Object

## Create a unit with UnitClass support
## @param unit_class: UnitClass or CharacterClass resource (optional)
## @param unit_name: Unit name
## @param team: Team ID (0 = player, 1 = enemy)
## @param position: Grid position
## @param units_container: Container to add unit to
## @param unit_manager: UnitManager instance
## @param stat_overrides: Optional stat overrides
## @return: Created Unit node (Node3D)
static func create_unit(
	unit_class: Resource = null,
	unit_name: String = "Soldier",
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
	var unit_scene_path: String = GameConfig.assets.get("unit_scene", "res://scenes/unit.tscn")
	var unit_scene: PackedScene = load(unit_scene_path)
	if not unit_scene:
		push_error("UnitFactory: Failed to load unit scene from %s" % unit_scene_path)
		return null
		
	var unit: Node3D = unit_scene.instantiate()
	
	# Set basic properties
	unit.unit_name = unit_name
	unit.team = team
	
	# Assign UnitClass if provided
	if unit_class:
		unit.unit_class = unit_class
		# Unit will initialize from class in _ready()
	
	# Apply stat overrides (these will override class defaults)
	# Using String keys for flexibility with data loading
	for stat_name in stat_overrides:
		var value = stat_overrides[stat_name]
		
		match stat_name:
			"max_health", "hp":
				unit.max_health = value
				unit.current_health = value # Start at full HP
			"current_health":
				unit.current_health = value
			"movement_range", "mov":
				unit.movement_range = value
			"attack_range":
				unit.attack_range = value
			"str", "mag", "skill", "spd", "luck", "def", "res":
				unit.set(stat_name, value)
			_:
				# Try direct assignment for other properties
				if stat_name in unit:
					unit.set(stat_name, value)
	
	# Set grid position
	if unit.has_method("set_grid_position"):
		unit.set_grid_position(position)
	else:
		push_warning("UnitFactory: Unit missing set_grid_position method")
	
	# Apply scaling
	if GridManager:
		var unit_scale := GridManager.get_unit_scale()
		unit.scale = unit_scale
	
	# Set enemy texture if enemy team
	if team == 1:  # Enemy
		if unit.has_node("Sprite3D"):
			var enemy_tex_path: String = GameConfig.assets.get("unit_enemy_texture", "res://assets/unit_enemy.png")
			var sprite: Sprite3D = unit.get_node("Sprite3D")
			sprite.texture = load(enemy_tex_path)
			sprite.hframes = 1
			sprite.vframes = 1
	
	# Add to container and manager
	units_container.add_child(unit)
	if unit_manager.has_method("add_unit"):
		unit_manager.add_unit(unit)
		
	# --- Populate Inventory ---
	if unit.inventory:
		var items = _get_starter_items(unit)
		for item in items:
			unit.inventory.add_item(item)
	
	return unit


## Get starter items based on class
static func _get_starter_items(unit: Node3D) -> Array[Resource]:
	var items: Array[Resource] = []
	
	# Default Vulnerary for everyone
	items.append(ItemFactory.create_vulnerary())
	
	if not unit.unit_class:
		# Fallback defaults if no class
		items.append(WeaponFactory.create_iron_sword())
		return items
		
	var unit_class_name = unit.unit_class.display_name.to_lower()
	
	var weapons: Array[Weapon] = []
	
	if "knight" in unit_class_name or "cavalier" in unit_class_name:
		weapons = WeaponFactory.create_cavalier_starter_kit()
	elif "fighter" in unit_class_name or "warrior" in unit_class_name:
		weapons = WeaponFactory.create_fighter_starter_kit()
	elif "mage" in unit_class_name or "wizard" in unit_class_name:
		weapons = WeaponFactory.create_mage_starter_kit()
	elif "archer" in unit_class_name:
		# WeaponFactory doesn't have archer kit yet, use Iron Bow manually?
		# Fallback to default kit for now or generic sword if missing
		items.append(WeaponFactory.create_iron_sword()) 
	else:
		# Generic fallback
		weapons = WeaponFactory.create_knight_starter_kit()
		
	items.append_array(weapons)
	return items



## Create a unit from a data dictionary (for map loading)
## Dictionary format:
##   {
##     "name": String,
##     "team": int,
##     "position": Vector2i,
##     "unit_class": UnitClass (optional),
##     "max_health": int (optional),
##     "current_health": int (optional),
##     "stat_overrides": Dictionary (optional)
##   }
static func create_unit_from_data(
	data: Dictionary,
	units_container: Node3D,
	unit_manager: Node
) -> Node3D:
	var unit_class = data.get("unit_class", null)
	var unit_name: String = data.get("name", "Soldier")
	var team: int = data.get("team", 0)
	var position: Vector2i = data.get("position", Vector2i.ZERO)
	
	# Build stat_overrides from data
	var stat_overrides: Dictionary = {}
	if data.has("max_health"):
		stat_overrides["max_health"] = data["max_health"]
	if data.has("current_health"):
		stat_overrides["current_health"] = data["current_health"]
	if data.has("stat_overrides") and data["stat_overrides"] is Dictionary:
		# Merge any additional stat overrides
		var overrides: Dictionary = data["stat_overrides"]
		for key in overrides:
			stat_overrides[key] = overrides[key]
	
	return create_unit(unit_class, unit_name, team, position, units_container, unit_manager, stat_overrides)
