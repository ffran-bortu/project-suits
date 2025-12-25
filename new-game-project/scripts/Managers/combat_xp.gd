"""
FILE: combat_xp.gd
PURPOSE: Experience point calculation and award system with level scaling, class modifiers, and duo/solo unit support.

OVERVIEW:
This manager calculates and awards XP after combat, handling base XP (10 for hit, +20 for kill), level difference
bonuses/penalties (+10% per level above, -5% per level below with 50% minimum), class-based multipliers (Healer 1.2x,
Tank/Warrior 1.1x, etc.), and caps (max 50 XP per combat, or 15*level). Supports duo units (gain_duo_experience),
solo units (gain_solo_experience), and generic units (gain_experience). Emits signals for UI updates and tracking.

FUNCTIONS IN THIS FILE:

1. award_combat_xp(winner, loser, got_kill)
   - What it does: Main function - calculates XP with all bonuses, clamps to max, awards to unit, emits signals
   - Uses: Called by CombatManager after combat completes
   - Returns: XPAwardResult (detailed breakdown)

2. calculate_xp_breakdown(winner, loser, got_kill)
   - What it does: Calculates XP breakdown for UI preview without actually awarding
   - Uses: For showing XP forecast before combat
   - Returns: Dictionary {base_xp, kill_bonus, level_multiplier, class_multiplier, raw_total, final_clamped}

3. award_xp_batch(awards)
   - What it does: Awards XP to multiple units in batch (for efficiency)
   - Uses: When multiple units gain XP simultaneously
   - Returns: Array[XPAwardResult]

4. _calculate_xp_amount(winner, loser, got_kill, result)
   - What it does: Calculates total XP with base + kill bonus + level scaling + class modifier
   - Uses: During award_combat_xp()
   - Returns: int (total calculated XP)

5. _calculate_level_bonus(attacker, defender)
   - What it does: Returns multiplier based on level difference (1.0 + diff * 0.1 for higher, max 0.5 for lower)
   - Uses: To scale XP by challenge level
   - Returns: float (multiplier)

6. _get_class_xp_modifier(unit)
   - What it does: Returns class-based multiplier (Healer 1.2x, Warrior 1.1x, default 1.0x)
   - Uses: To adjust XP gain by class role
   - Returns: float (multiplier)

7. _clamp_xp_for_unit(unit, raw_xp)
   - What it does: Clamps to MAX_XP_PER_COMBAT (50) and level-based cap (level * 15)
   - Uses: To prevent excessive XP gains
   - Returns: int (clamped XP)

8. _award_xp_to_unit(unit, amount)
   - What it does: Calls appropriate method (gain_duo_experience, gain_solo_experience, gain_experience)
   - Uses: To actually grant XP to unit
   - Returns: bool (true if leveled up)

9. _get_unit_level(unit)
   - What it does: Extracts level from unit (tries level property, get_level method, get_average_level for duos)
   - Uses: For level difference calculations
   - Returns: int (level or 0 if unavailable)

NOTES:
- Single instance manager (one per battle scene)
- XP formula: (BASE + KILL_BONUS) * LEVEL_MULTIPLIER * CLASS_MULTIPLIER, then clamped
- Constants: BASE=10, KILL=20, MAX=50, LEVEL_BONUS=10%/level, LEVEL_PENALTY=5%/level, MIN=50%
- Class multipliers: Healer/Cleric=1.2x, Commander=1.15x, Warrior/Tank=1.1x, Archer=1.05x, others=1.0x
- Level cap: min(50, level * 15)
- Emits: xp_awarded(unit, amount, from_kill), xp_calculation_complete(unit, base, bonus, total)
- Depends on: CharacterData (via units), LevelUpSystem (called by units after XP gain)
"""


extends Node

# --- XP Configuration Constants ---
## Base XP awards
const BASE_ATTACK_XP: int = 10
const KILL_BONUS_XP: int = 20  # Added to base, not replacement
const MAX_XP_PER_COMBAT: int = 50

## Level difference scaling
const LEVEL_DIFF_BONUS_MULTIPLIER: float = 0.1  # +10% per level above
const LEVEL_DIFF_PENALTY_MULTIPLIER: float = 0.05  # -5% per level below
const MIN_XP_MULTIPLIER: float = 0.5  # Minimum 50% XP from lower level enemies

## Class-based XP modifiers
const CLASS_XP_MODIFIERS: Dictionary = {
	"Mage": 1.0,
	"Warrior": 1.1,
	"Archer": 1.05,
	"Healer": 1.2,
	"Commander": 1.15,
	"Tank": 1.1,
	"Assassin": 1.0,
	"Cleric": 1.2
}

# --- Signals ---
signal xp_awarded(unit: Node, amount: int, from_kill: bool)
signal xp_calculation_complete(unit: Node, base_xp: int, bonus_xp: int, total_xp: int)

