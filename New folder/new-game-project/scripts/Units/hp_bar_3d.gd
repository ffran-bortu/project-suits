# hp_bar_3d.gd - Simple HP bar using Sprite3D (Following instructions2.txt)
extends Node3D

# Get references to the Sprite3D nodes
@onready var hp_foreground: Sprite3D = $HPBar
@onready var hp_background: Sprite3D = $HPBarBackground

# Health bar settings
var full_width: float = 200.0  # This is the SCALE value, not world units!
var unit_reference = null

func _ready():
	# Validate sprite nodes exist
	if not has_node("HPBar"):
		push_error("HPBar3D: HPBar node not found!")
		return
	if not has_node("HPBarBackground"):
		push_error("HPBar3D: HPBarBackground node not found!")
		return
	
	# Get sprite references
	hp_foreground = $HPBar
	hp_background = $HPBarBackground
	
	# Create a simple white texture for the bars
	var image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(image)
	
	# Set textures
	if hp_foreground:
		hp_foreground.texture = texture
	if hp_background:
		hp_background.texture = texture
	
	# Set colors
	if hp_background:
		hp_background.modulate = Color(0.2, 0.2, 0.2)  # Dark grey background
	if hp_foreground:
		hp_foreground.modulate = Color(0, 1, 0)        # Green foreground
	
	# Start hidden
	visible = false

func setup_for_unit(unit_node):
	if not unit_node:
		return
	
	# Store reference to unit
	unit_reference = unit_node
	
	# Position above the unit (adjust based on unit scale if needed)
	if GridManager:
		var unit_scale = GridManager.get_unit_scale()
		position.y = unit_scale.y * 1.2  # Adjust this value as needed
	else:
		position.y = 1.0  # Default height
	
	# Set the scale for both bars
	# With pixel_size = 0.01, scale.x of 200 = 2.0 world units width
	full_width = 200.0  # This is the SCALE value, not world units!
	
	if hp_background:
		hp_background.scale.x = full_width
		hp_background.scale.y = 20.0  # Height scale
		hp_background.scale.z = 1.0
	
	if hp_foreground:
		hp_foreground.scale.x = full_width
		hp_foreground.scale.y = 20.0  # Height scale
		hp_foreground.scale.z = 1.0
	
	# Keep them centered initially
	if hp_background:
		hp_background.position = Vector3.ZERO
	if hp_foreground:
		hp_foreground.position = Vector3(0.0, 0.0, 0.01)  # Slightly in front for z-ordering
	
	# Update the display
	if "current_health" in unit_node and "max_health" in unit_node:
		update_hp_display(unit_node.current_health, unit_node.max_health)
	
	# Start hidden - will be shown when unit is selected
	visible = false

func update_hp_display(current_hp: int, max_hp: int):
	if max_hp <= 0:
		return
	
	if not hp_foreground or not hp_background:
		return
	
	# Ensure background is at the correct position (our reference point)
	hp_background.position = Vector3.ZERO
	
	# Calculate health percentage (0.0 to 1.0)
	var health_percent = float(current_hp) / float(max_hp)
	health_percent = clamp(health_percent, 0.0, 1.0)
	
	# Get background's actual scale (our reference)
	var background_scale_x = hp_background.scale.x
	var pixel_size = hp_background.pixel_size
	
	# Calculate actual world sizes
	var background_world_width = background_scale_x * pixel_size
	var foreground_world_width = background_world_width * health_percent
	
	# Calculate background's left edge in local space (background is centered at 0)
	var background_left_edge = -background_world_width / 2.0
	
	# Position foreground so its left edge aligns with background's left edge
	# Foreground center = background_left_edge + foreground_world_width / 2.0
	hp_foreground.position.x = background_left_edge + foreground_world_width / 2.0
	hp_foreground.position.z = 0.01  # Keep in front for z-ordering
	
	# Update foreground scale to match health percentage
	hp_foreground.scale.x = background_scale_x * health_percent
	hp_foreground.scale.y = hp_background.scale.y  # Keep same height
	hp_foreground.scale.z = hp_background.scale.z   # Keep same depth
	
	# Change color based on health
	if health_percent > 0.6:
		hp_foreground.modulate = Color(0, 1, 0)      # Green
	elif health_percent > 0.3:
		hp_foreground.modulate = Color(1, 1, 0)      # Yellow
	else:
		hp_foreground.modulate = Color(1, 0, 0)      # Red
	
	# Ensure fully opaque
	hp_foreground.modulate.a = 1.0

func show_hp_bar():
	visible = true
	if unit_reference and "current_health" in unit_reference and "max_health" in unit_reference:
		# Reset background position (always centered)
		if hp_background:
			hp_background.position = Vector3.ZERO
			hp_background.visible = true
		
		# Update display (this will set foreground position correctly)
		update_hp_display(unit_reference.current_health, unit_reference.max_health)
		
		# Make sure foreground is visible
		if hp_foreground:
			hp_foreground.visible = true

func hide_hp_bar():
	visible = false
	if hp_foreground:
		hp_foreground.visible = false
	if hp_background:
		hp_background.visible = false
