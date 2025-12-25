# turn_counter.gd - Turn counter display
extends Label

var current_turn: int = 1

func _ready():
	# Connect to game state
	var game_state = get_node("/root/GameStateManager")
	if game_state:
		game_state.player_turn_started.connect(_on_player_turn_started)
	
	update_display()

func _on_player_turn_started():
	current_turn += 1
	update_display()
	
	# Pulse animation when turn changes
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	var original_scale = scale
	scale = Vector2.ZERO
	tween.tween_property(self, "scale", original_scale, 0.5)

func update_display():
	text = "Turn: " + str(current_turn)

func reset_turn():
	current_turn = 1
	update_display()
