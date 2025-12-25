"""
FILE: visual_component.gd
PURPOSE: Manages visual representation of a Unit (Sprite3D, Animations, Selection, Team Colors).
"""
class_name VisualComponent
extends Node

## Component for managing unit visuals (Sprite, Selection, Effects)
##
## Handles sprite instantiation, team coloring, selection indicators,
## and hit/damage effects.

var _unit: Unit
var _sprite: Sprite3D
var _selection_indicator: Node3D
var _hp_bar: Node3D

var _stored_color: Color = Color.WHITE
var _selection_tween: Tween

var _anim_player: AnimationPlayer

func setup(unit: Unit) -> void:
	assert(unit != null, "VisualComponent: Unit dependency cannot be null in setup()")
	_unit = unit
	_initialize_visuals()
	# Default idle
	play_animation("IDLE")

func _initialize_visuals() -> void:
	# Find or create Sprite3D
	if _unit.has_node("Sprite3D"):
		_sprite = _unit.get_node("Sprite3D")
		if _sprite.has_node("AnimationPlayer"):
			_anim_player = _sprite.get_node("AnimationPlayer")
	else:
		_sprite = Sprite3D.new()
		_sprite.name = "Sprite3D"
		_sprite.pixel_size = 0.025
		_sprite.texture = PlaceholderTexture2D.new()
		_unit.add_child(_sprite)
	
	## *** UNIT POSITIONING LAYER 3 of 3: VISUAL/RENDER SPACE ***
	## Sprite positioning for billboard Sprite3D:
	## - sprite.position.y = 0.0 (sprite anchor at unit root = ground level)
	## - sprite.offset.y adjusts where the image renders relative to anchor
	## - For sprites to "stand on ground", offset must be 0 or slightly positive
	## - Billboard sprites don't follow normal 3D positioning rules
	
	## LAYER 3: Sprite positioning for billboard mode
	## Billboard sprites face camera in screen-space
	## Positive offset.y extends sprite upward from root
	
	# Root at ground level
	_sprite.position.y = 0.0
	
	# Offset sprite upward so bottom edge sits at ground
	if _sprite.texture:
		var h = _sprite.texture.get_height()
		# Full half-height offset for proper ground standing
		_sprite.offset.y = h / 2.0
	else:
		_sprite.offset.y = 100.0  # Fallback
	
	# Ensure billboard mode
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	
	# Find or create SelectionIndicator
	if _unit.has_node("SelectionIndicator"):
		_selection_indicator = _unit.get_node("SelectionIndicator")
	else:
		# Fallback creation if not in scene
		var indicator = CSGTorus3D.new()
		indicator.name = "SelectionIndicator"
		indicator.inner_radius = 1.0
		indicator.outer_radius = 1.2
		indicator.sides = 16
		indicator.material = GameConfig.get_material("cursor") if GameConfig else StandardMaterial3D.new()
		_unit.add_child(indicator)
		_selection_indicator = indicator
	
	_selection_indicator.visible = false
	
	# Find HP Bar
	if _unit.has_node("HPBar3D"):
		_hp_bar = _unit.get_node("HPBar3D")

func set_scale(scale_val: float) -> void:
	_unit.scale = Vector3(scale_val, scale_val, scale_val)

func set_team_color(is_player: bool) -> void:
	if not _sprite: 
		push_error("VisualComponent.set_team_color: _sprite is NULL for unit ", _unit.unit_name if _unit else "UNKNOWN")
		return
	
	if is_player:
		_stored_color = Color(0.6, 0.6, 1.2) # Blueish
	else:
		_stored_color = Color(2.0, 0.0, 0.0) # Bright Red
	
	_sprite.modulate = _stored_color

func _process(_delta: float) -> void:
	# Maintain color integrity but allow damage animation to override temporarily?
	# Basic check: if animation is playing DAMAGE, don't reset.
	if _anim_player and _anim_player.current_animation == "DAMAGE":
		return
		
	if _sprite and _sprite.modulate != _stored_color:
		_sprite.modulate = _stored_color

func on_selected() -> void:
	if _selection_indicator:
		_selection_indicator.visible = true
		_play_selection_animation()
	
	if _hp_bar and _hp_bar.has_method("show_hp_bar"):
		_hp_bar.show_hp_bar()

func on_deselected() -> void:
	if _selection_indicator:
		_selection_indicator.visible = false
		if _selection_tween: _selection_tween.kill()
	
	if _hp_bar and _hp_bar.has_method("hide_hp_bar"):
		_hp_bar.hide_hp_bar()

func _play_selection_animation() -> void:
	if _selection_tween: _selection_tween.kill()
	_selection_tween = create_tween().set_loops()
	_selection_tween.tween_property(_selection_indicator, "rotation_degrees:y", 360.0, 2.0).from(0.0)

func play_hit_effect() -> void:
	if _anim_player and _anim_player.has_animation("DAMAGE"):
		_anim_player.play("DAMAGE")
		return
		
	if not _sprite: return
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", Color(3,3,3), 0.05)
	tween.tween_property(_sprite, "modulate", _stored_color, 0.1)

func play_animation(anim_name: String) -> void:
	if _anim_player and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)

func update_hp_bar(current: int, max_hp: int) -> void:
	if _hp_bar and _hp_bar.has_method("update_hp_display"):
		_hp_bar.update_hp_display(current, max_hp)
