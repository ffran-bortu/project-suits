# enemy_ai.gd - Dedicated enemy AI manager
extends Node

## Enemy AI weights for target selection
const WEIGHT_KILL = 100.0          # Bonus for targets we can kill
const WEIGHT_LOW_HP = 50.0         # Bonus for low HP targets (scales with missing HP%)
const WEIGHT_DISTANCE = -5.0       # Penalty per tile of distance
const WEIGHT_FAVORABLE_MATCHUP = 25.0  # Bonus for good matchups (e.g., stronger unit)

## Threat assessment constants
const DANGER_THRESHOLD = 0.5       # HP% below which unit should retreat
const SAFE_ATTACK_DISTANCE = 2     # Preferred distance for ranged units

# Dependencies - set from phase_manager
var unit_manager: Node = null
var combat_manager: Node = null

func set_dependencies(unit_mgr: Node, combat_mgr: Node):
	unit_manager = unit_mgr
	combat_manager = combat_mgr

## Main AI decision function for an enemy unit's turn.
## Returns a dictionary with action decisions.
## @param enemy_unit: The enemy unit taking its turn
## @return: Dictionary with {action: String, target: Node, move_to: Vector2i}
func decide_action(enemy_unit) -> Dictionary:
	if not enemy_unit or not unit_manager:
		return {"action": "wait", "target": null, "move_to": enemy_unit.grid_position}
	
	# Get all player units as potential targets
	var player_units = unit_manager.get_units_by_team(0)
	if player_units.is_empty():
		return {"action": "wait", "target": null, "move_to": enemy_unit.grid_position}
	
	# Check if unit is in danger (low HP)
	var hp_ratio = float(enemy_unit.current_health) / float(enemy_unit.max_health)
	if hp_ratio < DANGER_THRESHOLD:
		# Consider retreating
		var retreat_pos = find_retreat_position(enemy_unit, player_units)
		if retreat_pos != enemy_unit.grid_position:
			return {"action": "retreat", "target": null, "move_to": retreat_pos}
	
	# Select best target
	var best_target = select_best_target(enemy_unit, player_units)
	if not best_target:
		return {"action": "wait", "target": null, "move_to": enemy_unit.grid_position}
	
	# Determine best move to attack or approach target
	var best_move = calculate_best_attack_position(enemy_unit, best_target)
	
	return {
		"action": "attack_approach",
		"target": best_target,
		"move_to": best_move
	}

## Select the best target from available player units.
## @param enemy_unit: The unit selecting a target
## @param potential_targets: Array of possible targets
## @return: Best target unit, or null if none suitable
func select_best_target(enemy_unit, potential_targets: Array):
	if not enemy_unit or not combat_manager:
		return null
	
	var best_target = null
	var best_score = -INF
	
	for target in potential_targets:
		if not target or not target.is_alive():
			continue
		
		var score = evaluate_target(enemy_unit, target)
		if score > best_score:
			best_score = score
			best_target = target
	
	return best_target

## Evaluate how good a target is for this attacker.
## Higher scores = better targets.
## @param attacker: Unit doing the attacking
## @param target: Potential target unit
## @return: Score value (higher = better target)
func evaluate_target(attacker, target) -> float:
	var score = 0.0
	
	# Calculate potential damage
	var combat_stats = combat_manager.calculate_battle_stats(attacker, target) if combat_manager else {}
	var damage = combat_stats.get("damage", 0)
	
	# Massive bonus for lethal attacks (can kill target)
	if damage >= target.current_health:
		score += WEIGHT_KILL
	
	# Prefer low HP targets (scales with missing HP percentage)
	var target_hp_ratio = float(target.current_health) / float(target.max_health)
	score += (1.0 - target_hp_ratio) * WEIGHT_LOW_HP
	
	# Penalize distance
	var distance = get_manhattan_distance(attacker.grid_position, target.grid_position)
	score += distance * WEIGHT_DISTANCE
	
	# Prefer favorable matchups (we do more damage than they do)
	if combat_manager and combat_manager.has_method("can_counter_attack"):
		if combat_manager.can_counter_attack(target, attacker):
			var counter_stats = combat_manager.calculate_battle_stats(target, attacker)
			var counter_damage = counter_stats.get("damage", 0)
			
			# Bonus if we deal more damage
			if damage > counter_damage:
				score += WEIGHT_FAVORABLE_MATCHUP
			# Penalty if they deal more damage
			elif counter_damage > damage:
				score -= WEIGHT_FAVORABLE_MATCHUP * 0.5
	
	return score

