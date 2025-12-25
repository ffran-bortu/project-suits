"""
FILE: world_map_visual_controller.gd
PURPOSE: Tactical RPG world map with parchment cartography aesthetic, graph-based node system, and Fire Emblem-style visuals
FUNCTIONS: _ready, _create_sample_campaign, _create_node_visuals, _create_circle_polygon, _create_node_label, _get_node_color, _draw_connections, _position_player_avatar, _connect_signals, _on_node_input, _on_node_hover, _show/_hide_node_info, _on_enter/close_panel, _enter_node, _move_player_to_node, _start_battle, _get_node_data, _process (camera pan & drag), _input (zoom/ESC/drag), _return_to_menu, complete_current_node, get_all_nodes, get_node_by_id
NOTES: Uses graph structure for node placement and connections. Styled with green outlined text, white connection lines, and parchment aesthetic. Camera supports panning, zooming, and dragging. SaveManager compatible via "world_map" group and helper methods.
"""

extends Node2D
## Tactical world map with Fire Emblem-style parchment cartography
##
## Graph-based node system with aged map aesthetic and smooth interactions

# --- Scene References ---
@onready var camera: Camera2D = $Camera2D
@onready var background: Sprite2D = $MapContainer/Background
@onready var map_container: Node2D = $MapContainer
@onready var nodes_layer: Node2D = $MapContainer/NodesLayer
@onready var lines_layer: Node2D = $MapContainer/LinesLayer
@onready var labels_layer: Node2D = $MapContainer/LabelsLayer
@onready var player_avatar: Node2D = $MapContainer/PlayerAvatar
@onready var info_panel: Panel = $UILayer/NodeInfoPanel
@onready var node_name_label: Label = $UILayer/NodeInfoPanel/VBoxContainer/MarginContainer/Content/NodeName
@onready var node_type_label: Label = $UILayer/NodeInfoPanel/VBoxContainer/MarginContainer/Content/NodeType
@onready var node_level_label: Label = $UILayer/NodeInfoPanel/VBoxContainer/MarginContainer/Content/NodeLevel
@onready var enter_button: Button = $UILayer/NodeInfoPanel/VBoxContainer/MarginContainer/Content/ButtonContainer/EnterButton
@onready var close_button: Button = $UILayer/NodeInfoPanel/VBoxContainer/MarginContainer/Content/ButtonContainer/CloseButton

# --- Visual Constants ---
const NODE_RADIUS: float = 12.0
const LINE_WIDTH: float = 4.0
const LABEL_OFFSET: Vector2 = Vector2(0, -25)

# --- Colors (Parchment Cartography Palette) ---
const COLOR_NODE_UNLOCKED: Color = Color(1.0, 1.0, 1.0)  # White
const COLOR_NODE_LOCKED: Color = Color(0.4, 0.4, 0.4)  # Gray
const COLOR_NODE_COMPLETED: Color = Color(0.6, 0.6, 0.6)  # Light gray
const COLOR_NODE_CURRENT: Color = Color(1.0, 0.85, 0.3)  # Gold
const COLOR_NODE_SPECIAL: Color = Color(1.0, 0.3, 0.3)  # Red for special nodes
const COLOR_LINE_UNLOCKED: Color = Color(1.0, 1.0, 1.0, 0.9)  # White
const COLOR_LINE_LOCKED: Color = Color(0.5, 0.5, 0.5, 0.5)  # Faded gray
const COLOR_TEXT: Color = Color(0.3, 1.0, 0.0)  # Bright green (#4CFF00)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0)  # Black

# --- Graph Data Structure ---
var map_data: Dictionary = {
	"nodes": {},
	"connections": []
}

var node_visuals: Dictionary = {}  # node_id -> {"button": Area2D, "label": Label}
var current_node_id: String = "1"
var selected_node: Dictionary = {}

# --- SaveManager Compatibility ---
var visited_nodes: Array[String] = []  # Completed node IDs for save system
var current_node: Dictionary = {}  # Current node data (for save compat)

# --- Camera State ---
var camera_pan_speed: float = 500.0
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var camera_start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Add to world_map group for SaveManager compatibility
	add_to_group("world_map")
	
	_create_sample_campaign()
	_create_node_visuals()
	_draw_connections()
	_position_player_avatar()
	_connect_signals()
	
	# Set current_node for save compat
	current_node = map_data["nodes"].get(current_node_id, {})
	
	DebugLog.log("World Map Visual Ready", "cyan")


