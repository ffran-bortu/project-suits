"""
FILE: battle_manager.gd
PURPOSE: Manages battle flow including victory/defeat conditions and battle statistics tracking.

OVERVIEW:
This system monitors win/loss conditions throughout the battle, checking them each turn and after
significant events (like unit death). When battle-ending conditions are met, it triggers the 
appropriate victory or defeat screens and calculates final battle statistics including MVP, 
surviving units, and turn count. It serves as the authoritative source for "is the battle over?"

FUNCTIONS IN THIS FILE:

1. start_battle(battle_objectives, main_char)
   - What it does: Initializes battle with victory/defeat conditions and tracks the main character
   - Uses: Called when a new battle map loads to set up win/loss rules
   - Returns: void

2. check_all_conditions()
   - What it does: Evaluates all victory and defeat conditions to see if battle should end
   - Uses: Called every phase change and after unit deaths
   - Returns: void

3. check_defeat_conditions()
   - What it does: Checks if any lose conditions are met (main character death, time limit, etc.)
   - Uses: Called by check_all_conditions(), given priority over victory checks
   - Returns: void

4. check_victory_conditions()
   - What it does: Checks if any win conditions are met (defeat all enemies, survive X turns, etc.)
   - Uses: Called after defeat check passes in check_all_conditions()
   - Returns: void

5. check_all_enemies_defeated()
   - What it does: Returns true if all enemy team units are dead
   - Uses: Used by DEFEAT_ALL_ENEMIES victory condition
   - Returns: bool

6. check_all_units_dead()
   - What it does: Returns true if all player units are dead
   - Uses: Used by ALL_UNITS_DIE lose condition
   - Returns: bool

7. check_vip_dead()
   - What it does: Returns true if the designated VIP unit has died
   - Uses: Used by VIP_DIES lose condition
   - Returns: bool

8. find_vip_unit()
   - What it does: Searches player units for the VIP by name matching
   - Uses: Helper for VIP-based win/loss conditions
   - Returns: Unit (VIP unit or null if not found)

9. check_player_reached_location()
   - What it does: Returns true if any player unit is standing on a designated reach location
   - Uses: Used by REACH_LOCATION victory condition
   - Returns: bool

10. check_enemy_reached_location()
    - What it does: Returns true if any enemy unit is standing on a defended location
    - Uses: Used by ENEMY_REACHES_LOCATION lose condition
    - Returns: bool

11. trigger_victory()
    - What it does: Ends battle as won, calculates stats (MVP, survivors), emits battle_won signal
    - Uses: Called when any victory condition is met
    - Returns: void

12. trigger_defeat(reason)
    - What it does: Ends battle as lost, emits battle_lost signal with reason string
    - Uses: Called when any defeat condition is met
    - Returns: void

13. calculate_mvp()
    - What it does: Determines which unit got the most kills during battle
    - Uses: Called in trigger_victory() to include in battle stats
	- Returns: String (unit name or "No MVP")

14. record_kill(killer_name)
    - What it does: Increments kill count for a unit (for MVP tracking)
    - Uses: Should be called by combat manager when a unit defeats an enemy
    - Returns: void

15. record_damage(unit_name, amount)
    - What it does: Adds to total damage dealt by a unit (for alternate MVP calculation)
    - Uses: Can be called by combat manager for more granular MVP tracking
    - Returns: void

NOTES:
- Depends on UnitManager for unit queries (get_units_by_team)
- Depends on PhaseManager for turn tracking
- Connects to SignalBus.unit_died to react to deaths immediately
- Emits: battle_won(stats), battle_lost(reason)
- Current Implementation Issue: Uses hard-coded get_node() paths (violates Section 2.3)
  Should be refactored to use dependency injection via setup() method
"""

class_name BattleManager
extends Node
## Manages battle flow including victory/defeat conditions
##
## Checks win/loss conditions each turn and triggers appropriate
## screens when battle ends. Tracks battle statistics.

signal battle_won(stats: Dictionary)
signal battle_lost(reason: String)

## Current battle objectives
var objectives: BattleObjectives

## Battle statistics
var current_turn: int = 0
var units_defeated: Dictionary = {}  # unit_name -> kills
var damage_dealt: Dictionary = {}    # unit_name -> total_damage
var main_character: Unit = null

