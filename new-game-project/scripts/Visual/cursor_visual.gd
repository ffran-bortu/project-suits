"""
FILE: cursor_visual.gd
PURPOSE: Provides enhanced 3D visual representation of the tactical cursor with state-based animations and effects.

OVERVIEW:
This class renders the cursor with animated mesh and selection ring, using different colors and animations
for various states (normal, hover over unit/enemy, selected, invalid target, etc.). Continuous bob and
rotation animations run in normal state, while specific state transitions trigger pulsing, flashing, or
other visual feedback. All colors sync with GameConfig for consistent theming.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Sets up materials, meshes, and default cursor state
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. _setup_materials() -> void
   - What it does: Creates and configures StandardMaterial3D instances for cursor mesh and selection ring
   - Uses: Called during initialization to prepare rendering materials
   - Returns: void

3. _setup_meshes() -> void
   - What it does: Creates BoxMesh for cursor and TorusMesh for selection ring, adds as children
   - Uses: Called during initialization to build 3D geometry
   - Returns: void

4. _process(delta: float) -> void
   - What it does: Updates animation_time and calls _update_animations each frame
   - Uses: Called every frame by engine
   - Returns: void

5. _update_animations(delta: float) -> void
   - What it does: Applies continuous bob and rotation based on current state
   - Uses: Called from _process to animate cursor meshes
   - Returns: void

6. set_state(new_state: CursorState) -> void
   - What it does: Changes cursor state, updates visuals, and triggers state-specific animation
   - Uses: Called when cursor context changes (hovering unit, selecting, etc.)
   - Returns: void

7. _update_visuals() -> void
   - What it does: Sets colors and visibility based on current cursor state
   - Uses: Called by set_state to apply state-specific appearance
   - Returns: void

8. _set_colors(color: Color, show_ring: bool) -> void
   - What it does: Applies specified color to mesh material and shows/hides selection ring
   - Uses: Helper called by _update_visuals for different states
   - Returns: void

9. _play_state_animation() -> void
   - What it does: Triggers animation specific to current state (selection pulse, invalid shake, etc.)
   - Uses: Called by set_state when state changes
   - Returns: void

10. _play_selection_animation() -> void
    - What it does: Scales cursor with quick pulse tween when selected
    - Uses: Called for SELECTED state transition
    - Returns: void

11. _play_invalid_animation() -> void
    - What it does: Plays failure animation or idle fallback for invalid targets
    - Uses: Called for INVALID_TARGET state transition
    - Returns: void

12. update_from_hover(unit: Node) -> void
    - What it does: Sets cursor state based on hovered unit (friendly, enemy, or none)
    - Uses: Called when cursor moves over different grid cells
    - Returns: void

13. flash(color: Color, duration: float = 0.3) -> void
    - What it does: Temporarily changes cursor color with emission, then fades back to original
    - Uses: Called to provide quick visual feedback for events
    - Returns: void

14. hide_cursor() -> void
    - What it does: Fades cursor out and hides it with tween animation
    - Uses: Called when cursor should not be visible
    - Returns: void

15. show_cursor() -> void
    - What it does: Shows cursor and fades it in with tween animation
    - Uses: Called to restore cursor visibility
    - Returns: void

16. get_current_state() -> CursorState
    - What it does: Returns the current cursor state enum value
    - Uses: Query method for external systems
    - Returns: CursorState - current state

17. get_debug_summary() -> String
    - What it does: Returns formatted string with cursor state, position, visibility, and hovered unit info
    - Uses: Debugging and logging
    - Returns: String - debug information

18. debug_print() -> void
    - What it does: Prints debug summary to console
    - Uses: Called for debugging cursor state
    - Returns: void

NOTES:
- Depends on GameConfig for color palette (cursor_base, cursor_friendly, cursor_enemy, etc.)
- Uses CursorState enum: NORMAL, HOVER_UNIT, HOVER_ENEMY, SELECTED, ACTION_SELECT, ATTACK_TARGETING, INVALID_TARGET
- STATE_NAMES dictionary maps enum values to readable strings for debugging
- Bob height: 0.1 units, Bob speed: 2.0, Rotation speed: 30°/s, Pulse speed: 2.0
- Selection ring is TorusMesh with 0.6 inner/0.8 outer radius, rotated 90° to lie flat
- Materials use unshaded mode for consistent appearance
- All tweens stored in active_tween variable and killed before starting new ones
- Animations use various Tween transitions (CUBIC, ELASTIC, BOUNCE) for different effects
"""

# cursor_visual.gd - Enhanced 3D cursor with animations and state-based visuals
extends Node3D
class_name CursorVisual

