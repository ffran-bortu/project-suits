"""
FILE: character_data.gd
PURPOSE: Stores all data for a single playable character including stats, progression, and relationships.

OVERVIEW:
This resource represents a complete character in the game, tracking their current class, level, experience,
stats, and bond relationships with other characters. It manages two separate class pools (primary/secondary)
with independent leveling, a stat cache for performance, and comprehensive bond/support data. Characters gain
experience separately for frontline and backline positions and can switch between class sets.

FUNCTIONS IN THIS FILE:

1. _init()
   - What it does: Initializes character_id from character_name if empty
   - Uses: Called automatically when a new CharacterData resource is created
   - Returns: void

2. get_current_class(in_frontline)
   - What it does: Returns active CharacterClass based on using_primary flag and validates position compatibility
   - Uses: Stat calculations, UI displays, combat systems need to know current class
   - Returns: CharacterClass or null if none assigned

3. get_current_level()
   - What it does: Returns level of currently active class (primary or secondary)
   - Uses: Experience, stat calculations, UI displays
   - Returns: int level (1-40)

4. switch_class()
   - What it does: Toggles between primary and secondary class, marks cache dirty, emits signal
   - Uses: Player commands to change active class mid-campaign
   - Returns: void

5. get_stat_typed(stat_type, in_frontline)
   - What it does: Gets cached stat value using enum-based stat type
   - Uses: Combat calculations, UI displays, any system needing character stats
   - Returns: int stat value (refreshes cache if dirty)

6. get_stat(stat_name, in_frontline)
   - What it does: String-based version of get_stat_typed for backward compatibility
   - Uses: Legacy code not yet refactored to use enums
   - Returns: int stat value or 0 if stat name invalid

7. _string_to_stat_type(stat_name)
   - What it does: Converts string names like "hp", "str" to StatType enum
   - Uses: Internal helper for string-based API compatibility
   - Returns: StatType enum or -1 if invalid

8. _make_stat_cache_key(stat_type, is_frontline)
   - What it does: Creates unique cache key from stat type and position
   - Uses: Internal cache management
   - Returns: String like "2-F" or "5-B"

9. _mark_cache_dirty()
   - What it does: Flags cache for recalculation on next stat access
   - Uses: Called when level, class, or any stat-affecting property changes
   - Returns: void

10. _refresh_cache()
    - What it does: Recalculates all stats from current class and level, stores in cache
    - Uses: Called automatically when cache is dirty and stats are accessed
    - Returns: void

11. _refresh_cache_string_api(is_frontline, current_class, level)
    - What it does: Legacy fallback cache refresh using string-based API
    - Uses: Classes that don't support typed stat methods
    - Returns: void

12. get_all_stats(in_frontline)
    - What it does: Returns dictionary of all stats at once
    - Uses: Character sheets, stat comparison screens, save systems
    - Returns: Dictionary mapping StatType to int values

13. gain_exp(in_frontline, amount)
    - What it does: Awards experience to frontline or backline pool, checks for level up
    - Uses: Post-battle rewards, training systems
    - Returns: true if character leveled up

14. _check_level_up()
    - What it does: Checks if total experience meets threshold for next level
    - Uses: Called after any experience gain
    - Returns: true if level up occurred

15. _calculate_exp_for_level(target_level)
    - What it does: Calculates total EXP needed to reach a specific level
    - Uses: Level up checks, progression displays
    - Returns: int experience points required

16. _process_level_up()
    - What it does: Increments level, marks cache dirty, calculates stat gains, emits  signal
    - Uses: Called when experience threshold is met
    - Returns: true if successful

17. _calculate_stat_increases(old_level, new_level)
    - What it does: Determines which stats increased during level up based on growth rates
    - Uses: Level up animations, UI displays showing gained stats
    - Returns: Dictionary mapping StatType to int gains

18. get_bond_rank(partner_id)
    - What it does: Returns relationship rank with another character
    - Uses: Support conversation unlocking, combat bonuses
    - Returns: BondRank enum (NONE, C, B, A, S, A_PLUS)

19. get_bond_points(partner_id)
    - What it does: Returns numerical bond points accumulated with partner
    - Uses: Tracking progress toward next rank
    - Returns: int bond points (0-1000)

20. add_bond_points(partner_id, points)
    - What it does: Awards bond points, checks for rank up
    - Uses: Post-battle proximity bonuses, duo actions, healing
    - Returns: true if bond ranked up

21. _check_bond_rank_up(partner_id)
    - What it does: Checks if bond points meet threshold for next rank, emits signal
    - Uses: Called after bond points are added
    - Returns: true if rank increased

22. validate_character_data()
    - What it does: Checks for errors like empty names, null classes, invalid levels/experience
    - Uses: Resource creation, save file loading
    - Returns: Array of error message strings

23. repair_character_data()
    - What it does: Fixes invalid data by providing defaults and clamping values
    - Uses: Automatically called when loading corrupted saves
    - Returns: true if repairs were made

24. serialize()
    - What it does: Converts character to Dictionary for save files
    - Uses: Save system persists character progression
    - Returns: Dictionary with all character data

25. deserialize(data)
    - What it does: Loads character from save data Dictionary, validates and repairs
    - Uses: Load system restores character from saved games
    - Returns: true if successful

26. get_debug_summary()
    - What it does: Creates multi-line string with character stats, bonds, and validation
    - Uses: Development debugging, QA testing
    - Returns: String summary

27. debug_print()
    - What it does: Prints debug summary to console
    - Uses: Quick debugging during development
    - Returns: void

NOTES:
- Separate frontline_exp and backline_exp allow duo unit mechanics
- Bond system tracks relationships and unlocks support conversations
- Stats are cached for performance (cleared on level up or class switch)
- MAX_LEVEL constant set to 40
- Exclusive partner system for S/A+ ranks (one per character)
- Skill system temporarily disabled but structure remains
"""


