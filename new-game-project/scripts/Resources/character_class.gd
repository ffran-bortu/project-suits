"""
FILE: character_class.gd
PURPOSE: Defines character classes with stat progression, growth rates, and position bonuses.

OVERVIEW:
This resource stores everything that defines a character class (e.g. Knight, Mage, Archer) including
base stats, growth rates, and bonuses for frontline/backline positioning. It uses enum-based stat
types for type safety and includes a caching system for performance. Each class can specify which
positions it's compatible with and which weapon types it can use.

FUNCTIONS IN THIS FILE:

1. get_stat_at_level_typed(stat_type, level, is_frontline)
   - What it does: Calculates a stat value at a specific level with position bonuses (enum-based)
   - Uses: Called by character systems to get current stats based on level and position
   - Returns: int stat value with growth and position bonuses applied

2. get_stat_at_level(stat_name, level, is_frontline)
   - What it does: String-based version of stat calculation for backward compatibility
   - Uses: Legacy code that hasn't been refactored to use enums yet
   - Returns: int stat value or 0 if stat name invalid

3. _string_to_stat_type(stat_name) 
   - What it does: Converts string stat names like "hp" or "str" to StatType enum
   - Uses: Internal helper for backward compatibility with string-based API
   - Returns: StatType enum value or -1 if invalid

4. _get_cached_stat(stat_type, level, is_frontline)
   - What it does: Retrieves stat from cache or calculates and caches it
   - Uses: Performance optimization to avoid recalculating same stat multiple times
   - Returns: int cached or newly calculated stat value

5. _make_cache_key(stat_type, level, is_frontline)
   - What it does: Creates unique string key for cache dictionary
   - Uses: Internal helper for cache system to store/retrieve stat values
   - Returns: String like "2-15-F" representing stat type, level, and position

6. _calculate_stat(stat_type, level, is_frontline)
   - What it does: Performs actual stat calculation using base + (growth * level) + position bonus
   - Uses: Called when stat not in cache; core stat progression logic
   - Returns: int calculated stat value (never negative)

7. clear_stat_cache()
   - What it does: Empties the stat cache dictionary
   - Uses: Called when class properties change to force recalculation
   - Returns: void

8. get_all_stats_at_level(level, is_frontline)
   - What it does: Gets all 8 stats at once in a single dictionary
   - Uses: Character initialization, level-up displays, stat comparison screens
   - Returns: Dictionary mapping StatType enum to int values

9. get_base_stat_typed(stat_type)
   - What it does: Returns the level 1 base value for a stat (enum-based)
   - Uses: Stat calculation, character creation, class comparisons
   - Returns: int base stat value

10. get_base_stat(stat_name)
    - What it does: String-based version of get_base_stat_typed
    - Uses: Legacy compatibility
    - Returns: int base value or 0 if invalid

11. get_growth_rate_typed(stat_type)
    - What it does: Returns growth rate percentage (0-100) for a stat
    - Uses: Level-up calculations, probability systems, class comparisons
    - Returns: int growth rate percentage

12. get_growth_rate(stat_name)
    - What it does: String-based version of get_growth_rate_typed
    - Uses: Legacy compatibility
    - Returns: int growth rate or 0 if invalid

13. get_frontline_bonus_typed(stat_type)
    - What it does: Returns bonus applied when unit is in frontline position
    - Uses: Stat calculations, duo positioning systems
    - Returns: int bonus (can be negative, 0 if stat doesn't get frontline bonus)

14. get_frontline_bonus(stat_name)
    - What it does: String-based version of get_frontline_bonus_typed
    - Uses: Legacy compatibility
    - Returns: int bonus or 0 if invalid

15. get_backline_bonus_typed(stat_type)
    - What it does: Returns bonus applied when unit is in backline position
    - Uses: Stat calculations, duo positioning systems
    - Returns: int bonus (can be negative, 0 if stat doesn't get backline bonus)

16. get_backline_bonus(stat_name)
    - What it does: String-based version of get_backline_bonus_typed
    - Uses: Legacy compatibility
    - Returns: int bonus or 0 if invalid

17. validate_class()
    - What it does: Checks for errors like invalid growth rates, impossible position flags
    - Uses: Resource creation, save file loading, development debugging
    - Returns: Array of error message strings (empty if valid)

18. repair_class()
    - What it does: Fixes invalid class data by clamping values and fixing flags
    - Uses: Automatically called when loading corrupted save data
    - Returns: true if repairs were made, false if unchanged

19. debug_stat_progression(max_level)
    - What it does: Prints formatted table showing stat progression across levels
    - Uses: Game balance testing, class design iteration
    - Returns: void (prints to console)

20. get_debug_summary()
    - What it does: Creates multi-line string summary of class data and validation status
    - Uses: Development debugging, QA testing
    - Returns: String with class summary and validation results

NOTES:
- Uses stat caching to avoid expensive recalculations
- Supports both enum-based (new) and string-based (legacy) APIs
- Position bonuses allow tactical duo unit mechanics (frontline gets STR/DEF/HP, backline gets MAG/SPD/RES)
- Growth rates represent percentage chance per level (e.g. 50 = average 0.5 stat gain per level)
- Can specify position restrictions via can_be_frontline and can_be_backline flags
- Clear cache after any property changes to ensure accurate recalculation
"""