# --- XP Award Result Class ---
class XPAwardResult:
	var unit: Node = null
	var base_xp: int = 0
	var bonus_xp: int = 0
	var level_bonus_multiplier: float = 1.0
	var class_bonus_multiplier: float = 1.0
	var total_xp: int = 0
	var clamped_xp: int = 0
	var was_capped: bool = false
	var leveled_up: bool = false
	var new_level: int = 0
	
	func _to_string() -> String:
		return "XPAwardResult(unit=%s, total=%d, clamped=%d, capped=%s)" % [
			unit.unit_name if unit else "null",
			total_xp,
			clamped_xp,
			was_capped
		]


## Award XP after combat (duo/solo/regular unit aware)
## @param winner: Unit that won the combat
## @param loser: Unit that was defeated
## @param got_kill: Whether winner got the killing blow
## @return: XPAwardResult with details of XP award
func award_combat_xp(winner: Node, loser: Node, got_kill: bool) -> XPAwardResult:
	var result := XPAwardResult.new()
	result.unit = winner
	
	# Validate inputs
	if not _validate_xp_award(winner, loser, got_kill):
		return result
	
	# Calculate XP amount
	var calculated_xp := _calculate_xp_amount(winner, loser, got_kill, result)
	
	# Clamp XP to configured maximum
	result.total_xp = calculated_xp
	result.clamped_xp = _clamp_xp_for_unit(winner, calculated_xp)
	result.was_capped = result.clamped_xp < result.total_xp
	
	# Award XP to appropriate unit type
	result.leveled_up = _award_xp_to_unit(winner, result.clamped_xp)
	
	# Get new level if leveled up
	if result.leveled_up and winner.has_method("get_level"):
		result.new_level = winner.get_level()
	
	# Emit signals for tracking/UI
	xp_awarded.emit(winner, result.clamped_xp, got_kill)
	xp_calculation_complete.emit(
		winner, 
		result.base_xp, 
		result.bonus_xp, 
		result.clamped_xp
	)
	
	# Log XP award
	_log_xp_award(result, got_kill)
	
	return result


## Validate XP award is valid
## @param winner: Winner unit
## @param loser: Loser unit
## @param got_kill: Whether it was a kill
## @return: true if valid, false otherwise
func _validate_xp_award(winner: Node, loser: Node, got_kill: bool) -> bool:
	if not winner:
		push_warning("XP: Cannot award XP - no winner provided")
		return false
	
	if not loser:
		push_warning("XP: Cannot award XP - no loser provided")
		return false
	
	# Check if winner is alive
	if winner.has_method("is_alive") and not winner.is_alive():
		push_warning("XP: Cannot award XP to dead unit: %s" % winner.unit_name)
		return false
	
	# If got_kill is true, loser should be dead
	if got_kill:
		if loser.has_method("is_alive") and loser.is_alive():
			push_warning("XP: Got kill flag set but loser is still alive: %s" % loser.unit_name)
			# Continue anyway, might be valid in some cases
	
	return true


## Calculate XP amount based on combat context
## @param winner: Winner unit
## @param loser: Loser unit
## @param got_kill: Whether it was a kill
## @param result: Result object to populate
## @return: Total calculated XP
func _calculate_xp_amount(winner: Node, loser: Node, got_kill: bool, result: XPAwardResult) -> int:
	# Base XP
	result.base_xp = BASE_ATTACK_XP
	if got_kill:
		result.bonus_xp = KILL_BONUS_XP
	
	var raw_xp := result.base_xp + result.bonus_xp
	
	# Apply level difference multiplier
	result.level_bonus_multiplier = _calculate_level_bonus(winner, loser)
	
	# Apply class-based multiplier
	result.class_bonus_multiplier = _get_class_xp_modifier(winner)
	
	# Calculate final XP
	var final_xp := int(float(raw_xp) * result.level_bonus_multiplier * result.class_bonus_multiplier)
	
	return final_xp


## Calculate level-based XP bonus/penalty
## @param attacker: Attacking unit
## @param defender: Defending unit
## @return: Multiplier for XP (1.0 = no change, >1.0 = bonus, <1.0 = penalty)
func _calculate_level_bonus(attacker: Node, defender: Node) -> float:
	# Get levels if available
	var attacker_level := _get_unit_level(attacker)
	var defender_level := _get_unit_level(defender)
	
	if attacker_level == 0 or defender_level == 0:
		return 1.0  # No level data available
	
	var level_diff := defender_level - attacker_level
	
	if level_diff > 0:
		# Bonus for defeating higher level enemy
		return 1.0 + (level_diff * LEVEL_DIFF_BONUS_MULTIPLIER)
	elif level_diff < 0:
		# Reduced XP for defeating lower level enemy
		return max(MIN_XP_MULTIPLIER, 1.0 + (level_diff * LEVEL_DIFF_PENALTY_MULTIPLIER))
	
	return 1.0


## Get unit's level (handles different unit types)
## @param unit: Unit to get level from
## @return: Level or 0 if not available
func _get_unit_level(unit: Node) -> int:
	if not unit:
		return 0
	
	# Try direct level property
	if "level" in unit:
		return unit.level
	
	# Try get_level method
	if unit.has_method("get_level"):
		return unit.get_level()
	
	# Try duo unit level (average of characters)
	if unit.has_method("get_average_level"):
		return unit.get_average_level()
	
	return 0


