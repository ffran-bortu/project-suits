"""
FILE: world_map.gd (Managers version - full implementation)
PURPOSE: Complete world map manager with UI, campaign progression, save/load, and scene transitions.

OVERVIEW:
This is the full world map implementation with 2D navigation, visual node instances, connection lines,
camera zoom/pan, save/load state, and scene transitions to battles. Manages MapData resources, validates
map structure, creates visual instances for nodes, handles unlock progression, and orchestrates battle/
story/shop/rest events based on node types.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Validates map data, initializes map, tries to load save, plays music
   - Uses: Called automatically when node enters scene tree
   - Returns: void

2. _initialize_map() -> void
   - What it does: Validates/repairs map data, creates node instances, sets starting node, centers camera
   - Uses: Called during initialization
   - Returns: void

3. _create_node_instance(node: WorldMapNode) -> void
   - What it does: Creates visual Node2D for map node at specified position
   - Uses: Called for each node in map data
   - Returns: void

4. _try_load_save() -> void
   - What it does: Attempts to load saved map state, updates visuals
   - Uses: Called at startup
   - Returns: void

5. _center_on_node(node_id: String) -> void
   - What it does: Moves camera to center on specified node
   - Uses: Called when focusing on current/selected node
   - Returns: void

6. _update_visual_state() -> void
   - What it does: Refreshes all visual elements (connections and nodes)
   - Uses: Called after state changes
   - Returns: void

7. _update_connections() -> void
   - What it does: Redraws connection lines between nodes with color coding (gray/yellow/green)
   - Uses: Called when map state changes
   - Returns: void

8. _update_node_visuals() -> void
   - What it does: Updates visual state of all node instances
   - Uses: Called when map state changes
   - Returns: void

9. select_node(node_id: String) -> void
   - What it does: Handles node selection, validates accessibility, shows node info
   - Uses: Called when player clicks/selects a node
   - Returns: void

10. _show_node_info(node: WorldMapNode) -> void
    - What it does: Displays node information panel (TODO: actual UI)
    - Uses: Called when node selected
    - Returns: void

11. start_node(node: WorldMapNode) -> void
    - What it does: Initiates node based on type (battle/story/shop/rest)
    - Uses: Called when player confirms node start
    - Returns: void

12. _start_battle(node: WorldMapNode) -> void
    - What it does: Saves state and transitions to battle scene
    - Uses: Called for BATTLE type nodes
    - Returns: void

13. _start_story_event(node: WorldMapNode) -> void
    - What it does: Handles story event (TODO: implement, currently auto-completes)
    - Uses: Called for STORY type nodes
    - Returns: void

14. _start_shop(node: WorldMapNode) -> void
    - What it does: Opens shop (TODO: implement, currently auto-completes)
    - Uses: Called for SHOP type nodes
    - Returns: void

15. _start_rest_event(node: WorldMapNode) -> void
    - What it does: Handles rest event (TODO: implement, currently auto-completes)
    - Uses: Called for REST type nodes
    - Returns: void

16. complete_node(node: WorldMapNode, turns_taken: int = 0) -> void
    - What it does: Marks node complete, unlocks next nodes, saves state, emits signals
    - Uses: Called after completing node event
    - Returns: void

17. _unlock_next_nodes(completed_node: WorldMapNode) -> void
    - What it does: Checks requirements and unlocks subsequent nodes
    - Uses: Called after node completion
    - Returns: void

18. _show_notification(text: String) -> void
    - What it does: Shows notification message (TODO: actual UI)
    - Uses: Called for user feedback
    - Returns: void

19. save_map_state() -> bool
    - What it does: Serializes map state to user://world_map_save.dat
   - Uses: Called when state changes
    - Returns: bool - success

20. load_map_state() -> bool
    - What it does: Loads map state from save file
    - Uses: Called at startup
    - Returns: bool - success

21. _play_music() -> void
    - What it does: Plays map music from MapData
    - Uses: Called at startup
    - Returns: void

22. _input(event: InputEvent) -> void
    - What it does: Handles mouse wheel zoom and ESC key for menu
    - Uses: Godot input callback
    - Returns: void

23. _zoom_camera(factor: float) -> void
    - What it does: Zooms camera with clamping to min/max
    - Uses: Called from mouse wheel input
    - Returns: void

24. _show_menu() -> void
    - What it does: Shows map menu (TODO: implement)
    - Uses: Called when ESC pressed
    - Returns: void

25. get_debug_summary() -> String
    - What it does: Returns formatted string with map statistics
    - Uses: Debugging and logging
    - Returns: String - debug information

26. debug_print() -> void
    - What it does: Prints debug summary to console
    - Uses: Called for debugging map state
    - Returns: void

NOTES:
- Extends Node2D for 2D map rendering
- Depends on MapData resource with nodes array and validation methods
- Node instances stored in dictionary (node_id -> visual instance)
- Tracks visited_nodes, available_nodes arrays for progression
- Connection lines color-coded: gray (locked), yellow (completable), green (completed and next unlocked)
- Camera2D child handles zoom/pan (min zoom 0.5, max 2.0)
- Save file: user://world_map_save.dat
- Emits node_unlocked, node_completed, map_state_changed signals
- UILayer, LineRenderer, AudioStreamPlayer child nodes for full functionality
- Scene transitions via get_tree().change_scene_to_file()
- Map validation with repair functionality
- Starting node from MapData or export override
"""


