# combat_manager.gd - Optimized combat system
extends Node

# Dependencies - use signals for loose coupling
@onready var unit_manager = get_node("../UnitManager")

# Signals
signal attack_completed(attacker, target, damage)
signal combat_forecast_requested(attacker, defender, stats)
signal combat_started(attacker, target)

# Configurable combat constants
const BASE_WEAPON_HIT = 90
const MIN_HIT_RATE = 0
const MAX_HIT_RATE = 100
const MIN_CRIT_RATE = 0
const MAX_CRIT_RATE = 100
const CRIT_MULTIPLIER = 3
const DOUBLE_ATTACK_THRESHOLD = 4

## References to other managers
var grid_3d: Node = null
var phase_manager: Node = null
var battle_manager: Node = null  # NEW: For MVP tracking
var current_attacker = null
var current_target = null

func set_dependencies(grid: Node, phase_mgr: Node):
	## Set required dependencies for combat manager
	grid_3d = grid
	phase_manager = phase_mgr
	
	# Get battle manager reference
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_node("GameManager/BattleManager"):
		battle_manager = main.get_node("GameManager/BattleManager")

## Validate attack target and show combat forecast if valid.
## Called when player clicks on a cell during ATTACK_TARGETING state.
## @param grid_pos: Grid position player clicked
## @param attacker: Attacking unit
func handle_attack_target_selection(grid_pos: Vector2i, attacker):
	if not attacker or not attacker.is_alive():
		return
	
	# Validate we're in the correct state
	var game_state = get_node("/root/GameStateManager")
	if game_state and game_state.current_state != game_state.GameState.ATTACK_TARGETING:
		push_warning("CombatManager: Attack target selection called outside ATTACK_TARGETING state")
		return
	
	current_attacker = attacker
	var target = get_valid_attack_target(grid_pos, attacker)
	
	if target:
		current_target = target
		show_combat_forecast(attacker, target)

## Check if target at grid position is a valid attack target.
## Validates range, team, and unit presence.
## @param grid_pos: Grid position to check
## @param attacker: Attacking unit
## @return: Target unit if valid, null otherwise
func get_valid_attack_target(grid_pos: Vector2i, attacker):
	if not attacker:
		return null
	
	# Get attack range
	# Note: simple range check, assuming min range 1 for now if get_attack_range param assumes max
	# If GridManager.get_attack_range handles min/max, we might need to adjust, but based on previous code:
	var min_r = 1
	var max_r = attacker.attack_range
	if attacker.has_method("get_attack_range_min"): min_r = attacker.get_attack_range_min()
	if attacker.has_method("get_attack_range_max"): max_r = attacker.get_attack_range_max()
	
	var attack_cells = GridManager.get_attack_range(attacker.grid_position, max_r, min_r)
	
	# Validate target is in range
	if grid_pos not in attack_cells:
		return null
	
	# Get unit at position
	var target = unit_manager.get_unit_at_position(grid_pos)
	if not target or not target.is_alive():
		return null
	
	# Check if target is enemy
	if target.team == attacker.team:
		return null
	
	return target

func show_combat_forecast(attacker, target):
	# Calculate combat stats
	var stats = calculate_battle_stats(attacker, target)
	
	# Emit signal for UI to show forecast
	combat_forecast_requested.emit(attacker, target, stats)
	
	# We'll wait for confirmation via signal
	# In practice, you'd connect the forecast UI's confirmed signal to perform_attack

## Check if defender can counter-attack the attacker.
## Validates range and alive status.
## @param defender: Unit that would counter
## @param attacker: Unit that initiated combat
## @return: true if defender can counter, false otherwise
func can_counter_attack(defender, attacker) -> bool:
	if not defender or not attacker:
		return false
	
	if not defender.is_alive():
		return false
	
	# Get defender's attack range
	var min_range = 1
	var max_range = defender.attack_range
	if defender.has_method("get_attack_range_min"):
		min_range = defender.get_attack_range_min()
	if defender.has_method("get_attack_range_max"):
		max_range = defender.get_attack_range_max()
	
	# Calculate distance between units
	var distance = abs(attacker.grid_position.x - defender.grid_position.x) + \
				   abs(attacker.grid_position.y - defender.grid_position.y)
	
	# Check if attacker is within defender's range
	return distance >= min_range and distance <= max_range

## Execute a single attack round (one unit attacking another).
## Rolls for hit/crit and applies damage.
## @param attacker: Unit performing the attack
## @param defender: Unit being attacked
## @param stats: Pre-calculated battle stats
## @return: Damage dealt (0 if miss)
func execute_attack_round(attacker, defender, stats: Dictionary) -> int:
	if not attacker or not defender or not defender.is_alive():
		return 0
	
	# Roll for hit
	var hit_roll = randi() % 100
	var is_hit = hit_roll < stats.hit_rate
	var is_crit = false
	var final_damage = 0
	
	if is_hit:
		# Roll for crit
		var crit_roll = randi() % 100
		is_crit = crit_roll < stats.crit_rate
		
		final_damage = stats.damage
		
		if is_crit:
			print("  CRITICAL HIT!")
			final_damage *= CRIT_MULTIPLIER
		
		print("  %s hits %s for %d damage" % [attacker.unit_name, defender.unit_name, final_damage])
		
		# Apply damage with visual feedback
		if defender.has_method("take_damage_with_feedback"):
			defender.take_damage_with_feedback(final_damage, is_crit, false)
		else:
			defender.take_damage(final_damage)
		
		# Track damage for MVP (NEW)
		if battle_manager:
			battle_manager.record_damage(attacker.unit_name, final_damage)
			
			# Track kill if defender died
			if not defender.is_alive():
				battle_manager.record_kill(attacker.unit_name)
	else:
		print("  %s MISSES %s!" % [attacker.unit_name, defender.unit_name])
		
		# Show miss visual
		if defender.has_method("show_miss"):
			defender.show_miss()
	
	return final_damage

