"""
FILE: path_display.gd
PURPOSE: Visualizes unit movement paths in 3D with connected nodes and segments.

OVERVIEW:
This class renders movement paths as a series of sphere nodes connected by cylinder segments, creating
a clear visual representation of planned unit movement. Start and end nodes are larger for emphasis,
while middle waypoints are smaller. Path color and visibility can be dynamically updated, and the
system provides debugging utilities for path inspection.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Initializes path materials with configured colors and emission
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. _setup_materials() -> void
   - What it does: Creates StandardMaterial3D instances for path segments and nodes with transparency and emission
   - Uses: Called during initialization
   - Returns: void

3. display_path(path_positions: Array[Vector2i]) -> void
   - What it does: Clears existing path and creates visual nodes and segments for new path
   - Uses: Called when displaying a unit's movement path
   - Returns: void

4. clear_path() -> void
   - What it does: Frees all path node and segment meshes, clears arrays
   - Uses: Called when path is cancelled or before displaying new path
   - Returns: void

5. _create_path_node(position: Vector3, index: int, total: int) -> void
   - What it does: Creates SphereMesh at position with size scaled based on whether it's start, end, or middle node
   - Uses: Called for each waypoint in the path
   - Returns: void

6. _create_path_segment(start: Vector3, end: Vector3) -> void
   - What it does: Creates CylinderMesh connecting two positions, oriented along the connection vector
   - Uses: Called between consecutive path nodes to show connection
   - Returns: void

7. _get_path_world_pos(grid_pos: Vector2i) -> Vector3
   - What it does: Converts grid position to world 3D position with height offset for path visualization
   - Uses: Helper to position path elements above terrain
   - Returns: Vector3 - world position with height offset

8. update_path_color(color: Color) -> void
   - What it does: Changes path color and updates material on all existing segments
   - Uses: Called to dynamically recolor the path
   - Returns: void

9. set_path_visible(visible_state: bool) -> void
   - What it does: Shows or hides entire path display
   - Uses: Called to toggle path visibility
   - Returns: void

10. get_current_path() -> Array[Vector2i]
    - What it does: Returns duplicate of current path grid positions
    - Uses: Query method for external systems
    - Returns: Array[Vector2i] - path positions

11. has_path() -> bool
    - What it does: Checks if any path is currently displayed
    - Uses: Query method to test path state
    - Returns: bool - true if path exists

12. get_path_length() -> int
    - What it does: Returns number of nodes in current path
    - Uses: Query method for path size
    - Returns: int - node count

13. get_debug_summary() -> String
    - What it does: Returns formatted string with path statistics and first 5 positions
    - Uses: Debugging and logging
    - Returns: String - debug information

14. debug_print() -> void
    - What it does: Prints debug summary to console
    - Uses: Called for debugging path state
    - Returns: void

NOTES:
- Depends on GridManager for grid-to-world coordinate conversion
- Uses @export vars for configuration: path_color (cyan), node_color (white), path_width (0.1), node_size (0.2), height_offset (0.05)
- Node scaling: start=1.2x, end=1.5x, middle=0.6x for visual hierarchy
- Path segments are cylinders rotated to connect consecutive nodes
- All materials use unshaded mode for consistent appearance independent of lighting
- Materials have transparency and emission for glowing effect
- Emission intensity: path=color*0.3, node=color*0.5
- Minimum path length is 2 (requires at least start and end)
- All mesh instances properly freed with is_instance_valid check before queue_free
- Height offset ensures path renders above terrain surface
"""

# path_display.gd - Visualizes movement paths in 3D
extends Node3D
class_name PathDisplay

## Renders movement paths with nodes and connections

# --- Configuration ---
@export var path_color: Color = Color.CYAN
@export var node_color: Color = Color.WHITE
@export var path_width: float = 0.1
@export var node_size: float = 0.2
@export var height_offset: float = 0.05

# --- Materials ---
var path_material: StandardMaterial3D
var node_material: StandardMaterial3D

# --- Path Elements ---
var path_nodes: Array[MeshInstance3D] = []
var path_segments: Array[MeshInstance3D] = []

# --- State ---
var current_path: Array[Vector2i] = []
var is_visible: bool = true


func _ready() -> void:
	_setup_materials()


