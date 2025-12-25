class_name TacticsTile
extends StaticBody3D
## Represents a single tile on the tactical grid
##
## Each tile handles its own state (reachable, attackable, hover) and provides
## raycasting capabilities for neighbor detection and occupancy checking.
## This is a significant improvement over dictionary-based positioning.

#region State Flags
## Whether this tile is reachable by the current unit
var reachable: bool = false
## Whether this tile is attackable by the current unit
var attackable: bool = false
## Whether the cursor is currently hovering over this tile
var hover: bool = false
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
var hover_mat: StandardMaterial3D
var reachable_mat: StandardMaterial3D
var hover_reachable_mat: StandardMaterial3D
var attackable_mat: StandardMaterial3D
var hover_attackable_mat: StandardMaterial3D
#endregion

func _ready():
	# Load materials from GameConfig
	hover_mat = GameConfig.get_material("cursor")
	reachable_mat = GameConfig.get_material("movement")
	hover_reachable_mat = GameConfig.get_material("movement_hover")
	attackable_mat = GameConfig.get_material("attack")
	hover_attackable_mat = GameConfig.get_material("attack_hover")
	
	# Start with mesh hidden
	if tile_mesh:
		tile_mesh.visible = false

func _process(_delta: float) -> void:
	if not tile_mesh:
		return
	
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
## Uses raycasting to detect adjacent tiles that are within the specified
## height difference, respecting the game's climb/descend rules.
##
## @param max_height_diff: Maximum height difference to consider as neighbor
## @return: Array of neighboring TacticsTile objects
func get_neighbors(max_height_diff: float = 1.0) -> Array[TacticsTile]:
	var neighbors: Array[TacticsTile] = []
	
	if not has_node("RayCasting/Neighbors"):
		return neighbors
	
	var raycast_container = $RayCasting/Neighbors
	for ray in raycast_container.get_children():
		if ray is RayCast3D:
			var collider = ray.get_collider()
			if collider and collider is TacticsTile:
				var neighbor = collider as TacticsTile
				var height_diff = abs(neighbor.height - height)
				
				if height_diff <= max_height_diff:
					neighbors.append(neighbor)
	
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
func set_grid_position(pos: Vector2i, world_pos: Vector3):
	grid_pos = pos
	global_position = world_pos