## Battle state
var battle_active: bool = false
var checking_conditions: bool = false

# --- Dependencies (Injected) ---
var unit_manager: Node = null
var combat_manager: Node = null
var phase_manager: Node = null

## Set dependencies for the battle manager
## @param unit_mgr: UnitManager node
## @param combat_mgr: CombatManager node
## @param phase_mgr: PhaseManager node
func set_dependencies(unit_mgr: Node, combat_mgr: Node, phase_mgr: Node) -> void:
	unit_manager = unit_mgr
	combat_manager = combat_mgr
	phase_manager = phase_mgr
	
	_validate_dependencies()

## Validate required dependencies
func _validate_dependencies() -> void:
	if not unit_manager:
		DebugLog.error("BattleManager: UnitManager not set")
	if not combat_manager:
		DebugLog.error("BattleManager: CombatManager not set")
	if not phase_manager:
		DebugLog.error("BattleManager: PhaseManager not set")

func _ready() -> void:
	# Dependencies should be injected by Main or GameController
	add_to_group("battle_manager")
	if phase_manager: # Ensure phase_manager is set before connecting
		phase_manager.phase_changed.connect(_on_phase_changed)
	
	# Connect to unit signals
	SignalBus.unit_died.connect(_on_unit_died)

## Initialize battle with objectives
##
## @param battle_objectives: BattleObjectives resource for this map
## @param main_char: The main character unit (required)
func start_battle(battle_objectives: BattleObjectives, main_char: Unit) -> void:
	objectives = battle_objectives
	main_character = main_char
	battle_active = true
	current_turn = 0
	units_defeated.clear()
	damage_dealt.clear()
	
	DebugLog.success("Battle started with objectives")

func _on_phase_changed(new_phase) -> void:
	if new_phase == phase_manager.GamePhase.PLAYER_TURN:
		current_turn += 1
		DebugLog.log("Turn %d" % current_turn, "purple")
	
	# Check conditions after each phase
	if battle_active:
		check_all_conditions()

func _on_unit_died(unit: Unit) -> void:
	DebugLog.log("BattleManager: Unit died %s. Active? %s" % [unit.unit_name, battle_active], "yellow")
	# Track who defeated this unit (for MVP)
	if unit.team == 1:  # Enemy died
		# TODO: Track who got the kill
		pass
	
	# Check all conditions (victory and defeat)
	if battle_active:
		check_all_conditions()

## Check all victory and defeat conditions
func check_all_conditions() -> void:
	if checking_conditions:
		return
	
	checking_conditions = true
	DebugLog.log("BattleManager: Checking all conditions", "gray")
	
	# Check defeat first (takes priority)
	check_defeat_conditions()
	
	if battle_active:
		check_victory_conditions()
	
	checking_conditions = false

## Check if any defeat conditions are met
func check_defeat_conditions() -> void:
	# ALWAYS check main character
	if main_character and not main_character.is_alive():
		trigger_defeat("The main character has fallen!")
		return
	
	# Check other lose conditions
	for condition in objectives.lose_conditions:
		match condition:
			BattleObjectives.LoseConditionType.ALL_UNITS_DIE:
				if check_all_units_dead():
					trigger_defeat("All units have been defeated!")
					return
			
			BattleObjectives.LoseConditionType.VIP_DIES:
				if check_vip_dead():
					trigger_defeat("The VIP has been defeated!")
					return
			
			BattleObjectives.LoseConditionType.ENEMY_REACHES_LOCATION:
				if check_enemy_reached_location():
					trigger_defeat("Enemies reached the target location!")
					return
			
			BattleObjectives.LoseConditionType.TIME_LIMIT:
				if current_turn > objectives.time_limit_turns:
					trigger_defeat("Time limit exceeded!")
					return