## Visual representation of tactical cursor with animations and effects

# --- Cursor State Enum ---
enum CursorState {
	NORMAL = 0,          # Default state
	HOVER_UNIT = 1,      # Hovering over friendly unit
	HOVER_ENEMY = 2,     # Hovering over enemy unit
	VALID_TARGET = 3,    # Valid attack/action target
	INVALID_TARGET = 4,  # Invalid target
	SELECTED = 5,        # Selection confirmed
	MOVING = 6,          # Unit moving
	ATTACKING = 7        # Combat targeting
}

const STATE_NAMES: Dictionary = {
	CursorState.NORMAL: "Normal",
	CursorState.HOVER_UNIT: "Hover Unit",
	CursorState.HOVER_ENEMY: "Hover Enemy",
	CursorState.VALID_TARGET: "Valid Target",
	CursorState.INVALID_TARGET: "Invalid Target",
	CursorState.SELECTED: "Selected",
	CursorState.MOVING: "Moving",
	CursorState.ATTACKING: "Attacking"
}

# --- Components ---
@onready var cursor_mesh: MeshInstance3D = $CursorMesh
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Materials ---
var mesh_material: StandardMaterial3D
var ring_material: StandardMaterial3D

# --- State ---
var current_state: CursorState = CursorState.NORMAL
var hovered_unit: Node = null

# --- Animation Properties ---
var bob_height: float = 0.1
var bob_speed: float = 2.0
var rotation_speed: float = 30.0
var pulse_speed: float = 2.0
var animation_time: float = 0.0

# --- Active Tweens ---
var active_tween: Tween = null


func _ready() -> void:
	_setup_materials()
	_setup_meshes()
	set_state(CursorState.NORMAL)


## Setup cursor materials
func _setup_materials() -> void:
	mesh_material = StandardMaterial3D.new()
	mesh_material.albedo_color = GameConfig.get_color("cursor_base")
	mesh_material.emission_enabled = true
	mesh_material.emission = GameConfig.get_color("cursor_base") * 0.3
	mesh_material.metallic = 0.0
	mesh_material.roughness = 0.2
	
	ring_material = StandardMaterial3D.new()
	ring_material.albedo_color = Color.WHITE
	ring_material.emission_enabled = true
	ring_material.emission = Color.WHITE * 0.2
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	if cursor_mesh:
		cursor_mesh.material_override = mesh_material
	if selection_ring:
		selection_ring.material_override = ring_material
		selection_ring.visible = false


## Setup mesh geometries
func _setup_meshes() -> void:
	if not cursor_mesh:
		cursor_mesh = MeshInstance3D.new()
		cursor_mesh.name = "CursorMesh"
		cursor_mesh.mesh = BoxMesh.new()
		cursor_mesh.mesh.size = Vector3(0.5, 0.2, 0.5)
		add_child(cursor_mesh)
	
	if not selection_ring:
		selection_ring = MeshInstance3D.new()
		selection_ring.name = "SelectionRing"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.3
		torus.outer_radius = 0.4
		selection_ring.mesh = torus
		selection_ring.rotation_degrees.x = 90
		add_child(selection_ring)


func _process(delta: float) -> void:
	animation_time += delta
	_update_animations(delta)


## Update continuous animations
## @param delta: Frame delta time
func _update_animations(delta: float) -> void:
	match current_state:
		CursorState.NORMAL, CursorState.HOVER_UNIT:
			# Gentle bobbing
			if cursor_mesh:
				var bob_offset := sin(animation_time * bob_speed) * bob_height
				cursor_mesh.position.y = bob_offset
				cursor_mesh.rotation.y += deg_to_rad(rotation_speed) * delta
		
		CursorState.HOVER_ENEMY, CursorState.VALID_TARGET:
			# Aggressive pulsing
			if cursor_mesh:
				var pulse := 1.0 + sin(animation_time * pulse_speed) * 0.2
				cursor_mesh.scale = Vector3.ONE * pulse
		
		CursorState.MOVING:
			# Fast rotation
			if cursor_mesh:
				cursor_mesh.rotation.y += deg_to_rad(rotation_speed * 3.0) * delta
	
	# Ring rotation (always)
	if selection_ring and selection_ring.visible:
		selection_ring.rotation.y += deg_to_rad(45.0) * delta


