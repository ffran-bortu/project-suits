## Unit - Represents a tactical unit on the grid
##
## Handles unit behavior including:
## - Movement and pathfinding
## - Combat stats and health
## - Visual feedback (selection, damage, HP bars)
## - Turn state management
extends Node3D

# Preload UnitClass to ensure it's recognized
@onready var game_state = get_node("/root/GameStateManager")

## Emitted when this unit is selected
signal unit_selected(unit)
## Emitted when this unit is deselected
signal unit_deselected(unit)
## Emitted when unit moves to a new position
signal unit_moved(from_pos, to_pos)
## Emitted when movement animation completes
signal movement_finished()

# Constants
const GROUND_OFFSET = 3.0  # Height above ground for normal positioning (lifted above grid)
const MOVEMENT_OFFSET = 3.0  # Height during movement animation (lifted above grid)

# Unit properties
var grid_position: Vector2i = Vector2i(0, 0)
var movement_range: int = 4
var team: int = 0
var unit_name: String = "Soldier"
var is_moving: bool = false
var movement_speed: float = 300.0
var current_movement_tween: Tween = null
var max_climb_height: float = 1.0  # Maximum height difference this unit can climb
@export var has_acted: bool = false
@export var has_moved: bool = false
var attack_range: int = 1  # Default attack range (melee)
var max_health: int = 10   # Maximum health
var current_health: int = 10  # Current health

# UnitClass reference (assignable in Inspector)
# Using Resource to avoid cyclic parsing issues
@export var unit_class: Resource = null

# All 8 core stats (initialized from UnitClass, but modifiable per-unit)
var str: int = 0  # Strength (physical weapon damage)
var mag: int = 0  # Magic (magical weapon damage)
var skill: int = 0  # Skill (affects hit rate and critical chance)
var spd: int = 0  # Speed (affects avoid and double attacks)
var luck: int = 0  # Luck (affects hit, avoid, crit avoid, skill activation)
var def: int = 0  # Defense (reduces physical damage)
var res: int = 0  # Resistance (reduces magical damage)
# Note: HP is represented by max_health and current_health

var sprite: Sprite3D
var selection_indicator: Sprite3D

func _ready():
	# Validate child nodes exist
	if not has_node("Sprite3D"):
		push_error("Unit: Sprite3D node not found!")
		return
	if not has_node("SelectionIndicator"):
		push_error("Unit: SelectionIndicator node not found!")
		return
	
	sprite = $Sprite3D
	selection_indicator = $SelectionIndicator
	
	# Validate GridManager exists
	if not GridManager:
		push_error("Unit: GridManager not available!")
		return
	
	reset_turn_state()
	
	# Initialize stats from UnitClass if assigned
	_initialize_from_class()
	
	# Apply scaling from GridManager (critical for HP bar positioning)
	var recommended_scale = GridManager.get_unit_scale()
	scale = recommended_scale
	
	update_position_visual()
	
	# Debug output (following instructions pattern)
	print("Unit initialized: ", unit_name, " at ", grid_position, 
		  " world pos: ", position, " scale: ", scale)
	
	# Setup HP bar if it exists (must be after scaling is applied)
	if has_node("HPBar3D"):
		var hp_bar = get_node("HPBar3D")
		if hp_bar.has_method("setup_for_unit"):
			# Call deferred to ensure unit scale is fully applied
			call_deferred("_setup_hp_bar", hp_bar)

# Internal helper to setup HP bar after unit is fully initialized
func _setup_hp_bar(hp_bar):
	if hp_bar and hp_bar.has_method("setup_for_unit"):
		hp_bar.setup_for_unit(self)

# Initialize unit stats from UnitClass
func _initialize_from_class():
	if not unit_class:
		# No class assigned - use defaults (backward compatibility)
		return
	
	# Initialize all stats from class
	max_health = unit_class.base_hp
	current_health = max_health  # Full HP on initialization
	movement_range = unit_class.base_movement
	attack_range = unit_class.attack_range_max  # For backward compatibility
	str = unit_class.base_str
	mag = unit_class.base_mag
	skill = unit_class.base_skill
	spd = unit_class.base_spd
	luck = unit_class.base_luck
	def = unit_class.base_def
	res = unit_class.base_res
	
	print("Unit ", unit_name, " initialized from class ", unit_class.class_name)
	print("  Stats: HP=", max_health, " Str=", str, " Mag=", mag, " Skill=", skill, 
		  " Spd=", spd, " Luck=", luck, " Def=", def, " Res=", res)
	print("  Movement: ", movement_range, " Attack Range: ", get_attack_range_min(), "-", get_attack_range_max())

