"""
FILE: combat_manager.gd
PURPOSE: Combat calculation and execution system handling attack validation, stat calculations, and damage resolution.

OVERVIEW:
This manager validates attack targets, calculates battle statistics (damage, hit rate, crit rate, doubling),
executes combat sequences (attacker → counter → doubles), awards XP, and cleans up defeated units. Uses
Fire Emblem combat formulas with hit/avoid, crit, and speed-based doubling. Caches attack ranges for
performance. Emits signals for UI updates and integrates with BattleManager for MVP tracking.

FUNCTIONS IN THIS FILE:

1. set_dependencies(grid, phase_mgr, unit_mgr)
   - What it does: Injects Grid3D, PhaseManager, UnitManager dependencies
   - Uses: Called by Main during initialization
   - Returns: void

2. handle_attack_target_selection(grid_pos, attacker)
   - What it does: Validates target at position, shows combat forecast if valid
   - Uses: When player clicks during ATTACK_TARGETING state
   - Returns: void

3. get_valid_attack_target(grid_pos, attacker)
   - What it does: Checks if position in range, has enemy unit, validates combat state
   - Uses: For attack target validation
   - Returns: Node (Unit) or null

4. show_combat_forecast(attacker, target)
   - What it does: Calculates stats, emits combat_forecast_requested signal for UI
   - Uses: To show pre-combat forecast panel
   - Returns: void

5. can_counter_attack(defender, attacker)
   - What it does: Checks if defender's weapon range can reach attacker
   - Uses: To determine if defender gets a counter-attack
   - Returns: bool

6. calculate_battle_stats(attacker, target)
   - What it does: Calculates damage, hit%, crit%, and doubling using FE formulas
   - Uses: For combat forecast and combat execution
   - Returns: Dictionary {damage, hit_rate, crit_rate, is_double}

7. execute_attack_round(attacker, defender, stats)
   - What it does: Rolls RNG for hit/crit, applies damage with visuals, tracks stats for MVP
   - Uses: Called 1-4 times per combat (attacker, counter, doubles)
   - Returns: int (damage dealt, 0 if miss)

8. perform_attack(attacker, target)
   - What it does: Executes full combat sequence: attacker→counter→attacker double→defender double
   - Uses: Main combat execution function
   - Returns: void

9. award_combat_xp(winner, loser, got_kill)
   - What it does: Awards XP based on kill or damage (20 for kill, 10 for damage)
   - Uses: After defeating enemy or successful hit
   - Returns: void

10. clear_attack_range_cache()
    - What it does: Clears cached attack ranges (call when units move/die)
    - Uses: After movement, after combat
    - Returns: void

11. _get_cached_attack_range(unit)
    - What it does: Returns cached attack range or calculates and caches  it
    - Uses: For performance optimization in attack validation
    - Returns: Array (grid positions)

12. _validate_combat_state(attacker, target)
    - What it does: Checks both units alive, not same team, have required methods
    - Uses: Before executing combat
    - Returns: bool

13. _check_and_handle_defeat(unit, opponent, unit_was_target)
    - What it does: Checks if unit died, awards XP, cleans up, finishes combat
    - Uses: After each attack round
    - Returns: bool (true if unit died)

14. _cleanup_defeated_unit(unit)
    - What it does: Removes from manager, clears cache, queue_free()
    - Uses: When unit dies
    - Returns: void

15. _finish_combat(attacker, target, damage)
    - What it does: Marks attacker as acted, clears visuals/caches, emits signals, ends turn
    - Uses: After combat sequence completes
    - Returns: void

NOTES:
- Single instance manager (one per battle scene)
- Combat formula constants: BASE_WEAPON_HIT=90, CRIT_MULTIPLIER=3, DOUBLE_ATTACK_THRESHOLD=4 SPD difference
- Hit = (Skill*2 + Luck/2 + 90) - (Target SPD*2 + Luck)
- Crit = (Skill/2 + Luck/2) - Target Luck
- Damage = Attack Power - Defense (or MAG - RES for magic)
- Attack range caching: LRU style, keyed by unit instance ID
- Combat rounds: 1) Attacker, 2) Counter (if in range), 3) Attacker double (if SPD ≥ target SPD +4), 4) Defender double
- Emits: combat_started, combat_forecast_requested, attack_completed
- Depends on: UnitManager, Grid3D, PhaseManager, BattleManager (optional for MVP), GridManager (for range calc)
"""


