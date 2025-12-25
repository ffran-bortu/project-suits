# grid_manager.gd - Global grid management (Singleton/Autoload)
extends Node

# Grid configuration
var grid_size = Vector2i(8, 8)  # Default 8x8 test grid
var cell_size = Vector2(64, 64)  # 64 pixels per cell
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1),  # Up
	Vector2i(0, 1),   # Down
	Vector2i(-1, 0),  # Left
	Vector2i(1, 0)    # Right
]  # Shared directions array to avoid re-allocating every search
var astar_grid: AStarGrid2D

# 3D Terrain data
var height_map: Dictionary = {}  # Format: {Vector2i(x,y): float(height)}
var height_unit_scale: float = 1.0  # 1.0 = 1 grid cell height difference
var max_climb_height: float = 1.0  # Maximum height difference units can climb

# Initialize the AStarGrid2D
func _ready():
	initialize_astar_grid()
	initialize_height_map()
	print("GridManager initialized: ", grid_size, " grid with cell size: ", cell_size)

# Create and configure AStarGrid2D
func initialize_astar_grid():
	astar_grid = AStarGrid2D.new()
	astar_grid.region = Rect2i(0, 0, grid_size.x, grid_size.y)
	astar_grid.cell_size = cell_size
	astar_grid.offset = cell_size * 0.5  # Center points in cells
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER  # Chess-style movement
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()
	
	# Make all cells walkable by default
	for x in grid_size.x:
		for y in grid_size.y:
			astar_grid.set_point_solid(Vector2i(x, y), false)

# Convert grid coordinates to screen position
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos) * cell_size + cell_size * 0.5

# Convert screen position to grid coordinates
func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos / cell_size)

# Check if a grid position is within bounds
func is_within_grid(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < grid_size.x and 
			grid_pos.y >= 0 and grid_pos.y < grid_size.y)

# Get movement cost between two adjacent cells (default: 1)
func get_movement_cost(from: Vector2i, to: Vector2i) -> int:
	return 1  # We'll add terrain costs later

# Calculate all reachable positions within movement range (with height consideration)
func get_movement_range(start_pos: Vector2i, movement_range: int, max_climb: float = -1.0) -> Array:
	var reachable_cells = []
	var visited = {}
	var queue = [{"pos": start_pos, "cost": 0}]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_pos = current["pos"]
		var current_cost = current["cost"]
		
		# Skip if we've already visited this position with equal or lower cost
		if visited.has(current_pos) and visited[current_pos] <= current_cost:
			continue
		
		visited[current_pos] = current_cost
		
		# Add to reachable if not the starting position
		if current_pos != start_pos:
			reachable_cells.append(current_pos)
		
		# Check all four directions (up, down, left, right)
		for direction in CARDINAL_DIRECTIONS:
			var next_pos = current_pos + direction
			
			# Check if position is within grid bounds and walkable
			if not is_within_grid(next_pos) or astar_grid.is_point_solid(next_pos):
				continue
			
			# Check if height difference is traversable
			if not can_traverse_height(current_pos, next_pos, max_climb):
				continue
			
			# Use height-aware movement cost
			var next_cost = current_cost + get_movement_cost_with_height(current_pos, next_pos)
			
			# If within movement range, add to queue
			if next_cost <= movement_range:
				queue.append({"pos": next_pos, "cost": next_cost})
	
	return reachable_cells

# Get path from start to target using A* with height consideration
func get_grid_path(start_pos: Vector2i, target_pos: Vector2i, max_climb: float = -1.0) -> Array:
	# Check if positions are valid
	if not is_within_grid(start_pos) or not is_within_grid(target_pos):
		return []
	
	# Check if target is reachable (not solid)
	if astar_grid.is_point_solid(target_pos):
		return []
	
	# Use custom A* pathfinding that considers height
	return find_path_3d(start_pos, target_pos, max_climb)