## Create tactical campaign graph (Fire Emblem style)
func _create_sample_campaign() -> void:
	# Define all nodes with positions matching tactical map layout
	map_data["nodes"] = {
		"1": {"pos": Vector2(150, 450), "type": "battle", "label": "1", "name": "Chapter 1: Awakening", "level": 1, "is_unlocked": true, "is_completed": false, "is_special": false, "node_id": "1"},
		"2": {"pos": Vector2(250, 400), "type": "battle", "label": "2", "name": "Chapter 2: Forest Patrol", "level": 2, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "2"},
		"3": {"pos": Vector2(350, 350), "type": "battle", "label": "3", "name": "Chapter 3: Mountain Pass", "level": 3, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "3"},
		"4": {"pos": Vector2(450, 300), "type": "battle", "label": "4", "name": "Chapter 4: Ambush", "level": 4, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "4"},
		"5": {"pos": Vector2(550, 350), "type": "battle", "label": "5", "name": "Chapter 5: Crossroads", "level": 5, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "5"},
		"6": {"pos": Vector2(650, 400), "type": "battle", "label": "6", "name": "Chapter 6: River Crossing", "level": 6, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "6"},
		"7": {"pos": Vector2(750, 450), "type": "battle", "label": "7", "name": "Chapter 7: Encampment", "level": 7, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "7"},
		"8": {"pos": Vector2(350, 250), "type": "battle", "label": "8", "name": "Chapter 8: Northern Route", "level": 5, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "8"},
		"9": {"pos": Vector2(550, 200), "type": "battle", "label": "9", "name": "Chapter 9: Highland Fort", "level": 7, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "9"},
		"10": {"pos": Vector2(450, 500), "type": "battle", "label": "10", "name": "Chapter 10: Southern Valley", "level": 6, "is_unlocked": false, "is_completed": false, "is_special": false, "node_id": "10"},
		"Pro": {"pos": Vector2(200, 300), "type": "story", "label": "Pro", "name": "Prologue: A New Journey", "level": 1, "is_unlocked": false, "is_completed": false, "is_special": true, "node_id": "Pro"},
		"End": {"pos": Vector2(850, 350), "type": "final", "label": "End", "name": "Final Chapter: Destiny", "level": 10, "is_unlocked": false, "is_completed": false, "is_special": true, "node_id": "End"}
	}
	
	# Define connections (edges in the graph)
	map_data["connections"] = [
		["1", "2"],
		["2", "3"],
		["3", "4"],
		["3", "8"],
		["4", "5"],
		["5", "6"],
		["6", "7"],
		["7", "End"],
		["8", "9"],
		["9", "End"],
		["4", "10"],
		["10", "6"],
		["Pro", "1"]
	]
	
	DebugLog.log("Created graph with %d nodes and %d connections" % [map_data["nodes"].size(), map_data["connections"].size()], "green")


## Create visual node buttons with Fire Emblem styling
func _create_node_visuals() -> void:
	for node_id in map_data["nodes"]:
		var node_data: Dictionary = map_data["nodes"][node_id]
		
		# Create Area2D for clickable node
		var area := Area2D.new()
		area.name = "Node_" + node_id
		area.position = node_data["pos"]
		
		# Create collision shape (circle)
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = NODE_RADIUS
		collision.shape = shape
		area.add_child(collision)
		
		# Create visual circle (using Polygon2D for better control)
		var circle := _create_circle_polygon(NODE_RADIUS)
		area.add_child(circle)
		
		# Set initial color based on state
		var node_color := _get_node_color(node_data)
		circle.color = node_color
		
		# Store reference
		circle.set_meta("node_id", node_id)
		area.set_meta("node_id", node_id)
		area.set_meta("circle", circle)
		
		# Connect signals for hover and click
		area.mouse_entered.connect(_on_node_hover.bind(node_id, true))
		area.mouse_exited.connect(_on_node_hover.bind(node_id, false))
		area.input_event.connect(_on_node_input.bind(node_id))
		
		nodes_layer.add_child(area)
		
		# Create label
		var label := _create_node_label(node_data["label"], node_data["pos"])
		labels_layer.add_child(label)
		
		# Store references
		node_visuals[node_id] = {
			"button": area,
			"circle": circle,
			"label": label
		}


## Create circle polygon for node visual
func _create_circle_polygon(radius: float) -> Polygon2D:
	var polygon := Polygon2D.new()
	var points: PackedVector2Array = []
	var segments := 32
	
	for i in range(segments):
		var angle := (i * TAU) / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	polygon.polygon = points
	polygon.color = Color.WHITE
	
	# Add black outline
	var outline := Line2D.new()
	outline.points = points
	outline.points.append(points[0])  # Close the loop
	outline.width = 2.0
	outline.default_color = COLOR_OUTLINE
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.antialiased = true
	polygon.add_child(outline)
	
	return polygon


