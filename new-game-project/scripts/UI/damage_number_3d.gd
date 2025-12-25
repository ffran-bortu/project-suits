"""
FILE: damage_number_3d.gd
PURPOSE: Floating 3D damage numbers displayed above units during combat for visual feedback.

OVERVIEW:
Extends Label3D to create animated floating text showing damage, healing, critical hits, and misses. Uses Tween
for smooth rise and fade animations. Pulls colors from GameConfig (damage, crit, heal, miss), supports variable
font sizes (larger for crits), has black outline for visibility, billboard always faces camera, renders on top (no depth test), and self-destructs after animation completes.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Sets billboard mode, no_depth_test, render_priority, outline, starts invisible
   - Uses: Initialization
   - Returns: void

2. show_damage(damage, is_critical, is_miss)
   - What it does: Sets text/color based on type, starts animation
   - Uses: Called by Unit.take_damage() or Unit.heal()
   - Returns: void

3. _animate()
   - What it does: Fades in, rises up (2.0 units),  fades out, queue_free
   - Uses: Called by show_damage()
   - Returns: void (async with awaits)

NOTES:
- Extends Label3D (3D scene node)
- RISE_DISTANCE = 2.0 (vertical rise)
- FADE_DURATION = 1.0 seconds total
- RISE_DURATION = 0.8 seconds (rises, then fades while stationary)
- Colors from GameConfig: damage_normal (red), damage_crit (yellow), damage_heal (green), damage_miss (gray)
- Font sizes: normal for damage/heal/miss, larger for crits (GameConfig.visual.damage_font_size_crit)
- Text format: "123" for damage, "123!" for crit, "+123" for healing, "MISS" for miss
- billboard = BILLBOARD_ENABLED (always faces camera)
- no_depth_test = true (renders through objects)
- render_priority = 10 (renders on top)
- outline_size = 4, outline_modulate = BLACK (visibility)
- Tween: parallel fade in + rise (CUBIC EASE_OUT), then linear fade out
- Self-destructs after animation (queue_free)
- is_animating flag prevents overlapping animations
"""

# damage_number_3d.gd - Floating damage numbers for combat feedback
extends Label3D

## Configuration
const RISE_DISTANCE = 2.0      # How high the number floats up
const FADE_DURATION = 1.0      # Total animation duration
const RISE_DURATION = 0.8      # How long it takes to rise

## Damage number colors (as variables since they depend on GameConfig runtime values)
var COLOR_DAMAGE = GameConfig.get_color("damage_normal") if GameConfig.colors else Color(1.0, 0.2, 0.2)
var COLOR_CRIT = GameConfig.get_color("damage_crit") if GameConfig.colors else Color(1.0, 0.8, 0.0)
var COLOR_HEAL = GameConfig.get_color("damage_heal") if GameConfig.colors else Color(0.2, 1.0, 0.3)
var COLOR_MISS = GameConfig.get_color("damage_miss") if GameConfig.colors else Color(0.7, 0.7, 0.7)

var start_position: Vector3
var is_animating: bool = false

func _ready():
	# Setup label properties
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 10
	outline_size = 4
	outline_modulate = Color.BLACK
	
	# Start invisible
	modulate.a = 0.0

## Show a damage number with animation.
## @param damage: Amount of damage (negative for healing)
## @param is_critical: Whether this was a critical hit
## @param is_miss: Whether the attack missed
func show_damage(damage: int, is_critical: bool = false, is_miss: bool = false):
	if is_animating:
		return
	
	is_animating = true
	start_position = position
	
	# Set text and color using GameConfig
	if is_miss:
		text = "MISS"
		modulate = GameConfig.get_color("damage_miss")
		font_size = GameConfig.visual.damage_font_size
	elif is_critical:
		text = str(damage) + "!"
		modulate = GameConfig.get_color("damage_crit")
		font_size = GameConfig.visual.damage_font_size_crit  # Larger for crits
	elif damage < 0:
		text = "+" + str(abs(damage))
		modulate = GameConfig.get_color("damage_heal")
		font_size = GameConfig.visual.damage_font_size
	else:
		text = str(damage)
		modulate = GameConfig.get_color("damage_normal")
		font_size = GameConfig.visual.damage_font_size	
	# Start animation
	_animate()

func _animate():
	# Create tween for smooth animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# Fade in quickly
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	
	# Rise up
	var target_pos = start_position + Vector3(0, RISE_DISTANCE, 0)
	tween.tween_property(self, "position", target_pos, RISE_DURATION)
	
	# Wait a bit, then fade out
	await tween.finished
	
	var fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_LINEAR)
	fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION - RISE_DURATION)
	
	await fade_tween.finished
	
	# Clean up
	queue_free()
