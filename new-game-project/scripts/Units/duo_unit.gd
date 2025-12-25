"""
FILE: duo_unit.gd
PURPOSE: Duo unit - fusion of two characters into one tactical unit with combined stats and bond bonuses.

OVERVIEW:
Extends Unit to represent two characters fighting together as a single powerful unit. Combines stats
from frontliner (frontline position class) and backliner (backline position class) - HP is summed,
other stats are averaged. Bond rank between characters grants hit/avoid/crit bonuses (C=+5, B=+10/+5, 
A=+15/+10, S=+20/+15). Players can switch positions mid-game and split back into two solos.

FUNCTIONS IN THIS FILE:

1. setup_duo(char_a, char_b, a_is_front)
   - What it does: Configures duo from two CharacterData, assigns frontliner/backliner, calculates stats
   - Uses: Creating duo from two solos, loading duos from save data
   - Returns: void

2. calculate_duo_stats()
   - What it does: Sums HP, averages other stats, uses frontliner's move/attack range
   - Uses: Called by setup_duo and after position switches
   - Returns: void

3. apply_bond_bonuses()
   - What it does: Applies hit/avoid/crit bonuses based on duo_bond_level (C=1, B=2, A=3, S/A+=4)
   - Uses: Called by calculate_duo_stats to add relationship bonuses
   - Returns: void (currently just logs, awaits hit/avoid/crit properties)

4. switch_positions()
   - What it does: Swaps frontliner and backliner, recalculates stats, updates unit_name
   - Uses: Player command during battle to change active position
   - Returns: void

5. split_duo(split_position)
   - What it does: Creates two SoloUnits from the duo, divides HP proportionally, marks both as acted
   - Uses: Player command to separate duo back into solos
   - Returns: Array [solo1, solo2] (caller must add to scene and remove duo)

6. gain_duo_experience(amount)
   - What it does: Awards XP to frontliner (frontline exp) and backliner (backline exp)
   - Uses: Post-battle XP rewards for duos
   - Returns: void

NOTES:
- DuoPosition enum: FRONTLINER (active), BACKLINER (support)
- HP = frontliner.max_hp + backliner.max_hp (summed for durability)
- Other stats = average of frontliner and backliner
- Movement/attack range from frontliner's class only
- duo_bond_level loaded from char_a.get_bond_rank(char_b.character_id)
- Bond bonuses: C=+5 hit/avoid, B=+10/+10/+5 crit, A=+15/+15/+10, S=+20/+20/+15
- Sets meta("is_duo", true) for visual differentiation in Unit._ready
- Larger visual scale than solo (3.0x vs 2.0x in Unit.setup_visual)
- unit_name format: "Lyn & Eliwood"
- split_duo() splits HP based on individual max_hp ratios
- Both solos marked has_acted=true and has_moved=true after split
- Integrates with CharacterData and BondSystem
"""

class_name DuoUnit
extends Unit
## Duo unit - fusion of two characters into one unit
##
## BEST PRACTICE: Extends existing Unit class for compatibility
## Acts as single unit but pools stats and actions from both characters

## Duo position enum
enum DuoPosition {
	FRONTLINER,
	BACKLINER
}

## The two characters in this duo
var character_a: CharacterData
var character_b: CharacterData

## Current positions
var frontliner: CharacterData
var backliner: CharacterData

## Bond level for this specific pair
var duo_bond_level: int = 0

## Setup duo from two characters
##
## BEST PRACTICE: Set properties before adding to tree
## @param char_a: First character
## @param char_b: Second character
## @param a_is_front: Whether char_a is frontliner
func setup_duo(char_a: CharacterData, char_b: CharacterData, a_is_front: bool):
	character_a = char_a
	character_b = char_b
	
	# Set positions
	if a_is_front:
		frontliner = char_a
		backliner = char_b
	else:
		frontliner = char_b
		backliner = char_a
	
	# Set unit name
	unit_name = frontliner.character_name + " & " + backliner.character_name
	
	# Load bond level using CharacterData API
	duo_bond_level = char_a.get_bond_rank(char_b.character_id)
	
	# Calculate combined stats
	calculate_duo_stats()
	
	DebugLog.log("Duo formed: " + unit_name, "green")

