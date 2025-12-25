# grid_3d.gd - 3D grid visualization
extends Node3D

var grid_meshes: Array = []
var highlight_meshes: Array = []
var path_meshes: Array = []
var attack_highlights: Array = []
var cursor_highlight: MeshInstance3D = null
var hover_highlight: MeshInstance3D = null  # NEW: Separate hover highlight
var current_hover_pos: Vector2i = Vector2i(-1, -1)  # NEW: Track hovered position

func _ready():
	# Wait a frame to ensure terrain is set first
	await get_tree().process_frame
	create_3d_grid()

func regenerate_grid():
	# Clear existing grid and recreate with updated heights
	clear_all()
	create_3d_grid()

func clear_all():
	# Clear all visualizations
	for mesh in grid_meshes:
		mesh.queue_free()
	grid_meshes.clear()
	clear_highlights()
	clear_path()
	clear_attack_highlights()
	clear_cursor_highlight()

func create_3d_grid():
	var grid_size = GridManager.grid_size
	
	# Create 3D cells with visible depth
	for x in grid_size.x:
		for y in grid_size.y:
			var grid_pos = Vector2i(x, y)
			var height = GridManager.get_height(grid_pos)
			
			# Create 3D cell with walls if elevated
			var cell_meshes = create_3d_cell_box(grid_pos, height)
			
			# Color based on checkerboard pattern and height
			var base_color: Color
			if (x + y) % 2 == 0:
				base_color = Color(0.75, 0.75, 0.75, 1.0)  # Light grey
			else:
				base_color = Color(0.55, 0.55, 0.55, 1.0)  # Dark grey
			
			# Adjust color based on height
			if height > 0.5:
				base_color = base_color.lerp(Color(0.95, 0.85, 0.65, 1.0), height * 0.3)  # Mountain color
			elif height < 0:
				base_color = base_color.lerp(Color(0.4, 0.5, 0.7, 1.0), abs(height) * 0.3)  # Valley/water color
			
			# Apply materials to all meshes
			for i in range(cell_meshes.size()):
				var mesh = cell_meshes[i]
				var material = StandardMaterial3D.new()
				
				if i == 0:  # Top face
					material.albedo_color = base_color
				else:  # Walls - darker for depth
					material.albedo_color = base_color.darkened(0.5)
				
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				# Add slight metallic/roughness for better 3D look
				material.metallic = 0.1
				material.roughness = 0.8
				
				mesh.set_surface_override_material(0, material)
				add_child(mesh)
				grid_meshes.append(mesh)
			
			# Add border lines for better cell definition
			if height <= 0.01:  # Only add borders to flat cells to avoid clutter
				create_cell_border(grid_pos, base_color.darkened(0.2))
	

func create_cell_border(grid_pos: Vector2i, border_color: Color):
	# Create thin border lines around cell edges for definition
	var cell_size = GridManager.cell_size
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	var half_x = cell_size.x * 0.5
	var half_y = cell_size.y * 0.5
	var border_height = 0.02
	
	# Create 4 edge lines (simplified - just top edges)
	var edges = [
		{"pos": world_pos + Vector3(-half_x, border_height, -half_y), "size": Vector2(cell_size.x, border_height), "rot": Vector3(0, 0, 0)},  # Front
		{"pos": world_pos + Vector3(-half_x, border_height, half_y), "size": Vector2(cell_size.x, border_height), "rot": Vector3(0, 180, 0)},  # Back
		{"pos": world_pos + Vector3(-half_x, border_height, -half_y), "size": Vector2(cell_size.y, border_height), "rot": Vector3(0, -90, 0)},  # Left
		{"pos": world_pos + Vector3(half_x, border_height, -half_y), "size": Vector2(cell_size.y, border_height), "rot": Vector3(0, 90, 0)}  # Right
	]
	
	# Only create front and right edges to avoid duplication
	for i in [0, 3]:  # Front and right edges only
		var edge = edges[i]
		var quad = QuadMesh.new()
		quad.size = edge.size
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = quad
		mesh_instance.position = edge.pos
		mesh_instance.rotation_degrees = edge.rot
		
		var material = StandardMaterial3D.new()
		material.albedo_color = border_color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.set_surface_override_material(0, material)
		add_child(mesh_instance)
		grid_meshes.append(mesh_instance)

func create_quad_mesh() -> MeshInstance3D:
	var quad = QuadMesh.new()
	quad.size = Vector2(GridManager.cell_size.x, GridManager.cell_size.y)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = quad
	return mesh_instance