class_name CharacterData
extends Resource

## Character data with type-safe stats, progression tracking, and validation

# --- Stat Type Enum (Moved to GameTypes) ---
# See scripts/Core/game_types.gd
# MAX_HP is now handled as GameTypes.StatType.HP
# enum StatType { HP, STR, MAG, SPD, SKILL, LUCK, DEF, RES }

# --- Bond System ---
enum BondRank { NONE = 0, C = 1, B = 2, A = 3, S = 4, A_PLUS = 5 }

const BOND_RANK_NAMES: Dictionary = {
	BondRank.NONE: "None",
	BondRank.C: "C",
	BondRank.B: "B",
	BondRank.A: "A",
	BondRank.S: "S",
	BondRank.A_PLUS: "A+"
}

# --- Validation Constants ---
const MAX_LEVEL: int = 40
const MIN_LEVEL: int = 1
const MAX_BOND_POINTS: int = 1000

# --- Basic Info ---
@export var character_name: String = "Hero"
@export var character_id: String = ""  # Unique ID for save/load
@export var portrait: Texture2D
@export var frontline_sprite: Texture2D
@export var backline_sprite: Texture2D

# --- Classes ---
@export_group("Classes")
@export var primary_class: CharacterClass
@export var secondary_class: CharacterClass
@export var hidden_class: CharacterClass  # Unlockable

# --- Class Selection ---
var using_primary: bool = true

# --- Levels (Separate for each class) ---
@export_group("Progression")
@export_range(1, 40) var primary_level: int = 1
@export_range(1, 40) var secondary_level: int = 1
@export_range(1, 40) var hidden_level: int = 1

# --- Experience (Separate for positions) ---
var frontline_exp: int = 0
var backline_exp: int = 0

# --- Current Stats (Calculated from class + level) ---
var current_hp: int = 20
var max_hp: int = 20
var strength: int = 5
var mag: int = 3
var spd: int = 5
var skill: int = 5
var luck: int = 5
var def: int = 4
var res: int = 2

