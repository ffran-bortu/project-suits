"""
FILE: battle_objectives.gd
PURPOSE: Defines and manages victory and defeat conditions for tactical battles.

OVERVIEW:
This resource stores all possible win and lose conditions for a battle map, including
scenarios like defeating all enemies, surviving turns, protecting VIPs, or reaching locations.
It provides comprehensive validation and repair functionality to ensure battle objectives
are always valid and achievable. The system supports both simple ("defeat all enemies") and
complex multi-condition scenarios.

FUNCTIONS IN THIS FILE:

1. validate_objectives()
   - What it does: Checks all conditions and parameters for errors and conflicts
   - Uses: Called before battle start and after loading from save data
   - Returns: Array of error message strings (empty if valid)

2. _validate_win_conditions()
   - What it does: Validates win conditions and their required parameters
   - Uses: Called by validate_objectives to check victory requirements
   - Returns: Array of error messages

3. _validate_lose_conditions()
   - What it does: Validates lose conditions and their required parameters
   - Uses: Called by validate_objectives to check defeat triggers
   - Returns: Array of error messages

4. _validate_parameters()
   - What it does: Validates numerical parameters like turn counts and location arrays
   - Uses: Called by validate_objectives for range checking
   - Returns: Array of error messages

5. _check_for_conflicts()
   - What it does: Identifies impossible scenarios like conflicting turn limits
   - Uses: Called by validate_objectives to detect logical conflicts
   - Returns: Array of warning messages

6. repair_objectives()
   - What it does: Fixes invalid objectives by clamping values and removing invalid conditions
   - Uses: Called automatically when loading corrupted save data
   - Returns: true if repairs were made, false if unchanged

7. get_fallback_objectives()
   - What it does: Creates default valid objectives ("defeat all enemies")
   - Uses: Called when objectives are unfixable or missing
   - Returns: New BattleObjectives instance with safe defaults

8. has_win_condition(condition)
   - What it does: Checks if specific win condition is active
   - Uses: Battle system queries this to determine victory evaluation
   - Returns: true if condition is in win_conditions array

9. has_lose_condition(condition)
   - What it does: Checks if specific lose condition is active
   - Uses: Battle system queries this to determine defeat evaluation
   - Returns: true if condition is in lose_conditions array

10. get_win_condition_description(condition)
    - What it does: Converts WinConditionType enum to human-readable text
    - Uses: UI displays this to show players the victory objectives
    - Returns: String description like "Defeat all enemy units"

11. get_lose_condition_description(condition)
    - What it does: Converts LoseConditionType enum to human-readable text
    - Uses: UI displays this to show players the failure conditions
    - Returns: String description like "Main character dies"

12. get_all_win_descriptions()
    - What it does: Gets descriptions for all active win conditions
    - Uses: Objective screen displays all ways to win the battle
    - Returns: Array of description strings

13. get_all_lose_descriptions()
    - What it does: Gets descriptions for all active lose conditions
    - Uses: Objective screen displays all ways to lose the battle
    - Returns: Array of description strings

14. serialize()
    - What it does: Converts objectives to Dictionary for save files
    - Uses: Save system calls this to persist battle objectives
    - Returns: Dictionary with all objective data

15. deserialize(data)
    - What it does: Loads objectives from save data Dictionary
    - Uses: Load system restores battle objectives from saved games
    - Returns: true if successful, false if data invalid

16. get_debug_summary()
    - What it does: Creates formatted debug output showing all objectives
    - Uses: Development debugging and testing objective configurations
    - Returns: Multi-line string summary

17. debug_print()
    - What it does: Prints debug summary to console
    - Uses: Quick debugging during development
    - Returns: void

NOTES:
- Supports both simple single-condition and complex multi-condition battles
- victory_requires_all flag determines if conditions use AND or OR logic
- MAIN_CHARACTER_DIES is always implicitly checked as a lose condition
- Includes economic validation (no impossible turn requirements)
- Integrates with save/load system via serialize/deserialize
"""


class_name BattleObjectives
extends Resource

## Defines victory and defeat conditions for a battle with comprehensive validation

# --- Objective Type Enums ---
enum WinConditionType {
	DEFEAT_ALL_ENEMIES = 0,
	SURVIVE_TURNS = 1,
	REACH_LOCATION = 2,
	PROTECT_VIP = 3
}

