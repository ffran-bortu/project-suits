"""
FILE: solo_unit.gd
PURPOSE: Solo unit - single character fighting alone with stat penalty (or Lone Wolf bonus).

OVERVIEW:
Extends Unit base class to represent a character fighting solo (not paired in a duo). Applies a
-30% stat penalty by default (SOLO_PENALTY = 0.7) to discourage solo fighting, UNLESS the character
has the "Lone Wolf" unique skill, which grants +20% stats instead (solo_multiplier = 1.2). This
creates a strategic choice between duo bonuses and specialized solo builds.

FUNCTIONS IN THIS FILE:

1. setup_solo(character_data, in_frontline)
   - What it does: Configures solo unit from CharacterData, checks for Lone Wolf skill, calculates stats
   - Uses: Unit creation, duo splitting into solos
   - Returns: void

2. calculate_solo_stats(in_frontline)
   - What it does: Gets stats from character's class, applies solo_multiplier, stores in Unit properties
   - Uses: Called by setup_solo and whenever stats need recalculation
   - Returns: void

3. pair_with(other_solo, self_is_front)
   - What it does: Creates new DuoUnit from this solo and another solo unit
   - Uses: Player command to merge two solos into duo
   - Returns: DuoUnit (caller must handle adding to scene and removing solos)

4. gain_solo_experience(amount, in_frontline)
   - What it does: Awards XP to character's frontline or backline experience pool
   - Uses: Post-battle XP rewards
   - Returns: void

NOTES:
- SOLO_PENALTY = 0.7 means 70% of normal stats (30% penalty)
- Lone Wolf skill changes multiplier to 1.2 (120% stats, 20% bonus)
- Sets meta("is_solo", true) for visual differentiation in Unit._ready
- Smaller visual scale than duo (2.0x vs 3.0x in Unit.setup_visual)
- Character stats pulled from character.get_current_class()
- Movement and attack_range come from CharacterClass
- pair_with() does NOT remove the solos - caller must handle cleanup
- Integrates with CharacterData for progression and stat calculations
"""

class_name SoloUnit
extends Unit
## Solo unit - single character fighting alone
##
## BEST PRACTICE: Extends Unit for compatibility
## Applies solo penalty/bonus based on character skills



## Solo stat modifier
const SOLO_PENALTY: float = 0.7  # 70% stats when alone (most units)
var solo_multiplier: float = SOLO_PENALTY

## Whether this unit is stronger alone (Lone Wolf skill)
var has_lone_wolf: bool = false

## Setup solo unit from character
##
## @param character_data: CharacterData
## @param in_frontline: Whether to use frontline class
func setup_solo(character_data: CharacterData, in_frontline: bool = true):
	character = character_data
	
	# Set name
	unit_name = character_data.character_name
	
	# Check for Lone Wolf skill
	has_lone_wolf = "Lone Wolf" in character_data.unique_skill_names
	
	if has_lone_wolf:
		solo_multiplier = 1.2  # 120% when alone!
		DebugLog.success(unit_name + " has Lone Wolf! (+20% stats solo)")
	else:
		solo_multiplier = SOLO_PENALTY
		DebugLog.warn(unit_name + " is fighting solo (-30% stats)")
	
	# Calculate stats
	calculate_solo_stats(in_frontline)

## Calculate solo stats with penalty/bonus
##
## @param in_frontline: Position to use
func calculate_solo_stats(in_frontline: bool):
	var current_class = character.get_current_class(in_frontline)
	
	if not current_class:
		push_error("SoloUnit: No class for " + character.character_name)
		return
	
	# Get base stats (using direct properties instead of broken get_stat)
	max_health = character.max_hp
	strength = character.strength
	mag = character.mag
	spd = character.spd
	skill = character.skill
	luck = character.luck
	def = character.def
	res = character.res
	
	# Movement and attack range from class
	if "movement_range" in current_class:
		movement_range = current_class.movement_range
	else:
		movement_range = 4  # Default
	
	if "attack_range" in current_class:
		attack_range = current_class.attack_range
	else:
		attack_range = 1  # Default melee
	
	# Apply solo multiplier
	max_health = int(max_health * solo_multiplier)
	strength = int(strength * solo_multiplier)
	mag = int(mag * solo_multiplier)
	spd = int(spd * solo_multiplier)
	skill = int(skill * solo_multiplier)
	def = int(def * solo_multiplier)
	res = int(res * solo_multiplier)
	# Luck doesn't get modified
	
	current_health = max_health
	
	DebugLog.log("Solo stats: HP=%d STR=%d MOV=%d (%.0f%%)" % [max_health, strength, movement_range, solo_multiplier * 100], "cyan")
	
	# Visual setup needs to be deferred until after _ready when sprite exists
	# Store unit type for visual setup in _ready
	set_meta("is_solo", true)

## Pair with another solo to create duo
##
## @param other_solo: Another SoloUnit
## @param self_is_front: Whether this unit becomes frontliner
## @return: New DuoUnit
func pair_with(other_solo: SoloUnit, self_is_front: bool) -> DuoUnit:
	# Create duo unit (BEST PRACTICE: instantiate node properly)
	var duo = DuoUnit.new()
	
	# PHASE 4 FIX: Inject dependencies into new unit
	if has_method("set_dependencies") and game_state:
		duo.set_dependencies(game_state)
	elif "game_state" in duo and game_state: # Direct property fallback
		duo.game_state = game_state
	
	# Setup duo before adding to tree
	duo.setup_duo(self.character, other_solo.character, self_is_front)
	
	# Copy position to duo (use position not global_position - not in tree yet)
	duo.position = self.position
	duo.grid_position = self.grid_position
	duo.team = self.team
	
	DebugLog.success("Paired: " + duo.unit_name)
	
	# Don't remove solos here - let caller handle cleanup
	return duo

## Gain experience
##
## @param amount: XP amount
## @param in_frontline: Position XP is gained for
func gain_solo_experience(amount: int, in_frontline: bool):
	character.gain_exp(in_frontline, amount)
	DebugLog.log("%s gained %d XP (%s)" % [unit_name, amount, "frontline" if in_frontline else "backline"], "green")