# --- Bond Data (Type-safe) ---
@export_group("Bonds")
var bond_data: Array[BondData] = []  # List of bond progress objects
var exclusive_partner: String = ""  # S or A+ rank partner

# --- Skills ---
@export var unique_skill_names: Array[String] = []  # Keep for "Lone Wolf" feature
## DISABLED: Skill system temporarily disabled
# var learned_skills: Array[String] = []  # Skill IDs
# var equipped_skills: Array[String] = []  # Active skill slots

# --- Stat Cache ---
var _stat_cache: Dictionary = {}  # (stat_type, is_frontline) -> value
var _cache_dirty: bool = true

# --- Signals ---
@warning_ignore("unused_signal")
signal stats_changed(stat_types: Array)
signal level_up(new_level: int, stat_increases: Dictionary)
signal class_switched(new_class: CharacterClass)
signal bond_updated(partner_id: String, new_rank: BondRank)


func _init() -> void:
	if character_id.is_empty():
		character_id = character_name.to_snake_case()


## Get current active class
## @param in_frontline: Position to check
## @return: Active CharacterClass
func get_current_class(in_frontline: bool) -> CharacterClass:
	var current_class := primary_class if using_primary else secondary_class
	
	if not current_class:
		push_error("CharacterData: No class assigned to %s" % character_name)
		return null
	
	# Validate position compatibility
	if in_frontline and not current_class.can_be_frontline:
		push_warning("%s class cannot be frontline!" % current_class.display_name)
	if not in_frontline and not current_class.can_be_backline:
		push_warning("%s class cannot be backline!" % current_class.display_name)
	
	return current_class


## Get current level for active class
## @return: Level
func get_current_level() -> int:
	if using_primary:
		return primary_level
	else:
		return secondary_level


## Switch between primary and secondary class
func switch_class() -> void:
	using_primary = not using_primary
	_mark_cache_dirty()
	class_switched.emit(get_current_class(true))


## Get stat using enum (cached for performance)
## @param stat_type: GameTypes.StatType enum
## @param in_frontline: Position
## @return: Stat value
func get_stat_typed(stat_type: GameTypes.StatType, in_frontline: bool) -> int:
	if _cache_dirty:
		_refresh_cache()
	
	var key := _make_stat_cache_key(stat_type, in_frontline)
	return _stat_cache.get(key, 0)


## Get stat using string (backward compatibility)
## @param stat_name: Stat name
## @param in_frontline: Position
## @return: Stat value
func get_stat(stat_name: String, in_frontline: bool) -> int:
	var stat_type := _string_to_stat_type(stat_name)
	if stat_type == -1:
		push_warning("CharacterData: Unknown stat name '%s'" % stat_name)
		return 0
	return get_stat_typed(stat_type, in_frontline)


## Convert string to StatType enum
## @param stat_name: String name
## @return: GameTypes.StatType or -1 if invalid
func _string_to_stat_type(stat_name: String) -> GameTypes.StatType:
	return GameTypes.string_to_stat_type(stat_name)


## Make cache key
## @param stat_type: GameTypes.StatType
## @param is_frontline: Position
## @return: Cache key
func _make_stat_cache_key(stat_type: GameTypes.StatType, is_frontline: bool) -> String:
	return "%d-%s" % [stat_type, "F" if is_frontline else "B"]


## Mark cache as dirty (recalc needed)
func _mark_cache_dirty() -> void:
	_cache_dirty = true


