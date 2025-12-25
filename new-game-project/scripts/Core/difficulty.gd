"""
FILE: difficulty.gd
PURPOSE: Manages game difficulty settings and provides stat multipliers for enemies and XP.

OVERVIEW:
This static class stores the current difficulty level (Easy/Normal/Hard/Lunatic) and provides
multipliers that affect enemy stats and player XP gains. Easy mode gives enemies 80% stats and
players 120% XP, while Lunatic gives enemies 160% stats and players 80% XP. Used by enemy
spawning and combat systems to scale challenge.

FUNCTIONS IN THIS FILE:

1. get_enemy_stat_multiplier()
   - What it does: Returns multiplier for enemy stats based on difficulty (0.8 to 1.6)
   - Uses: Called when spawning enemies or calculating enemy stats
   - Returns: float (0.8 for Easy, 1.0 for Normal, 1.3 for Hard, 1.6 for Lunatic)

2. get_xp_multiplier()
   - What it does: Returns multiplier for player XP gains based on difficulty
   - Uses: Called when awarding XP after combat
   - Returns: float (1.2 for Easy, 1.0 for Normal/Hard, 0.8 for Lunatic)

3. get_level_name(level)
   - What it does: Converts difficulty enum to display string
   - Uses: For UI difficulty selection screen
   - Returns: String ("Easy", "Normal", "Hard", or "Lunatic")

4. get_level_description(level)
   - What it does: Returns description text explaining what each difficulty does
   - Uses: For difficulty selection UI tooltip
   - Returns: String with percentage and recommendation

NOTES:
- Static class (all members static, use Difficulty.get_enemy_stat_multiplier() directly)
- Contains enum Level: EASY, NORMAL, HARD, LUNATIC
- Static variable current_level stores selected difficulty
- No dependencies (leaf utility class)
- Used by: enemy spawning, combat calculations, XP awards
"""

class_name Difficulty
extends RefCounted
## Manages game difficulty settings
##
## Provides global difficulty state and stat modifiers for enemies.
## Uses static variables (best practice: avoid autoload for simple data).

enum Level {
	EASY,
	NORMAL,
	HARD,
	LUNATIC
}

## Current difficulty level
static var current_level: Level = Level.NORMAL

## Get enemy stat multiplier based on difficulty
##
## @return: Multiplier for enemy stats (0.8 = 80%, 1.6 = 160%)
static func get_enemy_stat_multiplier() -> float:
	match current_level:
		Level.EASY:
			return 0.8
		Level.NORMAL:
			return 1.0
		Level.HARD:
			return 1.3
		Level.LUNATIC:
			return 1.6
	return 1.0

## Get player XP multiplier based on difficulty
##
## @return: Multiplier for XP gains
static func get_xp_multiplier() -> float:
	match current_level:
		Level.EASY:
			return 1.2  # Bonus XP on easy
		Level.NORMAL:
			return 1.0
		Level.HARD:
			return 1.0
		Level.LUNATIC:
			return 0.8  # Less XP on hardest difficulty
	return 1.0

## Get display name for difficulty level
##
## @param level: Difficulty level enum
## @return: Human-readable name
static func get_level_name(level: Level) -> String:
	match level:
		Level.EASY:
			return "Easy"
		Level.NORMAL:
			return "Normal"
		Level.HARD:
			return "Hard"
		Level.LUNATIC:
			return "Lunatic"
	return "Normal"

## Get description for difficulty level
##
## @param level: Difficulty level enum
## @return: Description text
static func get_level_description(level: Level) -> String:
	match level:
		Level.EASY:
			return "Enemies have 80% stats. Recommended for new players."
		Level.NORMAL:
			return "Balanced difficulty. The intended experience."
		Level.HARD:
			return "Enemies have 130% stats. For experienced players."
		Level.LUNATIC:
			return "Enemies have 160% stats. Extreme challenge!"
	return ""
