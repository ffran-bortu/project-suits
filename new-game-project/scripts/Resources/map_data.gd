"""
FILE: map_data.gd
PURPOSE: Container for world map campaign data with node graph, connections, and progress tracking.

OVERVIEW:
This resource holds the entire world map structure as an array of WorldMapNode objects, managing the
campaign's node graph, progression paths, and completion tracking. Uses caching for fast node lookups
by ID, validates node connections and requirements, and calculates overall completion percentage.
Supports adding/removing nodes dynamically and repairing invalid data.

FUNCTIONS IN THIS FILE:

1. get_node(node_id)
   - What it does: Returns WorldMapNode by ID using cache
   - Uses: Accessing specific nodes during gameplay
   - Returns: WorldMapNode or null

2. get_node_by_name(node_name)
   - What it does: Finds node by display name (linear search)
   - Uses: Debug commands, name-based lookups
   - Returns: WorldMapNode or null

3. has_node(node_id)
   - What it does: Checks if node ID exists in map
   - Uses: Validation, connection checking
   - Returns: bool

4. get_available_nodes(current_node_id)
   - What it does: Returns array of unlocked next nodes from current position
   - Uses: UI displays available destinations
   - Returns: Array of accessible WorldMapNode objects

5. get_unlocked_nodes()
   - What it does: Returns all nodes with is_unlocked = true
   - Uses: Progress tracking, save displays
   - Returns: Array of WorldMapNode

6. get_completed_nodes()
   - What it does: Returns all nodes with is_completed = true
   - Uses: Progress tracking, completion percentage
   - Returns: Array of WorldMapNode

7. get_starting_node()
   - What it does: Returns node matching starting_node_id
   - Uses: Campaign initialization, new game
   - Returns: WorldMapNode or null

8. _rebuild_cache()
   - What it does: Clears and repopulates _node_cache dictionary from nodes array
   - Uses: Called when cache_dirty flag is true
   - Returns: void

9. _mark_cache_dirty()
   - What it does: Sets cache_dirty = true to force rebuild on next access
   - Uses: Called after adding/removing nodes
   - Returns: void

10. add_node(node)
    - What it does: Appends node to nodes array, marks cache dirty
    - Uses: Dynamic node creation, procedural maps
    - Returns: true if added (checks for duplicates and empty IDs)

11. remove_node(node_id)
    - What it does: Removes node from nodes array by ID
    - Uses: Dynamic map editing
    - Returns: true if found and removed

12. validate_map_data()
    - What it does: Checks for errors like empty IDs, missing starting node, broken connections, duplicate IDs
    - Uses: Resource creation, saveload, development
    - Returns: Array of error message strings

13. repair_map_data()
    - What it does: Fixes invalid data by generating IDs, removing nulls, setting starting node
    - Uses: Automatic repair after loading corrupted maps
    - Returns: true if repairs made

14. get_completion_percentage()
    - What it does: Calculates percentage of required (non-optional) nodes completed
    - Uses: Progress bars, achievement tracking
    - Returns: float 0-100

15. get_debug_summary()
    - What it does: Creates formatted summary with node counts, validation status
    - Uses: Development debugging
    - Returns: String summary

16. debug_print()
    - What it does: Prints debug summary to console
    - Uses: Quick debugging
    - Returns: void

NOTES:
- Uses _node_cache Dictionary for O(1) node lookups by ID
- cache_dirty flag triggers rebuild on next access
- Validates node connections (next_nodes, required_nodes must exist)
- Detects duplicate node IDs during validation
- starting_node_id must reference an existing node
- Supports background_texture and map_music for world map visuals
- Completion percentage only counts non-optional nodes
- repair_map_data() calls repair_node() on each node
- add_node() rejects nodes with empty ID or duplicate ID
"""


class_name MapData
extends Resource

## World map data container with node management and validation

# --- Basic Info ---
@export_group("Map Info")
@export var map_id: String = ""
@export var map_name: String = "Main Campaign"
@export_multiline var map_description: String = ""

# --- Nodes ---
@export_group("Nodes")
@export var nodes: Array[WorldMapNode] = []
@export var starting_node_id: String = ""

# --- Visuals ---
@export_group("Visuals")
@export var background_texture: Texture2D
@export var map_music: AudioStream

# --- Cache ---
var _node_cache: Dictionary = {}  # node_id -> WorldMapNode
var _cache_dirty: bool = true


## Get node by ID
## @param node_id: Node ID
## @return: WorldMapNode or null
func get_node(node_id: String) -> WorldMapNode:
	if _cache_dirty:
		_rebuild_cache()
	return _node_cache.get(node_id, null)


## Get node by name
## @param node_name: Node name
## @return: WorldMapNode or null
func get_node_by_name(node_name: String) -> WorldMapNode:
	for node in nodes:
		if node.node_name == node_name:
			return node
	return null


## Check if has node
## @param node_id: Node ID
## @return: true if exists
func has_node(node_id: String) -> bool:
	if _cache_dirty:
		_rebuild_cache()
	return _node_cache.has(node_id)


## Get available nodes from current node
## @param current_node_id: Current node ID
## @return: Array of accessible nodes
func get_available_nodes(current_node_id: String) -> Array[WorldMapNode]:
	var current_node := get_node(current_node_id)
	var available: Array[WorldMapNode] = []
	
	if not current_node:
		return available
	
	for next_node_id in current_node.next_nodes:
		var next_node := get_node(next_node_id)
		if next_node and next_node.is_unlocked:
			available.append(next_node)
	
	return available


