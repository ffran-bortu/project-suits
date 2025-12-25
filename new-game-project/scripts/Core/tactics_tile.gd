"""
FILE: tactics_tile.gd
PURPOSE: Represents a single tile on the tactical grid with state management and visual highlights.

OVERVIEW:
Each tile on the battle grid is a TacticsTile node that manages its own state (reachable, attackable,
hover) and updates its visual highlight accordingly. Uses the dirty flag pattern (Section 2.4) to
only update visuals when state changes, improving performance. Provides grid-based neighbor finding
(no raycasting needed) and occupancy checking via raycasts. Stores pathfinding data (parent, distance).

FUNCTIONS IN THIS FILE:

1. _ensure_materials_loaded()
   - What it does: Lazily loads highlight materials from GameConfig on first use
   - Uses: Called before updating visuals to ensure materials available
   - Returns: void

2. _update_visual_state()
   - What it does: Updates tile mesh visibility and material based on current state flags
   - Uses: Called by _process() when _state_dirty flag is true
   - Returns: void

3. get_neighbors(max_height_diff)
   - What it does: Returns array of adjacent tiles within height range (grid-based, no raycasts)
   - Uses: For pathfinding neighbor traversal
   - Returns: Array[TacticsTile]

4. get_occupier()
   - What it does: Raycasts upward to detect if a unit is standing on this tile
   - Uses: For movement blocking, combat target detection
   - Returns: Unit node or null

5. is_occupied()
   - What it does: Quick check if tile has a unit on it
   - Uses: Before allowing movement to tile
   - Returns: bool

6. reset_markers()
   - What it does: Clears pathfinding data and state flags (called before each pathfinding)
   - Uses: At start of movement range calculation
   - Returns: void

7. set_grid_position(pos, world_pos)
   - What it does: Sets tile's grid coordinates and 3D world position
   - Uses: During grid initialization by GridManager
   - Returns: void

NOTES:
- Each tile is a StaticBody3D node with collision for raycasting
- Uses dirty flag pattern: reachable/attackable/hover setters mark _state_dirty = true
- _process() only runs visual update if _state_dirty (performance optimization per Section 2.4)
- Materials: cursor (hover), movement/movement_hover (reachable), attack/attack_hover (attackable)
- Pathfinding data: pf_root (parent tile), pf_distance (cost from start)
- Grid data: grid_pos (Vector2i), height (float)
- Depends on: GridManager (for get_tile_at), GameConfig (for materials)
"""

class_name TacticsTile
extends StaticBody3D
## Represents a single tile on the tactical grid
##
## Each tile handles its own state (reachable, attackable, hover) and provides
## raycasting capabilities for neighbor detection and occupancy checking.
## This is a significant improvement over dictionary-based positioning.

#region State Flags
## Whether this tile is reachable by the current unit
var reachable: bool = false:
	set(value):
		if reachable != value:
			reachable = value
			_state_dirty = true

## Whether this tile is attackable by the current unit
var attackable: bool = false:
	set(value):
		if attackable != value:
			attackable = value
			_state_dirty = true

## Whether the cursor is currently hovering over this tile
var hover: bool = false:
	set(value):
		if hover != value:
			hover = value
			_state_dirty = true

## Internal flag to track if visual state needs updating
var _state_dirty: bool = false
#endregion

#region Pathfinding Data
## Parent tile in pathfinding algorithm (for path reconstruction)
var pf_root: TacticsTile = null
## Distance from pathfinding start point
var pf_distance: float = 0.0
#endregion

#region Grid Data
## Grid position of this tile (x, y coordinates)
var grid_pos: Vector2i = Vector2i(0, 0)
## Height level of this tile
var height: float = 0.0
#endregion

#region Visual Components
## Mesh for highlighting (hidden by default)
@onready var tile_mesh: MeshInstance3D = $TileMesh
## Materials for different states
var hover_mat: StandardMaterial3D = null
var reachable_mat: StandardMaterial3D = null
var hover_reachable_mat: StandardMaterial3D = null
var attackable_mat: StandardMaterial3D = null
var hover_attackable_mat: StandardMaterial3D = null
var _materials_loaded: bool = false
#endregion

