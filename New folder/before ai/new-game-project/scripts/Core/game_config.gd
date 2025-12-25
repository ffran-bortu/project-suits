class_name GameConfig
extends Node
## Centralized game configuration
##
## This class contains all game constants, colors, and configuration values
## in one place for easy tuning and consistency across the project.

#region Colors
## Color codes used throughout the game (RGBA hex format)
static var colors: Dictionary = {
	"movement_highlight": "00FF003F",      # Green, semi-transparent
	"movement_bright": "00FF0050",         # Brighter green for hover
	"attack_highlight": "FF00004F",        # Red, semi-transparent  
	"attack_bright": "FF424270",           # Brighter red for hover
	"cursor_base": "FFFF0050",             # Yellow, semi-transparent
	"cursor_bright": "FFFF0070",           # Brighter yellow
	"path_color": "0000FF80",              # Blue, semi-transparent
	"hp_green": "00FF00FF",                # Healthy HP
	"hp_yellow": "FFFF00FF",               # Medium HP
	"hp_red": "FF0000FF",                  # Low HP
	"damage_normal": "FF3333FF",           # Normal damage
	"damage_crit": "FFC800FF",             # Critical damage
	"damage_heal": "33FF33FF",             # Healing
	"damage_miss": "B3B3B3FF",             # Miss
}
#endregion

#region Unit Configuration
## Default unit configuration values
static var unit: Dictionary = {
	"walk_speed": 5,                       # Movement animation speed
	"jump_height_max": 1.0,                # Max height units can jump
	"ground_offset": 3.0,                  # Height above ground
	"movement_offset": 3.0,                # Height during movement
	"base_hp": 20,                         # Default max HP
	"base_movement": 4,                    # Default movement range
	"base_attack_range": 1,                # Default attack range
}
#endregion

#region Visual Configuration
## Visual effect configuration
static var visual: Dictionary = {
	# Damage numbers
	"damage_number_rise": 2.0,             # How high damage numbers float
	"damage_number_duration": 1.0,         # Total animation time
	"damage_font_size": 36,                # Normal damage font size
	"damage_font_size_crit": 48,           # Critical hit font size
	
	# HP bars
	"hp_bar_transition": 0.3,              # HP change animation time
	"hp_bar_fade": 0.2,                    # Fade in/out time
	"hp_bar_flash": 0.1,                   # Damage flash duration
	
	# Cursor
	"cursor_pulse_speed": 0.6,             # Pulse animation speed
	"cursor_bounce_height": 0.05,          # Bounce amplitude
	
	# Selection ring
	"selection_rotate_speed": 2.0,         # Rotation speed (seconds per 360°)
	"selection_pulse_speed": 0.8,          # Scale pulse speed
	"selection_scale_min": 1.2,            # Minimum scale
	"selection_scale_max": 1.3,            # Maximum scale
	
	# Grid highlights
	"highlight_pulse_speed": 0.8,          # Grid pulse speed
	"movement_alpha_min": 0.3,             # Movement highlight min alpha
	"movement_alpha_max": 0.5,             # Movement highlight max alpha
	"attack_alpha_min": 0.4,               # Attack highlight min alpha
	"attack_alpha_max": 0.7,               # Attack highlight max alpha
}
#endregion

#region Combat Configuration
## Combat system configuration
static var combat: Dictionary = {
	"crit_multiplier": 3,                  # Critical hit damage multiplier
	"double_attack_speed_diff": 4,         # Speed difference for doubling
	"hit_flash_duration": 0.05,            # Unit flash on hit
	"shake_duration": 0.03,                # Unit shake per step
	"shake_intensity": 0.1,                # Shake distance
}
#endregion

#region Grid Configuration
## Grid and pathfinding configuration
static var grid: Dictionary = {
	"cell_size_x": 64.0,                   # Cell width
	"cell_size_y": 64.0,                   # Cell depth
	"grid_size_x": 8,                      # Grid width in cells
	"grid_size_y": 8,                      # Grid height in cells
	"height_unit_scale": 3.0,              # Visual height multiplier
}
#endregion

#region Camera Configuration
## Camera system configuration
static var camera: Dictionary = {
	"default_fov": 60.0,               # Default field of view
	"min_fov": 30.0,                   # Minimum zoom (most zoomed in)
	"max_fov": 90.0,                   # Maximum zoom (most zoomed out)
	"zoom_speed": 5.0,                 # Zoom increment per scroll
	"zoom_smoothness": 0.15,           # How fast FOV interpolates (0-1)
	
	"pan_speed": 20.0,                 # WASD movement speed
	"pan_smoothness": 0.2,             # Camera movement smoothness
	"boundary_radius": 30.0,           # How far camera can move from center
}
#endregion

#region Material Pool
## Pre-created materials for performance
static var materials: Dictionary = {}

## Initialize all materials (call once at game start)
static func init_materials() -> void:
	if not materials.is_empty():
		return  # Already initialized
	
	# Grid highlight materials
	materials["movement"] = create_highlight_material(colors.movement_highlight)
	materials["movement_hover"] = create_highlight_material(colors.movement_bright)
	materials["attack"] = create_highlight_material(colors.attack_highlight)
	materials["attack_hover"] = create_highlight_material(colors.attack_bright)
	materials["cursor"] = create_highlight_material(colors.cursor_base)
	materials["path"] = create_highlight_material(colors.path_color)
	
	print("GameConfig: Materials initialized")

## Creates a StandardMaterial3D with specified color for grid highlights
##
## @param color_hex: The color in hexadecimal RGBA format (e.g., "FF0000FF")
## @return: A new StandardMaterial3D instance configured for highlights
static func create_highlight_material(color_hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color_hex)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

## Creates a StandardMaterial3D for general use
##
## @param color: The Color to use
## @param shaded: Whether to use shading (default: false)
## @return: A new StandardMaterial3D instance
static func create_material(color: Color, shaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if not shaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material
#endregion

## Get a color by name
##
## @param color_name: Name of the color from the colors dictionary
## @return: Color object
static func get_color(color_name: String) -> Color:
	if color_name in colors:
		return Color(colors[color_name])
	push_warning("GameConfig: Color '%s' not found, returning white" % color_name)
	return Color.WHITE

## Get a pre-created material by name
##
## @param material_name: Name of the material from the materials dictionary
## @return: StandardMaterial3D or null if not found
static func get_material(material_name: String) -> StandardMaterial3D:
	if materials.is_empty():
		push_warning("GameConfig: Materials not initialized! Call init_materials() first.")
		init_materials()
	
	if material_name in materials:
		return materials[material_name]
	
	push_warning("GameConfig: Material '%s' not found" % material_name)
	return null
