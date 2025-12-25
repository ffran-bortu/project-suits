# unit_info_panel.gd - Displays unit info on hover
extends Panel

@onready var name_label = $VBox/Name
@onready var hp_label = $VBox/HP
@onready var stats_label = $VBox/Stats
@onready var range_label = $VBox/Range

var current_unit = null

func _ready():
	hide()
	modulate.a = 0.0

func show_unit_info(unit):
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
			hp_label.modulate = Color.GREEN
		elif hp_ratio > 0.3:
			hp_label.modulate = Color.YELLOW
		else:
			hp_label.modulate = Color.RED
	
	if stats_label:
		stats_label.text = "Str: %d  Spd: %d  Def: %d" % [unit.str, unit.spd, unit.def]
	
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
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func hide_info():
	current_unit = null
	
	# Fade out
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	
	hide()

func update_position(cursor_pos: Vector2):
	# Position panel near cursor but keep on screen
	var viewport_size = get_viewport_rect().size
	var panel_size = size
	
	# Default: bottom-right of cursor
	var target_pos = cursor_pos + Vector2(20, 20)
	
	# Check if it would go off screen
	if target_pos.x + panel_size.x > viewport_size.x:
		target_pos.x = cursor_pos.x - panel_size.x - 20
	
	if target_pos.y + panel_size.y > viewport_size.y:
		target_pos.y = cursor_pos.y - panel_size.y - 20
	
	position = target_pos
