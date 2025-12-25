"""
FILE: ui_helper.gd
PURPOSE: Autoload singleton providing UI interaction utilities (checking if mouse is over UI).

OVERVIEW:
This autoload helps prevent UI click-through issues by checking if the mouse cursor is currently
hovering over any visible UI Control elements. Input systems can query this before processing
clicks to avoid selecting units or tiles when the player is actually clicking on a menu or panel.
Caches the UI canvas reference for performance.

FUNCTIONS IN THIS FILE:

1. is_mouse_over_ui()
   - What it does: Checks if mouse cursor is currently over any visible UI element
   - Uses: Called by input handlers before processing world clicks
   - Returns: bool (true if over UI, false if over game world)

2. _find_ui_canvas()
   - What it does: Locates and caches the UICanvas node reference
   - Uses: Called at _ready() and when cache is missing
   - Returns: void

3. _check_control_children(node, mouse_pos)
   - What it does: Recursively checks if mouse is over any Control in node tree
   - Uses: Helper for is_mouse_over_ui() to traverse UI hierarchy
   - Returns: bool

NOTES:
- Autoload singleton (accessible as UIHelper from anywhere)
- Current status: TEMPORARILY DISABLED (returns false) due to invisible UI blocking issue
- TODO: Fix transparent UI element covering screen
- Caches ui_canvas reference for performance (avoids repeated get_node calls)
- No dependencies (leaf utility node)
- Used by: input handlers, cursor controller, mouse click processing
"""

extends Node
## UIHelper - Autoload singleton for UI-related operations
##
## Provides utilities for checking UI interaction states and handling
## UI-aware input processing. Use as autoload: UIHelper.is_mouse_over_ui()
##
## This is now a proper singleton with cached references for better performance.

# Cached UI canvas reference
var ui_canvas: CanvasLayer = null

func _ready() -> void:
	# Cache UI canvas reference for performance
	_find_ui_canvas()

## Find and cache the UI canvas reference
func _find_ui_canvas() -> void:
	# Try to find UICanvas in the main scene
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		ui_canvas = main.get_node_or_null("UICanvas")
		if ui_canvas:
			print("UIHelper: Cached UI canvas reference")
		else:
			push_warning("UIHelper: UICanvas not found in Main scene")

## Check if the mouse cursor is currently over any UI element
##
## This prevents clicks from "falling through" UI panels to the game world.
## Checks all Control nodes in the UI canvas to see if they contain the mouse position.
##
## @return: true if mouse is over any visible UI element, false otherwise
func is_mouse_over_ui() -> bool:
	# TEMPORARY FIX: Disabled UI blocking to allow cursor movement
	# TODO: Find and fix the transparent UI element covering the screen
	return false
	
	# Ensure we have a UI canvas reference
	#if not ui_canvas:
	#	_find_ui_canvas()
	#	if not ui_canvas:
	#		return false
	
	#var mouse_pos = get_viewport().get_mouse_position()
	
	# Check all Control children recursively
	#return _check_control_children(ui_canvas, mouse_pos)

## Recursively check if mouse is over any Control node
##
## @param node: Node to check
## @param mouse_pos: Current mouse position
## @return: true if mouse is over this node or any children
func _check_control_children(node: Node, mouse_pos: Vector2) -> bool:
	# Check if this node is a visible Control
	if node is Control:
		var control = node as Control
		if control.visible and control.get_global_rect().has_point(mouse_pos):
			return true
	
	# Recursively check children
	for child in node.get_children():
		if _check_control_children(child, mouse_pos):
			return true
	
	return false