class_name CharacterClass
extends Resource

## Defines a character class with type-safe stats, growth rates, and position bonuses

# --- Stat Type Enum ---
# --- Stat Type Enum ---
# Moved to GameTypes.gd
# enum StatType { HP, STR, MAG, SPD, SKILL, LUCK, DEF, RES }

# --- Stat Name Constants ---
const STAT_NAMES: Dictionary = {
	GameTypes.StatType.HP: "hp",
	GameTypes.StatType.STR: "str",
	GameTypes.StatType.MAG: "mag",
	GameTypes.StatType.SPD: "spd",
	GameTypes.StatType.SKILL: "skill",
	GameTypes.StatType.LUCK: "luck",
	GameTypes.StatType.DEF: "def",
	GameTypes.StatType.RES: "res"
}

const STAT_DISPLAY_NAMES: Dictionary = {
	GameTypes.StatType.HP: "Health",
	GameTypes.StatType.STR: "Strength",
	GameTypes.StatType.MAG: "Magic",
	GameTypes.StatType.SPD: "Speed",
	GameTypes.StatType.SKILL: "Skill",
	GameTypes.StatType.LUCK: "Luck",
	GameTypes.StatType.DEF: "Defense",
	GameTypes.StatType.RES: "Resistance"
}

# --- Class Archetype Enum ---
enum ClassArchetype {
	WARRIOR,      # Physical attacker
	MAGE,         # Magic attacker
	SUPPORT,      # Healer/buffer
	COMMANDER,    # Leader/buffer
	TANK,         # High defense
	ASSASSIN,     # High crit/speed
	ARCHER,       # Ranged physical
	CLERIC        # Healing specialist
}

# --- Equipment Type Enums ---
enum WeaponType {
	SWORD = 0,
	LANCE = 1,
	AXE = 2,
	BOW = 3,
	STAFF = 4,
	TOME = 5,
	DAGGER = 6
}

const WEAPON_TYPE_NAMES: Dictionary = {
	WeaponType.SWORD: "Sword",
	WeaponType.LANCE: "Lance",
	WeaponType.AXE: "Axe",
	WeaponType.BOW: "Bow",
	WeaponType.STAFF: "Staff",
	WeaponType.TOME: "Tome",
	WeaponType.DAGGER: "Dagger"
}

# --- Validation Constants ---
const MIN_GROWTH_RATE: int = 0
const MAX_GROWTH_RATE: int = 100
const MIN_BASE_STAT: int = 0
const MAX_BASE_STAT: int = 50
const MAX_LEVEL: int = 40

# --- Class Identification ---
@export var display_name: String = "Fighter"
@export var archetype: ClassArchetype = ClassArchetype.WARRIOR
@export_multiline var description: String = ""

# --- Position Compatibility ---
@export var can_be_frontline: bool = true
@export var can_be_backline: bool = true

# --- Base Stats at Level 1 ---
@export_group("Base Stats")
@export_range(1, 50) var base_hp: int = 20
@export_range(0, 50) var base_str: int = 5
@export_range(0, 50) var base_mag: int = 3
@export_range(0, 50) var base_spd: int = 5
@export_range(0, 50) var base_skill: int = 5
@export_range(0, 50) var base_luck: int = 5
@export_range(0, 50) var base_def: int = 4
@export_range(0, 50) var base_res: int = 2