func update_position_visual():
	_update_world_position(grid_position, GROUND_OFFSET)

# Internal helper to update world position from grid position
func _update_world_position(grid_pos: Vector2i, offset: float = GROUND_OFFSET):
	if not GridManager:
		push_error("Unit: GridManager not available!")
		return
	
	if not GridManager.is_within_grid(grid_pos):
		push_error("Unit: Invalid grid position: ", grid_pos)
		return
	
	var world_pos = GridManager.grid_to_world_3d(grid_pos)
	world_pos.y += offset
	position = world_pos

func set_grid_position(new_pos: Vector2i):
	# Validate grid position
	if not GridManager or not GridManager.is_within_grid(new_pos):
		push_error("Unit: Cannot set invalid grid position: ", new_pos)
		return
	
	var old_position = grid_position
	grid_position = new_pos
	
	# Update visual position using helper
	_update_world_position(new_pos, GROUND_OFFSET)
	
	unit_moved.emit(old_position, new_pos)

func select():
	selection_indicator.visible = true
	
	# Rotation animation
	var rotate_tween = create_tween()
	rotate_tween.set_loops()
	rotate_tween.set_trans(Tween.TRANS_LINEAR)
	rotate_tween.tween_property(selection_indicator, "rotation_degrees:y", 360, 2.0)
	
	# Pulsing scale animation
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(selection_indicator, "scale", Vector3(1.3, 1.3, 1.3), 0.8)
	pulse_tween.tween_property(selection_indicator, "scale", Vector3(1.2, 1.2, 1.2), 0.8)
	
	# Show HP bar when unit is selected
	if has_node("HPBar3D"):
		var hp_bar = get_node("HPBar3D")
		if hp_bar and hp_bar.has_method("show_hp_bar"):
			hp_bar.show_hp_bar()
	unit_selected.emit(self)

func deselect():
	selection_indicator.visible = false
	selection_indicator.rotation_degrees.y = 0  # Reset rotation
	selection_indicator.scale = Vector3(1.2, 1.2, 1.2)  # Reset scale
	# Hide HP bar when unit is deselected
	if has_node("HPBar3D"):
		var hp_bar = get_node("HPBar3D")
		if hp_bar and hp_bar.has_method("hide_hp_bar"):
			hp_bar.hide_hp_bar()
	unit_deselected.emit(self)

func is_within_move_range(target_pos: Vector2i) -> bool:
	var distance = abs(target_pos.x - grid_position.x) + abs(target_pos.y - grid_position.y)
	return distance <= movement_range

func get_movement_cost_to(target_pos: Vector2i) -> int:
	return 1

func reset_turn_state():
	has_acted = false
	has_moved = false
	selection_indicator.visible = false
	# Hide HP bar when turn resets
	if has_node("HPBar3D"):
		var hp_bar = get_node("HPBar3D")
		if hp_bar and hp_bar.has_method("hide_hp_bar"):
			hp_bar.hide_hp_bar()

## Mark unit as having moved this turn
func mark_as_moved():
	has_moved = true

## Mark unit as having acted this turn
func mark_as_acted():
	has_acted = true

## Apply damage to this unit with visual feedback
##
## @param amount: Amount of damage to apply
func take_damage(amount: int):
	var old_health = current_health
	current_health -= amount
	current_health = max(0, current_health)
	_update_hp_bar()
	
	# Visual feedback for damage
	_show_damage_number(amount, false, false)
	_play_hit_effect()
	
	SignalBus.unit_health_changed.emit(self, old_health, current_health)
	
	if current_health <= 0:
		SignalBus.unit_died.emit(self)

## Take damage with visual feedback parameters.
## @param amount: Damage amount
## @param is_crit: Whether this was a critical hit
## @param is_miss: Whether the attack missed (for custom handling)
func take_damage_with_feedback(amount: int, is_crit: bool, is_miss: bool):
	var old_health = current_health
	current_health -= amount
	current_health = max(0, current_health)
	_update_hp_bar()
	
	# Visual feedback with crit info
	_show_damage_number(amount, is_crit, is_miss)
	if not is_miss:
		_play_hit_effect()
	
	SignalBus.unit_health_changed.emit(self, old_health, current_health)
	
	if current_health <= 0:
		SignalBus.unit_died.emit(self)

