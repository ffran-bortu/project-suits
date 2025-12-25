"""
FILE: enemy_ai.gd
PURPOSE: Enemy AI decision-making system with threat assessment, tactical positioning, and performance optimization.

OVERVIEW:
This manager decides what each enemy unit should do on their turn: attack, retreat, or wait. It evaluates all
player targets, calculates combat outcomes, assesses threats, and selects optimal actions/positions. Uses
weighted scoring for target selection (favoring kills and low HP targets), threat assessment for retreat
decisions, and aggressive caching for performance. Integrates with CombatManager for stat calculations and
UnitManager for positioning data.

FUNCTIONS IN THIS FILE:

1. set_dependencies(unit_mgr, combat_mgr)
   - What it does: Injects UnitManager and CombatManager dependencies
   - Uses: Called by Main or PhaseManager during initialization
   - Returns: void

2. decide_action(enemy_unit)
   - What it does: Main AI function - decides action for enemy's turn (attack/retreat/wait)
   - Uses: Called by PhaseManager for each enemy during enemy phase
   - Returns: Dictionary {action, target, move_to}

3. select_best_target(enemy_unit, potential_targets)
   - What it does: Evaluates all players, returns highest-scoring target
   - Uses: During decide_action() to choose who to attack
   - Returns: Node (Unit) or null

4. evaluate_target(attacker, target)
   - What it does: Scores target based on: lethal damage (+100), low HP (+50), distance (-5/tile), favorable matchup (+25)
   - Uses: For each potential target during selection
   - Returns: float (score, higher = better target)

5. calculate_best_attack_position(attacker, target)
   - What it does: Finds reachable position that allows attack at optimal range
   - Uses: After selecting target, to determine where to move
   - Returns: Vector2i (grid position)

6. find_retreat_position_optimized(unit, threats)
   - What it does: Finds reachable position farthest from threats (safety score = sum of distances)
   - Uses: When unit should retreat (low HP, surrounded, can be killed)
   - Returns: Vector2i (safest position)

7. _assess_threat_level(unit, threats)
   - What it does: Calculates HP ratio, nearby threat count, total incoming damage, can_be_killed flag
   - Uses: To determine if unit should retreat
   - Returns: Dictionary with threat assessment

8. _should_retreat(unit, threat_assessment)
   - What it does: Decides retreat based on: critical HP (<25%), can be killed, low HP + surrounded
   - Uses: After assessing threats
   - Returns: bool

9. clear_caches()
   - What it does: Clears all cached data (combat stats, movement ranges, threat map)
   - Uses: Called by PhaseManager at end of enemy turn
   - Returns: void

10. invalidate_cache_for_unit(unit)
    - What it does: Clears cached data for specific unit (when it moves/acts)
    - Uses: Called after each enemy action
    - Returns: void

11. _get_cached_combat_stats(attacker, defender)
    - What it does: Returns cached battle stats or calculates and caches them
    - Uses: For performance optimization in target evaluation
    - Returns: Dictionary {damage, hit_rate, crit_rate, is_double}

12. _get_cached_movement_range(unit)
    - What it does: Returns cached movement range or calculates via GridManager
    - Uses: For positioning decisions
    - Returns: Array (reachable cells)

13. get_manhattan_distance(a, b)
    - What it does: Calculates Manhattan distance between positions
    - Uses: For distance calculations in scoring
    - Returns: int

14. _validate_unit_for_ai(unit)
    - What it does: Checks unit is alive, has required methods, dependencies set
    - Uses: Before processing any AI logic
    - Returns: bool

NOTES:
- Single instance manager (one per battle scene)
- Scoring weights: KILL=100, LOW_HP=50, DISTANCE=-5/tile, FAVORABLE_MATCHUP=25
- Threat thresholds: DANGER=50% HP, CRITICAL=25% HP, THREAT_COUNT=3 enemies
- Retreat distance: MIN=3 tiles from threats, prefers max distance
- Performance: Caches combat stats (key: attacker_id-defender_id), movement ranges (key: unit_id)
- Cache invalidation: Per-unit after action, full clear at end of turn
- Depends on: UnitManager, CombatManager, GridManager
"""