## Refresh stat cache
func _refresh_cache() -> void:
	_stat_cache.clear()
	
	for is_frontline in [true, false]:
		var current_class := get_current_class(is_frontline)
		if not current_class:
			continue
		
		var level := get_current_level()
		
		# Use CharacterClass enum API if available
		if current_class.has_method("get_stat_at_level_typed"):
			for stat_type in GameTypes.StatType.values():
				var value := current_class.get_stat_at_level_typed(stat_type, level, is_frontline)
				var key := _make_stat_cache_key(stat_type, is_frontline)
				_stat_cache[key] = value
		else:
			# Fallback to string API
			_refresh_cache_string_api(is_frontline, current_class, level)
	
	_cache_dirty = false


## Refresh cache using string API (legacy)
## @param is_frontline: Position
## @param current_class: Character class
## @param level: Level
func _refresh_cache_string_api(is_frontline: bool, current_class: CharacterClass, level: int) -> void:
	var stat_names := ["hp", "str", "mag", "spd", "skill", "luck", "def", "res"]
	
	for stat_name in stat_names:
		var value := current_class.get_stat_at_level(stat_name, level, is_frontline)
		var stat_type := _string_to_stat_type(stat_name)
		if stat_type != -1:
			var key := _make_stat_cache_key(stat_type, is_frontline)
			_stat_cache[key] = value
	
	# Note: HP stat represents max HP (no separate MAX_HP enum value)


## Get all stats at once
## @param in_frontline: Position
## @return: Dictionary of StatType -> value
func get_all_stats(in_frontline: bool) -> Dictionary:
	if _cache_dirty:
		_refresh_cache()
	
	var stats := {}
	for stat_type in GameTypes.StatType.values():
		stats[stat_type] = get_stat_typed(stat_type, in_frontline)
	return stats


## Gain experience in a position
## @param in_frontline: Position
## @param amount: XP amount
## @return: true if leveled up
func gain_exp(in_frontline: bool, amount: int) -> bool:
	if amount <= 0:
		return false
	
	if in_frontline:
		frontline_exp += amount
	else:
		backline_exp += amount
	
	# Check for level up
	return _check_level_up()


## Check and process level up
## @return: true if leveled up
func _check_level_up() -> bool:
	var current_level := get_current_level()
	if current_level >= MAX_LEVEL:
		return false
	
	var exp_needed := _calculate_exp_for_level(current_level + 1)
	var current_exp := frontline_exp + backline_exp  # Combined for now
	
	if current_exp >= exp_needed:
		return _process_level_up()
	
	return false


## Calculate XP needed for level
## @param target_level: Target level
## @return: XP required
func _calculate_exp_for_level(target_level: int) -> int:
	return int(100 * pow(1.5, target_level - 1))


## Process level up
## @return: true if successful
func _process_level_up() -> bool:
	var old_level := get_current_level()
	
	# Increase level
	if using_primary:
		primary_level = min(primary_level + 1, MAX_LEVEL)
	else:
		secondary_level = min(secondary_level + 1, MAX_LEVEL)
	
	var new_level := get_current_level()
	
	# Mark cache dirty for recalculation
	_mark_cache_dirty()
	
	# Emit signal with stat increases
	var stat_increases := _calculate_stat_increases(old_level, new_level)
	level_up.emit(new_level, stat_increases)
	
	return true


## Calculate stat increases from level up
## @param old_level: Previous level
## @param new_level: New level
## @return: Dictionary of stat increases
func _calculate_stat_increases(old_level: int, new_level: int) -> Dictionary:
	var increases := {}
	var current_class := get_current_class(true)
	
	if not current_class:
		return increases
	
	# Calculate difference for each stat
	for stat_type in [GameTypes.StatType.HP, GameTypes.StatType.STR, GameTypes.StatType.MAG, GameTypes.StatType.SPD,
					  GameTypes.StatType.SKILL, GameTypes.StatType.LUCK, GameTypes.StatType.DEF, GameTypes.StatType.RES]:
		var old_value := current_class.get_stat_at_level_typed(stat_type, old_level, true) if current_class.has_method("get_stat_at_level_typed") else 0
		var new_value := current_class.get_stat_at_level_typed(stat_type, new_level, true) if current_class.has_method("get_stat_at_level_typed") else 0
		var increase := new_value - old_value
		
		if increase > 0:
			increases[stat_type] = increase
	
	return increases


