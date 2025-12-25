class_name Unit
extends Node3D

## Unit - Represents a tactical unit on the grid (Refactored Phase 4)
##
## Acts as a Facade for:
## - HealthComponent: HP, damage, death
## - MovementComponent: Pathfinding, movement animation
## - VisualComponent: Sprites, selection, effects

# --- Components ---
var health_component: HealthComponent
var movement_component: MovementComponent
var visual_component: VisualComponent
var inventory: Inventory

# --- Global State ---
var game_state: GameStateManager = null 

# --- Properties ---
var character: CharacterData
var unit_name: String = "Unit"

var team: int = 0
var portrait: Texture2D
var level: int = 1
var exp: int = 0
var grid_position: Vector2i = Vector2i(0, 0)
# Note: inventory is already declared as a component, removing duplicate here
# Note: unit_name is already declared above, removing duplicate here

# Stats (Data kept on Unit for now, easy access for Solos/Duos)
# Note: HP is delegated to HealthComponent via proxies
var strength: int = 0
var mag: int = 0
var skill: int = 0
var spd: int = 0
var luck: int = 0
var def: int = 0
var res: int = 0

# Range / Movement Configuration
var movement_range: int = 4
var attack_range: int = 1

# State Flags
@export var has_acted: bool = false
@export var has_moved: bool = false
@export var unit_class: Resource = null
var status_effects: Dictionary[String, bool] = {}

# --- Signals (Re-emitted from components for compatibility) ---
signal unit_selected(unit)
signal unit_deselected(unit)
signal unit_moved(from_pos, to_pos)
signal movement_finished()

# --- Internal Storage for properties set before components ready ---
var _initial_max_hp: int = 10
var _initial_current_hp: int = 10

# --- Getters / Setters Proxy ---
var max_health: int:
	get:
		if health_component: return health_component.max_health
		return _initial_max_hp
	set(value):
		_initial_max_hp = value
		if health_component: health_component.max_health = value

var current_health: int:
	get:
		if health_component: return health_component.current_health
		return _initial_current_hp
	set(value):
		_initial_current_hp = value
		if health_component: health_component.current_health = value

var is_moving: bool:
	get:
		return movement_component.is_moving() if movement_component else false
	set(value):
		pass # Read-only relative to component

# Backward compatibility for subclasses accessing sprite directly
var sprite: Sprite3D:
	get:
		return visual_component._sprite if visual_component else null

var selection_indicator: Node3D:
	get:
		return visual_component._selection_indicator if visual_component else null

# --- Constants ---
# GROUND_OFFSET now in GameConfig.visual.ground_offset

func _init() -> void:
	# Components instantiated here but added in _ready to ensure tree access
	health_component = HealthComponent.new()
	movement_component = MovementComponent.new()
	visual_component = VisualComponent.new()
	inventory = Inventory.new()

func _ready() -> void:
	# Add Components
	health_component.name = "HealthComponent"
	add_child(health_component)
	
	movement_component.name = "MovementComponent"
	add_child(movement_component)
	
	visual_component.name = "VisualComponent"
	add_child(visual_component)
	
	inventory.name = "Inventory"
	add_child(inventory)
	
	# Dependencies are injected via set_dependencies() or UnitManager
	
	# Setup Components
	health_component.initialize(_initial_max_hp)

	health_component.current_health = _initial_current_hp # Sync if set before ready
	movement_component.setup(self)
	visual_component.setup(self)
	
	# Connect Signals
	_connect_component_signals()
	
	# Validate GridManager
	if not GridManager:
		push_error("Unit: GridManager not available!")
		return
		
	reset_turn_state()
	_initialize_from_class()
	
	# Apply initial position
	var offset: float = GameConfig.unit.get("ground_offset", 0.0)
	print("=== UNIT SPAWN: ", unit_name, " (Team ", team, ") ===")
	print("  Grid position: ", grid_position)
	print("  Ground offset: ", offset)
	_update_world_position(grid_position, offset)
	print("  Final world pos: ", global_position)
	
	# Scale
	scale = GridManager.get_unit_scale()
	print("  Scale: ", scale)
	print("Unit initialized (Component Architecture): ", unit_name)
	
	# Visibility: Hide player units initially (they appear during deployment)
	if team == 0: # TEAM_PLAYER
		visible = false
		print("  Unit hidden (Player team waiting for deployment)")
	
	# Visual Setup (Subclass hook)
	if has_meta("is_duo"):
		setup_visual(3.0, team == 0)
	elif has_meta("is_solo"):
		setup_visual(2.0, team == 0)

func _connect_component_signals() -> void:
	# Visuals react to Health
	health_component.damaged.connect(func(_amt): visual_component.play_hit_effect())
	health_component.health_changed.connect(func(cur, old, max_hp): 
		visual_component.update_hp_bar(cur, max_hp)
		SignalBus.unit_health_changed.emit(self, old, cur)
	)
	health_component.died.connect(func(): SignalBus.unit_died.emit(self))
	
	# Movement
	movement_component.movement_finished.connect(func(): movement_finished.emit())