extends Node
class_name CombatManager

# --- Combat Formula Constants ---
# --- Combat Formula Constants ---
# Moved to GameConfig to centralize balancing
var CRIT_MULTIPLIER: int = GameConfig.combat.crit_multiplier

# --- Signals ---
signal attack_completed(attacker: Node, target: Node, damage: int)
signal combat_started(attacker: Node, target: Node)
signal turn_end_requested(unit: Node)

# --- Dependencies (Injected) ---
var unit_manager: UnitManager = null
var grid_3d: Node = null
var phase_manager: Node = null
var battle_manager: Node = null
var game_state: Node = null

# --- State Variables ---
var current_attacker: Unit = null
var current_target: Unit = null

# --- Cache for Performance ---
var _attack_range_cache: Dictionary = {}  # String -> Array[Vector2i], but GDScript doesn't support nested types


func _ready() -> void:
	# Dependencies are injected by main.gd via set_dependencies(), so we don't validate here
	pass


## Unified dependency injection - all dependencies set at once
## @param grid: Grid3D node for visual feedback
## @param phase_mgr: PhaseManager for turn management
## @param unit_mgr: UnitManager for unit tracking
## @param game_state_node: GameStateManager reference
func set_dependencies(grid: Node, phase_mgr: Node, unit_mgr: Node, game_state_node: Node) -> void:
	grid_3d = grid
	phase_manager = phase_mgr
	game_state = game_state_node
	
	# Try to get unit_manager from parameter or sibling node
	if unit_mgr:
		unit_manager = unit_mgr
	else:
		unit_manager = get_node_or_null("../UnitManager")
	
	# Get battle manager via signal bus or service locator pattern
	_connect_to_battle_manager()
	
	_validate_dependencies()


## Validate all required dependencies are set
func _validate_dependencies() -> void:
	var missing_deps: Array[String] = []
	
	if not unit_manager:
		missing_deps.append("UnitManager")
	if not grid_3d:
		missing_deps.append("Grid3D")
	if not phase_manager:
		missing_deps.append("PhaseManager")
	
	if missing_deps.size() > 0:
		push_error("CombatManager: Missing required dependencies: %s" % ", ".join(missing_deps))


## Connect to battle manager using service locator pattern
func _connect_to_battle_manager() -> void:
	# Try to find battle manager through scene tree traversal
	var root := get_tree().root
	if not root:
		return
	
	var main := root.get_node_or_null("Main")
	if main:
		battle_manager = main.get_node_or_null("GameManager/BattleManager")
		if not battle_manager:
			push_warning("CombatManager: BattleManager not found at expected path")


## Validate attack target and show combat forecast if valid
## @param grid_pos: Grid position player clicked
## @param attacker: Attacking unit
func handle_attack_target_selection(grid_pos: Vector2i, attacker: Unit) -> void:
	if not _validate_combat_state(attacker, null):
		return
	
	# Validate we're in the correct state
	var local_game_state := get_node_or_null("/root/GlobalGameState")
	if not local_game_state:
		push_error("CombatManager: GameStateManager not found")
		return
	
	if local_game_state.current_state != local_game_state.GameState.ATTACK_TARGETING:
		push_warning("CombatManager: Attack target selection called outside ATTACK_TARGETING state")
		return
	
	current_attacker = attacker
	var target := get_valid_attack_target(grid_pos, attacker)
	
	if target:
		current_target = target
		show_combat_forecast(attacker, target)


## Validate combat prerequisites
## @param attacker: Attacking unit
## @param target: Defending unit (can be null for initial validation)
## @return: true if combat can proceed, false otherwise
func _validate_combat_state(attacker: Node, target: Node) -> bool:
	if not attacker:
		push_warning("CombatManager: No attacker provided")
		return false
	
	if not attacker.has_method("is_alive"):
		push_error("CombatManager: Attacker missing is_alive() method")
		return false
	
	if not attacker.is_alive():
		push_warning("CombatManager: Attacker is not alive")
		return false
	
	if target:
		if not target.has_method("is_alive"):
			push_error("CombatManager: Target missing is_alive() method")
			return false
		
		if not target.is_alive():
			push_warning("CombatManager: Target is not alive")
			return false
		
		# Check if same team
		if attacker.team == target.team:
			push_warning("CombatManager: Cannot attack unit on same team")
			return false
	
	return true