## Setup materials for path visualization
func _setup_materials() -> void:
	path_material = StandardMaterial3D.new()
	path_material.albedo_color = path_color
	path_material.emission_enabled = true
	path_material.emission = path_color * 0.3
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	node_material = StandardMaterial3D.new()
	node_material.albedo_color = node_color
	node_material.emission_enabled = true
	node_material.emission = node_color * 0.5
	node_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Display path through grid positions
## @param path_positions: Array of grid positions
func display_path(path_positions: Array[Vector2i]) -> void:
	clear_path()
	
	if path_positions.size() < 2:
		return
	
	current_path = path_positions.duplicate()
	
	# Create nodes and segments
	for i in range(path_positions.size()):
		var grid_pos := path_positions[i]
		var world_pos := _get_path_world_pos(grid_pos)
		
		# Create node
		_create_path_node(world_pos, i, path_positions.size())
		
		# Create segment to previous node
		if i > 0:
			var prev_pos := _get_path_world_pos(path_positions[i - 1])
			_create_path_segment(prev_pos, world_pos)
	
	is_visible = true


## Clear all path visuals
func clear_path() -> void:
	for node in path_nodes:
		if is_instance_valid(node):
			node.queue_free()
	
	for segment in path_segments:
		if is_instance_valid(segment):
			segment.queue_free()
	
	path_nodes.clear()
	path_segments.clear()
	current_path.clear()


## Create visual node for path position
## @param position: World position
## @param index: Node index in path
## @param total: Total nodes in path
func _create_path_node(position: Vector3, index: int, total: int) -> void:
	var node := MeshInstance3D.new()
	node.name = "PathNode_%d" % index
	
	# Create sphere mesh
	var sphere := SphereMesh.new()
	sphere.radius = node_size
	sphere.height = node_size * 2
	node.mesh = sphere
	node.material_override = node_material
	
	# Position
	node.global_position = position
	
	# Scale based on position (larger for start/end)
	if index == 0:
		node.scale = Vector3.ONE * 1.2  # Start
	elif index == total - 1:
		node.scale = Vector3.ONE * 1.5  # End
	else:
		node.scale = Vector3.ONE * 0.6  # Middle
	
	add_child(node)
	path_nodes.append(node)


## Create segment between two positions
## @param start: Start position
## @param end: End position
func _create_path_segment(start: Vector3, end: Vector3) -> void:
	var segment := MeshInstance3D.new()
	segment.name = "PathSegment_%d" % path_segments.size()
	
	# Create cylinder mesh
	var distance := start.distance_to(end)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = path_width
	cylinder.bottom_radius = path_width
	cylinder.height = distance
	
	segment.mesh = cylinder
	segment.material_override = path_material
	
	# Position and orient
	segment.global_position = (start + end) / 2.0
	segment.look_at(end, Vector3.UP)
	segment.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	
	add_child(segment)
	path_segments.append(segment)


## Get world position for path visualization
## @param grid_pos: Grid position
## @return: World position with height offset
func _get_path_world_pos(grid_pos: Vector2i) -> Vector3:
	var world_pos := GridManager.grid_to_world_3d(grid_pos)
	world_pos.y += height_offset
	return world_pos


## Update path color
## @param color: New path color
func update_path_color(color: Color) -> void:
	path_color = color
	path_material.albedo_color = color
	path_material.emission = color * 0.3
	
	# Update existing segments
	for segment in path_segments:
		if is_instance_valid(segment):
			segment.material_override = path_material


## Set visibility
## @param visible: Whether path should be visible
func set_path_visible(visible_state: bool) -> void:
	is_visible = visible_state
	self.visible = visible_state


## Get current path
## @return: Array of grid positions
func get_current_path() -> Array[Vector2i]:
	return current_path.duplicate()


## Check if path is displayed
## @return: true if path exists
func has_path() -> bool:
	return not current_path.is_empty()


## Get path length
## @return: Number of nodes in path
func get_path_length() -> int:
	return current_path.size()


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Path Display ===\n"
	summary += "Nodes: %d\n" % path_nodes.size()
	summary += "Segments: %d\n" % path_segments.size()
	summary += "Visible: %s\n" % is_visible
	
	if not current_path.is_empty():
		summary += "Path: "
		for i in range(min(5, current_path.size())):
			summary += "%s " % current_path[i]
		if current_path.size() > 5:
			summary += "... (%d more)" % (current_path.size() - 5)
		summary += "\n"
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