# --- Position Bonuses ---
@export_group("Frontline Bonuses")
@export_range(-10, 10) var frontline_str_bonus: int = 2
@export_range(-10, 10) var frontline_def_bonus: int = 3
@export_range(-10, 10) var frontline_hp_bonus: int = 5

@export_group("Backline Bonuses")
@export_range(-10, 10) var backline_mag_bonus: int = 2
@export_range(-10, 10) var backline_spd_bonus: int = 2
@export_range(-10, 10) var backline_res_bonus: int = 3

# --- Growth Rates (0-100) ---
@export_group("Growth Rates")
@export_range(0, 100) var hp_growth: int = 50
@export_range(0, 100) var str_growth: int = 45
@export_range(0, 100) var mag_growth: int = 30
@export_range(0, 100) var spd_growth: int = 40
@export_range(0, 100) var skill_growth: int = 35
@export_range(0, 100) var luck_growth: int = 40
@export_range(0, 100) var def_growth: int = 30
@export_range(0, 100) var res_growth: int = 25

# --- Equipment Restrictions ---
@export_group("Equipment")
@export var usable_weapon_types: Array[String] = ["Sword"]  # Legacy compatibility

# --- Stat Cache ---
var _stat_cache: Dictionary = {}  # (stat_type, level, is_frontline) -> value
var _cache_enabled: bool = true


## Get stat at specific level (enum-based, cached)
## @param stat_type: GameTypes.StatType enum
## @param level: Current level
## @param is_frontline: Position
## @return: Calculated stat value
func get_stat_at_level_typed(stat_type: GameTypes.StatType, level: int, is_frontline: bool) -> int:
	if _cache_enabled:
		return _get_cached_stat(stat_type, level, is_frontline)
	return _calculate_stat(stat_type, level, is_frontline)


## Get stat at specific level (string-based for backward compatibility)
## @param stat_name: Name of stat (hp, str, etc)
## @param level: Current level
## @param is_frontline: Position
## @return: Calculated stat value
func get_stat_at_level(stat_name: String, level: int, is_frontline: bool) -> int:
	var stat_type := _string_to_stat_type(stat_name)
	if stat_type == -1:
		push_warning("CharacterClass: Unknown stat name '%s', returning 0" % stat_name)
		return 0
	return get_stat_at_level_typed(stat_type, level, is_frontline)


## Convert string stat name to StatType enum
## @param stat_name: String stat name
## @return: StatType enum value or -1 if invalid
func _string_to_stat_type(stat_name: String) -> GameTypes.StatType:
	return GameTypes.string_to_stat_type(stat_name)


## Get cached stat or calculate if not cached
## @param stat_type: Stat type
## @param level: Level
## @param is_frontline: Position
## @return: Stat value
func _get_cached_stat(stat_type: GameTypes.StatType, level: int, is_frontline: bool) -> int:
	var key := _make_cache_key(stat_type, level, is_frontline)
	
	if not _stat_cache.has(key):
		_stat_cache[key] = _calculate_stat(stat_type, level, is_frontline)
	
	return _stat_cache[key]


## Make cache key
## @param stat_type: GameTypes.StatType
## @param level: Level
## @param is_frontline: Position
## @return: Cache key string
func _make_cache_key(stat_type: GameTypes.StatType, level: int, is_frontline: bool) -> String:
	return "%d-%d-%s" % [stat_type, level, "F" if is_frontline else "B"]


## Calculate stat value
## @param stat_type: GameTypes.StatType
## @param level: Level
## @param is_frontline: Position
## @return: Calculated stat value
func _calculate_stat(stat_type: GameTypes.StatType, level: int, is_frontline: bool) -> int:
	var base := get_base_stat_typed(stat_type)
	var growth := get_growth_rate_typed(stat_type)
	
	# Growth calculation (average/expected value)
	var growth_bonus := int((level - 1) * growth / 100.0)
	var total := base + growth_bonus
	
	# Apply position bonuses
	if is_frontline:
		total += get_frontline_bonus_typed(stat_type)
	else:
		total += get_backline_bonus_typed(stat_type)
	
	return max(0, total)  # Ensure non-negative


## Clear stat cache (call when class properties change)
func clear_stat_cache() -> void:
	_stat_cache.clear()