## Create label for node with green text and black outline
func _create_node_label(text: String, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos + LABEL_OFFSET
	
	# Use LabelSettings for outline (Godot 4.x way)
	var label_settings := LabelSettings.new()
	label_settings.font_size = 18
	label_settings.font_color = COLOR_TEXT
	label_settings.outline_size = 4
	label_settings.outline_color = COLOR_OUTLINE
	
	label.label_settings = label_settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Center the label
	label.pivot_offset = label.size / 2
	
	return label


## Get node color based on state
func _get_node_color(node_data: Dictionary) -> Color:
	if node_data.get("is_special", false):
		return COLOR_NODE_SPECIAL
	elif node_data.get("is_completed", false):
		return COLOR_NODE_COMPLETED
	elif node_data.get("is_unlocked", false):
		return COLOR_NODE_UNLOCKED
	else:
		return COLOR_NODE_LOCKED


## Draw connection lines between nodes (graph edges)
func _draw_connections() -> void:
	for connection in map_data["connections"]:
		var from_id: String = connection[0]
		var to_id: String = connection[1]
		
		var from_node: Dictionary = map_data["nodes"].get(from_id, {})
		var to_node: Dictionary = map_data["nodes"].get(to_id, {})
		
		if not from_node or not to_node:
			continue
		
		var from_pos: Vector2 = from_node["pos"]
		var to_pos: Vector2 = to_node["pos"]
		
		# Determine line color based on unlock status
		var line_color := COLOR_LINE_LOCKED
		if from_node.get("is_unlocked", false) and to_node.get("is_unlocked", false):
			line_color = COLOR_LINE_UNLOCKED
		elif from_node.get("is_unlocked", false):
			line_color = COLOR_LINE_UNLOCKED.lerp(COLOR_LINE_LOCKED, 0.5)
		
		# Create Line2D
		var line := Line2D.new()
		line.add_point(from_pos)
		line.add_point(to_pos)
		line.width = LINE_WIDTH
		line.default_color = line_color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.antialiased = true
		line.z_index = -1
		
		lines_layer.add_child(line)


## Position player avatar at current node
func _position_player_avatar() -> void:
	var node_data: Dictionary = map_data["nodes"].get(current_node_id, {})
	if node_data:
		player_avatar.position = node_data["pos"]
		player_avatar.visible = true
		
		# Update current node color
		if current_node_id in node_visuals:
			var circle: Polygon2D = node_visuals[current_node_id]["circle"]
			circle.color = COLOR_NODE_CURRENT


## Connect UI signals
func _connect_signals() -> void:
	if enter_button:
		enter_button.pressed.connect(_on_enter_node_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_panel_pressed)


## Handle node input (click)
func _on_node_input(_viewport: Node, event: InputEvent, _shape_idx: int, node_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var node_data: Dictionary = map_data["nodes"].get(node_id, {})
			if node_data:
				selected_node = node_data
				selected_node["id"] = node_id  # Add ID for later use
				_show_node_info(node_data)


## Handle node hover
func _on_node_hover(node_id: String, is_hovering: bool) -> void:
	if node_id not in node_visuals:
		return
	
	var visuals: Dictionary = node_visuals[node_id]
	var area: Area2D = visuals["button"] as Area2D
	var target_scale: Vector2 = Vector2.ONE * 1.2 if is_hovering else Vector2.ONE
	
	# Smooth scale animation
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(area, "scale", target_scale, 0.2)


## Show node info panel
func _show_node_info(node_data: Dictionary) -> void:
	if not info_panel:
		return
	
	node_name_label.text = node_data.get("name", "Unknown")
	node_type_label.text = "Type: %s" % node_data.get("type", "battle").capitalize()
	node_level_label.text = "Recommended Level: %d" % node_data.get("level", 1)
	
	# Enable/disable enter button
	var is_unlocked: bool = node_data.get("is_unlocked", false) as bool
	var is_completed: bool = node_data.get("is_completed", false) as bool
	enter_button.disabled = not is_unlocked or is_completed
	
	info_panel.visible = true


## Hide node info panel
func _hide_node_info() -> void:
	if info_panel:
		info_panel.visible = false
	selected_node = {}


## Handle enter node button
func _on_enter_node_pressed() -> void:
	if selected_node.is_empty():
		return
	
	# Store node data before clearing selected_node
	var node_to_enter := selected_node.duplicate()
	_hide_node_info()
	_enter_node(node_to_enter)


## Handle close panel button
func _on_close_panel_pressed() -> void:
	_hide_node_info()


## Enter a node (move player and start event)
func _enter_node(node_data: Dictionary) -> void:
	if node_data.is_empty():
		push_error("_enter_node called with empty node_data")
		return
	
	if not node_data.get("is_unlocked", false):
		DebugLog.log("Node is locked!", "yellow")
		return
	
	# Move player avatar
	_move_player_to_node(node_data)
	
	# Start battle after a short delay
	await get_tree().create_timer(0.5).timeout
	_start_battle(node_data)


## Animate player movement to node
func _move_player_to_node(node_data: Dictionary) -> void:
	var node_id: String = selected_node.get("id", "")
	if node_id.is_empty():
		return
	
	current_node_id = node_id
	current_node = node_data  # Update for save compat
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_avatar, "position", node_data["pos"], 0.5)
	await tween.finished
	
	DebugLog.log("Moved to: %s" % node_data.get("name", node_id), "cyan")


## Start battle scene
func _start_battle(node_data: Dictionary) -> void:
	DebugLog.success("Starting battle: %s" % node_data.get("name", "Unknown"))
	
	# TODO: Save world map state via SaveManager
	# TODO: Pass node data to battle scene
	
	var battle_scene_path: String = GameConfig.assets.get("battle_scene", "res://scenes/main.tscn")
	var error := get_tree().change_scene_to_file(battle_scene_path)
	if error != OK:
		push_error("Failed to load battle scene: %d" % error)


## Get node data by ID
func _get_node_data(node_id: String) -> Dictionary:
	return map_data["nodes"].get(node_id, {})


## Handle camera panning and dragging
func _process(delta: float) -> void:
	# Keyboard panning
	var pan_dir := Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		pan_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		pan_dir.y += 1
	if Input.is_action_pressed("move_left"):
		pan_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		pan_dir.x += 1
	
	if pan_dir != Vector2.ZERO:
		camera.position += pan_dir.normalized() * camera_pan_speed * delta
	
	# Mouse dragging
	if is_dragging:
		var mouse_pos := get_viewport().get_mouse_position()
		var delta_pos := (drag_start_pos - mouse_pos) / camera.zoom
		camera.position = camera_start_pos + delta_pos


## Handle input (zoom, drag, escape)
func _input(event: InputEvent) -> void:
	# Escape to main menu
	if event.is_action_pressed("ui_cancel"):
		if info_panel.visible:
			_hide_node_info()
		else:
			_return_to_menu()
	
	# Mouse interactions
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		
		# Zoom with mouse wheel
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = camera.zoom * 1.1
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = camera.zoom * 0.9
		
		camera.zoom = camera.zoom.clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		
		# Camera dragging with middle or right mouse
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE or mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				is_dragging = true
				drag_start_pos = get_viewport().get_mouse_position()
				camera_start_pos = camera.position
			else:
				is_dragging = false


## Return to main menu
func _return_to_menu() -> void:
	DebugLog.log("Returning to main menu", "cyan")
	var menu_path: String = GameConfig.assets.get("main_menu_scene", "res://scenes/menu_main.tscn")
	get_tree().change_scene_to_file(menu_path)


## Complete current node (call this after battle victory)
func complete_current_node() -> void:
	var node_data := _get_node_data(current_node_id)
	if node_data.is_empty():
		return
	
	node_data["is_completed"] = true
	
	# Unlock nodes connected from this one
	for connection in map_data["connections"]:
		if connection[0] == current_node_id:
			var next_id: String = connection[1]
			var next_node := _get_node_data(next_id)
			if next_node:
				next_node["is_unlocked"] = true
				
				# Update visual
				if next_id in node_visuals:
					var circle: Polygon2D = node_visuals[next_id]["circle"]
					circle.color = COLOR_NODE_UNLOCKED
	
	# Track visited nodes for save system
	if current_node_id not in visited_nodes:
		visited_nodes.append(current_node_id)
	
	DebugLog.success("Completed: %s" % node_data.get("name", current_node_id))
	
	# TODO: Save state via SaveManager


## Get all nodes (SaveManager compatibility)
## @return: Array of node dictionaries
func get_all_nodes() -> Array:
	var nodes: Array = []
	for node_id in map_data["nodes"]:
		nodes.append(map_data["nodes"][node_id])
	return nodes


## Get node by ID (SaveManager compatibility)
## @param node_id: Node ID to find
## @return: Node dictionary or empty dict
func get_node_by_id(node_id: String) -> Dictionary:
	return map_data["nodes"].get(node_id, {})


