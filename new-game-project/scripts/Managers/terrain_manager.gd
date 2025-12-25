"""
FILE: terrain_manager.gd
PURPOSE: Procedural terrain generation and management with height maps, terrain types, and tactical properties.

OVERVIEW:
This manager generates procedural terrain using FastNoiseLite, classifying cells into types (Grass, Dirt, Sand,
Stone, Water, Forest, Mountain) based on height values. Each terrain type has movement cost, defense bonus, and
avoid bonus. Supports obstacle placement, save/load terrain state, and provides query methods for pathfinding
and combat calculations.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Initializes noise generator and adds to terrain_manager group
   - Uses: Called automatically when node enters scene tree
   - Returns: void

2. _initialize_noise() -> void
   - What it does: Creates and configures FastNoiseLite with seed and frequency
   - Uses: Called during initialization
   - Returns: void

3. generate_terrain() -> void
   - What it does: Generates terrain for entire grid, emits terrain_generated signal
   - Uses: Called at map start
   - Returns: void

4. _generate_cell_terrain(grid_pos: Vector2i) -> void
   - What it does: Generates single cell's height from noise, classifies type, stores data
   - Uses: Called for each grid cell during generation
   - Returns: void

5. _classify_terrain(data: TerrainData, height: float) -> void
   - What it does: Sets terrain type and properties based on height thresholds
   - Uses: Called after generating cell height
   - Returns: void

6. place_obstacles() -> void
   - What it does: Randomly places impassable obstacles in mountains/forests
   - Uses: Called after terrain generation for variety
   - Returns: void

7. get_height(grid_pos: Vector2i) -> float
   - What it does: Returns height value at position
   - Uses: Query method for rendering/logic
   - Returns: float - height value

8. get_terrain_data(grid_pos: Vector2i) -> TerrainData
   - What it does: Returns full terrain data object at position
   - Uses: Query method for detailed terrain info
   - Returns: TerrainData or null

9. is_traversable(grid_pos: Vector2i) -> bool
   - What it does: Checks if position can be moved through (not water, not obstacle)
   - Uses: Pathfinding and movement validation
   - Returns: bool - true if traversable

10. get_movement_cost(grid_pos: Vector2i) -> int
    - What it does: Returns movement cost for terrain type
    - Uses: Pathfinding calculations
    - Returns: int - movement cost (1-4)

11. get_terrain_bonus(grid_pos: Vector2i, bonus_type: String) -> int
    - What it does: Returns defense or avoid bonus for terrain
    - Uses: Combat calculations
    - Returns: int - bonus value

12. get_terrain_color(grid_pos: Vector2i) -> Color
    - What it does: Returns color for visual representation of terrain type
    - Uses: Grid rendering/debugging
    - Returns: Color - terrain color

13. save_terrain_data() -> bool
    - What it does: Serializes terrain to user://terrain_save.dat
    - Uses: Saving game state
    - Returns: bool - true if successful

14. load_terrain_data() -> bool
    - What it does: Loads terrain from save file, emits terrain_updated signal
    - Uses: Loading game state
   - Returns: bool - true if successful

15. get_debug_summary() -> String
    - What it does: Returns formatted string with terrain statistics and distribution
    - Uses: Debugging and logging
    - Returns: String - debug information

16. debug_print() -> void
    - What it does: Prints debug summary to console
    - Uses: Called for debugging terrain state
    - Returns: void

NOTES:
- Depends on GridManager for grid dimensions and coordinate access
- Uses FastNoiseLite for procedural generation (Perlin noise)
- TerrainData inner class with serialize/deserialize for save system
- Terrain types: GRASS (default), DIRT, SAND, STONE, WATER (impassable), FOREST, MOUNTAIN
- Height thresholds: Water <-0.6, Sand <-0.5, Grass <0.2, Dirt <0.4, Forest <0.6, Stone <0.8, Mountain >=0.8
- Movement costs range from 1 (grass/dirt) to 4 (mountain), water=3 but impassable
- Defense bonuses: 0-3, Avoid bonuses: 0-15
- Obstacle spawn chances: 30% on mountains, 20% in forests
- Configuration exports: height_scale (2.0), height_smoothness (0.5), water_level (-0.5), noise_frequency (0.1)
- Emits terrain_generated and terrain_updated signals
- Color mapping for visualization included
"""


