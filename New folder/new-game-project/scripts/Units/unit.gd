# unit.gd - 3D version
extends Node3D

# Preload UnitClass to ensure it's recognized
const UnitClassScript = preload("res://scripts/Resources/unit_class.gd")

signal unit_selected(unit)
signal unit_deselected(unit)
signal unit_moved(from_pos, to_pos)
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
# Using the preloaded script type
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
	print("  Movement: ", movement_range, " Attack Range: ", attack_range_min(), "-", attack_range_max())

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
	# Show HP bar when unit is selected
	if has_node("HPBar3D"):
		var hp_bar = get_node("HPBar3D")
		if hp_bar and hp_bar.has_method("show_hp_bar"):
			hp_bar.show_hp_bar()
	unit_selected.emit(self)

func deselect():
	selection_indicator.visible = false
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

func mark_as_moved():
	has_moved = true

func mark_as_acted():
	has_acted = true

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	_update_hp_bar()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	_update_hp_bar()

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
	if is_moving:
		return
	
	if path_cells.size() <= 1:
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
