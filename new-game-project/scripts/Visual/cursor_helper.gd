"""
FILE: cursor_helper.gd
PURPOSE: Static utility for managing cursor shape changes across the game.

OVERVIEW:
Provides centralized cursor shape management to improve UX. Changes cursor based on
context: arrow for default, pointing hand for interactive elements, move for panning.
Checks current shape before setting to avoid redundant API calls.

PUBLIC API:
- set_arrow() -> void: Set default arrow cursor
- set_move() -> void: Set move/pan cursor
- set_pointing_hand() -> void: Set interactive element cursor

NOTES:
- All functions are static (no instantiation needed)
- Checks Input.get_current_cursor_shape() before changing
- Use CursorHelper.set_arrow() instead of creating instances
"""

class_name CursorHelper
extends RefCounted

## Static utility for cursor shape management


## Set cursor to default arrow
static func set_arrow() -> void:
	if Input.get_current_cursor_shape() != Input.CURSOR_ARROW:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Set cursor to move shape (for panning/dragging)
static func set_move() -> void:
	if Input.get_current_cursor_shape() != Input.CURSOR_MOVE:
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)


## Set cursor to pointing hand (for interactive elements)
static func set_pointing_hand() -> void:
	if Input.get_current_cursor_shape() != Input.CURSOR_POINTING_HAND:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
