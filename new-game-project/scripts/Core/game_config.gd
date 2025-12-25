"""
FILE: game_config.gd
PURPOSE: Centralized repository of all game constants, colors, and configuration values.

OVERVIEW:
This class provides a single source of truth for all tunable parameters in the game, including
visual settings (colors, animation speeds), gameplay balance, and unit defaults. By centralizing 
these values, designers can tune the game feel without hunting through dozens of files. 
Also manages a material pool for frequently-used StandardMaterial3D instances to improve performance.

FUNCTIONS IN THIS FILE:
(See source for details)
"""

class_name GameConfig
extends RefCounted
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
	"phase_player": "3366CC90",            # Player phase banner (Blue)
	"phase_enemy": "CC333390",             # Enemy phase banner (Red)
	"phase_ally": "33CC6690",              # Ally phase banner (Green)
	
	# World Map Nodes
	"node_unlocked": "4DA6FF",             # Blue
	"node_completed": "4DFF4D",            # Green
	"node_locked": "666666",               # Gray
	"node_current": "FFCC33",              # Yellow
	"line_unlocked": "80CCFF99",           # Light Blue
	"line_locked": "4D4D4D66",             # Dark Gray
	"ui_disabled": "999999FF",             # Gray for disabled buttons
	
	# State Display Colors
	"state_player_turn": "00FF00FF",       # Green
	"state_enemy_turn": "FF0000FF",        # Red
	"state_unit_selected": "FFFF00FF",     # Yellow
	"state_unit_moving": "FF8000FF",       # Orange
}
#endregion

#region Unit Configuration
## Default unit configuration values
static var unit: Dictionary = {
	"walk_speed": 3,                       # Movement animation speed (slowed for clarity)
	"jump_height_max": 1.0,                # Max height units can jump
	# LAYER 2 POSITIONING: Gameplay offset added to GridManager's base position
	# Set to 0.0 = units sit exactly on ground (no Z-fighting, no hovering)
	# Increase if you want units to hover (e.g., 0.1 for flying units)
	"ground_offset": 0.0,                  # Height above ground (units sit on ground)
	"movement_offset": 0.02,               # Height during movement
	"base_hp": 20,                         # Default max HP
	"base_movement": 4,                    # Default movement range                   # Default movement range
	"base_attack_range": 1,                # Default attack range
}
#endregion

#region Assets
## Asset paths (Scenes, Textures, etc.)
static var assets: Dictionary = {
	"unit_scene": "res://scenes/unit.tscn",
	"unit_enemy_texture": "res://assets/unit_enemy.png",
	"main_menu_scene": "res://scenes/menu_main.tscn",
	"world_map_scene": "res://scenes/world_map_visual.tscn",
	"battle_scene": "res://scenes/main.tscn",
	"level_up_ui_scene": "res://scenes/ui/level_up_ui.tscn",
	"combat_forecast_scene": "res://scenes/ui/combat_forecast.tscn",
	"enemy_ai_script": "res://scripts/Managers/enemy_ai.gd"
}
#endregion

#region View Configuration
## UI Scene Paths
static var ui: Dictionary = {
	"unit_selection_panel": "res://scenes/ui/unit_selection_panel.tscn",
	"support_menu": "res://scenes/ui/support_menu.tscn",
	"support_viewer": "res://scenes/ui/support_viewer.tscn", 
	"difficulty_select": "res://scenes/ui/difficulty_select.tscn",
	"options_menu": "res://scenes/ui/options_menu.tscn",
	"tooltip_offset": Vector2(20, 20)
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
	
	"unit_scale": Vector3(1.0, 1.0, 1.0),  # Scale 1.0 matches 1.0 grid size
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
	
	# XP Values
	"xp_kill": 20,
	"xp_hit": 10,
	
	# Formula Constants
	"base_weapon_hit": 90,
	"hit_skill_multiplier": 2,
	"hit_luck_divisor": 2.0,
	"crit_skill_divisor": 2.0,
	"avoid_speed_multiplier": 2,
	"min_hit_rate": 0,
	"max_hit_rate": 100,
	"min_crit_rate": 0,
	"max_crit_rate": 100,
}
#endregion

#region Enemy AI Configuration
## Enemy AI behavior configuration
static var EnemyAI: Dictionary = {
	"WEIGHT_KILL": 100.0,
	"WEIGHT_LOW_HP": 50.0,
	"WEIGHT_DISTANCE": -5.0,
	"WEIGHT_FAVORABLE_MATCHUP": 25.0,
	
	"DANGER_THRESHOLD": 0.5,           # 50% HP
	"CRITICAL_THRESHOLD": 0.25,        # 25% HP
	"THREAT_COUNT_THRESHOLD": 3,       # Number of enemies to consider "surrounded"
	
	"SAFE_ATTACK_DISTANCE": 2,
	"MIN_RETREAT_DISTANCE": 3,
}
#endregion

