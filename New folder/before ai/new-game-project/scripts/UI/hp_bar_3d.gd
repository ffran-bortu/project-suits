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
		push_error("HPBar3D: HPBar node not found! Check scene structure.")
		return
	if not has_node("HPBarBackground"):
		push_error("HPBar3D: HPBarBackground node not found! Check scene structure.")
		return
	
	# Get sprite references
	hp_foreground = $HPBar
	hp_background = $HPBarBackground
	
	# Validate nodes are actually Sprite3D
	if not hp_foreground is Sprite3D:
		push_error("HPBar3D: HPBar node is not a Sprite3D!")
		return
	if not hp_background is Sprite3D:
		push_error("HPBar3D: HPBarBackground node is not a Sprite3D!")
		return
	
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
	
	# Target position and scale
	var target_pos_x = background_left_edge + foreground_world_width / 2.0
	var target_scale_x = background_scale_x * health_percent
	
	# Smooth HP transitions using tweens
	var hp_tween = create_tween()
	hp_tween.set_parallel(true)  # Run position and scale changes simultaneously
	hp_tween.set_trans(Tween.TRANS_CUBIC)
	hp_tween.set_ease(Tween.EASE_OUT)
	
	# Tween position
	hp_tween.tween_property(hp_foreground, "position:x", target_pos_x, 0.3)
	
	# Tween scale
	hp_tween.tween_property(hp_foreground, "scale:x", target_scale_x, 0.3)
	
	# Keep same height and depth
	hp_foreground.position.z = 0.01  # Keep in front for z-ordering
	hp_foreground.scale.y = hp_background.scale.y
	hp_foreground.scale.z = hp_background.scale.z
	
	# Change color based on health (smooth color transition)
	var target_color: Color
	if health_percent > 0.6:
		target_color = Color(0, 1, 0)      # Green
	elif health_percent > 0.3:
		target_color = Color(1, 1, 0)      # Yellow
	else:
		target_color = Color(1, 0, 0)      # Red
	
	# Tween color change
	hp_tween.tween_property(hp_foreground, "modulate", target_color, 0.3)
	
	# Pulse effect when damage taken (if HP decreased)
	if unit_reference and "current_health" in unit_reference:
		# Check if we have a stored previous HP
		var prev_hp = current_hp
		if "_prev_hp" in unit_reference:
			prev_hp = unit_reference._prev_hp
		
		if current_hp < prev_hp:
			# Red flash effect
			var flash_tween = create_tween()
			flash_tween.tween_property(hp_background, "modulate", Color(1, 0.5, 0.5), 0.1)
			flash_tween.tween_property(hp_background, "modulate", Color(0.2, 0.2, 0.2), 0.2)
		
		# Store current HP for next comparison
		unit_reference.set("_prev_hp", current_hp)

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
		
		# Fade in animation using sprite transparency
		if hp_background and hp_foreground:
			var fade_tween = create_tween()
			fade_tween.set_parallel(true)
			fade_tween.set_trans(Tween.TRANS_CUBIC)
			fade_tween.set_ease(Tween.EASE_OUT)
			
			# Fade in both sprites
			var bg_color = hp_background.modulate
			var fg_color = hp_foreground.modulate
			bg_color.a = 0.0
			fg_color.a = 0.0
			hp_background.modulate = bg_color
			hp_foreground.modulate = fg_color
			
			bg_color.a = 1.0
			fg_color.a = 1.0
			fade_tween.tween_property(hp_background, "modulate", bg_color, 0.2)
			fade_tween.tween_property(hp_foreground, "modulate", fg_color, 0.2)

func hide_hp_bar():
	# Fade out animation using sprite transparency
	if hp_background and hp_foreground:
		var fade_tween = create_tween()
		fade_tween.set_parallel(true)
		fade_tween.set_trans(Tween.TRANS_CUBIC)
		fade_tween.set_ease(Tween.EASE_IN)
		
		var bg_color = hp_background.modulate
		var fg_color = hp_foreground.modulate
		bg_color.a = 0.0
		fg_color.a = 0.0
		
		fade_tween.tween_property(hp_background, "modulate", bg_color, 0.15)
		fade_tween.tween_property(hp_foreground, "modulate", fg_color, 0.15)
		await fade_tween.finished
	
	visible = false
	if hp_foreground:
		hp_foreground.visible = false
	if hp_background:
		hp_background.visible = false