extends Node
class_name TerrainManager

## Manages procedural terrain with height maps, types, and properties

# --- Terrain Type Enum ---
enum TerrainType {
	GRASS = 0,
	DIRT = 1,
	SAND = 2,
	STONE = 3,
	WATER = 4,
	FOREST = 5,
	MOUNTAIN = 6
}

const TERRAIN_NAMES: Dictionary = {
	TerrainType.GRASS: "Grass",
	TerrainType.DIRT: "Dirt",
	TerrainType.SAND: "Sand",
	TerrainType.STONE: "Stone",
	TerrainType.WATER: "Water",
	TerrainType.FOREST: "Forest",
	TerrainType.MOUNTAIN: "Mountain"
}

# --- Terrain Data Class ---
class TerrainData:
	var height: float = 0.0
	var type: TerrainType = TerrainType.GRASS
	var movement_cost: int = 1
	var defense_bonus: int = 0
	var avoid_bonus: int = 0
	var can_traverse: bool = true
	
	func serialize() -> Dictionary:
		return {
			"height": height,
			"type": type,
			"movement_cost": movement_cost,
			"defense_bonus": defense_bonus,
			"avoid_bonus": avoid_bonus,
			"can_traverse": can_traverse
		}
	
	func deserialize(data: Dictionary) -> void:
		height = data.get("height", 0.0)
		type = data.get("type", TerrainType.GRASS)
		movement_cost = data.get("movement_cost", 1)
		defense_bonus = data.get("defense_bonus", 0)
		avoid_bonus = data.get("avoid_bonus", 0)
		can_traverse = data.get("can_traverse", true)

# --- Configuration ---
@export var height_scale: float = 2.0
@export var height_smoothness: float = 0.5
@export var water_level: float = GameConfig.Terrain.HEIGHT_WATER_LEVEL
@export var noise_seed: int = 0
@export var noise_frequency: float = 0.1

# --- Data Storage ---
var terrain_data: Dictionary[Vector2i, TerrainData] = {}  # Vector2i -> TerrainData
var obstacles: Dictionary[Vector2i, bool] = {}  # Vector2i -> bool

# --- Noise Generator ---
var noise: FastNoiseLite

# --- Signals ---
signal terrain_generated()
signal terrain_updated()


func _ready() -> void:
	_initialize_noise()
	add_to_group("terrain_manager")


## Initialize noise generator
func _initialize_noise() -> void:
	noise = FastNoiseLite.new()
	noise.seed = noise_seed if noise_seed != 0 else randi()
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN


## Generate procedural terrain
func generate_terrain() -> void:
	print("TerrainManager: Generating terrain...")
	
	var grid_size: Vector2i = GridManager.grid_size
	var cells_generated := 0
	
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var grid_pos := Vector2i(x, y)
			_generate_cell_terrain(grid_pos)
			cells_generated += 1
	
	print("TerrainManager: Generated %d terrain cells" % cells_generated)
	terrain_generated.emit()


## Generate terrain for single cell
## @param grid_pos: Grid position
func _generate_cell_terrain(grid_pos: Vector2i) -> void:
	var data := TerrainData.new()
	
	# Generate height from noise
	var noise_value := noise.get_noise_2d(float(grid_pos.x), float(grid_pos.y))
	var height := noise_value * height_scale
	
	# Apply smoothing
	height = lerp(0.0, height, height_smoothness)
	data.height = height
	
	# Determine terrain type based on height
	_classify_terrain(data, height)
	
	# Store data
	terrain_data[grid_pos] = data
	
	# Update GridManager if needed
	if GridManager.has_method("set_height"):
		GridManager.set_height(grid_pos, height)