## Check if target at grid position is a valid attack target
## @param grid_pos: Grid position to check
## @param attacker: Attacking unit
## @return: Target unit if valid, null otherwise
func get_valid_attack_target(grid_pos: Vector2i, attacker: Node) -> Node:
	if not attacker or not unit_manager:
		return null
	
	# Get attack range (with caching)
	var attack_cells := _get_cached_attack_range(attacker)
	
	# Validate target is in range
	if grid_pos not in attack_cells:
		return null
	
	# Get unit at position
	var target: Node = unit_manager.get_unit_at_position(grid_pos)
	if not target:
		return null
	
	# Validate combat state
	if not _validate_combat_state(attacker, target):
		return null
	
	return target


## Get cached attack range for unit to avoid recalculation
## @param unit: Unit to get attack range for
## @return: Array of grid positions in attack range
func _get_cached_attack_range(unit: Node) -> Array:
	var unit_key := str(unit.get_instance_id())
	
	# Check if cached
	if _attack_range_cache.has(unit_key):
		return _attack_range_cache[unit_key]
	
	# Calculate and cache
	var min_range := 1
	var max_range: int = unit.get("attack_range") if "attack_range" in unit else 1
	
	if unit.has_method("get_attack_range_min"):
		min_range = unit.get_attack_range_min()
	if unit.has_method("get_attack_range_max"):
		max_range = unit.get_attack_range_max()
	
	var attack_cells: Array = GridManager.get_attack_range(unit.grid_position, max_range, min_range)
	_attack_range_cache[unit_key] = attack_cells
	
	return attack_cells


## Clear attack range cache (call when units move or die)
func clear_attack_range_cache() -> void:
	_attack_range_cache.clear()


## Show combat forecast UI
## @param attacker: Attacking unit
## @param target: Defending unit
func show_combat_forecast(attacker: Node, target: Node) -> void:
	var stats := calculate_battle_stats(attacker, target)
	# combat_forecast_requested.emit(attacker, target, stats) # Old local signal
	SignalBus.combat_forecast_requested.emit(attacker, target, stats)


## Check if defender can counter-attack the attacker
## @param defender: Unit that would counter
## @param attacker: Unit that initiated combat
## @return: true if defender can counter, false otherwise
func can_counter_attack(defender: Node, attacker: Node) -> bool:
	if not defender or not attacker:
		return false
	
	if not defender.has_method("is_alive") or not defender.is_alive():
		return false
	
	# Get defender's attack range
	var min_range := 1
	var max_range: int = defender.get("attack_range") if "attack_range" in defender else 1
	
	if defender.has_method("get_attack_range_min"):
		min_range = defender.get_attack_range_min()
	if defender.has_method("get_attack_range_max"):
		max_range = defender.get_attack_range_max()
	
	# Calculate distance between units
	var distance: int = abs(attacker.grid_position.x - defender.grid_position.x) + \
					abs(attacker.grid_position.y - defender.grid_position.y)
	
	return distance >= min_range and distance <= max_range


## Execute a single attack round
## @param attacker: Unit performing the attack
## @param defender: Unit being attacked
## @param stats: Pre-calculated battle stats
## @return: Damage dealt (0 if miss)
func execute_attack_round(attacker: Node, defender: Node, stats: Dictionary) -> int:
	if not attacker or not defender:
		return 0
	
	if not defender.has_method("is_alive") or not defender.is_alive():
		return 0
	
	# Roll for hit
	var hit_roll: int = randi() % GameConfig.combat.max_hit_rate
	var is_hit: bool = hit_roll < stats.get("hit_rate", 0)
	var is_crit := false
	var final_damage := 0
	
	if is_hit:
		# Roll for crit
		var crit_roll: int = randi() % GameConfig.combat.max_crit_rate
		is_crit = crit_roll < stats.get("crit_rate", 0)
		
		final_damage = stats.get("damage", 0)
		
		if is_crit:
			DebugLog.log("  CRITICAL HIT!", "yellow")
			final_damage *= CRIT_MULTIPLIER
		
		DebugLog.log("  %s hits %s for %d damage" % [attacker.unit_name, defender.unit_name, final_damage], "cyan")
		
		# Apply damage with visual feedback
		if defender.has_method("take_damage_with_feedback"):
			defender.take_damage_with_feedback(final_damage, is_crit, false)
		elif defender.has_method("take_damage"):
			defender.take_damage(final_damage)
		
		# Track damage for MVP
		if battle_manager and battle_manager.has_method("record_damage"):
			battle_manager.record_damage(attacker.unit_name, final_damage)
			
			# Track kill if defender died
			if defender.has_method("is_alive") and not defender.is_alive():
				if battle_manager.has_method("record_kill"):
					battle_manager.record_kill(attacker.unit_name)
	else:
		DebugLog.log("  %s MISSES %s!" % [attacker.unit_name, defender.unit_name], "yellow")
		
		# Show miss visual
		if defender.has_method("show_miss"):
			defender.show_miss()
	
	return final_damage