## Check if any victory conditions are met
func check_victory_conditions() -> void:
	for condition in objectives.win_conditions:
		match condition:
			BattleObjectives.WinConditionType.DEFEAT_ALL_ENEMIES:
				if check_all_enemies_defeated():
					trigger_victory()
					return
			
			BattleObjectives.WinConditionType.SURVIVE_TURNS:
				if current_turn >= objectives.survive_turn_count:
					trigger_victory()
					return
			
			BattleObjectives.WinConditionType.REACH_LOCATION:
				if check_player_reached_location():
					trigger_victory()
					return
			
			BattleObjectives.WinConditionType.PROTECT_VIP:
				# VIP survived X turns
				if current_turn >= objectives.survive_turn_count:
					var vip = find_vip_unit()
					if vip and vip.is_alive():
						trigger_victory()
						return

## Condition checkers
func check_all_enemies_defeated() -> bool:
	if not unit_manager:
		return false
	
	var enemies = unit_manager.get_units_by_team(1)  # Team 1 = enemies
	DebugLog.log("BattleManager: Checking enemies defeated. Count: %d" % enemies.size(), "gray")
	
	for enemy in enemies:
		if enemy.is_alive():
			DebugLog.log("  Enemy still alive: %s" % enemy.unit_name, "gray")
			return false
	
	# If we get here, no living enemies were found
	return true 

func check_all_units_dead() -> bool:
	if not unit_manager:
		return false
	
	var player_units = unit_manager.get_units_by_team(0)  # Team 0 = player
	for unit in player_units:
		if unit.is_alive():
			return false
	
	return true

func check_vip_dead() -> bool:
	var vip = find_vip_unit()
	if vip:
		return not vip.is_alive()
	return false

func find_vip_unit() -> Unit:
	if not unit_manager or objectives.vip_unit_name == "":
		return null
	
	var player_units = unit_manager.get_units_by_team(0)  # Team 0 = player
	for unit in player_units:
		if unit.unit_name == objectives.vip_unit_name:
			return unit
	
	return null

func check_player_reached_location() -> bool:
	if not unit_manager:
		return false
	
	var player_units = unit_manager.get_units_by_team(0)  # Team 0 = player
	for unit in player_units:
		if unit.grid_position in objectives.reach_locations:
			return true
	
	return false

func check_enemy_reached_location() -> bool:
	if not unit_manager:
		return false
	
	var enemy_units = unit_manager.get_units_by_team(1)  # Team 1 = enemies
	for unit in enemy_units:
		if unit.grid_position in objectives.defend_locations:
			return true
	
	return false

## Trigger victory
func trigger_victory() -> void:
	if not battle_active:
		return
	
	battle_active = false
	DebugLog.success("VICTORY!")
	
	# Calculate stats
	var stats = {
		"turns": current_turn,
		"mvp": calculate_mvp(),
		"units_survived": count_surviving_units()
	}
	
	battle_won.emit(stats)

## Trigger defeat
##
## @param reason: Why the player lost
func trigger_defeat(reason: String) -> void:
	if not battle_active:
		return
	
	battle_active = false
	DebugLog.error("DEFEAT: " + reason)
	
	battle_lost.emit(reason)

## Calculate MVP (unit with most kills/damage)
func calculate_mvp() -> String:
	if units_defeated.is_empty() and damage_dealt.is_empty():
		return "No MVP"
	
	# Simple: most kills
	var max_kills = 0
	var mvp_name = ""
	
	for unit_name in units_defeated:
		if units_defeated[unit_name] > max_kills:
			max_kills = units_defeated[unit_name]
			mvp_name = unit_name
	
	return mvp_name if mvp_name != "" else "No MVP"

## Count surviving player units
func count_surviving_units() -> int:
	if not unit_manager:
		return 0
	
	var count = 0
	var player_units = unit_manager.get_units_by_team(0)  # Team 0 = player
	for unit in player_units:
		if unit.is_alive():
			count += 1
	
	return count

## Record a kill for MVP tracking
##
## @param killer_name: Name of unit who got the kill
func record_kill(killer_name: String) -> void:
	if not units_defeated.has(killer_name):
		units_defeated[killer_name] = 0
	units_defeated[killer_name] += 1

## Record damage for MVP tracking
##
## @param unit_name: Name of unit who dealt damage
## @param amount: Damage amount
func record_damage(unit_name: String, amount: int) -> void:
	if not damage_dealt.has(unit_name):
		damage_dealt[unit_name] = 0
	damage_dealt[unit_name] += amount