## Classify terrain type based on height
## @param data: TerrainData to update
## @param height: Height value
func _classify_terrain(data: TerrainData, height: float) -> void:
	if height < water_level - 0.1:
		data.type = TerrainType.WATER
		data.movement_cost = GameConfig.Terrain.COST_IMPASSABLE
		data.can_traverse = false
		data.defense_bonus = 0
		data.avoid_bonus = 0
	
	elif height < water_level:
		data.type = TerrainType.SAND
		data.movement_cost = GameConfig.Terrain.COST_DIFFICULT
		data.can_traverse = true
		data.defense_bonus = 0
		data.avoid_bonus = 0
	
	elif height < GameConfig.Terrain.HEIGHT_GRASS:
		data.type = TerrainType.GRASS
		data.movement_cost = GameConfig.Terrain.COST_DEFAULT
		data.can_traverse = true
		data.defense_bonus = 0
		data.avoid_bonus = 0
	
	elif height < GameConfig.Terrain.HEIGHT_DIRT:
		data.type = TerrainType.DIRT
		data.movement_cost = GameConfig.Terrain.COST_DEFAULT
		data.can_traverse = true
		data.defense_bonus = GameConfig.Terrain.BONUS_DEF_DIRT
		data.avoid_bonus = 0
	
	elif height < GameConfig.Terrain.HEIGHT_FOREST:
		data.type = TerrainType.FOREST
		data.movement_cost = GameConfig.Terrain.COST_DIFFICULT
		data.can_traverse = true
		data.defense_bonus = GameConfig.Terrain.BONUS_DEF_FOREST
		data.avoid_bonus = GameConfig.Terrain.BONUS_AVO_FOREST
	
	elif height < GameConfig.Terrain.HEIGHT_STONE:
		data.type = TerrainType.STONE
		data.movement_cost = GameConfig.Terrain.COST_DIFFICULT
		data.can_traverse = true
		data.defense_bonus = GameConfig.Terrain.BONUS_DEF_STONE
		data.avoid_bonus = GameConfig.Terrain.BONUS_AVO_STONE
	
	else:
		data.type = TerrainType.MOUNTAIN
		data.movement_cost = GameConfig.Terrain.COST_MOUNTAIN
		data.can_traverse = true
		data.defense_bonus = GameConfig.Terrain.BONUS_DEF_MOUNTAIN
		data.avoid_bonus = GameConfig.Terrain.BONUS_AVO_MOUNTAIN


## Place random obstacles
func place_obstacles() -> void:
	var obstacle_count := 0
	
	for grid_pos in terrain_data:
		var data := terrain_data[grid_pos]
		
		# Mountains have rocks
		if data.type == TerrainType.MOUNTAIN and randf() < 0.3:
			obstacles[grid_pos] = true
			data.can_traverse = false
			obstacle_count += 1
		
		# Forests have dense trees
		elif data.type == TerrainType.FOREST and randf() < 0.2:
			obstacles[grid_pos] = true
			data.movement_cost = 3
			obstacle_count += 1
	
	print("TerrainManager: Placed %d obstacles" % obstacle_count)


## Get height at grid position
## @param grid_pos: Grid position
## @return: Height value
func get_height(grid_pos: Vector2i) -> float:
	var data := terrain_data.get(grid_pos)
	return data.height if data else 0.0


## Get terrain data at position
## @param grid_pos: Grid position
## @return: TerrainData or null
func get_terrain_data(grid_pos: Vector2i) -> TerrainData:
	return terrain_data.get(grid_pos, null)


## Check if position is traversable
## @param grid_pos: Grid position
## @return: true if can traverse
func is_traversable(grid_pos: Vector2i) -> bool:
	var data := get_terrain_data(grid_pos)
	if not data:
		return false
	return data.can_traverse and not obstacles.get(grid_pos, false)


## Get movement cost for terrain
## @param grid_pos: Grid position
## @return: Movement cost
func get_movement_cost(grid_pos: Vector2i) -> int:
	var data := get_terrain_data(grid_pos)
	return data.movement_cost if data else 1