## Get bond rank with partner
## @param partner_id: Partner ID
## @return: Bond rank
func get_bond_rank(partner_id: String) -> BondRank:
	var bond := _get_bond_data_object(partner_id)
	return bond.rank if bond else BondRank.NONE


## Get bond points with partner
## @param partner_id: Partner ID
## @return: Bond points
func get_bond_points(partner_id: String) -> int:
	var bond := _get_bond_data_object(partner_id)
	return bond.points if bond else 0


## Add bond points and check for rank up
## @param partner_id: Partner ID
## @param points: Points to add
## @return: true if ranked up
func add_bond_points(partner_id: String, points: int) -> bool:
	if points <= 0:
		return false
	
	var bond := _get_bond_data_object(partner_id)
	
	# Initialize bond data if needed
	if not bond:
		bond = BondData.new()
		bond.partner_id = partner_id
		bond.rank = BondRank.NONE
		bond.points = 0
		bond_data.append(bond)
	
	bond.points = min(bond.points + points, MAX_BOND_POINTS)
	
	# Check for rank up
	return _check_bond_rank_up(partner_id)


## Check and process bond rank up
## @param partner_id: Partner ID
## @return: true if ranked up
func _check_bond_rank_up(partner_id: String) -> bool:
	var bond := _get_bond_data_object(partner_id)
	if not bond:
		return false
	
	var current_rank: BondRank = bond.rank
	var points: int = bond.points
	
	# Rank thresholds
	var new_rank := current_rank
	
	if points >= 800 and current_rank < BondRank.S:
		new_rank = BondRank.A
	elif points >= 600 and current_rank < BondRank.A:
		new_rank = BondRank.A
	elif points >= 400 and current_rank < BondRank.B:
		new_rank = BondRank.B
	elif points >= 200 and current_rank < BondRank.C:
		new_rank = BondRank.C
	
	if new_rank > current_rank:
		bond.rank = new_rank
		bond_updated.emit(partner_id, new_rank)
		return true
	
	return false


## Helper to find bond data for a partner
## @param partner_id: Partner's ID
## @return: BondData object or null
func _get_bond_data_object(partner_id: String) -> BondData:
	for bond in bond_data:
		if bond.partner_id == partner_id:
			return bond
	return null


## Validate character data
## @return: Array of error messages
func validate_character_data() -> Array[String]:
	var errors: Array[String] = []
	
	# Validate name
	if character_name.is_empty():
		errors.append("Character name is empty")
	
	# Validate classes
	if not primary_class:
		errors.append("Primary class is null")
	
	if secondary_class and secondary_class == primary_class:
		errors.append("Secondary class cannot be same as primary")
	
	# Validate levels
	if primary_level < MIN_LEVEL or primary_level > MAX_LEVEL:
		errors.append("Primary level out of range: %d" % primary_level)
	if secondary_level < MIN_LEVEL or secondary_level > MAX_LEVEL:
		errors.append("Secondary level out of range: %d" % secondary_level)
	
	# Validate experience
	if frontline_exp < 0:
		errors.append("Frontline experience is negative")
	if backline_exp < 0:
		errors.append("Backline experience is negative")
	
	return errors


