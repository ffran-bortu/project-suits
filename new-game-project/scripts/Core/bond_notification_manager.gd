"""
FILE: bond_notification_manager.gd
PURPOSE: Displays popup notifications when characters unlock new support ranks.

OVERVIEW:
This manager connects to BondSystem signals and spawns visual notification popups when support ranks
unlock (C, B, A, S). Instantiates bond notification UI scenes and provides them with character names
and rank data. Can also manually trigger point gain notifications if desired.

FUNCTIONS IN THIS FILE:

1. _ready() -> void
   - What it does: Finds BondSystem reference, connects to support_unlocked signal
   - Uses: Called automatically when node enters scene tree
   - Returns: void

2. _on_support_unlocked(char_a_name: String, char_b_name: String, rank: String) -> void
   - What it does: Spawns notification popup for rank unlock
   - Uses: Signal callback from BondSystem when new rank achieved
   - Returns: void

3. _spawn_rank_notification(char_a_name: String, char_b_name: String, rank: String) -> void
   - What it does: Instantiates notification scene, adds to tree, calls show_rank_unlocked method
   - Uses: Called internally when rank unlocks
   - Returns: void

4. show_points_gained(char_a_name: String, char_b_name: String, points: int) -> void
   - What it does: Manually spawns notification showing bond point gain (not automatic to avoid spam)
   - Uses: Can be called by BondSystem if point-by-point feedback desired
   - Returns: void

NOTES:
- Depends on BondSystem (sibling node) for support unlock signals
- Loads bond_notification.tscn scene for popup UI
- Only triggers on rank unlocks by default (not every point gain) to avoid spam
- Validates character names and rank are not empty before spawning
- Adds notifications to root scene tree so they appear above everything
- Validates notification has required methods before using
"""


extends Node
class_name BondNotificationManager
## Manages display of bond point notifications
##
## Connects to BondSystem signals and spawns notification popups

const BOND_NOTIFICATION_SCENE = preload("res://scenes/ui/bond_notification.tscn")

var bond_system: Node = null

func _ready() -> void:
	# Get BondSystem reference
	bond_system = get_node_or_null("../BondSystem")
	if not bond_system:
		push_error("BondNotificationManager: BondSystem not found as sibling node")
		return
	
	# Connect to bond system signals
	if not bond_system.has_signal("support_unlocked"):
		push_error("BondNotificationManager: BondSystem missing support_unlocked signal")
		return
	
	bond_system.support_unlocked.connect(_on_support_unlocked)
	
	# We won't connect to every point gain (too spammy), only rank ups
	# But we need a way to show points occasionally
	
	DebugLog.success("BondNotificationManager initialized")

## Handle support unlock signal
func _on_support_unlocked(char_a_name: String, char_b_name: String, rank: String) -> void:
	_spawn_rank_notification(char_a_name, char_b_name, rank)

## Spawn notification for rank unlock
func _spawn_rank_notification(char_a_name: String, char_b_name: String, rank: String) -> void:
	# Validate inputs
	if char_a_name.is_empty() or char_b_name.is_empty() or rank.is_empty():
		push_warning("BondNotificationManager: Invalid names or rank for notification")
		return
	
	var notification = BOND_NOTIFICATION_SCENE.instantiate()
	if not notification:
		push_error("BondNotificationManager: Failed to instantiate notification scene")
		return
	
	# Add to scene tree
	get_tree().root.add_child(notification)
	
	# Show rank unlocked
	if notification.has_method("show_rank_unlocked"):
		notification.show_rank_unlocked(char_a_name, char_b_name, rank)
	else:
		push_error("BondNotificationManager: Notification missing show_rank_unlocked() method")
		notification.queue_free()

## Manually show point gain (called from BondSystem if desired)
func show_points_gained(char_a_name: String, char_b_name: String, points: int) -> void:
	var notification = BOND_NOTIFICATION_SCENE.instantiate()
	get_tree().root.add_child(notification)
	
	if notification.has_method("show_points_gained"):
		notification.show_points_gained(char_a_name, char_b_name, points)