## Execute combat between attacker and target.
## Handles full combat sequence: attack, counter, doubles.
## @param attacker: Attacking unit
## @param target: Defending unit
func perform_attack(attacker, target):
	if not attacker or not target:
		return
	
	combat_started.emit(attacker, target)
	
	print("=== COMBAT ===")
	print("%s initiates combat with %s" % [attacker.unit_name, target.unit_name])
	
	# Calculate stats for both units
	var attacker_stats = calculate_battle_stats(attacker, target)
	var defender_stats = {}
	var defender_can_counter = can_counter_attack(target, attacker)
	
	if defender_can_counter:
		defender_stats = calculate_battle_stats(target, attacker)
	
	# === ROUND 1: Attacker's Initial Attack ===
	print("Round 1: %s attacks" % attacker.unit_name)
	execute_attack_round(attacker, target, attacker_stats)
	
	# Check if target died
	if not target.is_alive():
		print("%s has been defeated!" % target.unit_name)
		_cleanup_defeated_unit(target)
		_finish_combat(attacker, target, 0)
		return
	
	# === ROUND 2: Defender's Counter-Attack ===
	if defender_can_counter:
		print("Round 2: %s counters" % target.unit_name)
		execute_attack_round(target, attacker, defender_stats)
		
		# Check if attacker died from counter
		if not attacker.is_alive():
			print("%s has been defeated by counter-attack!" % attacker.unit_name)
			_cleanup_defeated_unit(attacker)
			_finish_combat(attacker, target, 0)
			return
	else:
		print("Round 2: %s cannot counter (out of range)" % target.unit_name)
	
	# === ROUND 3: Attacker's Double Attack (if applicable) ===
	if attacker_stats.is_double and target.is_alive():
		print("Round 3: %s doubles!" % attacker.unit_name)
		execute_attack_round(attacker, target, attacker_stats)
		
		if not target.is_alive():
			print("%s has been defeated!" % target.unit_name)
			_cleanup_defeated_unit(target)
			_finish_combat(attacker, target, 0)
			return
	
	# === ROUND 4: Defender's Double Attack (if applicable) ===
	if defender_can_counter and defender_stats.get("is_double", false) and attacker.is_alive():
		print("Round 4: %s doubles!" % target.unit_name)
		execute_attack_round(target, attacker, defender_stats)
		
		if not attacker.is_alive():
			print("%s has been defeated!" % attacker.unit_name)
			_cleanup_defeated_unit(attacker)
			_finish_combat(attacker, target, 0)
			return
	
	print("=== COMBAT COMPLETE ===")
	_finish_combat(attacker, target, 0)

# Helper to clean up defeated units
func _cleanup_defeated_unit(unit):
	if unit_manager:
		unit_manager.remove_unit(unit)
		unit.queue_free()

# Helper to finalize combat
func _finish_combat(attacker, target, damage: int):
	# Mark attacker as acted
	if attacker and attacker.is_alive():
		attacker.mark_as_acted()
	
	# Clean up visuals
	if grid_3d:
		grid_3d.clear_attack_highlights()
	
	# Notify listeners
	attack_completed.emit(attacker, target, damage)
	
	# End turn for player units
	if attacker and attacker.is_alive() and attacker.team == 0 and phase_manager:
		phase_manager.end_current_unit_turn()

## Calculate battle statistics for combat forecast.
## Returns damage, hit rate, crit rate, and double attack status.
## @param attacker: Attacking unit
## @param target: Defending unit
## @return: Dictionary with combat stats {damage, hit_rate, crit_rate, is_double}
func calculate_battle_stats(attacker, target) -> Dictionary:
	var stats = {
		damage = 0,
		hit_rate = 0,
		crit_rate = 0,
		is_double = false
	}
	
	if not attacker or not target:
		return stats
	
	# 1. Calculate Damage
	var attack_power = attacker.str
	var defense = target.def
	
	# Handle Magic vs Res if implemented
	if attacker.has_method("get_damage_type") and attacker.get_damage_type() == 1:
		attack_power = attacker.mag
		defense = target.res
	
	stats.damage = max(0, attack_power - defense)
	
	# 2. Calculate Hit Rate
	var skill = attacker.skill
	var luck = attacker.luck
	
	# Base hit calculation
	var hit_chance = (skill * 2) + int(luck / 2.0) + BASE_WEAPON_HIT
	
	# Avoid calculation
	var target_speed = target.spd
	var target_luck = target.luck
	var avoid = (target_speed * 2) + target_luck
	
	stats.hit_rate = clamp(hit_chance - avoid, MIN_HIT_RATE, MAX_HIT_RATE)
	
	# 3. Calculate Crit Rate
	var crit_chance = int(skill / 2.0) + int(luck / 2.0)
	var crit_avoid = target_luck
	stats.crit_rate = clamp(crit_chance - crit_avoid, MIN_CRIT_RATE, MAX_CRIT_RATE)
	
	# 4. Check for Double Attack
	var attacker_speed = attacker.spd
	if attacker_speed >= target_speed + DOUBLE_ATTACK_THRESHOLD:
		stats.is_double = true
	
	return stats

# Cleanup function
func cleanup():
	current_attacker = null
	current_target = null