extends Node

# --- AI Decision Constants ---
# Use centralized configuration
var WEIGHT_KILL: float = 100.0
var WEIGHT_LOW_HP: float = 50.0
var WEIGHT_DISTANCE: float = -5.0
var WEIGHT_FAVORABLE_MATCHUP: float = 25.0

var DANGER_THRESHOLD: float = 0.5
var CRITICAL_THRESHOLD: float = 0.25
var THREAT_COUNT_THRESHOLD: int = 3

var SAFE_ATTACK_DISTANCE: int = 2
var MIN_RETREAT_DISTANCE: int = 3

func _ready() -> void:
	if "EnemyAI" in GameConfig:
		var config = GameConfig.EnemyAI
		WEIGHT_KILL = config.get("WEIGHT_KILL", 100.0)
		WEIGHT_LOW_HP = config.get("WEIGHT_LOW_HP", 50.0)
		WEIGHT_DISTANCE = config.get("WEIGHT_DISTANCE", -5.0)
		WEIGHT_FAVORABLE_MATCHUP = config.get("WEIGHT_FAVORABLE_MATCHUP", 25.0)
		
		DANGER_THRESHOLD = config.get("DANGER_THRESHOLD", 0.5)
		CRITICAL_THRESHOLD = config.get("CRITICAL_THRESHOLD", 0.25)
		THREAT_COUNT_THRESHOLD = config.get("THREAT_COUNT_THRESHOLD", 3)
		
		SAFE_ATTACK_DISTANCE = config.get("SAFE_ATTACK_DISTANCE", 2)
		MIN_RETREAT_DISTANCE = config.get("MIN_RETREAT_DISTANCE", 3)

# --- Dependencies (Injected) ---
var unit_manager: Node = null
var combat_manager: Node = null

# --- Performance Caches ---
var _combat_stat_cache: Dictionary = {}    # (attacker_id, defender_id) -> stats
var _movement_range_cache: Dictionary = {} # unit_id -> reachable_cells
var _threat_map: Dictionary = {}           # grid_position -> threat_level

# --- AI State Tracking ---
var _cache_valid: bool = false


## Set AI dependencies with validation
## @param unit_mgr: UnitManager node
## @param combat_mgr: CombatManager node
func set_dependencies(unit_mgr: Node, combat_mgr: Node) -> void:
	unit_manager = unit_mgr
	combat_manager = combat_mgr
	
	_validate_dependencies()


## Validate all required dependencies
func _validate_dependencies() -> void:
	if not unit_manager:
		push_error("EnemyAI: UnitManager dependency is required")
	
	if not combat_manager:
		push_error("EnemyAI: CombatManager dependency is required")


## Main AI decision function for an enemy unit's turn
## @param enemy_unit: The enemy unit taking its turn
## @return: Dictionary with {action: String, target: Node, move_to: Vector2i}
func decide_action(enemy_unit: Unit) -> Dictionary:
	# Validate inputs
	if not _validate_unit_for_ai(enemy_unit):
		return _get_fallback_action(enemy_unit)
	
	# Get potential targets
	var player_units: Array = _get_player_units()
	if player_units.is_empty():
		return _create_wait_action(enemy_unit)
	
	# Assess threat level
	var _threat_assessment := _assess_threat_level(enemy_unit, player_units)
	
	# Decide on retreat vs attack
	# Decide on retreat vs attack
	# RETREAT DISABLED FOR TESTING
	#if _should_retreat(enemy_unit, threat_assessment):
	#	var retreat_pos := find_retreat_position_optimized(enemy_unit, player_units)
	#	if retreat_pos != enemy_unit.grid_position:
	#		DebugLog.log("AI: %s retreating (HP: %d%%)" % [
	#			enemy_unit.unit_name,
	#			int(threat_assessment.hp_ratio * 100)
	#		], "yellow")
	#		return _create_retreat_action(enemy_unit, retreat_pos)
	
	# Select best target
	var best_target := select_best_target(enemy_unit, player_units)
	if not best_target:
		return _create_wait_action(enemy_unit)
	
	# Calculate best attack position
	var best_move := calculate_best_attack_position(enemy_unit, best_target)
	
	return _create_attack_action(enemy_unit, best_target, best_move)


