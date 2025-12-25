class_name BattleObjectives
extends Resource
## Defines victory and defeat conditions for a battle
##
## This resource is assigned per-map to determine how the player
## wins or loses the battle. Multiple conditions can be active.

enum WinConditionType {
	DEFEAT_ALL_ENEMIES,
	SURVIVE_TURNS,
	REACH_LOCATION,
	PROTECT_VIP
}

enum LoseConditionType {
	MAIN_CHARACTER_DIES,    # Always checked
	ALL_UNITS_DIE,
	VIP_DIES,
	ENEMY_REACHES_LOCATION,
	TIME_LIMIT
}

## Active win conditions for this battle
@export var win_conditions: Array[WinConditionType] = [WinConditionType.DEFEAT_ALL_ENEMIES]

## Active lose conditions (MAIN_CHARACTER_DIES always active)
@export var lose_conditions: Array[LoseConditionType] = [LoseConditionType.ALL_UNITS_DIE]

## For SURVIVE_TURNS condition
@export var survive_turn_count: int = 10

## For REACH_LOCATION condition
@export var reach_locations: Array[Vector2i] = []

## For PROTECT_VIP condition
@export var vip_unit_name: String = ""

## For TIME_LIMIT condition
@export var time_limit_turns: int = 20

## For ENEMY_REACHES_LOCATION condition
@export var defend_locations: Array[Vector2i] = []
