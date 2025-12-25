"""
FILE: grid_3d.gd
PURPOSE: Renders the 3D tactical grid with terrain elevation, movement highlights, attack ranges, and path visualization.

OVERVIEW:
This system creates the full 3D grid battlefield with visible cell edges, elevation walls for height differences,
movement range highlights with hover effects, attack range displays, path arrows for unit movement, and cursor
positioning indicators. It handles all visual feedback for tactical gameplay by dynamically creating and clearing
mesh instances based on game state. Color-coded highlights use GameConfig for consistent theming.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Clears existing visualizations and creates the 3D grid from GridManager data
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. clear_all()
   - What it does: Frees all grid meshes and clears all highlight/path arrays
   - Uses: Called before recreating grid or when resetting visualization
   - Returns: void

3. create_3d_grid()
   - What it does: Iterates through all grid positions, creates 3D cells with height-based walls and borders
   - Uses: Called during initialization to build the entire tactical grid
   - Returns: void

4. create_cell_border(grid_pos: Vector2i, border_color: Color)
   - What it does: Creates thin quad meshes around cell edges for visual definition (front and right edges only)
   - Uses: Called for flat cells to add border lines
   - Returns: void

5. create_quad_mesh() -> MeshInstance3D
   - What it does: Creates a QuadMesh sized to match grid cell dimensions
   - Uses: Helper for creating flat surfaces
   - Returns: MeshInstance3D - configured quad mesh instance

6. create_3d_cell_box(grid_pos: Vector2i, height: float) -> Array
   - What it does: Creates top face and four wall faces for elevated terrain cells
   - Uses: Called for each grid cell to build 3D geometry
   - Returns: Array - mesh instances for cell faces

7. create_wall_mesh(width: float, height: float) -> MeshInstance3D
   - What it does: Creates a quad mesh for cell walls with specified dimensions
   - Uses: Helper for building elevation walls
   - Returns: MeshInstance3D - wall quad mesh

8. draw_movement_highlights(reachable_cells: Array) -> void
   - What it does: Shows semi-transparent blue overlays on cells within movement range
   - Uses: Called when unit is selected to show where it can move
   - Returns: void

9. update_hover_in_range(grid_pos: Vector2i) -> void
   - What it does: Shows brighter highlight on single cell being hovered within movement range
   - Uses: Called when cursor moves over highlighted movement cells
   - Returns: void

10. draw_path(path_cells: Array) -> void
    - What it does: Creates cyan path overlays with directional arrow indicators between waypoints
    - Uses: Called when displaying unit's planned movement path
    - Returns: void

11. create_arrow_indicator(pos: Vector3, direction: Vector2i) -> MeshInstance3D
    - What it does: Creates small triangle mesh pointing in movement direction
    - Uses: Called for each path segment to show movement flow
    - Returns: MeshInstance3D - arrow indicator or null if invalid direction

12. clear_highlights() -> void
   - What it does: Removes all movement range highlight meshes
   - Uses: Called when unit is deselected or state changes
   - Returns: void

13. clear_path() -> void
    - What it does: Removes all path visualization meshes
    - Uses: Called when path is cancelled or new path is drawn
    - Returns: void

14. draw_attack_highlights(attackable_cells: Array) -> void
    - What it does: Shows red semi-transparent overlays on cells within attack range
    - Uses: Called when attack action is selected
    - Returns: void

15. clear_attack_highlights() -> void
    - What it does: Removes all attack range highlight meshes
    - Uses: Called when exiting attack mode
    - Returns: void

16. show_cursor_highlight(grid_pos: Vector2i) -> void
    - What it does: Creates bright yellow highlight under cursor position
    - Uses: Called to emphasize current cursor location
    - Returns: void

17. clear_cursor_highlight() -> void
    - What it does: Removes cursor position highlight
    - Uses: Called when cursor highlight should be hidden
    - Returns: void

18. _add_pulse_animation(mesh: MeshInstance3D, from_color: Color, to_color: Color) -> void
    - What it does: Applies repeating color fade tween to mesh for pulsing effect
    - Uses: Called for highlights that should draw attention with animation
    - Returns: void

19. (Additional helper functions for highlight creation and mesh setup)

NOTES:
- Depends on GridManager for grid dimensions, cell size, height data, and coordinate conversion
- Depends on GameConfig for highlight colors (movement, attack, cursor, path, etc.) and offset values
- Creates 3D cells with BoxMesh top surface and QuadMesh walls for elevation
- Wall height calculated as: (terrain_height * GridManager.height_unit_scale) - 0.1
- Only creates walls if height > 0.05 to avoid unnecessary geometry
- Cell borders only added to flat cells (height <= 0.01) to reduce visual clutter
- Movement highlights use semi-transparent blue (GameConfig.get_color("movement"))
- Attack highlights use semi-transparent red (GameConfig.get_color("attack"))
- Path uses cyan color (GameConfig.get_color("path")) with directional arrows
- Cursor highlight uses bright yellow (GameConfig.get_color("cursor_bright"))
- Hover highlight uses brighter movement color with pulse animation
- All highlights positioned slightly above terrain using GameConfig.grid.highlight_offset values
- Arrow indicators are ImmediateMesh triangles rotated to point in movement direction
- Pulse animations use infinite loop tweens with SINE transitions for smooth oscillation
"""

# grid_3d.gd - 3D grid visualization
extends Node3D

