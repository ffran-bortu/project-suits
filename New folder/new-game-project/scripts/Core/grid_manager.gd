# grid_manager.gd - Final optimized version
extends Node

# Grid configuration - KEEP your original scale
var grid_size = Vector2i(8, 8)
var cell_size = Vector2(64, 64)  # KEEP as 3D units

# Cache dependencies
var unit_manager: Node = null

# Constants
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1),  # Up (North)
	Vector2i(0, 1),   # Down (South)
	Vector2i(-1, 0),  # Left (West)
	Vector2i(1, 0)    # Right (East)
]

# 3D Terrain data
var height_map: Dictionary = {}
var height_unit_scale: float = 3.0  # Multiplier to make height differences more visible
var max_climb_height: float = 1.0  # Max height units can climb up

func _ready():
	initialize_height_map()
	print("GridManager initialized: ", grid_size, " grid with cell size: ", cell_size)

# === GRID OPERATIONS ===
func is_within_grid(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < grid_size.x and 
			grid_pos.y >= 0 and grid_pos.y < grid_size.y)

# Convert grid → 3D world position WITH height
func grid_to_world_3d(grid_pos: Vector2i) -> Vector3:
	if not is_within_grid(grid_pos):
		return Vector3.ZERO
	
	var height = get_height(grid_pos) * height_unit_scale
	return Vector3(
		grid_pos.x * cell_size.x + cell_size.x * 0.5,  # Center in cell
		height,                                         # Y is up (height)
		grid_pos.y * cell_size.y + cell_size.y * 0.5   # Z is forward/depth
	)

# Convert 3D world → 2D grid (ignore height)
func world_to_grid_3d(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int((world_pos.x - cell_size.x * 0.5) / cell_size.x),
		int((world_pos.z - cell_size.y * 0.5) / cell_size.y)
	)

# === HEIGHT MAP ===
func initialize_height_map():
	height_map.clear()
	for x in grid_size.x:
		for y in grid_size.y:
			var pos = Vector2i(x, y)
			height_map[pos] = 0.0  # Flat terrain by default

func get_height(grid_pos: Vector2i) -> float:
	return height_map.get(grid_pos, 0.0)

func set_height(grid_pos: Vector2i, height: float):
	if is_within_grid(grid_pos):
		height_map[grid_pos] = height

func can_traverse_height(from: Vector2i, to: Vector2i, max_climb: float = -1.0) -> bool:
	if max_climb < 0:
		max_climb = max_climb_height
	
	var from_height = get_height(from)
	var to_height = get_height(to)
	var height_diff = to_height - from_height
	
	# Allow going down any distance, but limit going up
	# This means units can go down cliffs but can't climb steep walls
	if height_diff > max_climb:  # Trying to go up too high
		return false
	
	return true  # Going down or climbing within limits is OK

# === MOVEMENT & PATHFINDING ===
func get_movement_range(start_pos: Vector2i, movement_range: int, unit = null) -> Array:
	var reachable_cells = []
	var visited = {start_pos: 0}
	var queue = [start_pos]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cost = visited[current]
		
		for dir in CARDINAL_DIRECTIONS:
			var next = current + dir
			
			if not is_within_grid(next):
				continue
			
			# Check if blocked by enemy
			if unit and is_cell_blocked_by_enemy(next, unit):
				continue
			
			# Check if height is traversable
			if not can_traverse_height(current, next):
				continue
			
			var next_cost = current_cost + 1
			
			if next_cost <= movement_range and not visited.has(next):
				visited[next] = next_cost
				queue.append(next)
				if next != start_pos:
					reachable_cells.append(next)
	
	return reachable_cells

func get_grid_path(start_pos: Vector2i, target_pos: Vector2i, unit = null) -> Array:
	if not is_within_grid(start_pos) or not is_within_grid(target_pos):
		return []
	
	return find_path_astar(start_pos, target_pos, unit)

func find_path_astar(start: Vector2i, goal: Vector2i, unit = null) -> Array:
	# A* pathfinding with height consideration
	var open_set = [start]
	var came_from = {}
	var g_score = {start: 0}
	var f_score = {start: heuristic(start, goal)}
	
	while open_set.size() > 0:
		open_set.sort_custom(func(a, b): return f_score.get(a, INF) < f_score.get(b, INF))
		var current = open_set.pop_front()
		
		if current == goal:
			return reconstruct_path(came_from, current)
		
		for dir in CARDINAL_DIRECTIONS:
			var neighbor = current + dir
			
			if not is_within_grid(neighbor):
				continue
			
			# Check if blocked by enemy
			if unit and is_cell_blocked_by_enemy(neighbor, unit):
				continue
			
			# Check height (asymmetric: can go down any distance, limit going up)
			if not can_traverse_height(current, neighbor):
				continue
			
			var tentative_g = g_score[current] + 1
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, goal)
				
				if not neighbor in open_set:
					open_set.append(neighbor)
	
	return []  # No path found

func reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array:
	var path = [current]
	while current in came_from:
		current = came_from[current]
		path.push_front(current)
	return path

func heuristic(a: Vector2i, b: Vector2i) -> int:
	# Manhattan distance for 4-directional movement
	return abs(a.x - b.x) + abs(a.y - b.y)

func is_cell_blocked_by_enemy(grid_pos: Vector2i, moving_unit) -> bool:
	if not unit_manager:
		return false
	
	var unit_at_pos = unit_manager.get_unit_at_position(grid_pos)
	if unit_at_pos and unit_at_pos != moving_unit:
		return unit_at_pos.team != moving_unit.team
	
	return false

# === ATTACK RANGE ===
func get_attack_range(unit_pos: Vector2i, attack_range: int) -> Array:
	var attack_cells = []
	
	# Diamond pattern for Manhattan movement
	for x in range(-attack_range, attack_range + 1):
		for y in range(-attack_range, attack_range + 1):
			var distance = abs(x) + abs(y)
			if 1 <= distance and distance <= attack_range:
				var cell_pos = unit_pos + Vector2i(x, y)
				if is_within_grid(cell_pos):
					attack_cells.append(cell_pos)
	
	return attack_cells

# === UNIT SCALING HELPER ===
func get_unit_scale() -> Vector3:
	# Returns recommended scale for units based on grid size
	# Adjust this based on your actual unit model size
	# Current: 2.5x scale for visibility
	return Vector3(2.5, 2.5, 2.5)