enum LoseConditionType {
	MAIN_CHARACTER_DIES = 0,    # Always implicitly checked
	ALL_UNITS_DIE = 1,
	VIP_DIES = 2,
	ENEMY_REACHES_LOCATION = 3,
	TIME_LIMIT = 4
}

# --- Validation Constants ---
const MIN_TURN_COUNT: int = 1
const MAX_TURN_COUNT: int = 100
const MAX_LOCATIONS: int = 20

# --- Active Conditions ---
## Active win conditions for this battle
@export var win_conditions: Array[WinConditionType] = [WinConditionType.DEFEAT_ALL_ENEMIES]

## Active lose conditions (MAIN_CHARACTER_DIES always implicitly active)
@export var lose_conditions: Array[LoseConditionType] = [LoseConditionType.ALL_UNITS_DIE]

# --- Condition Parameters ---
## For SURVIVE_TURNS condition - must be positive
@export_range(1, 100) var survive_turn_count: int = 10

## For REACH_LOCATION condition
@export var reach_locations: Array[Vector2i] = []

## For PROTECT_VIP condition - must match actual unit name
@export var vip_unit_name: String = ""

## For TIME_LIMIT condition - must be positive
@export_range(1, 100) var time_limit_turns: int = 20

## For ENEMY_REACHES_LOCATION condition
@export var defend_locations: Array[Vector2i] = []

# --- Optional Objectives ---
## Whether all win conditions must be met (true) or any (false)
@export var victory_requires_all: bool = false

## Optional objective descriptions for UI
@export_multiline var objective_description: String = ""


## Validate all objectives and parameters
## @return: Array of error messages (empty if valid)
func validate_objectives() -> Array[String]:
	var errors: Array[String] = []
	
	# Validate win conditions
	errors.append_array(_validate_win_conditions())
	
	# Validate lose conditions
	errors.append_array(_validate_lose_conditions())
	
	# Validate parameters
	errors.append_array(_validate_parameters())
	
	# Check for conflicts
	errors.append_array(_check_for_conflicts())
	
	return errors


## Validate win conditions and their parameters
## @return: Array of error messages
func _validate_win_conditions() -> Array[String]:
	var errors: Array[String] = []
	
	if win_conditions.is_empty():
		errors.append("No win conditions specified - battle cannot be won")
	
	for condition in win_conditions:
		match condition:
			WinConditionType.SURVIVE_TURNS:
				if survive_turn_count < MIN_TURN_COUNT:
					errors.append("SURVIVE_TURNS: turn count must be at least %d" % MIN_TURN_COUNT)
			
			WinConditionType.REACH_LOCATION:
				if reach_locations.is_empty():
					errors.append("REACH_LOCATION: no locations specified")
				elif reach_locations.size() > MAX_LOCATIONS:
					errors.append("REACH_LOCATION: too many locations (%d, max %d)" % [
						reach_locations.size(), MAX_LOCATIONS
					])
			
			WinConditionType.PROTECT_VIP:
				if vip_unit_name.is_empty():
					errors.append("PROTECT_VIP: no VIP unit name specified")
	
	return errors


## Validate lose conditions and their parameters
## @return: Array of error messages
func _validate_lose_conditions() -> Array[String]:
	var errors: Array[String] = []
	
	for condition in lose_conditions:
		match condition:
			LoseConditionType.VIP_DIES:
				if vip_unit_name.is_empty():
					errors.append("VIP_DIES: no VIP unit name specified")
			
			LoseConditionType.ENEMY_REACHES_LOCATION:
				if defend_locations.is_empty():
					errors.append("ENEMY_REACHES_LOCATION: no locations specified")
				elif defend_locations.size() > MAX_LOCATIONS:
					errors.append("ENEMY_REACHES_LOCATION: too many locations (%d, max %d)" % [
						defend_locations.size(), MAX_LOCATIONS
					])
			
			LoseConditionType.TIME_LIMIT:
				if time_limit_turns < MIN_TURN_COUNT:
					errors.append("TIME_LIMIT: turn count must be at least %d" % MIN_TURN_COUNT)
	
	return errors