## Find best position to attack target from, or approach if can't attack yet.
## @param attacker: Unit that will attack
## @param target: Target to attack
## @return: Best grid position to move to
func calculate_best_attack_position(attacker, target) -> Vector2i:
	if not attacker or not target or not unit_manager:
		return attacker.grid_position if attacker else Vector2i.ZERO
	
	# Get attack range
	var min_range = 1
	var max_range = attacker.attack_range
	if attacker.has_method("get_attack_range_min"):
		min_range = attacker.get_attack_range_min()
	if attacker.has_method("get_attack_range_max"):
		max_range = attacker.get_attack_range_max()
	
	# Get movement range
	var reachable_cells = GridManager.get_movement_range(
		attacker.grid_position, 
		attacker.movement_range,
		attacker
	)
	
	# Check if target is already in attack range from current position
	var current_distance = get_manhattan_distance(attacker.grid_position, target.grid_position)
	if current_distance >= min_range and current_distance <= max_range:
		# Already in range, don't move
		return attacker.grid_position
	
	# Find best reachable position that puts target in range
	var best_pos = attacker.grid_position
	var best_distance_to_ideal = INF
	
	# For ranged units, prefer max range; for melee, prefer min range
	var ideal_distance = max_range if max_range > 1 else min_range
	
	for cell in reachable_cells:
		# Check if cell is occupied
		var unit_at_cell = unit_manager.get_unit_at_position(cell)
		if unit_at_cell and unit_at_cell != attacker:
			continue
		
		var distance_to_target = get_manhattan_distance(cell, target.grid_position)
		
		# Check if this position allows attacking the target
		if distance_to_target >= min_range and distance_to_target <= max_range:
			# This position puts target in range
			var distance_to_ideal = abs(distance_to_target - ideal_distance)
			if distance_to_ideal < best_distance_to_ideal:
				best_distance_to_ideal = distance_to_ideal
				best_pos = cell
		elif best_distance_to_ideal == INF:
			# No attack position found yet, get as close as possible
			if distance_to_target < get_manhattan_distance(best_pos, target.grid_position):
				best_pos = cell
	
	return best_pos

## Find a retreat position away from enemies.
## @param unit: Unit that needs to retreat
## @param threats: Array of enemy units to retreat from
## @return: Safest reachable position
func find_retreat_position(unit, threats: Array) -> Vector2i:
	if not unit or not unit_manager:
		return unit.grid_position
	
	var reachable_cells = GridManager.get_movement_range(
		unit.grid_position, 
		unit.movement_range,
		unit
	)
	
	if reachable_cells.is_empty():
		return unit.grid_position
	
	var best_pos = unit.grid_position
	var best_safety_score = -INF
	
	for cell in reachable_cells:
		# Check if cell is occupied
		var unit_at_cell = unit_manager.get_unit_at_position(cell)
		if unit_at_cell and unit_at_cell != unit:
			continue
		
		# Calculate safety score (sum of distances to all threats)
		var safety_score = 0.0
		for threat in threats:
			if threat and threat.is_alive():
				safety_score += get_manhattan_distance(cell, threat.grid_position)
		
		if safety_score > best_safety_score:
			best_safety_score = safety_score
			best_pos = cell
	
	return best_pos

## Get Manhattan distance between two grid positions.
## @param a: First position
## @param b: Second position
## @return: Manhattan distance
func get_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
