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

## References to other managers
var unit_manager: Node
var phase_manager: Node

## Battle statistics
var current_turn: int = 0
var units_defeated: Dictionary = {}  # unit_name -> kills
var damage_dealt: Dictionary = {}    # unit_name -> total_damage
var main_character: Unit = null

## Battle state
var battle_active: bool = false
var checking_conditions: bool = false

func _ready():
	# Get manager references
	unit_manager = get_node("/root/Main/GameManager/UnitManager")
	phase_manager = get_node("/root/Main/GameManager/PhaseManager")
	
	# Connect to phase changes
	if phase_manager:
		phase_manager.phase_changed.connect(_on_phase_changed)
	
	# Connect to unit signals
	SignalBus.unit_died.connect(_on_unit_died)

## Initialize battle with objectives
##
## @param battle_objectives: BattleObjectives resource for this map
## @param main_char: The main character unit (required)
func start_battle(battle_objectives: BattleObjectives, main_char: Unit):
	objectives = battle_objectives
	main_character = main_char
	battle_active = true
	current_turn = 0
	units_defeated.clear()
	damage_dealt.clear()
	
	DebugLog.success("Battle started with objectives")

func _on_phase_changed(new_phase):
	if new_phase == phase_manager.GamePhase.PLAYER_TURN:
		current_turn += 1
		DebugLog.log("Turn %d" % current_turn, "purple")
	
	# Check conditions after each phase
	if battle_active:
		check_all_conditions()

func _on_unit_died(unit: Unit):
	# Track who defeated this unit (for MVP)
	if unit.team == 1:  # Enemy died
		# TODO: Track who got the kill
		pass
	
	# Check defeat conditions immediately
	if battle_active:
		check_defeat_conditions()

## Check all victory and defeat conditions
func check_all_conditions():
	if checking_conditions:
		return
	
	checking_conditions = true
	
	# Check defeat first (takes priority)
	check_defeat_conditions()
	
	if battle_active:
		check_victory_conditions()
	
	checking_conditions = false

## Check if any defeat conditions are met
func check_defeat_conditions():
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
func check_victory_conditions():
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
	
	var enemies = unit_manager.enemy_units
	for enemy in enemies:
		if enemy.is_alive():
			return false
	
	return enemies.size() > 0

func check_all_units_dead() -> bool:
	if not unit_manager:
		return false
	
	var player_units = unit_manager.player_units
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
	
	for unit in unit_manager.player_units:
		if unit.unit_name == objectives.vip_unit_name:
			return unit
	
	return null

func check_player_reached_location() -> bool:
	if not unit_manager:
		return false
	
	for unit in unit_manager.player_units:
		if unit.grid_position in objectives.reach_locations:
			return true
	
	return false

func check_enemy_reached_location() -> bool:
	if not unit_manager:
		return false
	
	for unit in unit_manager.enemy_units:
		if unit.grid_position in objectives.defend_locations:
			return true
	
	return false

## Trigger victory
func trigger_victory():
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
func trigger_defeat(reason: String):
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
	for unit in unit_manager.player_units:
		if unit.is_alive():
			count += 1
	
	return count

## Record a kill for MVP tracking
##
## @param killer_name: Name of unit who got the kill
func record_kill(killer_name: String):
	if not units_defeated.has(killer_name):
		units_defeated[killer_name] = 0
	units_defeated[killer_name] += 1

## Record damage for MVP tracking
##
## @param unit_name: Name of unit who dealt damage
## @param amount: Damage amount
func record_damage(unit_name: String, amount: int):
	if not damage_dealt.has(unit_name):
		damage_dealt[unit_name] = 0
	damage_dealt[unit_name] += amount
