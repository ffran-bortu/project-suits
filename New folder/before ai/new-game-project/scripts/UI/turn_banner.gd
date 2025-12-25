# turn_banner.gd - Phase transition banner
extends Control

@onready var label = $Label
@onready var panel = $Panel

# Banner colors
const COLOR_PLAYER_PHASE = Color(0.2, 0.6, 1.0)    # Blue
const COLOR_ENEMY_PHASE = Color(1.0, 0.3, 0.2)     # Red
const COLOR_NEUTRAL = Color(0.7, 0.7, 0.7)         # Grey

func _ready():
	# Start hidden
	modulate.a = 0.0
	hide()
	
	# Connect to game state changes
	var game_state = get_node("/root/GameStateManager")
	if game_state:
		game_state.player_turn_started.connect(_on_player_turn_started)
		game_state.enemy_turn_started.connect(_on_enemy_turn_started)

func _on_player_turn_started():
	show_banner("PLAYER PHASE", COLOR_PLAYER_PHASE)

func _on_enemy_turn_started():
	show_banner("ENEMY PHASE", COLOR_ENEMY_PHASE)

func show_banner(text: String, color: Color):
	if not label or not panel:
		return
	
	label.text = text
	panel.modulate = color
	
	# Animate banner in from top
	var start_pos = position
	position.y = -200
	
	show()
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	
	# Fade in
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	
	# Slide in from top
	tween.tween_property(self, "position:y", start_pos.y, 0.5)
	
	await tween.finished
	
	# Hold for a moment
	await get_tree().create_timer(1.5).timeout
	
	# Fade out
	var fade_out = create_tween()
	fade_out.set_trans(Tween.TRANS_CUBIC)
	fade_out.set_ease(Tween.EASE_IN)
	fade_out.tween_property(self, "modulate:a", 0.0, 0.4)
	
	await fade_out.finished
	hide()
	position = start_pos