## Validate unit is suitable for AI processing
## @param unit: Unit to validate
## @return: true if valid, false otherwise
func _validate_unit_for_ai(unit: Node) -> bool:
	if not unit:
		push_warning("EnemyAI: Null unit provided")
		return false
	
	if not unit.has_method("is_alive"):
		push_error("EnemyAI: Unit missing is_alive() method")
		return false
	
	if not unit.is_alive():
		push_warning("EnemyAI: Trying to process dead unit: %s" % unit.unit_name)
		return false
	
	if not unit_manager or not combat_manager:
		push_error("EnemyAI: Dependencies not set")
		return false
	
	return true


## Get all player units safely
## @return: Array of player units
func _get_player_units() -> Array:
	if not unit_manager or not unit_manager.has_method("get_units_by_team"):
		return []
	
	return unit_manager.get_units_by_team(0)


## Assess threat level for a unit
## @param unit: Unit to assess
## @param threats: Array of threat units
## @return: Dictionary with threat assessment data
func _assess_threat_level(unit: Unit, threats: Array) -> Dictionary:
	var assessment := {
		"hp_ratio": float(unit.current_health) / float(unit.max_health),
		"threat_count": 0,
		"nearby_threats": 0,
		"can_be_killed": false,
		"total_incoming_damage": 0
	}
	
	for threat in threats:
		if not threat or not threat.has_method("is_alive") or not threat.is_alive():
			continue
		
		assessment.threat_count += 1
		
		var distance := get_manhattan_distance(unit.grid_position, threat.grid_position)
		if distance <= 3:
			assessment.nearby_threats += 1
		
		# Check if threat can attack us
		if combat_manager and combat_manager.has_method("calculate_battle_stats"):
			var stats := _get_cached_combat_stats(threat, unit)
			var potential_damage: int = stats.get("damage", 0)
			assessment.total_incoming_damage += potential_damage
			
			if potential_damage >= unit.current_health:
				assessment.can_be_killed = true
	
	return assessment


## Determine if unit should retreat
## @param unit: Unit to check
## @param threat_assessment: Threat assessment data
## @return: true if should retreat, false otherwise
func _should_retreat(_unit: Node, threat_assessment: Dictionary) -> bool:
	var hp_ratio: float = threat_assessment.get("hp_ratio", 1.0)
	var nearby_threats: int = threat_assessment.get("nearby_threats", 0)
	var can_be_killed: bool = threat_assessment.get("can_be_killed", false)
	
	# Critical health - always retreat
	if hp_ratio < CRITICAL_THRESHOLD:
		return true
	
	# Can be killed by a single enemy - retreat if possible
	if can_be_killed:
		return true
	
	# Low health and surrounded
	if hp_ratio < DANGER_THRESHOLD and nearby_threats >= THREAT_COUNT_THRESHOLD:
		return true
	
	return false


## Select the best target from available player units
## @param enemy_unit: The unit selecting a target
## @param potential_targets: Array of possible targets
## @return: Best target unit, or null if none suitable
func select_best_target(enemy_unit: Unit, potential_targets: Array) -> Unit:
	if not enemy_unit or potential_targets.is_empty():
		return null
	
	var best_target: Node = null
	var best_score: float = -INF
	
	for target in potential_targets:
		if not target or not target.has_method("is_alive") or not target.is_alive():
			continue
		
		var score := _evaluate_target_cached(enemy_unit, target)
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target


## Evaluate target with caching
## @param attacker: Attacking unit
## @param target: Target unit
## @return: Target score
func _evaluate_target_cached(attacker: Node, target: Node) -> float:
	return evaluate_target(attacker, target)