## Get all stats at level
## @param level: Level
## @param is_frontline: Position
## @return: Dictionary of StatType -> value
func get_all_stats_at_level(level: int, is_frontline: bool) -> Dictionary:
	var stats := {}
	for stat_type in GameTypes.StatType.values():
		stats[stat_type] = get_stat_at_level_typed(stat_type, level, is_frontline)
	return stats


## Get base stat (enum-based)
## @param stat_type: GameTypes.StatType
## @return: Base value
func get_base_stat_typed(stat_type: GameTypes.StatType) -> int:
	match stat_type:
		GameTypes.StatType.HP: return base_hp
		GameTypes.StatType.STR: return base_str
		GameTypes.StatType.MAG: return base_mag
		GameTypes.StatType.SPD: return base_spd
		GameTypes.StatType.SKILL: return base_skill
		GameTypes.StatType.LUCK: return base_luck
		GameTypes.StatType.DEF: return base_def
		GameTypes.StatType.RES: return base_res
		_: return 0


## Get base stat (string-based for backward compatibility)
## @param stat_name: Stat name
## @return: Base value
func get_base_stat(stat_name: String) -> int:
	var stat_type := _string_to_stat_type(stat_name)
	if stat_type == -1:
		return 0
	return get_base_stat_typed(stat_type)


## Get growth rate (enum-based)
## @param stat_type: GameTypes.StatType
## @return: Growth rate (0-100)
func get_growth_rate_typed(stat_type: GameTypes.StatType) -> int:
	match stat_type:
		GameTypes.StatType.HP: return hp_growth
		GameTypes.StatType.STR: return str_growth
		GameTypes.StatType.MAG: return mag_growth
		GameTypes.StatType.SPD: return spd_growth
		GameTypes.StatType.SKILL: return skill_growth
		GameTypes.StatType.LUCK: return luck_growth
		GameTypes.StatType.DEF: return def_growth
		GameTypes.StatType.RES: return res_growth
		_: return 0


## Get growth rate (string-based for backward compatibility)
## @param stat_name: Stat name
## @return: Growth rate
func get_growth_rate(stat_name: String) -> int:
	var stat_type := _string_to_stat_type(stat_name)
	if stat_type == -1:
		return 0
	return get_growth_rate_typed(stat_type)


## Get frontline bonus (enum-based)
## @param stat_type: GameTypes.StatType
## @return: Bonus value
func get_frontline_bonus_typed(stat_type: GameTypes.StatType) -> int:
	match stat_type:
		GameTypes.StatType.STR: return frontline_str_bonus
		GameTypes.StatType.DEF: return frontline_def_bonus
		GameTypes.StatType.HP: return frontline_hp_bonus
		_: return 0


## Get frontline bonus (string-based for backward compatibility)
## @param stat_name: Stat name
## @return: Bonus value
func get_frontline_bonus(stat_name: String) -> int:
	var stat_type := _string_to_stat_type(stat_name)
	if stat_type == -1:
		return 0
	return get_frontline_bonus_typed(stat_type)


## Get backline bonus (enum-based)
## @param stat_type: GameTypes.StatType
## @return: Bonus value
func get_backline_bonus_typed(stat_type: GameTypes.StatType) -> int:
	match stat_type:
		GameTypes.StatType.MAG: return backline_mag_bonus
		GameTypes.StatType.SPD: return backline_spd_bonus
		GameTypes.StatType.RES: return backline_res_bonus
		_: return 0


## Get backline bonus (string-based for backward compatibility)
## @param stat_name: Stat name
## @return: Bonus value
func get_backline_bonus(stat_name: String) -> int:
	var stat_type := _string_to_stat_type(stat_name)
	if stat_type == -1:
		return 0
	return get_backline_bonus_typed(stat_type)


## Validate class properties
## @return: Array of error messages (empty if valid)
func validate_class() -> Array[String]:
	var errors: Array[String] = []
	
	# Validate position flags
	if not can_be_frontline and not can_be_backline:
		errors.append("Class cannot be in any position")
	
	# Validate growth rates
	for stat_name in ["hp", "str", "mag", "spd", "skill", "luck", "def", "res"]:
		var growth := get_growth_rate(stat_name)
		if growth < MIN_GROWTH_RATE or growth > MAX_GROWTH_RATE:
			errors.append("Invalid %s growth rate: %d (must be %d-%d)" % [
				stat_name, growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE
			])
	
	# Validate base stats
	for stat_type in GameTypes.StatType.values():
		var base := get_base_stat_typed(stat_type)
		if base < MIN_BASE_STAT:
			errors.append("Invalid base %s: %d (must be >= %d)" % [
				STAT_NAMES[stat_type], base, MIN_BASE_STAT
			])
	
	# Validate display name
	if display_name.is_empty():
		errors.append("Display name is empty")
	
	return errors


