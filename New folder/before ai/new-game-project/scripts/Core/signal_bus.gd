# signal_bus.gd - Global Event Bus
extends Node

## UI Signals
## Emitted when unit completes movement and action menu should be shown
## @param unit_world_pos: 3D world position where menu should appear
signal action_menu_requested(unit_world_pos: Vector3)

## Emitted when map cursor moves to a new position
## @param grid_pos: New grid position of cursor
signal map_cursor_moved(grid_pos: Vector2i)

## Emitted when a unit selection changes
signal unit_focus_changed(unit)

## Emitted when player confirms end turn
signal turn_ended

## Unit Signals
## Emitted when a unit's health changes
## @param unit: Unit node that was affected
## @param old_hp: Previous health value
## @param new_hp: New health value
signal unit_health_changed(unit, old_hp: int, new_hp: int)

## Emitted when a unit dies in combat
signal unit_died(unit: Unit)

## Combat Signals
## Emitted when combat begins between two units
## @param attacker: Attacking unit
## @param target: Defending unit
signal combat_started(attacker, target)

## Emitted when combat concludes
## @param attacker: Attacking unit
## @param target: Defending unit
signal combat_ended(attacker, target)