## Get terrain bonus
## @param grid_pos: Grid position
## @param bonus_type: "defense" or "avoid"
## @return: Bonus value
func get_terrain_bonus(grid_pos: Vector2i, bonus_type: String) -> int:
	var data := get_terrain_data(grid_pos)
	if not data:
		return 0
	
	match bonus_type:
		"defense":
			return data.defense_bonus
		"avoid":
			return data.avoid_bonus
		_:
			return 0


## Get terrain color for visualization
## @param grid_pos: Grid position
## @return: Color
func get_terrain_color(grid_pos: Vector2i) -> Color:
	var data := get_terrain_data(grid_pos)
	if not data:
		return Color.GRAY
	
	match data.type:
		TerrainType.GRASS:
			return Color(0.2, 0.6, 0.2)
		TerrainType.DIRT:
			return Color(0.5, 0.3, 0.2)
		TerrainType.SAND:
			return Color(0.9, 0.8, 0.6)
		TerrainType.STONE:
			return Color(0.5, 0.5, 0.5)
		TerrainType.WATER:
			return Color(0.2, 0.4, 0.8)
		TerrainType.FOREST:
			return Color(0.1, 0.4, 0.1)
		TerrainType.MOUNTAIN:
			return Color(0.6, 0.5, 0.4)
		_:
			return Color.GRAY


## Save terrain data
## @return: true if successful
func save_terrain_data() -> bool:
	var save_data := {
		"version": 1,
		"noise_seed": noise.seed,
		"terrain_data": {},
		"obstacles": obstacles
	}
	
	# Serialize terrain data
	for grid_pos in terrain_data:
		var key := "%d,%d" % [grid_pos.x, grid_pos.y]
		save_data.terrain_data[key] = terrain_data[grid_pos].serialize()
	
	var save_file := FileAccess.open("user://terrain_save.dat", FileAccess.WRITE)
	if not save_file:
		push_error("TerrainManager: Failed to open save file!")
		return false
	
	save_file.store_var(save_data)
	save_file.close()
	
	print("TerrainManager: Saved terrain data")
	return true


## Load terrain data
## @return: true if successful
func load_terrain_data() -> bool:
	if not FileAccess.file_exists("user://terrain_save.dat"):
		print("TerrainManager: No save file found")
		return false
	
	var save_file := FileAccess.open("user://terrain_save.dat", FileAccess.READ)
	if not save_file:
		push_error("TerrainManager: Failed to open save file!")
		return false
	
	var save_data: Variant = save_file.get_var()
	save_file.close()
	
	if not save_data is Dictionary:
		push_error("TerrainManager: Invalid save data!")
		return false
	
	# Restore noise seed
	noise.seed = save_data.get("noise_seed", 0)
	
	# Restore terrain data
	terrain_data.clear()
	var terrain_dict: Dictionary = save_data.get("terrain_data", {})
	for key in terrain_dict:
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		
		var grid_pos := Vector2i(int(parts[0]), int(parts[1]))
		var data := TerrainData.new()
		data.deserialize(terrain_dict[key])
		terrain_data[grid_pos] = data
	
	# Restore obstacles
	obstacles = save_data.get("obstacles", {})
	
	print("TerrainManager: Loaded terrain data (%d cells)" % terrain_data.size())
	terrain_updated.emit()
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Terrain Manager ===\n"
	summary += "Cells: %d\n" % terrain_data.size()
	summary += "Obstacles: %d\n" % obstacles.size()
	summary += "Noise Seed: %d\n" % noise.seed
	
	# Count terrain types
	var type_counts := {}
	for grid_pos in terrain_data:
		var type := terrain_data[grid_pos].type
		type_counts[type] = type_counts.get(type, 0) + 1
	
	summary += "\nTerrain Distribution:\n"
	for type in type_counts:
		summary += "  %s: %d\n" % [TERRAIN_NAMES[type], type_counts[type]]
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