extends Node2D
class_name WorldMap

## Manages world map navigation, node progression, and campaign state

# --- Constants ---
const SAVE_FILE_PATH: String = "user://world_map_save.dat"
const DEFAULT_ZOOM: Vector2 = Vector2(1.0, 1.0)
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0

# --- Exports ---
@export var map_data: MapData
@export var starting_node_id: String = ""

# --- Node References ---
@onready var camera: Camera2D = $Camera2D
@onready var map_container: Node2D = $MapContainer
@onready var ui_layer: CanvasLayer = $UILayer
@onready var line_renderer: Node2D = $LineRenderer
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

# --- State ---
var current_node: WorldMapNode = null
var node_instances: Dictionary[String, Node2D] = {}  # node_id -> WorldMapNodeInstance
var visited_nodes: Array[String] = []
var available_nodes: Array[String] = []

# --- Signals ---
signal node_unlocked(node_id: String)
signal node_completed(node_id: String)
signal map_state_changed()


func _ready() -> void:
	if not map_data:
		push_error("WorldMap: No map data assigned!")
		return
	
	_initialize_map()
	_try_load_save()
	_play_music()


## Initialize map from data
func _initialize_map() -> void:
	if not map_data:
		return
	
	# Validate map data
	var errors := map_data.validate_map_data()
	if not errors.is_empty():
		push_error("WorldMap: Map data validation failed!")
		for error in errors:
			push_error("  - %s" % error)
		
		# Try to repair
		if map_data.repair_map_data():
			push_warning("WorldMap: Map data repaired")
		else:
			return
	
	# Create node instances
	for node in map_data.nodes:
		_create_node_instance(node)
	
	# Set starting node
	var start_id := starting_node_id if not starting_node_id.is_empty() else map_data.starting_node_id
	if map_data.has_node(start_id):
		var start_node := map_data.get_node(start_id)
		start_node.unlock()
		available_nodes.append(start_id)
		current_node = start_node
		
		_center_on_node(start_id)
	
	_update_visual_state()


## Create visual instance for node
## @param node: WorldMapNode
func _create_node_instance(node: WorldMapNode) -> void:
	if not node:
		return
	
	# TODO: Load actual scene when  created
	var node_instance := Node2D.new()
	node_instance.position = node.position
	node_instance.name = node.node_id
	
	map_container.add_child(node_instance)
	node_instances[node node_id] = node_instance


## Try to load saved state
func _try_load_save() -> void:
	if load_map_state():
		print("WorldMap: Loaded saved state")
		_update_visual_state()
	else:
		print("WorldMap: No save file found, starting fresh")


## Center camera on node
## @param node_id: Node ID
func _center_on_node(node_id: String) -> void:
	if node_id in node_instances:
		var node_instance := node_instances[node_id]
		if node_instance:
			camera.position = node_instance.position