#region Grid Configuration
## Grid and pathfinding configuration
static var grid: Dictionary = {
	"cell_size_x": 1.0,                   # Cell width
	"cell_size_y": 1.0,                   # Cell depth
	"grid_size_x": 8,                      # Grid width in cells
	"grid_size_y": 8,                      # Grid height in cells
	"height_unit_scale": 1.0,              # Visual height multiplier
	
	# Grid highlight layer heights (Y offsets)
	"highlight_offset_cursor": 0.01,       # Cursor highlight (bottom layer)
	"highlight_offset_movement": 0.02,     # Movement range
	"highlight_offset_hover": 0.03,        # Hover highlight
	"highlight_offset_path": 0.04,         # Path preview
	"highlight_offset_attack": 0.05,       # Attack range (top layer)
}
#endregion

#region Camera Configuration
## Camera system configuration
static var camera: Dictionary = {
	# Disgaea-style dimetric projection (2:1 pixel ratio)
	# Lowered to 15° for flatter view and better sprite visibility
	"pitch_angle": 15.0,               # Lower angle = flatter map, more sprite visible
	"yaw_angle": 45.0,                 # Diagonal orientation
	
	# Camera positioning
	"camera_distance": 25.0,           # Base distance from target
	"vertical_headroom_ratio": 0.3,    # 30% empty space above cursor
	
	# Zoom settings (orthogonal size)
	"default_fov": 60.0,               # Default field of view
	"min_fov": 30.0,                   # Minimum zoom (most zoomed in)
	"max_fov": 90.0,                   # Maximum zoom (most zoomed out)
	"zoom_speed": 5.0,                 # Zoom increment per scroll
	"zoom_smoothness": 0.15,           # How fast FOV interpolates (0-1)
	
	# Panning
	"pan_speed": 20.0,                 # WASD movement speed
	"pan_smoothness": 0.2,             # Camera movement smoothness
	"boundary_radius": 30.0,           # How far camera can move from center
	
	# Edge panning configuration
	"edge_pan_enabled": true,          # Enable mouse edge panning
	"edge_pan_threshold": 20,          # Pixels from edge to trigger
	"edge_pan_delay": 0.2,             # Seconds before panning starts
	"edge_pan_speed_multiplier": 0.8,  # Relative to keyboard pan speed
	
	# Overhead toggle (top-down mode for grid counting)
	"overhead_fov": 50.0,              # Slightly tighter for precision
	"overhead_transition_speed": 0.3,  # Tween duration for mode switch
	
	# Legacy positioning ratios (kept for compatibility, overridden by pitch_angle)
	"distance_multiplier": 0.25,       # Base distance from grid center
	"position_x_ratio": 0.7,           # X offset ratio
	"position_y_ratio": 0.8,           # Y (height) offset ratio
	"position_z_ratio": 0.7,           # Z offset ratio
}
#endregion

#region Bond Configuration
## Bond System Configuration
static var Bond: Dictionary = {
	"POINTS_FOR_C": 100,
	"POINTS_FOR_B": 200,
	"POINTS_FOR_A": 300,
	"POINTS_FOR_S_OR_APLUS": 450,
	
	"POINTS_PER_TURN_TOGETHER": 2,
	"POINTS_PER_DUO_ACTION": 5,
	"POINTS_PER_HEAL": 5,
	"POINTS_PER_RANGE_OVERLAP_ATTACK": 3
}
#endregion

#region Terrain Configuration
## Terrain generation parameters
static var Terrain: Dictionary = {
	# Height Thresholds
	"HEIGHT_WATER_LEVEL": -0.5,
	"HEIGHT_GRASS": 0.2,
	"HEIGHT_DIRT": 0.4,
	"HEIGHT_FOREST": 0.6,
	"HEIGHT_STONE": 0.8,
	
	# Movement Costs
	"COST_DEFAULT": 1,
	"COST_DIFFICULT": 2,
	"COST_MOUNTAIN": 4,
	"COST_IMPASSABLE": 99,
	
	# Bonuses (Defense/Avoid)
	"BONUS_DEF_DIRT": 0,
	"BONUS_DEF_FOREST": 1,
	"BONUS_AVO_FOREST": 10,
	"BONUS_DEF_STONE": 0,
	"BONUS_AVO_STONE": 5,
	"BONUS_DEF_MOUNTAIN": 2,
	"BONUS_AVO_MOUNTAIN": 20
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
