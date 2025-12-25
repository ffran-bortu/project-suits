class_name UIHelper
extends Node
## Helper utilities for UI-related operations
##
## Provides static methods for checking UI interaction states
## and handling UI-aware input processing.

## Check if the mouse cursor is currently over any UI element
##
## This prevents clicks from "falling through" UI panels to the game world.
## Checks all Control nodes in the UI canvas to see if they contain the mouse position.
##
## @return: true if mouse is over any visible UI element, false otherwise
static func is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Get the UI canvas (assuming it's named UICanvas in main scene)
	var ui_canvas = get_tree().root.get_node_or_null("Main/UICanvas")
	if not ui_canvas:
		return false
	
	# Check all Control children recursively
	return _check_control_children(ui_canvas, mouse_pos)

## Recursively check if mouse is over any Control node
##
## @param node: Node to check
## @param mouse_pos: Current mouse position
## @return: true if mouse is over this node or any children
static func _check_control_children(node: Node, mouse_pos: Vector2) -> bool:
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

## Get viewport for static context
##
## @return: Current viewport
static func get_viewport() -> Viewport:
	return Engine.get_main_loop().root.get_viewport()

## Get scene tree for static context
##
## @return: Current scene tree
static func get_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
