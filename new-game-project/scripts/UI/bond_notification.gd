"""
FILE: bond_notification.gd
PURPOSE: Displays temporary notifications for bond point gains and support rank unlocks.

OVERVIEW:
Extends CanvasLayer to show brief popup notifications at top-center of screen when characters gain bond points
or unlock new support ranks. Uses RichTextLabel for colored text, animates fade in/out with Tween, auto-positions
on viewport resize, and self-destructs after animation completes. Minimal, non-intrusive UI feedback.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Positions notification, connects to viewport size_changed
   - Uses: Initialization
   - Returns: void

2. _position_notification()
   - What it does: Centers panel at top of screen (viewport.x/2, y=50)
   - Uses: Initial position and viewport resize
   - Returns: void

3. show_points_gained(char_a_name, char_b_name, points)
   - What it does: Displays "+X Bond CharA ↔ CharB" in yellow, animates
   - Uses: After combat/duo actions award bond points
   - Returns: void

4. show_rank_unlocked(char_a_name, char_b_name, rank)
   - What it does: Displays "Support RANK Unlocked! CharA + CharB" in cyan, animates
   - Uses: When bond points reach rank threshold (C/B/A/S/A+)
   - Returns: void

5. _animate_notification()
   - What it does: Fades in (0.2s), waits (1.5s), fades out (0.3s), queue_free
   - Uses: Called by show functions
   - Returns: void

NOTES:
- Extends CanvasLayer (always on top)
- class_name BondNotification for instantiation
- RichTextLabel supports BBCode colors ([color=yellow], [color=cyan])
- Panel positioned at (viewport_width/2 - panel_width/2, 50)
- Heart icon TextureRect decorates notification
- Tween sequence: fade in → wait → fade out → destroy
- Automatically destroys self after animation (queue_free)
- Connects to viewport.size_changed for responsive positioning
- Non-blocking, auto-dismissing feedback
"""

extends CanvasLayer
class_name BondNotification
## Displays bond point gain notifications
##
## Shows small popups when units gain bond points or unlock support ranks

@onready var notification_panel: Panel = $Control/Panel
@onready var notification_text: RichTextLabel = $Control/Panel/HBoxContainer/RichTextLabel
@onready var heart_icon: TextureRect = $Control/Panel/HBoxContainer/HeartIcon

func _ready():
	# Position at top center of screen
	_position_notification()
	
	# Connect to viewport size changes for repositioning
	get_viewport().size_changed.connect(_position_notification)

## Position notification at top-center of screen
func _position_notification():
	var viewport_size = get_viewport().size
	notification_panel.position = Vector2(
		viewport_size.x / 2 - notification_panel.size.x / 2,
		50
	)

## Show bond points gained
## @param char_a_name: First character name
## @param char_b_name: Second character name
## @param points: Points gained
func show_points_gained(char_a_name: String, char_b_name: String, points: int):
	notification_text.text = "[color=yellow]+%d Bond[/color] %s ↔ %s" % [points, char_a_name, char_b_name]
	_animate_notification()

## Show support rank unlocked
## @param char_a_name: First character name
## @param char_b_name: Second character name
## @param rank: Rank unlocked (C/B/A/S/A+)
## Show support rank unlocked
## @param char_a_name: First character name
## @param char_b_name: Second character name
## @param rank: Rank unlocked (C/B/A/S/A+)
func show_rank_unlocked(char_a_name: String, char_b_name: String, rank: String):
	notification_text.text = "[color=cyan]Support %s Unlocked![/color] %s + %s" % [rank, char_a_name, char_b_name]
	_animate_notification()

## Animate notification fade in/out
func _animate_notification():
	if has_node("Control"):
		$Control.modulate.a = 0
		var tween = create_tween()
		tween.tween_property($Control, "modulate:a", 1.0, 0.2)
		tween.tween_interval(1.5)
		tween.tween_property($Control, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()