func create_3d_cell_box(grid_pos: Vector2i, height: float) -> Array:
	# Create a 3D cell with visible depth
	var meshes = []
	var cell_size = GridManager.cell_size
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	var wall_height = height * GridManager.height_unit_scale
	
	# Create top face (the main cell surface) - always create this
	var top_quad = create_quad_mesh()
	top_quad.position = world_pos
	top_quad.rotation_degrees.x = -90
	meshes.append(top_quad)
	
	# Create side walls if there's significant height
	if wall_height > 0.05:
		var half_size_x = cell_size.x * 0.5
		var half_size_y = cell_size.y * 0.5
		
		# Front wall (positive Z) - facing camera
		var front_wall = create_wall_mesh(cell_size.x, wall_height)
		front_wall.position = world_pos + Vector3(0, wall_height * 0.5, half_size_y)
		front_wall.rotation_degrees.x = 0
		front_wall.rotation_degrees.y = 0
		meshes.append(front_wall)
		
		# Back wall (negative Z)
		var back_wall = create_wall_mesh(cell_size.x, wall_height)
		back_wall.position = world_pos + Vector3(0, wall_height * 0.5, -half_size_y)
		back_wall.rotation_degrees.x = 0
		back_wall.rotation_degrees.y = 180
		meshes.append(back_wall)
		
		# Left wall (negative X)
		var left_wall = create_wall_mesh(cell_size.y, wall_height)
		left_wall.position = world_pos + Vector3(-half_size_x, wall_height * 0.5, 0)
		left_wall.rotation_degrees.x = 0
		left_wall.rotation_degrees.y = -90
		meshes.append(left_wall)
		
		# Right wall (positive X)
		var right_wall = create_wall_mesh(cell_size.y, wall_height)
		right_wall.position = world_pos + Vector3(half_size_x, wall_height * 0.5, 0)
		right_wall.rotation_degrees.x = 0
		right_wall.rotation_degrees.y = 90
		meshes.append(right_wall)
	
	return meshes

func create_wall_mesh(width: float, height: float) -> MeshInstance3D:
	var quad = QuadMesh.new()
	quad.size = Vector2(width, height)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = quad
	return mesh_instance

## Highlight cells in movement range and track hover
##
## @param cells: Array of Vector2i grid positions
func highlight_movement_range(cells: Array):
	clear_highlights()
	current_hover_pos = Vector2i(-1, -1)  # Reset hover
	
	for cell in cells:
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += 0.01  # Slightly above ground
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		# Use pre-created material from config
		var material = GameConfig.get_material("movement")
		if not material:
			push_error("Grid3D: Failed to get movement material from GameConfig")
			return
		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		highlight_meshes.append(quad)
		
		# Add gentle pulsing animation
		var pulse_from = GameConfig.get_color("movement_highlight")
		var pulse_to = GameConfig.get_color("movement_bright")
		_add_pulse_animation(quad, pulse_from, pulse_to)

## Update hover highlight for a specific position
##
## Call this when cursor moves over a highlighted cell
##
## @param grid_pos: Grid position being hovered, or Vector2i(-1,-1) to clear
func update_hover_in_range(grid_pos: Vector2i):
	# Clear previous hover
	if hover_highlight:
		hover_highlight.queue_free()
		hover_highlight = null
	
	# Check if position is invalid
	if grid_pos.x < 0 or grid_pos.y < 0:
		current_hover_pos = Vector2i(-1, -1)
		return
	
	current_hover_pos = grid_pos
	
	# Create hover highlight
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	world_pos.y += 0.015  # Slightly above movement highlights
	
	var quad = create_quad_mesh()
	quad.position = world_pos
	quad.rotation_degrees.x = -90
	
	# Use brighter material for hover
	var material = GameConfig.get_material("movement_hover")
	if not material:
		material = GameConfig.create_material(GameConfig.get_color("movement_bright"))
	
	quad.set_surface_override_material(0, material)
	add_child(quad)
	hover_highlight = quad
	
	# Pulse animation
	var pulse_from = GameConfig.get_color("movement_bright")
	var pulse_to = Color(GameConfig.get_color("movement_bright"))
	pulse_to.a = 0.8  # Even brighter
	_add_pulse_animation(quad, pulse_from, pulse_to)

func draw_path(path_cells: Array):
	clear_path()
	
	for i in range(1, path_cells.size()):  # Skip first cell
		var cell = path_cells[i]
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += 0.02  # Above movement highlights
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		# Use pre-created material from config
		var material = GameConfig.get_material("path")
		if not material:
			push_error("Grid3D: Failed to get path material from GameConfig")
			return
		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		path_meshes.append(quad)
		
		# Add arrow indicator showing direction
		if i < path_cells.size() - 1:
			var next_cell = path_cells[i + 1]
			var direction = next_cell - cell
			
			# Create small arrow triangle
			var arrow = create_arrow_indicator(world_pos, direction)
			if arrow:
				add_child(arrow)
				path_meshes.append(arrow)