## Validate numerical parameters
## @return: Array of error messages
func _validate_parameters() -> Array[String]:
	var errors: Array[String] = []
	
	if survive_turn_count < MIN_TURN_COUNT or survive_turn_count > MAX_TURN_COUNT:
		errors.append("survive_turn_count out of valid range [%d, %d]" % [MIN_TURN_COUNT, MAX_TURN_COUNT])
	
	if time_limit_turns < MIN_TURN_COUNT or time_limit_turns > MAX_TURN_COUNT:
		errors.append("time_limit_turns out of valid range [%d, %d]" % [MIN_TURN_COUNT, MAX_TURN_COUNT])
	
	return errors


## Check for conflicting conditions
## @return: Array of warning messages
func _check_for_conflicts() -> Array[String]:
	var warnings: Array[String] = []
	
	# SURVIVE_TURNS and TIME_LIMIT conflict
	if (WinConditionType.SURVIVE_TURNS in win_conditions and 
		LoseConditionType.TIME_LIMIT in lose_conditions):
		if survive_turn_count >= time_limit_turns:
			warnings.append("CONFLICT: SURVIVE_TURNS (%d) >= TIME_LIMIT (%d) - impossible to win" % [
				survive_turn_count, time_limit_turns
			])
	
	# Both VIP conditions active but no VIP specified
	if (WinConditionType.PROTECT_VIP in win_conditions or 
		LoseConditionType.VIP_DIES in lose_conditions):
		if vip_unit_name.is_empty():
			warnings.append("VIP conditions active but no VIP unit specified")
	
	return warnings


## Attempt to repair invalid objectives
## @return: true if repaired successfully, false if unfixable
func repair_objectives() -> bool:
	var was_repaired := false
	
	# Ensure at least one win condition
	if win_conditions.is_empty():
		win_conditions = [WinConditionType.DEFEAT_ALL_ENEMIES]
		was_repaired = true
	
	# Clamp numerical values
	if survive_turn_count < MIN_TURN_COUNT:
		survive_turn_count = MIN_TURN_COUNT
		was_repaired = true
	elif survive_turn_count > MAX_TURN_COUNT:
		survive_turn_count = MAX_TURN_COUNT
		was_repaired = true
	
	if time_limit_turns < MIN_TURN_COUNT:
		time_limit_turns = MIN_TURN_COUNT
		was_repaired = true
	elif time_limit_turns > MAX_TURN_COUNT:
		time_limit_turns = MAX_TURN_COUNT
		was_repaired = true
	
	# Limit location arrays
	if reach_locations.size() > MAX_LOCATIONS:
		reach_locations = reach_locations.slice(0, MAX_LOCATIONS)
		was_repaired = true
	
	if defend_locations.size() > MAX_LOCATIONS:
		defend_locations = defend_locations.slice(0, MAX_LOCATIONS)
		was_repaired = true
	
	# Remove invalid VIP conditions if no VIP name
	if vip_unit_name.is_empty():
		if WinConditionType.PROTECT_VIP in win_conditions:
			win_conditions.erase(WinConditionType.PROTECT_VIP)
			was_repaired = true
		if LoseConditionType.VIP_DIES in lose_conditions:
			lose_conditions.erase(LoseConditionType.VIP_DIES)
			was_repaired = true
	
	# Remove location conditions without locations
	if reach_locations.is_empty():
		if WinConditionType.REACH_LOCATION in win_conditions:
			win_conditions.erase(WinConditionType.REACH_LOCATION)
			was_repaired = true
	
	if defend_locations.is_empty():
		if LoseConditionType.ENEMY_REACHES_LOCATION in lose_conditions:
			lose_conditions.erase(LoseConditionType.ENEMY_REACHES_LOCATION)
			was_repaired = true
	
	return was_repaired


## Get fallback objectives (always valid)
## @return: New BattleObjectives with safe defaults
static func get_fallback_objectives() -> BattleObjectives:
	var fallback := BattleObjectives.new()
	var win_conds: Array[WinConditionType] = [WinConditionType.DEFEAT_ALL_ENEMIES]
	var lose_conds: Array[LoseConditionType] = [LoseConditionType.ALL_UNITS_DIE]
	fallback.win_conditions = win_conds
	fallback.lose_conditions = lose_conds
	fallback.survive_turn_count = 10
	fallback.time_limit_turns = 20
	return fallback


## Check if specific win condition is active
## @param condition: Win condition to check
## @return: true if active, false otherwise
func has_win_condition(condition: WinConditionType) -> bool:
	return condition in win_conditions


## Check if specific lose condition is active
## @param condition: Lose condition to check
## @return: true if active, false otherwise
func has_lose_condition(condition: LoseConditionType) -> bool:
	return condition in lose_conditions