## Evaluate how good a target is for this attacker
## @param attacker: Unit doing the attacking
## @param target: Potential target unit
## @return: Score value (higher = better target)
func evaluate_target(attacker: Unit, target: Unit) -> float:
	var score := 0.0
	
	# Get cached combat stats
	var combat_stats := _get_cached_combat_stats(attacker, target)
	var damage: int = combat_stats.get("damage", 0)
	
	# Lethal attack bonus
	if damage >= target.current_health:
		score += WEIGHT_KILL
	
	# Low HP target bonus
	var target_hp_ratio := float(target.current_health) / float(target.max_health)
	score += (1.0 - target_hp_ratio) * WEIGHT_LOW_HP
	
	# Distance penalty
	var distance := get_manhattan_distance(attacker.grid_position, target.grid_position)
	score += distance * WEIGHT_DISTANCE
	
	# Favorable matchup bonus
	if combat_manager and combat_manager.has_method("can_counter_attack"):
		if combat_manager.can_counter_attack(target, attacker):
			var counter_stats := _get_cached_combat_stats(target, attacker)
			var counter_damage: int = counter_stats.get("damage", 0)
			
			if damage > counter_damage:
				score += WEIGHT_FAVORABLE_MATCHUP
			elif counter_damage > damage:
				score -= WEIGHT_FAVORABLE_MATCHUP * 0.5
	
	return score


## Get combat stats with caching
## @param attacker: Attacking unit
## @param defender: Defending unit
## @return: Combat stats dictionary
func _get_cached_combat_stats(attacker: Unit, defender: Unit) -> Dictionary:
	if not combat_manager or not attacker or not defender:
		return {}
	
	# Create cache key
	# Create cache key (using ints is faster for dictionary keys)
	var attacker_id := attacker.get_instance_id()
	var defender_id := defender.get_instance_id()
	# Shift attacker ID to create unique key combined with defender ID
	var cache_key := (attacker_id << 32) | defender_id
	
	# Check cache
	if _combat_stat_cache.has(cache_key):
		return _combat_stat_cache[cache_key]
	
	# Calculate and cache
	var stats: Dictionary = {}
	if combat_manager.has_method("calculate_battle_stats"):
		stats = combat_manager.calculate_battle_stats(attacker, defender)
		_combat_stat_cache[cache_key] = stats
	
	return stats


## Find best position to attack target from
## @param attacker: Unit that will attack
## @param target: Target to attack
## @return: Best grid position to move to
func calculate_best_attack_position(attacker: Unit, target: Unit) -> Vector2i:
	if not attacker or not target:
		return attacker.grid_position if attacker else Vector2i.ZERO
	
	# Get attack range
	var min_range := 1
	var max_range: int = attacker.get("attack_range") if "attack_range" in attacker else 1
	
	if attacker.has_method("get_attack_range_min"):
		min_range = attacker.get_attack_range_min()
	if attacker.has_method("get_attack_range_max"):
		max_range = attacker.get_attack_range_max()
	
	# Check if already in range
	var current_distance := get_manhattan_distance(attacker.grid_position, target.grid_position)
	if current_distance >= min_range and current_distance <= max_range:
		return attacker.grid_position
	
	# Get cached movement range
	var reachable_cells := _get_cached_movement_range(attacker)
	
	# Find best position
	var best_pos: Vector2i = attacker.grid_position
	var best_distance_to_ideal: float = INF
	var ideal_distance := max_range if max_range > 1 else min_range
	
	for cell in reachable_cells:
		# Check occupation
		if not _is_cell_available(cell, attacker):
			continue
		
		var distance_to_target := get_manhattan_distance(cell, target.grid_position)
		
		# Position allows attack
		if distance_to_target >= min_range and distance_to_target <= max_range:
			var distance_to_ideal: float = abs(distance_to_target - ideal_distance)
			if distance_to_ideal < best_distance_to_ideal:
				best_distance_to_ideal = distance_to_ideal
				best_pos = cell
		# Fallback: get closer
		elif best_distance_to_ideal == INF:
			if distance_to_target < get_manhattan_distance(best_pos, target.grid_position):
				best_pos = cell
	
	return best_pos


