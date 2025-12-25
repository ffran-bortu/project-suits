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
