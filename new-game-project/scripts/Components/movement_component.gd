class_name MovementComponent
extends Node

## Component for managing unit movement and path following
##
## Handles the actual movement animation along a grid path using Tweens.
## Depends on the parent unit having a `position` property and `set_grid_position` method.

signal movement_started()
signal movement_finished()

var _unit: Unit
var _is_moving: bool = false
var _movement_tween: Tween

func setup(unit: Unit) -> void:
	assert(unit != null, "MovementComponent: Unit dependency cannot be null in setup()")
	_unit = unit

func is_moving() -> bool:
	return _is_moving

func move_along_path(path_cells: Array[Vector2i]) -> void:
	if _is_moving:
		push_warning("MovementComponent: Already moving!")
		return
		
	if path_cells.size() <= 1:
		movement_finished.emit()
		return
	
	_is_moving = true
	movement_started.emit()
	
	if _movement_tween:
		_movement_tween.kill()
	
	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_SINE)
	_movement_tween.set_ease(Tween.EASE_IN_OUT)
	
	var world_positions: Array[Vector3] = []
	
	# Pre-calculate positions
	for i in range(1, path_cells.size()):
		var grid_pos = path_cells[i]
		if not GridManager.is_within_grid(grid_pos):
			continue
			
		var world_pos = GridManager.grid_to_world_3d(grid_pos)
		# NO offset - units stay at ground level (fixes jumping on flat maps)
		# var offset = GameConfig.unit.movement_offset if GameConfig else 3.0
		# world_pos.y += offset  // REMOVED to fix jumping
		world_positions.append(world_pos)
	
	# Animate
	# Trigger JUMP animation on visual component if available
	if _unit.visual_component:
		_unit.visual_component.play_animation("JUMP")

	for pos in world_positions:
		var duration = 0.2
		if GameConfig:
			# Calculate duration based on speed = dist/time -> time = dist/speed
			# Assuming 1 tile approx 1-2 meters. 
			# Actually GameConfig has walk_speed, let's use fixed 0.2s per tile for now for smoothness
			pass
		_movement_tween.tween_property(_unit, "position", pos, duration)
	
	# Cleanup callback
	_movement_tween.tween_callback(func():
		_finish_movement(path_cells.back())
	)

func _finish_movement(final_grid_pos: Vector2i) -> void:
	_is_moving = false
	if _unit:
		_unit.set_grid_position(final_grid_pos)
		if _unit.visual_component:
			_unit.visual_component.play_animation("IDLE")
	movement_finished.emit()
