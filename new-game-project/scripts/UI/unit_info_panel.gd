"""
FILE: unit_info_panel.gd
PURPOSE: Displays a hover tooltip showing unit statistics and information near the cursor.

OVERVIEW:
This panel appears when the player hovers over a unit, showing key information like name, HP with
color-coded health bar, stats (strength, speed, defense), and attack range. It intelligently positions
itself near the cursor while staying on screen and uses fade animations for smooth appearance and
disappearance.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Initializes panel as hidden with zero opacity
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. show_unit_info(unit)
   - What it does: Populates panel with unit's data, positions near cursor, and fades in with animation
   - Uses: Called when cursor hovers over a unit
   - Returns: void

3. hide_info()
   - What it does: Fades out panel and hides it, clearing current unit reference
   - Uses: Called when cursor leaves a unit or panel should be dismissed
   - Returns: void

4. update_position(cursor_pos: Vector2)
   - What it does: Positions panel near cursor while keeping it fully visible on screen
   - Uses: Called to reposition panel as cursor moves or when initially shown
   - Returns: void

NOTES:
- Displays unit name, HP ratio with color coding (green >60%, yellow >30%, red otherwise)
- Shows core stats: Strength, Speed, and Defense
- Displays attack range, supporting both single-value and min-max ranges
- Intelligently repositions to avoid going off-screen edges
- Default position is bottom-right of cursor (+20, +20), but shifts if that would clip viewport
- Uses cubic easing for smooth fade in (0.2s) and fade out (0.15s) animations
"""

# unit_info_panel.gd - Displays unit info on hover
"""
FILE: unit_info_panel.gd
PURPOSE: Unit information panel showing stats, HP, equipment for selected/hovered unit.
NOTES: Unit details UI panel.
"""
extends Panel

@onready var name_label = $VBox/Name
@onready var hp_label = $VBox/HP
@onready var stats_label = $VBox/Stats
@onready var range_label = $VBox/Range

var current_unit: Unit = null
var active_tween: Tween = null

func _ready() -> void:
	hide()
	modulate.a = 0.0

func show_unit_info(unit: Unit) -> void:
	if not unit:
		hide_info()
		return
	
	current_unit = unit
	
	# Update labels
	if name_label:
		name_label.text = unit.unit_name
	
	if hp_label:
		hp_label.text = "HP: %d/%d" % [unit.current_health, unit.max_health]
		
		# Color code HP
		var hp_ratio = float(unit.current_health) / float(unit.max_health)
		if hp_ratio > 0.6:
			hp_label.modulate = GameConfig.get_color("hp_green")
		elif hp_ratio > 0.3:
			hp_label.modulate = GameConfig.get_color("hp_yellow")
		else:
			hp_label.modulate = GameConfig.get_color("hp_red")
	
	if stats_label:
		stats_label.text = "Str: %d  Spd: %d  Def: %d" % [unit.strength, unit.spd, unit.def]
	
	if range_label:
		var min_range = 1
		var max_range = unit.attack_range
		if unit.has_method("get_attack_range_min"):
			min_range = unit.get_attack_range_min()
		if unit.has_method("get_attack_range_max"):
			max_range = unit.get_attack_range_max()
		
		if min_range == max_range:
			range_label.text = "Range: %d" % max_range
		else:
			range_label.text = "Range: %d-%d" % [min_range, max_range]
	
	# Fade in
	show()
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_info() -> void:
	current_unit = null
	
	# Fade out
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_IN)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await active_tween.finished
	
	hide()

func update_position(cursor_pos: Vector2) -> void:
	# Position panel near cursor but keep on screen
	var viewport_size = get_viewport_rect().size
	var panel_size = size
	
	# Default: bottom-right of cursor
	var offset = GameConfig.ui.tooltip_offset
	var target_pos = cursor_pos + offset
	
	# Check if it would go off screen
	if target_pos.x + panel_size.x > viewport_size.x:
		target_pos.x = cursor_pos.x - panel_size.x - 20
	
	if target_pos.y + panel_size.y > viewport_size.y:
		target_pos.y = cursor_pos.y - panel_size.y - 20
	
	position = target_pos