## Calculate combined stats from both characters
func calculate_duo_stats():
	# Get stats from both characters
	var front_class = frontliner.get_current_class(true)
	var back_class = backliner.get_current_class(false)
	
	if not front_class or not back_class:
		push_error("DuoUnit: Missing class for duo")
		return
	
	# HP: Sum both (duo has combined health pool)
	max_health = frontliner.max_hp + backliner.max_hp
	current_health = max_health
	
	# Other stats: Average (using direct properties instead of broken get_stat)
	strength = int((frontliner.strength + backliner.strength) / 2.0)
	mag = int((frontliner.mag + backliner.mag) / 2.0)
	spd = int((frontliner.spd + backliner.spd) / 2.0)
	skill = int((frontliner.skill + backliner.skill) / 2.0)
	luck = int((frontliner.luck + backliner.luck) / 2.0)
	def = int((frontliner.def + backliner.def) / 2.0)
	res = int((frontliner.res + backliner.res) / 2.0)
	
	# Movement range: Use frontliner's movement (front_class already declared above)
	if front_class and "movement_range" in front_class:
		movement_range = front_class.movement_range
	else:
		movement_range = 4  # Default
	
	# Attack range: Use frontliner's weapon range
	if front_class and "attack_range" in front_class:
		attack_range = front_class.attack_range
	else:
		attack_range = 1  # Default melee
	
	# Apply bond bonuses
	apply_bond_bonuses()
	
	DebugLog.log("Duo stats calculated: HP=%d STR=%d MOV=%d" % [max_health, strength, movement_range], "cyan")
	
	# Visual setup needs to be deferred until after _ready when sprite exists
	# Store unit type for visual setup in _ready
	set_meta("is_duo", true)

## Apply stat bonuses based on bond level
func apply_bond_bonuses():
	var hit_bonus = 0
	var avoid_bonus = 0
	var crit_bonus = 0
	
	match duo_bond_level:
		1:  # C rank
			hit_bonus = 5
			avoid_bonus = 5
		2:  # B rank
			hit_bonus = 10
			avoid_bonus = 10
			crit_bonus = 5
		3:  # A rank
			hit_bonus = 15
			avoid_bonus = 15
			crit_bonus = 10
		4:  # S or A+ rank
			hit_bonus = 20
			avoid_bonus = 20
			crit_bonus = 15
	
	# TODO: Apply bonuses when hit/avoid/crit properties exist
	# For now, just log
	if duo_bond_level > 0:
		DebugLog.log("Bond bonuses: +%d hit, +%d avoid, +%d crit" % [hit_bonus, avoid_bonus, crit_bonus], "purple")

## Switch frontliner and backliner positions
func switch_positions():
	var temp = frontliner
	frontliner = backliner
	backliner = temp
	
	# Recalculate stats with new positions
	calculate_duo_stats()
	
	# Update name
	unit_name = frontliner.character_name + " & " + backliner.character_name
	
	DebugLog.log("Duo positions switched: " + unit_name, "yellow")
	
	# TODO: Play switch animation

## Split duo into two solo units (returns array [solo1, solo2])
func split_duo(split_position: Vector2i) -> Array:
	var solo_scene = preload("res://scenes/solo_unit.tscn")
	
	var solo1 = solo_scene.instantiate()
	solo1.team = team
	solo1.setup_solo(frontliner, true)
	solo1.grid_position = grid_position
	solo1.position = position
	
	var solo2 = solo_scene.instantiate()
	solo2.team = team
	solo2.setup_solo(backliner, false)
	solo2.grid_position = split_position
	solo2.position = GridManager.grid_to_world_3d(split_position)
	
	# Split HP by max HP ratio
	var total_max = solo1.max_health + solo2.max_health
	solo1.current_health = int(current_health * float(solo1.max_health) / total_max)
	solo2.current_health = int(current_health * float(solo2.max_health) / total_max)
	
	# Both end turn
	solo1.has_acted = true
	solo1.has_moved = true
	solo2.has_acted = true
	solo2.has_moved = true
	
	return [solo1, solo2]

## Gain experience (both characters gain XP separately)
##
## @param amount: XP amount
func gain_duo_experience(amount: int):
	# Frontliner gains frontline XP
	frontliner.gain_exp(true, amount)
	
	# Backliner gains backline XP
	backliner.gain_exp(false, amount)
	
	DebugLog.log("Duo gained %d XP (split between positions)" % amount, "green")
