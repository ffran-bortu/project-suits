"""
FILE: signal_bus.gd
PURPOSE: Global event bus for cross-system communication via signals.

OVERVIEW:
This autoload provides a centralized hub for important game events that need to be broadcast to
multiple unrelated systems. By routing signals through SignalBus instead of direct connections,
we achieve loose coupling - systems don't need references to each other, they just emit/listen
to the bus. This is especially important for UI responding to gameplay events (unit health changes,
combat start/end) and gameplay responding to player input (turn ended, cursor moved).

SIGNALS IN THIS FILE:

1. action_menu_requested(unit_world_pos: Vector3)
   - When emitted: After unit completes movement and can choose an action
   - Who emits: UnitManager or movement system
   - Who listens: ActionMenu UI to show "Attack/Wait/Items" popup

2. map_cursor_moved(grid_pos: Vector2i)
   - When emitted: Player moves cursor to a new grid tile
   - Who emits: CursorController
   - Who listens: UnitInfoPanel (to show tile/unit details), Grid (to update hover highlight)

3. unit_focus_changed(unit)
   - When emitted: Selection changes to a different unit
   - Who emits: UnitManager or cursor system
   - Who listens: Camera (to follow unit), UI panels (to show stats)

4. turn_ended
   - When emitted: Player confirms "End Turn" action
   - Who emits: UI (end turn button) or input system
   - Who listens: PhaseManager (to advance to enemy phase)

5. unit_health_changed(unit, old_hp: int, new_hp: int)
   - When emitted: Unit takes damage or heals
   - Who emits: Unit's take_damage() or heal() methods
   - Who listens: HPBar3D (to animate health change), BattleManager (to check defeat conditions)

6. unit_died(unit: Unit)
   - When emitted: Unit's HP reaches 0
   - Who emits: Unit's take_damage() when HP drops to 0
   - Who listens: BattleManager (check victory/defeat), UnitManager (remove from active list)

7. combat_started(attacker, target)
   - When emitted: Two units begin combat exchange
   - Who emits: CombatManager before calculating damage
   - Who listens: Camera (to focus on fight), UI (to hide/show forecast), BondSystem (for adjacency)

8. combat_ended(attacker, target)
   - When emitted: Combat exchange is fully resolved
   - Who emits: CombatManager after applying all damage/effects
   - Who listens: Camera (return control), UI (restore normal state)

NOTES:
- Autoload singleton (accessible as SignalBus from anywhere)
- All signals use @warning_ignore("unused_signal") to suppress false warnings
- This is a leaf node (no dependencies on other systems)
- Used by: virtually every system in the game
- Best Practice: Document what each signal means when connecting/emitting it
"""

# signal_bus.gd - Global Event Bus
extends Node

## UI Signals
## Emitted when unit completes movement and action menu should be shown
## @param unit_world_pos: 3D world position where menu should appear
@warning_ignore("unused_signal")
signal action_menu_requested(unit_world_pos: Vector3)

## Emitted when map cursor moves to a new position
## @param grid_pos: New grid position of cursor
@warning_ignore("unused_signal")
signal map_cursor_moved(grid_pos: Vector2i)

## Emitted when a unit selection changes
@warning_ignore("unused_signal")
signal unit_focus_changed(unit: Unit)

## Emitted when player confirms end turn
@warning_ignore("unused_signal")
signal turn_ended

## Unit Signals
## Emitted when a unit's health changes
## @param unit: Unit node that was affected
## @param old_hp: Previous health value
## @param new_hp: New health value
@warning_ignore("unused_signal")
signal unit_health_changed(unit: Unit, old_hp: int, new_hp: int)

## Emitted when a unit dies in combat
@warning_ignore("unused_signal")
signal unit_died(unit: Unit)

## Combat Signals
## Emitted when combat begins between two units
## @param attacker: Attacking unit
## @param target: Defending unit
@warning_ignore("unused_signal")
signal combat_started(attacker: Unit, target: Unit)

## Emitted when combat concludes
## @param attacker: Attacking unit
## @param target: Defending unit
@warning_ignore("unused_signal")
signal combat_ended(attacker: Unit, target: Unit)

## UI Request Signals
## Emitted when combat forecast should be displayed
@warning_ignore("unused_signal")
signal combat_forecast_requested(attacker: Node, defender: Node, stats: Dictionary)

## Emitted when a unit levels up
@warning_ignore("unused_signal")
signal level_up(character: Resource, new_level: int, stat_gains: Dictionary)

## Deployment Signals
@warning_ignore("unused_signal")
signal deployment_started(spawn_tiles: Array[Vector2i])

@warning_ignore("unused_signal")
signal deployment_tile_clicked(grid_pos: Vector2i)