## Execute full combat sequence
## @param attacker: Attacking unit
## @param target: Defending unit
func perform_attack(attacker: Node, target: Node) -> void:
	if not _validate_combat_state(attacker, target):
		return
	
	combat_started.emit(attacker, target)
	
	DebugLog.log("=== COMBAT ===", "cyan")
	DebugLog.log("%s initiates combat with %s" % [attacker.unit_name, target.unit_name], "cyan")
	
	# Calculate stats for both units
	var attacker_stats := calculate_battle_stats(attacker, target)
	var defender_stats: Dictionary = {}
	var defender_can_counter := can_counter_attack(target, attacker)
	
	if defender_can_counter:
		defender_stats = calculate_battle_stats(target, attacker)
	
	# === ROUND 1: Attacker's Initial Attack ===
	DebugLog.log("Round 1: %s attacks" % attacker.unit_name, "cyan")
	execute_attack_round(attacker, target, attacker_stats)
	await get_tree().create_timer(1.0).timeout
	
	if _check_and_handle_defeat(target, attacker, true):
		return
	
	# === ROUND 2: Defender's Counter-Attack ===
	if defender_can_counter:
		DebugLog.log("Round 2: %s counters" % target.unit_name, "cyan")
		execute_attack_round(target, attacker, defender_stats)
		await get_tree().create_timer(1.0).timeout
		
		# Check if attacker died (target is opponent)
		if is_instance_valid(target) and _check_and_handle_defeat(attacker, target, false):
			return
	else:
		DebugLog.log("Round 2: %s cannot counter (out of range)" % target.unit_name, "yellow")
		await get_tree().create_timer(0.5).timeout
	
	# === ROUND 3: Attacker's Double Attack ===
	if attacker_stats.get("is_double", false) and target.is_alive():
		DebugLog.log("Round 3: %s doubles!" % attacker.unit_name, "cyan")
		execute_attack_round(attacker, target, attacker_stats)
		await get_tree().create_timer(1.0).timeout
		
		# Check if target died (attacker is opponent)
		if is_instance_valid(attacker) and _check_and_handle_defeat(target, attacker, true):
			return
	
	# === ROUND 4: Defender's Double Attack ===
	if defender_can_counter and defender_stats.get("is_double", false) and attacker.is_alive():
		DebugLog.log("Round 4: %s doubles!" % target.unit_name, "cyan")
		execute_attack_round(target, attacker, defender_stats)
		await get_tree().create_timer(1.0).timeout
		
		# Check if attacker died (target is opponent)
		if is_instance_valid(target) and _check_and_handle_defeat(attacker, target, false):
			return
	
	DebugLog.log("=== COMBAT COMPLETE ===", "green")
	_finish_combat(attacker, target, 0)


## Check if unit was defeated and handle cleanup
## @param unit: Unit to check
## @param opponent: Opposing unit
## @param unit_was_target: True if unit was the target (for XP)
## @return: true if unit was defeated, false otherwise
func _check_and_handle_defeat(unit: Node, opponent: Node, unit_was_target: bool) -> bool:
	if not unit.has_method("is_alive") or unit.is_alive():
		return false
	
	DebugLog.success("%s has been defeated!" % unit.unit_name)
	_cleanup_defeated_unit(unit)
	
	# Notify systems of death (triggers BattleManager checks)
	SignalBus.unit_died.emit(unit)
	
	# Award XP to victor
	if unit_was_target and opponent.has_method("is_alive") and opponent.is_alive():
		award_combat_xp(opponent, unit, true)
	
	_finish_combat(opponent if unit_was_target else unit, unit if unit_was_target else opponent, 0)
	return true


