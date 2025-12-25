# unit.gd - 3D version
extends Node3D

signal unit_selected(unit)
signal unit_deselected(unit)
signal unit_moved(from_pos, to_pos)
signal movement_finished()

# Unit properties
var grid_position: Vector2i = Vector2i(0, 0)
var movement_range: int = 4
var team: int = 0
var unit_name: String = "Soldier"
var is_moving: bool = false
var movement_speed: float = 300.0
var current_movement_tween: Tween = null
var max_climb_height: float = 1.0  # Maximum height difference this unit can climb

var sprite: Sprite3D
var selection_indicator: Sprite3D

func _ready():
	sprite = $Sprite3D
	selection_indicator = $SelectionIndicator
	
	update_position_visual()
	print("Unit '", unit_name, "' ready at ", grid_position)

func update_position_visual():
	var world_pos_3d = GridManager.grid_to_world_3d(grid_position)
	world_pos_3d.y += 0.1  # Lift unit slightly above ground
	self.position = world_pos_3d
	if unit_name == "Player Knight":  # Debug print for player unit
		print("Unit '", unit_name, "' at grid ", grid_position, " -> world pos: ", world_pos_3d)

func set_grid_position(new_position: Vector2i):
	var old_position = grid_position
	grid_position = new_position
	update_position_visual()
	unit_moved.emit(old_position, new_position)

func select():
	selection_indicator.visible = true
	unit_selected.emit(self)
	print("Unit selected: ", unit_name)

func deselect():
	selection_indicator.visible = false
	unit_deselected.emit(self)

func is_within_move_range(target_pos: Vector2i) -> bool:
	var distance = abs(target_pos.x - grid_position.x) + abs(target_pos.y - grid_position.y)
	return distance <= movement_range

func get_movement_cost_to(target_pos: Vector2i) -> int:
	return 1

func is_at_position(check_pos: Vector2i) -> bool:
	return grid_position == check_pos

func move_along_path(path_cells: Array):
	if is_moving:
		print("Unit is already moving!")
		return
	
	if path_cells.size() <= 1:
		print("Path too short to move")
		return
	
	is_moving = true
	
	current_movement_tween = create_tween()
	current_movement_tween.set_trans(Tween.TRANS_SINE)
	current_movement_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Convert grid path to 3D world positions
	var world_positions = []
	for i in range(1, path_cells.size()):
		var world_pos = GridManager.grid_to_world_3d(path_cells[i])
		world_pos.y += 0.05  # Lift unit slightly above ground
		world_positions.append(world_pos)
	
	# Animate through 3D positions
	for i in range(world_positions.size()):
		var duration = 0.2  # Constant time per tile
		current_movement_tween.tween_property(self, "position", world_positions[i], duration)
	
	current_movement_tween.tween_callback(func(): 
		if world_positions.size() > 0:
			position = world_positions[world_positions.size() - 1]
		set_grid_position(path_cells[path_cells.size() - 1])
		is_moving = false
		movement_finished.emit()
	)
	
	print("Unit moving along path with ", path_cells.size(), " steps")