# Create arrow indicator showing movement direction
func create_arrow_indicator(pos: Vector3, direction: Vector2i) -> MeshInstance3D:
	var arrow_mesh = ImmediateMesh.new()
	var arrow_instance = MeshInstance3D.new()
	arrow_instance.mesh = arrow_mesh
	
	# Position slightly above path
	arrow_instance.position = pos
	arrow_instance.position.y += 0.03
	arrow_instance.rotation_degrees.x = -90
	
	# Rotate arrow to point in movement direction
	if direction.x > 0:
		arrow_instance.rotation_degrees.y = 90
	elif direction.x < 0:
		arrow_instance.rotation_degrees.y = -90
	elif direction.y > 0:
		arrow_instance.rotation_degrees.y = 180
	# direction.y < 0 is default (0 degrees)
	
	# Draw triangle arrow
	arrow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var arrow_size = 0.3
	arrow_mesh.surface_add_vertex(Vector3(0, arrow_size, 0))      # Tip
	arrow_mesh.surface_add_vertex(Vector3(-arrow_size/2, 0, 0))   # Left
	arrow_mesh.surface_add_vertex(Vector3(arrow_size/2, 0, 0))    # Right
	
	arrow_mesh.surface_end()
	
	# Material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.8)  # White arrow
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_instance.set_surface_override_material(0, material)
	
	return arrow_instance

func highlight_attack_range(cells: Array):
	clear_attack_highlights()
	
	for cell in cells:
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += 0.03  # Above other highlights
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		# Use pre-created material from config
		var material = GameConfig.get_material("attack")
		if not material:
			push_error("Grid3D: Failed to get attack material from GameConfig")
			return
		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		attack_highlights.append(quad)
		
		# Add pulsing animation (more intense for attack range)
		var pulse_from = GameConfig.get_color("attack_highlight")
		var pulse_to = GameConfig.get_color("attack_bright")
		_add_pulse_animation(quad, pulse_from, pulse_to)

# Helper function to add pulsing animation to a mesh
func _add_pulse_animation(mesh: MeshInstance3D, color_from: Color, color_to: Color):
	if not mesh:
		return
	
	var material = mesh.get_surface_override_material(0)
	if not material:
		return
	
	# Create looping fade animation
	var tween = create_tween()
	tween.set_loops()  # Loop indefinitely
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Pulse between two alpha values
	tween.tween_property(material, "albedo_color", color_to, 0.8)
	tween.tween_property(material, "albedo_color", color_from, 0.8)

func clear_attack_highlights():
	for mesh in attack_highlights:
		mesh.queue_free()
	attack_highlights.clear()

func clear_highlights():
	for mesh in highlight_meshes:
		mesh.queue_free()
	highlight_meshes.clear()

func clear_path():
	for mesh in path_meshes:
		mesh.queue_free()
	path_meshes.clear()

func highlight_cursor_position(grid_pos: Vector2i):
	# Clear previous cursor highlight
	clear_cursor_highlight()
	
	# Create light yellow semi-transparent highlight for cursor
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	world_pos.y += 0.005  # Slightly above ground, below other highlights
	
	var quad = create_quad_mesh()
	quad.position = world_pos
	quad.rotation_degrees.x = -90
	
	# Use pre-created material from config
	var material = GameConfig.get_material("cursor")
	if not material:
		push_error("Grid3D: Failed to get cursor material from GameConfig")
		return
	
	quad.set_surface_override_material(0, material)
	add_child(quad)
	cursor_highlight = quad
	
	# Add pulsing animation to cursor for visibility
	var tween = create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Pulse opacity
	tween.tween_property(material, "albedo_color", Color(1, 1, 0.6, 0.7), 0.6)
	tween.tween_property(material, "albedo_color", Color(1, 1, 0.6, 0.3), 0.6)
	
	# Add subtle bounce effect
	var bounce_tween = create_tween()
	bounce_tween.set_loops()
	bounce_tween.set_trans(Tween.TRANS_SINE)
	bounce_tween.set_ease(Tween.EASE_IN_OUT)
	
	var start_y = world_pos.y
	bounce_tween.tween_property(quad, "position:y", start_y + 0.05, 0.8)
	bounce_tween.tween_property(quad, "position:y", start_y, 0.8)

func clear_cursor_highlight():
	if cursor_highlight:
		cursor_highlight.queue_free()
		cursor_highlight = null