## Clean up defeated unit (deferred to prevent mid-combat crashes)
## @param unit: Unit to clean up
func _cleanup_defeated_unit(unit: Node) -> void:
	if not unit_manager:
		return
	
	# Clear from cache first
	var unit_key := str(unit.get_instance_id())
	_attack_range_cache.erase(unit_key)
	
	# Remove from unit manager
	if unit_manager.has_method("remove_unit"):
		unit_manager.remove_unit(unit)
	
	# Deferred free to prevent crashes
	unit.queue_free()


## Finalize combat and clean up
## @param attacker: Attacking unit
## @param target: Defending unit  
## @param damage: Final damage dealt
func _finish_combat(attacker: Node, target: Node, damage: int) -> void:
	# Mark attacker as acted
	if attacker and attacker.has_method("is_alive") and attacker.is_alive():
		if attacker.has_method("mark_as_acted"):
			attacker.mark_as_acted()
	
	# Clean up visuals
	if grid_3d and grid_3d.has_method("clear_attack_highlights"):
		grid_3d.clear_attack_highlights()
	
	# Clear attack range cache
	clear_attack_range_cache()
	
	# Notify listeners
	attack_completed.emit(attacker, target, damage)
	
	# End turn for player units
	if attacker and attacker.has_method("is_alive") and attacker.is_alive():
		if attacker.get("team") == 0:
			turn_end_requested.emit(attacker)


## Calculate battle statistics for combat forecast
## @param attacker: Attacking unit
## @param target: Defending unit
## @return: Dictionary with combat stats {damage, hit_rate, crit_rate, is_double}
func calculate_battle_stats(attacker: Unit, target: Unit) -> Dictionary:
	var stats := {
		"damage": 0,
		"hit_rate": 0,
		"crit_rate": 0,
		"is_double": false
	}
	
	if not attacker or not target:
		return stats
	
	# 1. Calculate Damage
	var attack_power: int = attacker.get("strength") if "strength" in attacker else 0
	var defense: int = target.get("def") if "def" in target else 0
	
	# Handle Magic vs Res if implemented
	if attacker.has_method("get_damage_type") and attacker.get_damage_type() == 1:
		attack_power = attacker.get("mag") if "mag" in attacker else 0
		defense = target.get("res") if "res" in target else 0
	
	stats.damage = max(0, attack_power - defense)
	
	# 2. Calculate Hit Rate
	var skill: int = attacker.get("skill") if "skill" in attacker else 0
	var luck: int = attacker.get("luck") if "luck" in attacker else 0
	
	var base_hit = GameConfig.combat.base_weapon_hit
	var skill_mult = GameConfig.combat.hit_skill_multiplier
	var luck_div = GameConfig.combat.hit_luck_divisor
	
	var hit_chance: int = (skill * skill_mult) + int(luck / luck_div) + base_hit
	
	# Avoid calculation
	var target_speed: int = target.get("spd") if "spd" in target else 0
	var target_luck: int = target.get("luck") if "luck" in target else 0
	var speed_mult = GameConfig.combat.avoid_speed_multiplier
	var avoid: int = (target_speed * speed_mult) + target_luck
	
	stats.hit_rate = clamp(hit_chance - avoid, GameConfig.combat.min_hit_rate, GameConfig.combat.max_hit_rate)
	
	# 3. Calculate Crit Rate
	var crit_skill_div = GameConfig.combat.crit_skill_divisor
	var crit_chance := int(skill / crit_skill_div) + int(luck / luck_div)
	var crit_avoid := target_luck
	stats.crit_rate = clamp(crit_chance - crit_avoid, GameConfig.combat.min_crit_rate, GameConfig.combat.max_crit_rate)
	
	# 4. Check for Double Attack
	var attacker_speed: int = attacker.get("spd") if "spd" in attacker else 0
	if attacker_speed >= target_speed + GameConfig.combat.double_attack_speed_diff:
		stats.is_double = true
	
	return stats


## Award XP after combat
## @param winner: Unit that won the combat
## @param loser: Unit that was defeated
## @param got_kill: Whether winner got the kill
func award_combat_xp(winner: Node, _loser: Node, got_kill: bool) -> void:
	# This would integrate with a level up system
	# Placeholder for future implementation
	if winner.has_method("award_xp"):
		var xp_amount: int = GameConfig.combat.xp_kill if got_kill else GameConfig.combat.xp_hit
		winner.award_xp(xp_amount)


## Cleanup function - clear state and caches
func cleanup() -> void:
	current_attacker = null
	current_target = null
	clear_attack_range_cache()


## Clean up when node is removed from tree
func _exit_tree() -> void:
	cleanup()
