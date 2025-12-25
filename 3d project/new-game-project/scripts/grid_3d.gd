# grid_3d.gd - 3D grid visualization
extends Node3D

var grid_meshes: Array = []
var highlight_meshes: Array = []
var path_meshes: Array = []

func _ready():
	create_3d_grid()
	print("3D Grid ready!")

func create_3d_grid():
	var grid_size = GridManager.grid_size
	var cell_size = GridManager.cell_size
	
	print("Creating 3D grid with depth visualization...")
	
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
					# Add subtle border effect with edge color
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
	
	print("Created 3D grid with ", grid_meshes.size(), " mesh pieces")

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

func highlight_movement_range(cells: Array):
	clear_highlights()
	
	for cell in cells:
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += 0.01  # Slightly above ground
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0, 1, 0, 0.3)  # Green highlight
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		highlight_meshes.append(quad)
	
	print("Added ", cells.size(), " movement highlights")

func draw_path(path_cells: Array):
	clear_path()
	
	for i in range(1, path_cells.size()):  # Skip first cell
		var cell = path_cells[i]
		var world_pos = GridManager.grid_to_world_3d(cell)
		world_pos.y += 0.02  # Above movement highlights
		
		var quad = create_quad_mesh()
		quad.position = world_pos
		quad.rotation_degrees.x = -90
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0, 0, 1, 0.5)  # Blue path
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
		quad.set_surface_override_material(0, material)
		add_child(quad)
		path_meshes.append(quad)
	
	print("Drew path with ", path_cells.size() - 1, " steps")

func clear_highlights():
	for mesh in highlight_meshes:
		mesh.queue_free()
	highlight_meshes.clear()
	print("Cleared movement highlights")

func clear_path():
	for mesh in path_meshes:
		mesh.queue_free()
	path_meshes.clear()
	print("Cleared path highlights")