## Show miss visual effect
func show_miss():
	_show_damage_number(0, false, true)

func heal(amount: int):
	var old_health = current_health
	current_health += amount
	current_health = min(max_health, current_health)
	_update_hp_bar()
	
	# Visual feedback for healing (negative damage = healing)
	_show_damage_number(-amount, false, false)
	
	SignalBus.unit_health_changed.emit(self, old_health, current_health)

# Show floating damage number
func _show_damage_number(damage: int, is_crit: bool, is_miss: bool):
	# Load damage number script
	var damage_number_script = preload("res://scripts/UI/damage_number_3d.gd")
	var damage_label = Label3D.new()
	damage_label.set_script(damage_number_script)
	
	# Position above unit
	damage_label.position = position + Vector3(0, 2.0, 0)
	
	# Add to scene
	get_parent().add_child(damage_label)
	
	# Show damage with animation
	if damage_label.has_method("show_damage"):
		damage_label.show_damage(damage, is_crit, is_miss)

# Play hit flash effect
func _play_hit_effect():
	if not sprite:
		return
	
	# Flash white briefly
	var hit_tween = create_tween()
	hit_tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	
	# Shake effect
	var original_pos = position
	var shake_tween = create_tween()
	shake_tween.tween_property(self, "position", original_pos + Vector3(0.1, 0, 0), 0.03)
	shake_tween.tween_property(self, "position", original_pos + Vector3(-0.1, 0, 0), 0.03)
	shake_tween.tween_property(self, "position", original_pos + Vector3(0.1, 0, 0), 0.03)
	shake_tween.tween_property(self, "position", original_pos, 0.03)

# Internal helper to update HP bar display
func _update_hp_bar():
	if has_node("HPBar3D"):
		var hp_bar = get_node("HPBar3D")
		if hp_bar and hp_bar.has_method("update_hp_display"):
			hp_bar.update_hp_display(current_health, max_health)

func is_alive() -> bool:
	return current_health > 0

func is_at_position(check_pos: Vector2i) -> bool:
	return grid_position == check_pos

# Helper methods for UnitClass properties
func get_attack_range_min() -> int:
	if unit_class:
		return unit_class.attack_range_min
	return 1  # Default to melee range

func get_attack_range_max() -> int:
	if unit_class:
		return unit_class.attack_range_max
	return attack_range  # Fallback to existing attack_range

func get_damage_type() -> int:
	# Returns damage type enum value (0 = PHYSICAL, 1 = MAGIC)
	if unit_class and "damage_type" in unit_class:
		return unit_class.damage_type
	# Default to PHYSICAL (0)
	return 0

func move_along_path(path_cells: Array):
	# Check if already moving
	if is_moving:
		push_warning("Unit: Attempted to move while already moving")
		return
	
	# Check if path is valid for movement
	if path_cells.size() <= 1:
		# Already at destination or invalid path
		# CRITICAL FIX: Must emit signal so awaiters don't hang
		movement_finished.emit()
		return
	
	is_moving = true
	
	current_movement_tween = create_tween()
	current_movement_tween.set_trans(Tween.TRANS_SINE)
	current_movement_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Convert grid path to 3D world positions
	var world_positions = []
	for i in range(1, path_cells.size()):
		if not GridManager or not GridManager.is_within_grid(path_cells[i]):
			push_error("Unit: Invalid path cell: ", path_cells[i])
			continue
		var world_pos = GridManager.grid_to_world_3d(path_cells[i])
		world_pos.y += MOVEMENT_OFFSET  # Lift unit above grid during movement
		world_positions.append(world_pos)
	
	# Animate through 3D positions
	for i in range(world_positions.size()):
		var duration = 0.2  # Constant time per tile
		current_movement_tween.tween_property(self, "position", world_positions[i], duration)
	
	# Add callback after all movement is complete
	current_movement_tween.tween_callback(func():
		if world_positions.size() > 0:
			position = world_positions[world_positions.size() - 1]
		set_grid_position(path_cells[path_cells.size() - 1])
		is_moving = false
		movement_finished.emit()
	)