## Update all visual elements
func _update_visual_state() -> void:
	_update_connections()
	_update_node_visuals()


## Update connection lines
func _update_connections() -> void:
	if not line_renderer or not line_renderer.has_method("clear_lines"):
		return
	
	line_renderer.clear_lines()
	
	for node in map_data.nodes:
		for next_node_id in node.next_nodes:
			var next_node := map_data.get_node(next_node_id)
			if not next_node:
				continue
			
			# Determine line color
			var color := Color.GRAY
			if node.is_completed:
				if next_node.is_unlocked:
					color = Color.GREEN
				else:
					color = Color.YELLOW
			
			# Draw line
			if line_renderer.has_method("draw_line"):
				line_renderer.draw_line(node.position, next_node.position, color, 2.0)


## Update node visuals
func _update_node_visuals() -> void:
	for node_id in node_instances:
		var node_instance := node_instances[node_id]
		if node_instance and node_instance.has_method("update_state"):
			node_instance.update_state()


## Handle node selection
## @param node_id: Selected node ID
func select_node(node_id: String) -> void:
	if not map_data.has_node(node_id):
		push_warning("WorldMap: Node not found: %s" % node_id)
		return
	
	var node := map_data.get_node(node_id)
	
	if not node.can_access():
		_show_notification("This node is not available yet")
		return
	
	if node_id not in available_nodes:
		_show_notification("You cannot access this node yet")
		return
	
	# Show node info
	_show_node_info(node)


## Show node information panel
## @param node: WorldMapNode
func _show_node_info(node: WorldMapNode) -> void:
	# TODO: Create actual UI panel
	print("Show info for: %s" % node.node_name)
	print("Type: %s" % node.get_type_name())
	print("Description: %s" % node.description)


## Start selected node
## @param node: WorldMapNode
func start_node(node: WorldMapNode) -> void:
	if not node:
		return
	
	current_node = node
	
	match node.node_type:
		WorldMapNode.NodeType.BATTLE:
			_start_battle(node)
		WorldMapNode.NodeType.STORY:
			_start_story_event(node)
		WorldMapNode.NodeType.SHOP:
			_start_shop(node)
		WorldMapNode.NodeType.REST:
			_start_rest_event(node)


## Start battle node
## @param node: WorldMapNode
func _start_battle(node: WorldMapNode) -> void:
	if node.map_scene_path.is_empty():
		push_error("WorldMap: No map scene path for battle node: %s" % node.node_name)
		return
	
	if not ResourceLoader.exists(node.map_scene_path):
		push_error("WorldMap: Map scene not found: %s" % node.map_scene_path)
		return
	
	# Save state before transition
	save_map_state()
	
	# Load battle scene
	get_tree().change_scene_to_file(node.map_scene_path)


## Start story event
## @param node: WorldMapNode
func _start_story_event(node: WorldMapNode) -> void:
	# TODO: Implement story event system
	print("Starting story event: %s" % node.node_name)
	# For now, auto-complete
	complete_node(node)


## Start shop
## @param node: WorldMapNode
func _start_shop(node: WorldMapNode) -> void:
	# TODO: Implement shop system
	print("Opening shop: %s" % node.node_name)
	complete_node(node)


## Start rest event
## @param node: WorldMapNode
func _start_rest_event(node: WorldMapNode) -> void:
	# TODO: Implement rest system
	print("Resting at: %s" % node.node_name)
	complete_node(node)


## Complete node and unlock next nodes
## @param node: WorldMapNode
## @param turns_taken: Turns to complete (for battles)
func complete_node(node: WorldMapNode, turns_taken: int = 0) -> void:
	if not node:
		return
	
	node.complete(turns_taken)
	
	# Add to visited
	if not node.node_id in visited_nodes:
		visited_nodes.append(node.node_id)
	
	# Remove from available
	var idx := available_nodes.find(node.node_id)
	if idx != -1:
		available_nodes.remove_at(idx)
	
	# Unlock next nodes
	_unlock_next_nodes(node)
	
	# Save progress
	save_map_state()
	
	# Update visuals
	_update_visual_state()
	
	# Emit signal
	node_completed.emit(node.node_id)
	map_state_changed.emit()


