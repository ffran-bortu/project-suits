"""
FILE: level_up_system.gd
PURPOSE: Handles experience points and Fire Emblem-style random stat growth on level up.

OVERVIEW:
This system checks if characters have earned enough XP to level up, then rolls random stat increases
based on their class's growth rates (percentage chance per stat). Each stat has a chance to increase
by +1 on level up. The character is healed to full HP when leveling up. Emits level_up signal with
stat gains for UI to display.

FUNCTIONS IN THIS FILE:

1. check_level_up(character)
   - What it does: Checks if character has enough XP to level up and levels them up if so
   - Uses: Called after combat when character gains XP
   - Returns: bool (true if level up occurred)

2. level_up_character(character)
   - What it does: Increments level, rolls stat growth for all 8 stats, applies gains, heals to full
   - Uses: Called by check_level_up() when XP threshold reached
   - Returns: void

3. roll_stat_growth(growth_rate)
   - What it does: Rolls RNG (0-99) and returns +1 if roll < growth_rate, else 0
   - Uses: Called 8 times per level up (once per stat: HP, STR, MAG, SPD, SKL, LCK, DEF, RES)
   - Returns: int (0 or 1)

NOTES:
- Singleton-like manager (one instance per game)
- Depends on: CharacterData (for stats), CharacterClass (for growth rates)
- Constants: XP_PER_LEVEL = 100, MAX_LEVEL = 30
- Emits: level_up(character, new_level, stat_gains Dictionary)
- Fire Emblem mechanic: Each stat has independent % chance to increase
- Heals character to full HP on level up (character.current_hp = character.max_hp after HP growth)
"""

extends Node
## Level up system - handles XP and stat growth

const XP_PER_LEVEL: int = 100
const MAX_LEVEL: int = 30

	# signal level_up(character: CharacterData, new_level: int, stat_gains: Dictionary)

## Check if character should level up
func check_level_up(character: CharacterData) -> bool:
	var total_xp = character.frontline_exp + character.backline_exp
	var required_xp = character.get_current_level() * XP_PER_LEVEL
	
	if total_xp >= required_xp and character.get_current_level() < MAX_LEVEL:
		level_up_character(character)
		return true
	return false

## Level up character with random growth
func level_up_character(character: CharacterData) -> void:
	var current_class = character.get_current_class(true)
	if not current_class:
		return
	
	# Increment level
	if character.using_primary:
		character.primary_level += 1
	else:
		character.secondary_level += 1
	
	var _new_level = character.get_current_level() # Unused locally
	var stat_gains: Dictionary = {}
	
	# Random growth for each stat
	stat_gains["hp"] = roll_stat_growth(current_class.hp_growth)
	stat_gains["str"] = roll_stat_growth(current_class.str_growth)
	stat_gains["mag"] = roll_stat_growth(current_class.mag_growth)
	stat_gains["spd"] = roll_stat_growth(current_class.spd_growth)
	stat_gains["skill"] = roll_stat_growth(current_class.skill_growth)
	stat_gains["luck"] = roll_stat_growth(current_class.luck_growth)
	stat_gains["def"] = roll_stat_growth(current_class.def_growth)
	stat_gains["res"] = roll_stat_growth(current_class.res_growth)
	
	# Apply gains
	character.max_hp += stat_gains["hp"]
	character.current_hp += stat_gains["hp"]  # Heal on level up
	character.str += stat_gains["str"]
	character.mag += stat_gains["mag"]
	character.spd += stat_gains["spd"]
	character.skill += stat_gains["skill"]
	character.luck += stat_gains["luck"]
	character.def += stat_gains["def"]
	character.res += stat_gains["res"]
	# Emit level up
	if "level" in character:
		DebugLog.log("Level Up: %s reached Lvl %d!" % [character.character_name, character.level], "magenta")
		SignalBus.level_up.emit(character, character.level, stat_gains)
	else:
		# Fallback if no level property
		DebugLog.log("Level Up: %s (level unknown)!" % character.character_name, "magenta")
		SignalBus.level_up.emit(character, 0, stat_gains)

## Roll for stat increase (% chance)
func roll_stat_growth(growth_rate: int) -> int:
	var roll = randi() % 100
	return 1 if roll < growth_rate else 0
