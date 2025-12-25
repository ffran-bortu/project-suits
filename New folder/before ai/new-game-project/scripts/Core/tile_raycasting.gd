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