## Repair invalid class properties
## @return: true if repaired, false if unfixable
func repair_class() -> bool:
	var was_repaired := false
	
	# Fix position flags
	if not can_be_frontline and not can_be_backline:
		can_be_frontline = true
		was_repaired = true
	
	# Clamp growth rates
	hp_growth = clamp(hp_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	str_growth = clamp(str_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	mag_growth = clamp(mag_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	spd_growth = clamp(spd_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	skill_growth = clamp(skill_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	luck_growth = clamp(luck_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	def_growth = clamp(def_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	res_growth = clamp(res_growth, MIN_GROWTH_RATE, MAX_GROWTH_RATE)
	
	# Clamp base stats
	base_hp = max(1, base_hp)  # HP must be at least 1
	base_str = max(MIN_BASE_STAT, base_str)
	base_mag = max(MIN_BASE_STAT, base_mag)
	base_spd = max(MIN_BASE_STAT, base_spd)
	base_skill = max(MIN_BASE_STAT, base_skill)
	base_luck = max(MIN_BASE_STAT, base_luck)
	base_def = max(MIN_BASE_STAT, base_def)
	base_res = max(MIN_BASE_STAT, base_res)
	
	# Fix display name
	if display_name.is_empty():
		display_name = "Unnamed Class"
		was_repaired = true
	
	# Clear cache after repair
	if was_repaired:
		clear_stat_cache()
	
	return was_repaired


## Debug: Print stat progression table
## @param max_level: Maximum level to display
func debug_stat_progression(max_level: int = 20) -> void:
	print("=== %s (%s) Stat Progression ===" % [display_name, ClassArchetype.keys()[archetype]])
	print("Lvl |  HP | Str | Mag | Spd | Skl | Lck | Def | Res | Position")
	print("----+-----+-----+-----+-----+-----+-----+-----+-----+---------")
	
	for level in range(1, min(max_level + 1, MAX_LEVEL + 1)):
		var front_stats := get_all_stats_at_level(level, true)
		var back_stats := get_all_stats_at_level(level, false)
		
		print("%3d | %3d | %3d | %3d | %3d | %3d | %3d | %3d | %3d | Front" % [
			level,
			front_stats[GameTypes.StatType.HP],
			front_stats[GameTypes.StatType.STR],
			front_stats[GameTypes.StatType.MAG],
			front_stats[GameTypes.StatType.SPD],
			front_stats[GameTypes.StatType.SKILL],
			front_stats[GameTypes.StatType.LUCK],
			front_stats[GameTypes.StatType.DEF],
			front_stats[GameTypes.StatType.RES]
		])
		
		print("    | %3d | %3d | %3d | %3d | %3d | %3d | %3d | %3d | Back" % [
			back_stats[GameTypes.StatType.HP],
			back_stats[GameTypes.StatType.STR],
			back_stats[GameTypes.StatType.MAG],
			back_stats[GameTypes.StatType.SPD],
			back_stats[GameTypes.StatType.SKILL],
			back_stats[GameTypes.StatType.LUCK],
			back_stats[GameTypes.StatType.DEF],
			back_stats[GameTypes.StatType.RES]
		])


## Get class summary for debugging
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== %s ===\n" % display_name
	summary += "Archetype: %s\n" % ClassArchetype.keys()[archetype]
	summary += "Positions: %s\n" % (
		"Both" if (can_be_frontline and can_be_backline) else
		"Frontline only" if can_be_frontline else
		"Backline only"
	)
	
	summary += "\nBase Stats (Level 1):\n"
	for stat_type in GameTypes.StatType.values():
		summary += "  %s: %d (Growth: %d%%)\n" % [
			STAT_DISPLAY_NAMES[stat_type],
			get_base_stat_typed(stat_type),
			get_growth_rate_typed(stat_type)
		]
	
	# Validation
	var errors := validate_class()
	if errors.is_empty():
		summary += "\n✓ Class valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary
