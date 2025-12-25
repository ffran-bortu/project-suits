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
	
	# Load bond level
	duo_bond_level = char_a.bond_levels.get(char_b.character_name, 0)
	
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
	max_health = frontliner.get_stat("hp", true) + backliner.get_stat("hp", false)
	current_health = max_health
	
	# Other stats: Average + position bonuses (already included in get_stat)
	str = (frontliner.get_stat("str", true) + backliner.get_stat("str", false)) / 2
	mag = (frontliner.get_stat("mag", true) + backliner.get_stat("mag", false)) / 2
	spd = (frontliner.get_stat("spd", true) + backliner.get_stat("spd", false)) / 2
	skill_stat = (frontliner.get_stat("skill", true) + backliner.get_stat("skill", false)) / 2
	luck = (frontliner.get_stat("luck", true) + backliner.get_stat("luck", false)) / 2
	def = (frontliner.get_stat("def", true) + backliner.get_stat("def", false)) / 2
	res = (frontliner.get_stat("res", true) + backliner.get_stat("res", false)) / 2
	
	# Apply bond bonuses
	apply_bond_bonuses()
	
	DebugLog.log("Duo stats calculated: HP=%d STR=%d" % [max_health, str], "cyan")

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

## Separate duo back into two solo units
##
## @return: Array of two SoloUnit instances
func separate_duo() -> Array:
	var solos: Array = []
	
	# Create solo units (will be created in SoloUnit class)
	# For now, return empty array
	# TODO: Implement in SoloUnit
	
	DebugLog.log("Duo separated: " + unit_name, "yellow")
	
	# Distribute HP proportionally
	var hp_ratio_a = float(character_a.current_hp) / character_a.max_hp
	var hp_ratio_b = float(character_b.current_hp) / character_b.max_hp
	var avg_ratio = (hp_ratio_a + hp_ratio_b) / 2.0
	
	# Each solo gets their share
	var hp_for_a = int(character_a.max_hp * avg_ratio)
	var hp_for_b = int(character_b.max_hp * avg_ratio)
	
	# Store HP for solo units to pick up
	character_a.current_hp = hp_for_a
	character_b.current_hp = hp_for_b
	
	return solos

## Gain experience (both characters gain XP separately)
##
## @param amount: XP amount
func gain_duo_experience(amount: int):
	# Frontliner gains frontline XP
	frontliner.gain_exp(true, amount)
	
	# Backliner gains backline XP
	backliner.gain_exp(false, amount)
	
	DebugLog.log("Duo gained %d XP (split between positions)" % amount, "green")