# Custom A* pathfinding that considers height differences
func find_path_3d(start_pos: Vector2i, target_pos: Vector2i, max_climb: float = -1.0) -> Array:
	# A* algorithm with height-aware costs
	var open_set = []  # Priority queue: [f_cost, pos, g_cost, came_from]
	var closed_set = {}  # Dictionary: pos -> true
	var came_from = {}  # Dictionary: pos -> previous_pos
	var g_score = {}  # Dictionary: pos -> cost from start
	var f_score = {}  # Dictionary: pos -> estimated total cost
	
	# Initialize starting position
	g_score[start_pos] = 0
	f_score[start_pos] = heuristic(start_pos, target_pos)
	open_set.append({"f": f_score[start_pos], "pos": start_pos, "g": 0, "from": null})
	
	# Sort open set by f_cost
	open_set.sort_custom(func(a, b): return a.f < b.f)
	
	while open_set.size() > 0:
		# Get node with lowest f_score
		var current = open_set.pop_front()
		var current_pos = current.pos
		
		# Skip if already processed
		if closed_set.has(current_pos):
			continue
		
		closed_set[current_pos] = true
		came_from[current_pos] = current.from
		
		# Check if we reached the target
		if current_pos == target_pos:
			# Reconstruct path
			return reconstruct_path(came_from, start_pos, target_pos)
		
		# Check all neighbors
		for direction in CARDINAL_DIRECTIONS:
			var neighbor_pos = current_pos + direction
			
			# Skip if out of bounds or solid
			if not is_within_grid(neighbor_pos) or astar_grid.is_point_solid(neighbor_pos):
				continue
			
			# Skip if already in closed set
			if closed_set.has(neighbor_pos):
				continue
			
			# Check if height difference is traversable
			if not can_traverse_height(current_pos, neighbor_pos, max_climb):
				continue
			
			# Calculate tentative g_score
			var tentative_g = g_score[current_pos] + get_movement_cost_with_height(current_pos, neighbor_pos)
			
			# If this path to neighbor is better, record it
			if not g_score.has(neighbor_pos) or tentative_g < g_score[neighbor_pos]:
				came_from[neighbor_pos] = current_pos
				g_score[neighbor_pos] = tentative_g
				f_score[neighbor_pos] = tentative_g + heuristic(neighbor_pos, target_pos)
				
				# Add to open set if not already there
				var in_open_set = false
				for item in open_set:
					if item.pos == neighbor_pos:
						item.f = f_score[neighbor_pos]
						item.g = tentative_g
						item.from = current_pos
						in_open_set = true
						break
				
				if not in_open_set:
					open_set.append({"f": f_score[neighbor_pos], "pos": neighbor_pos, "g": tentative_g, "from": current_pos})
				
				# Re-sort open set
				open_set.sort_custom(func(a, b): return a.f < b.f)
	
	# No path found
	return []

# Reconstruct path from came_from dictionary
func reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var path = []
	var current = goal
	
	while current != null and current != start:
		path.insert(0, current)
		current = came_from.get(current, null)
	
	# Add start position
	if path.size() > 0:
		path.insert(0, start)
	
	return path

# Heuristic function (Manhattan distance)
func heuristic(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)

# Check if height difference is traversable
func can_traverse_height(from: Vector2i, to: Vector2i, max_climb: float = -1.0) -> bool:
	if max_climb < 0:
		max_climb = max_climb_height
	
	var from_height = get_height(from)
	var to_height = get_height(to)
	var height_diff = to_height - from_height
	
	# Can always go down, but check if going up is too steep
	if height_diff > max_climb:
		return false
	
	return true

# Check if a position is reachable from start within movement range
func is_position_reachable(start_pos: Vector2i, target_pos: Vector2i, movement_range: int) -> bool:
	var reachable_cells = get_movement_range(start_pos, movement_range)
	for cell in reachable_cells:
		if cell == target_pos:
			return true
	return false

# Initialize height map (flat terrain by default)
func initialize_height_map():
	for x in grid_size.x:
		for y in grid_size.y:
			var pos = Vector2i(x, y)
			height_map[pos] = 0.0  # Flat terrain
	print("Height map initialized: ", grid_size, " cells")

# Convert 2D grid → 3D world position with height
func grid_to_world_3d(grid_pos: Vector2i) -> Vector3:
	if not is_within_grid(grid_pos):
		return Vector3.ZERO
	
	var height = height_map.get(grid_pos, 0.0) * height_unit_scale
	# Map grid coordinates to world coordinates
	# Grid X → World X (horizontal)
	# Grid Y → World Z (depth/forward)
	# Height → World Y (vertical)
	return Vector3(
		grid_pos.x * cell_size.x + cell_size.x * 0.5,  # Center in cell
		height,                                         # Y is up
		grid_pos.y * cell_size.y + cell_size.y * 0.5   # Z is forward/depth
	)

# Convert 3D world → 2D grid (ignore height)
func world_to_grid_3d(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int((world_pos.x - cell_size.x * 0.5) / cell_size.x),
		int((world_pos.z - cell_size.y * 0.5) / cell_size.y)
	)

# Get/set height
func set_height(grid_pos: Vector2i, height: float):
	if is_within_grid(grid_pos):
		height_map[grid_pos] = height

func get_height(grid_pos: Vector2i) -> float:
	return height_map.get(grid_pos, 0.0)

# Get movement cost considering height differences
func get_movement_cost_with_height(from: Vector2i, to: Vector2i) -> int:
	var base_cost = get_movement_cost(from, to)
	var from_height = get_height(from)
	var to_height = get_height(to)
	var height_diff = to_height - from_height
	
	# Height penalties/bonuses
	if height_diff > 0.5:      # Steep uphill
		return base_cost + 2
	elif height_diff > 0.1:    # Gentle uphill
		return base_cost + 1
	elif height_diff < -0.5:   # Steep downhill
		return base_cost       # Easier going down
	else:                      # Flat or minor slope
		return base_cost