## Get all unlocked nodes
## @return: Array of unlocked nodes
func get_unlocked_nodes() -> Array[WorldMapNode]:
	var unlocked: Array[WorldMapNode] = []
	for node in nodes:
		if node.is_unlocked:
			unlocked.append(node)
	return unlocked


## Get all completed nodes
## @return: Array of completed nodes
func get_completed_nodes() -> Array[WorldMapNode]:
	var completed: Array[WorldMapNode] = []
	for node in nodes:
		if node.is_completed:
			completed.append(node)
	return completed


## Get starting node
## @return: WorldMapNode or null
func get_starting_node() -> WorldMapNode:
	return get_node(starting_node_id)


## Rebuild node cache
func _rebuild_cache() -> void:
	_node_cache.clear()
	for node in nodes:
		if node and not node.node_id.is_empty():
			_node_cache[node.node_id] = node
	_cache_dirty = false


## Mark cache as dirty
func _mark_cache_dirty() -> void:
	_cache_dirty = true


## Add node
## @param node: Node to add
## @return: true if added
func add_node(node: WorldMapNode) -> bool:
	if not node:
		return false
	
	if node.node_id.is_empty():
		push_warning("MapData: Cannot add node with empty ID")
		return false
	
	if has_node(node.node_id):
		push_warning("MapData: Node ID already exists: %s" % node.node_id)
		return false
	
	nodes.append(node)
	_mark_cache_dirty()
	return true


## Remove node
## @param node_id: Node ID to remove
## @return: true if removed
func remove_node(node_id: String) -> bool:
	for i in range(nodes.size()):
		if nodes[i].node_id == node_id:
			nodes.remove_at(i)
			_mark_cache_dirty()
			return true
	return false


## Validate map data
## @return: Array of error messages
func validate_map_data() -> Array[String]:
	var errors: Array[String] = []
	
	if map_id.is_empty():
		errors.append("Map ID is empty")
	
	if map_name.is_empty():
		errors.append("Map name is empty")
	
	if nodes.is_empty():
		errors.append("Map has no nodes")
		return errors
	
	if starting_node_id.is_empty():
		errors.append("No starting node specified")
	elif not has_node(starting_node_id):
		errors.append("Starting node ID not found: %s" % starting_node_id)
	
	# Validate each node
	var node_ids: Array[String] = []
	for i in range(nodes.size()):
		var node := nodes[i]
		if not node:
			errors.append("Node at index %d is null" % i)
			continue
		
		# Check for duplicate IDs
		if node.node_id in node_ids:
			errors.append("Duplicate node ID: %s" % node.node_id)
		else:
			node_ids.append(node.node_id)
		
		# Validate node itself
		var node_errors := node.validate_node()
		for node_error in node_errors:
			errors.append("Node '%s': %s" % [node.node_name, node_error])
		
		# Check connections
		for next_node_id in node.next_nodes:
			if not has_node(next_node_id):
				errors.append("Node '%s' references non-existent next node: %s" % [node.node_name, next_node_id])
		
		for req_node_id in node.required_nodes:
			if not has_node(req_node_id):
				errors.append("Node '%s' references non-existent required node: %s" % [node.node_name, req_node_id])
	
	return errors


## Repair invalid map data
## @return: true if repaired
func repair_map_data() -> bool:
	var was_repaired := false
	
	if map_id.is_empty():
		map_id = map_name.to_snake_case()
		was_repaired = true
	
	# Remove null nodes
	var valid_nodes: Array[WorldMapNode] = []
	for node in nodes:
		if node:
			# Repair node
			if node.repair_node():
				was_repaired = true
			valid_nodes.append(node)
		else:
			was_repaired = true
	nodes = valid_nodes
	
	# Set starting node if missing
	if starting_node_id.is_empty() and not nodes.is_empty():
		starting_node_id = nodes[0].node_id
		was_repaired = true
	
	_mark_cache_dirty()
	return was_repaired


## Get progress percentage
## @return: Completion percentage (0-100)
func get_completion_percentage() -> float:
	if nodes.is_empty():
		return 0.0
	
	var completed_count := 0
	var required_count := 0
	
	for node in nodes:
		if not node.is_optional:
			required_count += 1
			if node.is_completed:
				completed_count += 1
	
	if required_count == 0:
		return 100.0
	
	return (float(completed_count) / float(required_count)) * 100.0


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Map: %s ===%s\n" % [map_name, " [%s]" % map_id if not map_id.is_empty() else ""]
	
	summary += "Nodes: %d\n" % nodes.size()
	summary += "Starting Node: %s\n" % starting_node_id
	
	var unlocked := get_unlocked_nodes()
	var completed := get_completed_nodes()
	summary += "Unlocked: %d\n" % unlocked.size()
	summary += "Completed: %d\n" % completed.size()
	summary += "Progress: %.1f%%\n" % get_completion_percentage()
	
	if background_texture:
		summary += "Background: Set\n"
	if map_music:
		summary += "Music: Set\n"
	
	var errors := validate_map_data()
	if errors.is_empty():
		summary += "\n✓ Map data valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
