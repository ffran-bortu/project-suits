class_name SoloUnit
extends Unit
## Solo unit - single character fighting alone
##
## BEST PRACTICE: Extends Unit for compatibility
## Applies solo penalty/bonus based on character skills

## Character data
var character: CharacterData

## Solo stat modifier
const SOLO_PENALTY: float = 0.7  # 70% stats when alone (most units)
var solo_multiplier: float = SOLO_PENALTY

## Whether this unit is stronger alone (Lone Wolf skill)
var has_lone_wolf: bool = false

## Setup solo unit from character
##
## @param char: CharacterData
## @param in_frontline: Whether to use frontline class
func setup_solo(char: CharacterData, in_frontline: bool = true):
	character = char
	
	# Set name
	unit_name = char.character_name
	
	# Check for Lone Wolf skill
	has_lone_wolf = "Lone Wolf" in char.unique_skill_names
	
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
	
	# Get base stats
	max_health = character.get_stat("hp", in_frontline)
	str = character.get_stat("str", in_frontline)
	mag = character.get_stat("mag", in_frontline)
	spd = character.get_stat("spd", in_frontline)
	skill_stat = character.get_stat("skill", in_frontline)
	luck = character.get_stat("luck", in_frontline)
	def = character.get_stat("def", in_frontline)
	res = character.get_stat("res", in_frontline)
	
	# Apply solo multiplier
	max_health = int(max_health * solo_multiplier)
	str = int(str * solo_multiplier)
	mag = int(mag * solo_multiplier)
	spd = int(spd * solo_multiplier)
	skill_stat = int(skill_stat * solo_multiplier)
	def = int(def * solo_multiplier)
	res = int(res * solo_multiplier)
	# Luck doesn't get modified
	
	current_health = max_health
	
	DebugLog.log("Solo stats: HP=%d STR=%d (%.0f%%)" % [max_health, str, solo_multiplier * 100], "cyan")

## Pair with another solo to create duo
##
## @param other_solo: Another SoloUnit
## @param self_is_front: Whether this unit becomes frontliner
## @return: New DuoUnit
func pair_with(other_solo: SoloUnit, self_is_front: bool) -> DuoUnit:
	# Create duo unit (BEST PRACTICE: instantiate node properly)
	var duo = DuoUnit.new()
	
	# Setup duo before adding to tree
	duo.setup_duo(self.character, other_solo.character, self_is_front)
	
	# Copy position to duo
	duo.global_position = self.global_position
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