func _ready() -> void:
	# Start with mesh hidden
	if tile_mesh:
		tile_mesh.visible = false
	
	# Mark initial state as dirty to ensure proper initialization
	_state_dirty = true

## Load materials from GameConfig (deferred to avoid init order issues)
func _ensure_materials_loaded() -> void:
	if _materials_loaded:
		return
	
	# Load materials from GameConfig
	hover_mat = GameConfig.get_material("cursor")
	reachable_mat = GameConfig.get_material("movement")
	hover_reachable_mat = GameConfig.get_material("movement_hover")
	attackable_mat = GameConfig.get_material("attack")
	hover_attackable_mat = GameConfig.get_material("attack_hover")
	
	_materials_loaded = true

func _process(_delta: float) -> void:
	# Only update if state changed
	if not _state_dirty:
		return
	
	_update_visual_state()
	_state_dirty = false

## Update the visual state of the tile based on current flags
func _update_visual_state() -> void:
	if not tile_mesh:
		return
	
	# Ensure materials are loaded
	_ensure_materials_loaded()
	
	# Update visibility - show if any state is active
	tile_mesh.visible = attackable or reachable or hover
	
	# Update material based on state priority
	if hover:
		if reachable:
			tile_mesh.set_surface_override_material(0, hover_reachable_mat)
		elif attackable:
			tile_mesh.set_surface_override_material(0, hover_attackable_mat)
		else:
			tile_mesh.set_surface_override_material(0, hover_mat)
	else:
		if reachable:
			tile_mesh.set_surface_override_material(0, reachable_mat)
		elif attackable:
			tile_mesh.set_surface_override_material(0, attackable_mat)

## Get all neighboring tiles within a given height range
##
## Uses simple grid mathematics to find adjacent tiles, eliminating
## the need for raycasting and physics frame dependencies.
##
## @param max_height_diff: Maximum height difference to consider as neighbor
## @return: Array of neighboring TacticsTile objects
func get_neighbors(max_height_diff: float = 1.0) -> Array[TacticsTile]:
	var neighbors: Array[TacticsTile] = []
	
	# 4 cardinal directions (grid-based, no raycasts needed!)
	var directions = [
		Vector2i(0, -1),  # North
		Vector2i(0, 1),   # South  
		Vector2i(-1, 0),  # West
		Vector2i(1, 0)    # East
	]
	
	for dir in directions:
		var neighbor_pos = grid_pos + dir
		var neighbor_tile = GridManager.get_tile_at(neighbor_pos)
		
		if neighbor_tile:
			var height_diff = abs(neighbor_tile.height - height)
			if height_diff <= max_height_diff:
				neighbors.append(neighbor_tile)
	
	print("TacticsTile %s: Found %d valid neighbors (grid-based)" % [grid_pos, neighbors.size()])
	return neighbors

## Get the unit currently occupying this tile
##
## Uses upward raycasting to detect if there's a unit on this tile.
##
## @return: The Unit node on this tile, or null if empty
func get_occupier():
	if not has_node("RayCasting/Above"):
		return null
	
	var raycast = $RayCasting/Above
	var collider = raycast.get_collider()
	
	# Check if it's a unit (has required methods/properties)
	if collider and collider.has_method("is_alive"):
		return collider
	
	return null

## Check if this tile is occupied by any unit
##
## @return: true if a unit is on this tile, false otherwise
func is_occupied() -> bool:
	return get_occupier() != null

## Reset all pathfinding markers
##
## Called at the start of each pathfinding operation to clear old data.
func reset_markers() -> void:
	pf_root = null
	pf_distance = 0.0
	reachable = false
	attackable = false

## Set this tile's grid position and world position
##
## @param pos: Grid coordinates (x, y)
## @param world_pos: Corresponding 3D world position
func set_grid_position(pos: Vector2i, world_pos: Vector3) -> void:
	grid_pos = pos
	global_position = world_pos