## Set cursor state
## @param new_state: Target state
func set_state(new_state: CursorState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	_update_visuals()
	_play_state_animation()
	
	# DebugLog.log("CursorVisual: State changed to %s" % STATE_NAMES[current_state])


## Update visual appearance based on state
func _update_visuals() -> void:
	match current_state:
		CursorState.NORMAL:
			_set_colors(GameConfig.get_color("cursor_base"), false)
		
		CursorState.HOVER_UNIT:
			_set_colors(Color.GREEN, true)
		
		CursorState.HOVER_ENEMY:
			_set_colors(Color.RED, true)
		
		CursorState.VALID_TARGET:
			_set_colors(Color.YELLOW, true)
		
		CursorState.INVALID_TARGET:
			_set_colors(Color.GRAY, false)
		
		CursorState.SELECTED:
			_set_colors(Color.CYAN, true)
		
		CursorState.MOVING:
			_set_colors(Color.LIGHT_BLUE, true)
		
		CursorState.ATTACKING:
			_set_colors(Color.ORANGE_RED, true)


## Set cursor colors
## @param color: Base color
## @param show_ring: Whether to show selection ring
func _set_colors(color: Color, show_ring: bool) -> void:
	if mesh_material:
		mesh_material.albedo_color = color
		mesh_material.emission = color * 0.3
	
	if selection_ring:
		selection_ring.visible = show_ring
		if show_ring and ring_material:
			ring_material.albedo_color = color


## Play animation for current state
func _play_state_animation() -> void:
	if not animation_player:
		return
	
	match current_state:
		CursorState.SELECTED:
			_play_selection_animation()
		CursorState.INVALID_TARGET:
			_play_invalid_animation()
		_:
			if animation_player.has_animation("cursor_idle"):
				animation_player.play("cursor_idle")


## Play selection animation
func _play_selection_animation() -> void:
	# Kill old tween
	if active_tween:
		active_tween.kill()
	
	# Scale pulse
	active_tween = create_tween()
	active_tween.tween_property(cursor_mesh, "scale", Vector3.ONE * 1.5, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(cursor_mesh, "scale", Vector3.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Play invalid target animation
func _play_invalid_animation() -> void:
	# Kill old tween
	if active_tween:
		active_tween.kill()
	
	# Shake effect
	var original_pos := cursor_mesh.position
	active_tween = create_tween()
	
	for i in range(3):
		active_tween.tween_property(cursor_mesh, "position:x", original_pos.x + 0.1, 0.05)
		active_tween.tween_property(cursor_mesh, "position:x", original_pos.x - 0.1, 0.05)
	
	active_tween.tween_property(cursor_mesh, "position", original_pos, 0.05)


## Set hovered unit
## @param unit: Unit being hovered
func set_hovered_unit(unit: Node) -> void:
	hovered_unit = unit
	
	if unit:
		if unit.is_in_group("player"):
			set_state(CursorState.HOVER_UNIT)
		elif unit.is_in_group("enemy"):
			set_state(CursorState.HOVER_ENEMY)
	else:
		set_state(CursorState.NORMAL)


## Flash cursor with color
## @param color: Flash color
## @param duration: Flash duration
func flash(color: Color, duration: float = 0.3) -> void:
	# Kill old tween
	if active_tween:
		active_tween.kill()
	
	var original_color := mesh_material.albedo_color
	var original_emission := mesh_material.emission
	
	active_tween = create_tween()
	active_tween.tween_property(mesh_material, "albedo_color", color, duration * 0.5)
	active_tween.parallel().tween_property(mesh_material, "emission", color * 0.7, duration * 0.5)
	active_tween.tween_property(mesh_material, "albedo_color", original_color, duration * 0.5)
	active_tween.parallel().tween_property(mesh_material, "emission", original_emission, duration * 0.5)


## Show cursor
func show_cursor() -> void:
	# Kill old tween
	if active_tween:
		active_tween.kill()
	
	visible = true
	active_tween = create_tween()
	active_tween.tween_property(self, "scale", Vector3.ONE, 0.3)\
		.from(Vector3.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Hide cursor
func hide_cursor() -> void:
	# Kill old tween
	if active_tween:
		active_tween.kill()
	
	active_tween = create_tween()
	active_tween.tween_property(self, "scale", Vector3.ZERO, 0.3)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await active_tween.finished
	visible = false


## Get current state
## @return: Current CursorState
func get_current_state() -> CursorState:
	return current_state


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Cursor Visual ===\n"
	summary += "State: %s\n" % STATE_NAMES[current_state]
	summary += "Position: (%.1f, %.1f, %.1f)\n" % [global_position.x, global_position.y, global_position.z]
	summary += "Visible: %s\n" % visible
	if hovered_unit:
		summary += "Hovered: %s\n" % hovered_unit.name
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
