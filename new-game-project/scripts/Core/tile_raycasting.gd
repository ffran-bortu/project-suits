"""
FILE: tile_raycasting.gd
PURPOSE: Raycasting component for TacticsTile neighbor and unit occupancy detection.

OVERVIEW:
This Node3D component is attached to each TacticsTile to handle raycasting for finding neighboring tiles
and detecting units standing on the tile. Contains child RayCast3D nodes pointing in 4 cardinal directions
(for neighbors) and one pointing up (for occupancy). NOTE: This class has a typo in the name (Tilte instead
of Tile) but fixing it would break existing scenes.

FUNCTIONS IN THIS FILE:

1. get_all_neighbors(height)
   - What it does: Returns array of neighboring tiles within specified height range
   - Uses: For pathfinding neighbor traversal (checks height difference for climbability)
   - Returns: Array[Node3D]

2. get_object_above()
   - What it does: Returns the object (unit) standing on this tile via upward raycast
   - Uses: For occupancy checks during pathfinding and movement validation
   - Returns: Object (Unit node) or null

NOTES:
- Class_name has typo: TilteRaycasting (should be TileRaycasting, but kept for compatibility)
- Extends Node3D (attached to TacticsTile as child)
- Contains child nodes: "Neighbors" container with 4 RayCast3D children, "Above" RayCast3D
- No dependencies (used by TacticsTile)
- Deprecated: GridManager now uses grid-based neighbor finding instead of raycasts for better performance
"""

class_name TilteRaycasting
extends Node3D
## Handles raycasting for TacticsTile neighbor and occupancy detection

## Get all neighboring tiles within height range
##
## @param height: Maximum height difference to consider
## @return: Array of neighboring Node3D objects (TacticsTiles)
func get_all_neighbors(height: float) -> Array[Node3D]:
	var neighbors: Array[Node3D] = []
	
	if not has_node("Neighbors"):
		return neighbors
	
	for ray in $Neighbors.get_children():
		if ray is RayCast3D:
			var obj = ray.get_collider()
			
			# Check if object exists and is within height range
			if obj and abs(obj.global_position.y - get_parent().global_position.y) <= height:
				neighbors.append(obj)
	
	return neighbors

## Get the object directly above the tile
##
## @return: Object above tile, or null if none
func get_object_above() -> Object:
	if not has_node("Above"):
		return null
	
	return $Above.get_collider()