## Set required dependencies
## @param game_state_node: GameStateManager instance
func set_dependencies(_game_state_node: Node) -> void:
	# Get GameStateManager singleton
	game_state = get_node("/root/GlobalGameState")


# --- Core API (Facade) ---

func setup_visual(unit_scale: float, is_player: bool) -> void:
	if visual_component:
		visual_component.set_scale(unit_scale)
		visual_component.set_team_color(is_player)

func select() -> void:
	if visual_component: visual_component.on_selected()
	unit_selected.emit(self)

func deselect() -> void:
	if visual_component: visual_component.on_deselected()
	unit_deselected.emit(self)

func take_damage(amount: int) -> void:
	health_component.take_damage(amount)

func take_damage_with_feedback(amount: int, is_crit: bool, is_miss: bool) -> void:
	# Complex damage feedback is slightly harder to componentize perfectly without refactoring UI calls
	# For now, we manually handle the popup here or move it to VisualComponent
	health_component.take_damage(amount)
	_show_damage_number(amount, is_crit, is_miss)

func heal(amount: int) -> void:
	health_component.heal(amount)
	_show_damage_number(-amount, false, false)

func move_along_path(path_cells: Array[Vector2i]) -> void:
	movement_component.move_along_path(path_cells)

## Use a consumable item
## @return: true if used successfully
func use_item(item: Consumable) -> bool:
	if not item in inventory.get_consumables():
		return false
		
	if not item.can_use_on(self):
		return false
		
	# Apply Effect
	match item.effect_type:
		Consumable.EffectType.HEAL:
			heal(item.power)
			# TODO: Play sound/visual
			
		Consumable.EffectType.BOOST_STAT:
			# Placeholder for stat boosting
			# self.add_stat_modifier(item.stat_type, item.power)
			pass
			
	# Update durability
	item.uses -= 1
	if item.uses <= 0:
		inventory.remove_item(item)
		
	return true


func is_alive() -> bool:
	return health_component.is_alive() if health_component else current_health > 0

func set_grid_position(new_pos: Vector2i) -> void:
	var old = grid_position
	grid_position = new_pos
	# Using local offset if we wanted, or fetch from config.
	# For performance, might cache this, but dictionary lookup is fast enough for turn-based.
	var offset: float = GameConfig.unit.get("ground_offset", 0.0)
	_update_world_position(new_pos, offset)
	unit_moved.emit(old, new_pos)

func mark_as_acted() -> void:
	has_acted = true

func mark_as_moved() -> void:
	has_moved = true

func reset_turn_state() -> void:
	has_acted = false
	has_moved = false
	if visual_component: visual_component.on_deselected()

# --- Legacy/Helper Methods ---

func _initialize_from_class() -> void:
	if not unit_class: return
	
	max_health = unit_class.base_hp
	current_health = max_health
	movement_range = unit_class.base_movement
	# ... sync other stats ...
	strength = unit_class.base_str
	mag = unit_class.base_mag
	skill = unit_class.base_skill
	spd = unit_class.base_spd
	luck = unit_class.base_luck
	def = unit_class.base_def
	res = unit_class.base_res

## Update unit's world position from grid coordinates.
##
## *** UNIT POSITIONING LAYER 2 of 3: GAMEPLAY SPACE ***
## Adds optional offset to GridManager's base position for gameplay purposes.
## Examples: hover effect, prevent Z-fighting, flying units, etc.
## Currently set to 0.0 for units to sit exactly on ground.
##
## @param grid_pos: Target grid position
## @param offset: Additional Y offset (from GameConfig.unit.ground_offset)
func _update_world_position(grid_pos: Vector2i, offset: float) -> void:
	if GridManager and GridManager.is_within_grid(grid_pos):
		var pos = GridManager.grid_to_world_3d(grid_pos)
		pos.y += offset
		position = pos
		print("  _update_world_position: grid(%d,%d) + offset %.2f → world (%.2f, %.2f, %.2f)" % [
			grid_pos.x, grid_pos.y, offset, pos.x, pos.y, pos.z
		])

const DAMAGE_NUMBER_SCRIPT = preload("res://scripts/UI/damage_number_3d.gd")

func _show_damage_number(amount: int, is_crit: bool, is_miss: bool) -> void:
	var damage_label = Label3D.new()
	damage_label.set_script(DAMAGE_NUMBER_SCRIPT)
	# Position lower - 0.2 units above sprite
	damage_label.position = position + Vector3(0, 0.2, 0)
	# Make 1.5x bigger (default pixel_size is ~0.004)
	damage_label.pixel_size = 0.006
	get_parent().add_child(damage_label)
	if damage_label.has_method("show_damage"):
		damage_label.show_damage(amount, is_crit, is_miss)

# Compatibility Getters
func get_attack_range_min() -> int: return unit_class.attack_range_min if unit_class else 1
func get_attack_range_max() -> int: return unit_class.attack_range_max if unit_class else attack_range
func get_damage_type() -> int: return unit_class.damage_type if unit_class else 0
func is_at_position(pos: Vector2i) -> bool: return grid_position == pos