## Unlock next nodes if requirements met
## @param completed_node: Just completed node
func _unlock_next_nodes(completed_node: WorldMapNode) -> void:
	for next_node_id in completed_node.next_nodes:
		var next_node := map_data.get_node(next_node_id)
		if not next_node or next_node.is_unlocked:
			continue
		
		# Check requirements
		var can_unlock := true
		for req_node_id in next_node.required_nodes:
			var req_node := map_data.get_node(req_node_id)
			if not req_node or not req_node.is_completed:
				can_unlock = false
				break
		
		if can_unlock:
			next_node.unlock()
			available_nodes.append(next_node_id)
			_show_notification("New node unlocked: %s" % next_node.node_name)
			node_unlocked.emit(next_node_id)


## Show notification message
## @param text: Notification text
func _show_notification(text: String) -> void:
	print("NOTIFICATION: %s" % text)
	# TODO: Create actual notification UI


## Save map state
## @return: true if successful
func save_map_state() -> bool:
	var save_data := {
		"map_id": map_data.map_id,
		"visited_nodes": visited_nodes,
		"available_nodes": available_nodes,
		"current_node_id": current_node.node_id if current_node else "",
		"nodes": {}
	}
	
	# Save node states
	for node in map_data.nodes:
		save_data.nodes[node.node_id] = node.serialize()
	
	# Write to file
	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not save_file:
		push_error("WorldMap: Failed to open save file for writing")
		return false
	
	save_file.store_var(save_data)
	save_file.close()
	return true


## Load map state
## @return: true if successful
func load_map_state() -> bool:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return false
	
	var save_file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not save_file:
		push_error("WorldMap: Failed to open save file for reading")
		return false
	
	var save_data: Variant = save_file.get_var()
	save_file.close()
	
	if not save_data is Dictionary:
		push_error("WorldMap: Invalid save data")
		return false
	
	# Apply state
	visited_nodes = save_data.get("visited_nodes", [])
	available_nodes = save_data.get("available_nodes", [])
	
	# Restore node states
	var nodes_data: Dictionary = save_data.get("nodes", {})
	for node_id in nodes_data:
		var node := map_data.get_node(node_id)
		if node:
			node.deserialize(nodes_data[node_id])
	
	# Restore current node
	var current_node_id: String = save_data.get("current_node_id", "")
	if not current_node_id.is_empty():
		current_node = map_data.get_node(current_node_id)
	
	return true


## Play map music
func _play_music() -> void:
	if not audio_player or not map_data:
		return
	
	if map_data.map_music:
		audio_player.stream = map_data.map_music
		audio_player.play()


## Handle input
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		
		# Zoom with mouse wheel
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_camera(0.9)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_camera(1.1)
	
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed:
			match key_event.keycode:
				KEY_ESCAPE:
					_show_menu()


## Get all nodes
## @return: Array of WorldMapNode
func get_all_nodes() -> Array[WorldMapNode]:
	return map_data.nodes if map_data else []


## Get node by ID
## @param node_id: ID
## @return: Node or null
func get_node_by_id(node_id: String) -> WorldMapNode:
	return map_data.get_node(node_id) if map_data and map_data.has_node(node_id) else null


## Zoom camera
## @param factor: Zoom factor
func _zoom_camera(factor: float) -> void:
	if not camera:
		return
	
	var new_zoom := camera.zoom * factor
	new_zoom.x = clamp(new_zoom.x, MIN_ZOOM, MAX_ZOOM)
	new_zoom.y = clamp(new_zoom.y, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = new_zoom


## Show map menu
func _show_menu() -> void:
	# TODO: Create actual menu
	print("Show menu")


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== World Map State ===\n"
	
	if map_data:
		summary += "Map: %s\n" % map_data.map_name
		summary += "Nodes: %d\n" % map_data.nodes.size()
	
	summary += "Visited: %d\n" % visited_nodes.size()
	summary += "Available: %d\n" % available_nodes.size()
	
	if current_node:
		summary += "Current: %s\n" % current_node.node_name
	
	if map_data:
		summary += "Progress: %.1f%%\n" % map_data.get_completion_percentage()
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
