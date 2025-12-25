# damage_number_3d.gd - Floating damage numbers for combat feedback
extends Label3D

## Configuration
const RISE_DISTANCE = 2.0      # How high the number floats up
const FADE_DURATION = 1.0      # Total animation duration
const RISE_DURATION = 0.8      # How long it takes to rise

## Damage number colors
const COLOR_DAMAGE = GameConfig.get_color("damage_normal") if GameConfig.colors else Color(1.0, 0.2, 0.2)
const COLOR_CRIT = GameConfig.get_color("damage_crit") if GameConfig.colors else Color(1.0, 0.8, 0.0)
const COLOR_HEAL = GameConfig.get_color("damage_heal") if GameConfig.colors else Color(0.2, 1.0, 0.3)
const COLOR_MISS = GameConfig.get_color("damage_miss") if GameConfig.colors else Color(0.7, 0.7, 0.7)

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