## Get class-based XP modifier
## @param unit: Unit to get modifier for
## @return: XP multiplier based on class
func _get_class_xp_modifier(unit: Node) -> float:
	if not unit:
		return 1.0
	
	# Try to get unit class name
	var class_name := ""
	
	if "unit_class" in unit and unit.unit_class:
		if "display_name" in unit.unit_class:
			class_name = unit.unit_class.display_name
		elif "class_name" in unit.unit_class:
			class_name = unit.unit_class.class_name
	
	# Look up modifier
	return CLASS_XP_MODIFIERS.get(class_name, 1.0)


## Clamp XP to prevent excessive gains
## @param unit: Unit receiving XP
## @param raw_xp: Unclamped XP amount
## @return: Clamped XP amount
func _clamp_xp_for_unit(unit: Node, raw_xp: int) -> int:
	# Global cap
	var clamped := min(raw_xp, MAX_XP_PER_COMBAT)
	
	# Optional: Per-level cap
	var unit_level := _get_unit_level(unit)
	if unit_level > 0:
		var level_cap := unit_level * 15  # Max 15 XP per level
		clamped = min(clamped, level_cap)
	
	return clamped


## Award XP to unit (handles different unit types)
## @param unit: Unit to receive XP
## @param amount: Amount of XP to award
## @return: true if unit leveled up, false otherwise
func _award_xp_to_unit(unit: Node, amount: int) -> bool:
	if not unit or amount <= 0:
		return false
	
	var leveled_up := false
	
	# Check if duo unit
	if unit.has_method("gain_duo_experience"):
		leveled_up = unit.gain_duo_experience(amount)
	
	# Check if solo unit
	elif unit.has_method("gain_solo_experience"):
		# Assume frontline for now - ideally this should be passed as parameter
		var is_frontline := true
		if "is_frontline" in unit:
			is_frontline = unit.is_frontline
		leveled_up = unit.gain_solo_experience(amount, is_frontline)
	
	# Check for generic gain_experience method
	elif unit.has_method("gain_experience"):
		var old_level := _get_unit_level(unit)
		unit.gain_experience(amount)
		var new_level := _get_unit_level(unit)
		leveled_up = new_level > old_level
	
	# Fallback - no XP system available
	else:
		push_warning("XP: Unit %s has no XP gain method - XP not tracked" % unit.unit_name)
		return false
	
	return leveled_up


## Log XP award for debugging
## @param result: XP award result
## @param got_kill: Whether it was a kill
func _log_xp_award(result: XPAwardResult, got_kill: bool) -> void:
	if not result.unit:
		return
	
	var unit_name: String = result.unit.unit_name if "unit_name" in result.unit else "Unknown"
	
	# Build log message
	var message := "%s gained %d XP" % [unit_name, result.clamped_xp]
	
	if got_kill:
		message += " (kill bonus)"
	
	# Add bonus info if significant
	if result.level_bonus_multiplier != 1.0:
		message += " [level x%.2f]" % result.level_bonus_multiplier
	
	if result.class_bonus_multiplier != 1.0:
		message += " [class x%.2f]" % result.class_bonus_multiplier
	
	if result.was_capped:
		message += " (capped from %d)" % result.total_xp
	
	if result.leveled_up:
		message += " - LEVEL UP!"
		DebugLog.success(message)
	else:
		DebugLog.log(message, "cyan")


## Calculate XP breakdown for debugging/UI
## @param winner: Winner unit
## @param loser: Loser unit
## @param got_kill: Whether it was a kill
## @return: Dictionary with XP breakdown
func calculate_xp_breakdown(winner: Node, loser: Node, got_kill: bool) -> Dictionary:
	var result := XPAwardResult.new()
	result.unit = winner
	
	if not _validate_xp_award(winner, loser, got_kill):
		return {}
	
	var _ = _calculate_xp_amount(winner, loser, got_kill, result)
	
	return {
		"base_xp": result.base_xp,
		"kill_bonus": result.bonus_xp,
		"level_multiplier": result.level_bonus_multiplier,
		"class_multiplier": result.class_bonus_multiplier,
		"raw_total": result.base_xp + result.bonus_xp,
		"calculated_total": int((result.base_xp + result.bonus_xp) * result.level_bonus_multiplier * result.class_bonus_multiplier),
		"final_clamped": _clamp_xp_for_unit(winner, int((result.base_xp + result.bonus_xp) * result.level_bonus_multiplier * result.class_bonus_multiplier))
	}


## Award XP to multiple units (batch processing)
## @param awards: Array of [unit, loser, got_kill] tuples
## @return: Array of XPAwardResult
func award_xp_batch(awards: Array) -> Array[XPAwardResult]:
	var results: Array[XPAwardResult] = []
	
	for award in awards:
		if award.size() >= 3:
			var result := award_combat_xp(award[0], award[1], award[2])
			results.append(result)
	
	return results