# Visual storage
var grid_meshes: Array[MeshInstance3D] = []
var highlight_meshes: Array[MeshInstance3D] = []
var path_meshes: Array[MeshInstance3D] = []
var path_indicators: Array[MeshInstance3D] = []
var attack_highlights: Array[MeshInstance3D] = []
var cursor_highlight: MeshInstance3D = null
var hover_highlight: MeshInstance3D = null  # NEW: Separate hover highlight
var current_hover_pos: Vector2i = Vector2i(-1, -1)  # NEW: Track hovered position

# Tween tracking for cleanup
var active_tweens: Array[Tween] = []

func _ready() -> void:
	# Wait a frame to ensure terrain is set first
	await get_tree().process_frame
	create_3d_grid()

func regenerate_grid():
	# Clear existing grid and recreate with updated heights
	clear_all()
	create_3d_grid()

func clear_all() -> void:
	# Clear all visualizations
	for mesh in grid_meshes:
		mesh.queue_free()
	grid_meshes.clear()
	clear_highlights()
	clear_path()
	clear_attack_highlights()
	clear_cursor_highlight()

func create_3d_grid() -> void:
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
	

func create_cell_border(grid_pos: Vector2i, border_color: Color) -> void:
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
		world_pos.y += GameConfig.grid.highlight_offset_movement
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		# Use pre-created material from config
		var material = GameConfig.get_material("movement")
		if not material:
			push_error("Grid3D: Failed to get movement material from GameConfig")
			return
		
		# Duplicate to ensure unique animation state
		material = material.duplicate()

		
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
func update_hover_in_range(grid_pos: Vector2i) -> void:
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
	world_pos.y += GameConfig.grid.highlight_offset_hover
	
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

func draw_path(path_cells: Array) -> void:
	clear_path()
	
	for i in range(1, path_cells.size()):  # Skip first cell
		var cell = path_cells[i]
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += GameConfig.grid.highlight_offset_path
		
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
		world_pos.y += GameConfig.grid.highlight_offset_attack
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		# Use pre-created material from config
		var material = GameConfig.get_material("attack")
		if not material:
			push_error("Grid3D: Failed to get attack material from GameConfig")
			return

		# Duplicate to ensure unique animation state
		material = material.duplicate()

		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		attack_highlights.append(quad)
		
		# Add pulsing animation (more intense for attack range)
		var pulse_from = GameConfig.get_color("attack_highlight")
		var pulse_to = GameConfig.get_color("attack_bright")
		_add_pulse_animation(quad, pulse_from, pulse_to)

func highlight_deployment_tiles(cells: Array):
	print("Grid3D: highlight_deployment_tiles called with %d cells" % cells.size())
	clear_highlights()
	current_hover_pos = Vector2i(-1, -1)
	
	for cell in cells:
		print("Grid3D: Creating deployment highlight for cell: ", cell)
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += GameConfig.grid.highlight_offset_movement
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		# User requested "light blue hue" - movement is usually blue
		var material = GameConfig.get_material("movement")
		if not material:
			push_error("Grid3D: Failed to get movement material")
			return

		# Duplicate to ensure unique animation state
		material = material.duplicate()

		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		highlight_meshes.append(quad)
		print("Grid3D: Created deployment highlight quad at ", world_pos)
		
		# Gentle pulsing similar to movement
		var pulse_from = GameConfig.get_color("movement_highlight")
		var pulse_to = GameConfig.get_color("movement_bright")
		_add_pulse_animation(quad, pulse_from, pulse_to)
	
	print("Grid3D: highlight_deployment_tiles completed. Total highlights: %d" % highlight_meshes.size())

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
	
	# Track tween for cleanup
	active_tweens.append(tween)

func clear_attack_highlights() -> void:
	for mesh in attack_highlights:
		mesh.queue_free()
	attack_highlights.clear()

func clear_highlights() -> void:
	# Kill all active tweens
	_cleanup_tweens()
	
	for mesh in highlight_meshes:
		mesh.queue_free()
	highlight_meshes.clear()

func clear_path() -> void:
	for mesh in path_meshes:
		mesh.queue_free()
	path_meshes.clear()

func highlight_cursor_position(grid_pos: Vector2i):
	# Clear previous cursor highlight
	clear_cursor_highlight()
	
	# Create light yellow semi-transparent highlight for cursor
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	world_pos.y += GameConfig.grid.highlight_offset_cursor
	
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
	active_tweens.append(tween)  # Track for cleanup
	
	# Add subtle bounce effect
	var bounce_tween = create_tween()
	bounce_tween.set_loops()
	bounce_tween.set_trans(Tween.TRANS_SINE)
	bounce_tween.set_ease(Tween.EASE_IN_OUT)
	
	var start_y = world_pos.y
	bounce_tween.tween_property(quad, "position:y", start_y + 0.05, 0.8)
	bounce_tween.tween_property(quad, "position:y", start_y, 0.8)
	active_tweens.append(bounce_tween)  # Track for cleanup

func clear_cursor_highlight() -> void:
	# Kill cursor highlight tweens before freeing the mesh
	_cleanup_tweens()
	
	if cursor_highlight:
		cursor_highlight.queue_free()
		cursor_highlight = null

## Clean up all active tweens
func _cleanup_tweens():
	for tween in active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	active_tweens.clear()

func _exit_tree():
	# Clean up all tweens when grid is removed
	_cleanup_tweens()