## Get cached movement range for unit
## @param unit: Unit to get range for
## @return: Array of reachable cells
func _get_cached_movement_range(unit: Unit) -> Array[Vector2i]:
	if not unit:
		return []
	
	var unit_id := unit.get_instance_id()
	
	# Check cache
	if _movement_range_cache.has(unit_id):
		return _movement_range_cache[unit_id]
	
	# Calculate and cache
	var movement_range: int = unit.get("movement_range") if "movement_range" in unit else 3
	var reachable_cells: Array = GridManager.get_movement_range(
		unit.grid_position,
		movement_range,
		unit
	)
	
	_movement_range_cache[unit_id] = reachable_cells
	return reachable_cells


## Check if cell is available for movement
## @param cell: Cell position to check
## @param moving_unit: Unit that wants to move there
## @return: true if available, false if occupied
func _is_cell_available(cell: Vector2i, moving_unit: Node) -> bool:
	if not unit_manager or not unit_manager.has_method("get_unit_at_position"):
		return true
	
	var unit_at_cell: Node = unit_manager.get_unit_at_position(cell)
	return not unit_at_cell or unit_at_cell == moving_unit


## Find optimized retreat position away from enemies
## @param unit: Unit that needs to retreat
## @param threats: Array of enemy units to retreat from
## @return: Safest reachable position
func find_retreat_position_optimized(unit: Unit, threats: Array) -> Vector2i:
	if not unit:
		return Vector2i.ZERO
	
	var reachable_cells := _get_cached_movement_range(unit)
	if reachable_cells.is_empty():
		return unit.grid_position
	
	var best_pos: Vector2i = unit.grid_position
	var best_safety_score: float = -INF
	
	for cell in reachable_cells:
		if not _is_cell_available(cell, unit):
			continue
		
		# Calculate safety score (sum of distances to threats)
		var safety_score := _calculate_safety_score(cell, threats)
		
		if safety_score > best_safety_score:
			best_safety_score = safety_score
			best_pos = cell
	
	return best_pos


## Calculate safety score for a position
## @param position: Position to evaluate
## @param threats: Array of threat units
## @return: Safety score (higher = safer)
func _calculate_safety_score(position: Vector2i, threats: Array) -> float:
	var score := 0.0
	
	for threat in threats:
		if not threat or not threat.has_method("is_alive") or not threat.is_alive():
			continue
		
		var distance := get_manhattan_distance(position, threat.grid_position)
		
		# Heavily weight minimum distance
		if distance >= MIN_RETREAT_DISTANCE:
			score += distance * 2.0
		else:
			score += distance * 0.5  # Penalize being too close
	
	return score


## Get Manhattan distance between two grid positions
## @param a: First position
## @param b: Second position
## @return: Manhattan distance
func get_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Clear all AI caches (call when units move/die)
func clear_caches() -> void:
	_combat_stat_cache.clear()
	_movement_range_cache.clear()
	_threat_map.clear()
	_cache_valid = false


## Clear cache for specific unit
## @param unit: Unit whose cache should be cleared
func invalidate_cache_for_unit(unit: Unit) -> void:
	if not unit:
		return
	
	var unit_id := unit.get_instance_id()
	_movement_range_cache.erase(unit_id)
	
	# Clear combat stats involving this unit
	# Clear combat stats involving this unit
	var keys_to_remove: Array = []
	for key in _combat_stat_cache.keys():
		# Check if unit ID is part of the combined key
		var attacker_part = key >> 32
		var defender_part = key & 0xFFFFFFFF
		if attacker_part == unit_id or defender_part == unit_id:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		_combat_stat_cache.erase(key)


# --- Action Creation Helpers ---

func _create_wait_action(unit: Node) -> Dictionary:
	return {
		"action": "wait",
		"target": null,
		"move_to": unit.grid_position if unit else Vector2i.ZERO
	}


func _create_retreat_action(_unit: Node, retreat_pos: Vector2i) -> Dictionary:
	return {
		"action": "retreat",
		"target": null,
		"move_to": retreat_pos
	}


func _create_attack_action(_unit: Node, target: Node, move_pos: Vector2i) -> Dictionary:
	return {
		"action": "attack_approach",
		"target": target,
		"move_to": move_pos
	}


func _get_fallback_action(unit: Node) -> Dictionary:
	DebugLog.log("AI: Fallback action for %s" % (unit.unit_name if unit else "unknown"), "yellow")
	return _create_wait_action(unit)