## Get human-readable description of win condition
## @param condition: Win condition type
## @return: Description string
func get_win_condition_description(condition: WinConditionType) -> String:
	match condition:
		WinConditionType.DEFEAT_ALL_ENEMIES:
			return "Defeat all enemy units"
		WinConditionType.SURVIVE_TURNS:
			return "Survive for %d turns" % survive_turn_count
		WinConditionType.REACH_LOCATION:
			return "Move any unit to designated location (%d locations)" % reach_locations.size()
		WinConditionType.PROTECT_VIP:
			return "Protect %s until battle ends" % vip_unit_name
		_:
			return "Unknown condition"


## Get human-readable description of lose condition
## @param condition: Lose condition type
## @return: Description string
func get_lose_condition_description(condition: LoseConditionType) -> String:
	match condition:
		LoseConditionType.MAIN_CHARACTER_DIES:
			return "Main character dies"
		LoseConditionType.ALL_UNITS_DIE:
			return "All player units are defeated"
		LoseConditionType.VIP_DIES:
			return "%s dies" % vip_unit_name
		LoseConditionType.ENEMY_REACHES_LOCATION:
			return "Enemy reaches defended location (%d locations)" % defend_locations.size()
		LoseConditionType.TIME_LIMIT:
			return "Time limit expires (%d turns)" % time_limit_turns
		_:
			return "Unknown condition"


## Get all win condition descriptions
## @return: Array of description strings
func get_all_win_descriptions() -> Array[String]:
	var descriptions: Array[String] = []
	for condition in win_conditions:
		descriptions.append(get_win_condition_description(condition))
	return descriptions


## Get all lose condition descriptions
## @return: Array of description strings
func get_all_lose_descriptions() -> Array[String]:
	var descriptions: Array[String] = []
	for condition in lose_conditions:
		descriptions.append(get_lose_condition_description(condition))
	return descriptions


## Serialize objectives for save/load
## @return: Dictionary representation
func serialize() -> Dictionary:
	return {
		"win_conditions": win_conditions,
		"lose_conditions": lose_conditions,
		"survive_turn_count": survive_turn_count,
		"reach_locations": reach_locations,
		"vip_unit_name": vip_unit_name,
		"time_limit_turns": time_limit_turns,
		"defend_locations": defend_locations,
		"victory_requires_all": victory_requires_all,
		"objective_description": objective_description
	}


## Deserialize objectives from save data
## @param data: Dictionary to deserialize from
## @return: true if successful, false otherwise
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	win_conditions = data.get("win_conditions", [WinConditionType.DEFEAT_ALL_ENEMIES])
	lose_conditions = data.get("lose_conditions", [LoseConditionType.ALL_UNITS_DIE])
	survive_turn_count = data.get("survive_turn_count", 10)
	reach_locations = data.get("reach_locations", [])
	vip_unit_name = data.get("vip_unit_name", "")
	time_limit_turns = data.get("time_limit_turns", 20)
	defend_locations = data.get("defend_locations", [])
	victory_requires_all = data.get("victory_requires_all", false)
	objective_description = data.get("objective_description", "")
	
	# Validate after deserialization
	var errors := validate_objectives()
	if not errors.is_empty():
		push_warning("Deserialized objectives have errors: %s" % ", ".join(errors))
		return repair_objectives()
	
	return true


## Get summary of objectives for debugging
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Battle Objectives ===\n"
	
	summary += "\nWin Conditions:\n"
	for desc in get_all_win_descriptions():
		summary += "  - %s\n" % desc
	
	summary += "\nLose Conditions:\n"
	for desc in get_all_lose_descriptions():
		summary += "  - %s\n" % desc
	
	summary += "\nParameters:\n"
	summary += "  Victory requires all: %s\n" % victory_requires_all
	
	if not vip_unit_name.is_empty():
		summary += "  VIP Unit: %s\n" % vip_unit_name
	
	if not reach_locations.is_empty():
		summary += "  Reach locations: %s\n" % reach_locations
	
	if not defend_locations.is_empty():
		summary += "  Defend locations: %s\n" % defend_locations
	
	# Validation status
	var errors := validate_objectives()
	if errors.is_empty():
		summary += "\n✓ Objectives valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Print objectives to console for debugging
func debug_print() -> void:
	print(get_debug_summary())