## Repair invalid character data
## @return: true if repaired
func repair_character_data() -> bool:
	var was_repaired := false
	
	# Fix name
	if character_name.is_empty():
		character_name = "Unnamed Hero"
		was_repaired = true
	
	# Fix ID
	if character_id.is_empty():
		character_id = character_name.to_snake_case()
		was_repaired = true
	
	# Clamp levels
	primary_level = clamp(primary_level, MIN_LEVEL, MAX_LEVEL)
	secondary_level = clamp(secondary_level, MIN_LEVEL, MAX_LEVEL)
	hidden_level = clamp(hidden_level, MIN_LEVEL, MAX_LEVEL)
	
	# Fix experience
	frontline_exp = max(0, frontline_exp)
	backline_exp = max(0, backline_exp)
	
	if was_repaired:
		_mark_cache_dirty()
	
	return was_repaired


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": character_name,
		"using_primary": using_primary,
		"primary_level": primary_level,
		"secondary_level": secondary_level,
		"hidden_level": hidden_level,
		"frontline_exp": frontline_exp,
		"backline_exp": backline_exp,
		"current_hp": current_hp,
		"bond_data": _serialize_bonds(),
		"exclusive_partner": exclusive_partner,
		## DISABLED: Skill system temporarily disabled
		# "learned_skills": learned_skills.duplicate(),
		# "equipped_skills": equipped_skills.duplicate()
	}


## Helper to serialize bonds
func _serialize_bonds() -> Array:
	var serialized_bonds := []
	for bond in bond_data:
		serialized_bonds.append({
			"partner_id": bond.partner_id,
			"rank": bond.rank,
			"points": bond.points,
			"conversations": bond.unlocked_conversations.duplicate()
		})
	return serialized_bonds


## Deserialize from save data
## @param data: Save data dictionary
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	character_id = data.get("character_id", character_id)
	character_name = data.get("character_name", character_name)
	using_primary = data.get("using_primary", true)
	primary_level = data.get("primary_level", 1)
	secondary_level = data.get("secondary_level", 1)
	hidden_level = data.get("hidden_level", 1)
	frontline_exp = data.get("frontline_exp", 0)
	backline_exp = data.get("backline_exp", 0)
	current_hp = data.get("current_hp", 20)
	
	# Deserialize bonds
	bond_data.clear()
	var raw_bonds = data.get("bond_data", [])
	
	# Handle legacy dictionary format
	if typeof(raw_bonds) == TYPE_DICTIONARY:
		for pid in raw_bonds:
			var d = raw_bonds[pid]
			var bond = BondData.new()
			bond.partner_id = pid
			bond.rank = d.get("rank", BondRank.NONE)
			bond.points = d.get("points", 0)
			bond.unlocked_conversations.assign(d.get("conversations", []))
			bond_data.append(bond)
	# Handle new array format
	elif typeof(raw_bonds) == TYPE_ARRAY:
		for d in raw_bonds:
			var bond = BondData.new()
			bond.partner_id = d.get("partner_id", "")
			bond.rank = d.get("rank", BondRank.NONE)
			bond.points = d.get("points", 0)
			bond.unlocked_conversations.assign(d.get("conversations", []))
			bond_data.append(bond)
			
	exclusive_partner = data.get("exclusive_partner", "")
	## DISABLED: Skill system temporarily disabled
	# learned_skills = data.get("learned_skills", [])
	# equipped_skills = data.get("equipped_skills", [])
	
	# Validate and repair if needed
	var errors := validate_character_data()
	if not errors.is_empty():
		push_warning("Deserialized character has errors: %s" % ", ".join(errors))
		repair_character_data()
	
	_mark_cache_dirty()
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== %s ===" % character_name
	summary += "\nID: %s\n" % character_id
	summary += "Active Class: %s (Level %d)\n" % [
		get_current_class(true).display_name if get_current_class(true) else "None",
		get_current_level()
	]
	
	summary += "\nStats (Frontline):\n"
	var front_stats := get_all_stats(true)
	for stat_type in GameTypes.StatType.values():
		var value: int = front_stats.get(stat_type, 0)
		summary += "  %s: %d\n" % [GameTypes.StatType.keys()[stat_type], value]
	
	summary += "\nExperience: Front=%d, Back=%d\n" % [frontline_exp, backline_exp]
	summary += "Bonds: %d partners\n" % bond_data.size()
	
	var errors := validate_character_data()
	if errors.is_empty():
		summary += "\n✓ Character valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
