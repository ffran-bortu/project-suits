"""
FILE: support_conversation.gd
PURPOSE: Support conversation resource for character relationship dialogues with rank progression.

OVERVIEW:
This resource represents a single support conversation between two characters at a specific relationship
rank (C/B/A/S/A+). Stores dialogue lines, unlock requirements (chapter, flags, prerequisite ranks), rewards,
and viewing status. Integrates with bond system for relationship progression. Supports text caching, validation,
serialization, and factory methods for quick creation. Used by dialogue system and support viewer.

FUNCTIONS IN THIS FILE:

1. get_character_a_name()
   - What it does: Returns character A display name from character_a_name or capitalized ID
   - Uses: UI displays, dialogue headers
   - Returns: String (never empty, falls back to "Unknown")

2. get_character_b_name()
   - What it does: Returns character B display name from character_b_name or capitalized ID
   - Uses: UI displays, dialogue headers  
   - Returns: String (never empty, falls back to "Unknown")

3. get_rank_string()
   - What it does: Converts rank enum to letter(s) like "C", "B", "A", "S", "A+"
   - Uses: UI displays, conversation IDs
   - Returns: String rank letter

4. get_rank_display_name()
   - What it does: Returns human-readable rank name ("Acquaintance", "Friend", etc.)
   - Uses: UI tooltips, status displays
   - Returns: String display name

5. get_text()
   - What it does: Returns formatted conversation text with header (uses cache)
   - Uses: Displaying full conversation
   - Returns: String formatted text

6. _refresh_text_cache()
   - What it does: Rebuilds formatted text from conversation_lines array
   - Uses: Called when cache_dirty is true
   - Returns: void

7. _mark_cache_dirty()
   - What it does: Sets cache_dirty flag to force refresh on next get_text()
   - Uses: After modifying conversation_lines
   - Returns: void

8. check_unlock_conditions(game_flags)
   - What it does: Validates all required_flags are true in Dictionary
   - Uses: Unlock system checks if conversation available
   - Returns: bool (true if all flags present and true)

9. mark_as_viewed()
   - What it does: Increments times_viewed, sets status to VIEWED, records timestamps
   - Uses: After player reads conversation
   - Returns: void

10. is_viewed()
    - What it does: Returns true if times_viewed > 0
    - Uses: UI marks as read, prevents duplicate rewards
    - Returns: bool

11. is_locked()
    - What it does: Returns true if status == LOCKED
    - Uses: UI grays out unavailable conversations
    - Returns: bool

12. is_available()
    - What it does: Returns true if status == AVAILABLE
    - Uses: UI shows accessible conversations
    - Returns: bool

13. unlock()
    - What it does: Changes status from LOCKED to AVAILABLE
    - Uses: Meeting unlock requirements
    - Returns: void

14. lock()
    - What it does: Changes status to LOCKED
    - Uses: Administrative relock (rare)
    - Returns: void

15. get_line_count()
    - What it does: Returns conversation_lines.size()
    - Uses: UI displays, validation
    - Returns: int

16. validate_conversation()
    - What it does: Checks for errors like empty IDs, same characters, invalid ranks, empty lines
    - Uses: Resource creation, save loading
    - Returns: Array of error strings

17. repair_conversation()
    - What it does: Fixes invaliddata by generating IDs, removing empty lines
    - Uses: Automatic repair on load
    - Returns: true if repairs made

18. clone()
    - What it does: Creates deep copy with "_clone" suffix on conversation_id
    - Uses: Templates, variations
    - Returns: New SupportConversation

19. serialize()
    - What it does: Converts runtime state (status, times_viewed, timestamps) to Dictionary
    - Uses: Save system
    - Returns: Dictionary

20. deserialize(data)
    - What it does: Restores runtime state from save data
    - Uses: Load system
    - Returns: true if successful

21. get_debug_summary()
    - What it does: Creates formatted summary with all metadata
    - Uses: Debugging
    - Returns: String

22. debug_print()
    - What it does: Prints summary to console
    - Uses: Quick debugging
    - Returns: void

23. create_simple(char_a, char_b, conversation_rank, lines) [static]
    - What it does: Factory method creates conversation at specified rank
    - Uses: Quick conversation creation
    - Returns: New SupportConversation

24. create_c_rank(char_a, char_b, lines) [static]
    - What it does: Creates C-rank conversation (no prerequisites)
    - Uses: First conversation tier
    - Returns: New SupportConversation at C rank

25. create_b_rank(char_a, char_b, lines) [static]
    - What it does: Creates B-rank (requires C rank)
    - Uses: Second conversation tier
    - Returns: New SupportConversation with required_rank = C

26. create_a_rank(char_a, char_b, lines) [static]
    - What it does: Creates A-rank (requires B rank) 
    - Uses: Third conversation tier
    - Returns: New SupportConversation with required_rank = B

27. string_to_rank(rank_string) [static]
    - What it does: Converts string "C"/"B"/"A"/"S"/"A+" to enum
    - Uses: Parsing, deserialization
    - Returns: RelationshipRank enum

NOTES:
- RelationshipRank enum: C (0), B (1), A (2), S (3), A_PLUS (4)
- ConversationStatus enum: LOCKED, AVAILABLE, VIEWED, COMPLETED
- MAX_LINES = 50 enforced
- conversation_lines is Array[String] (legacy simple format)
- relationship_points_reward awarded after viewing (typically 100)
- required_chapter, required_rank, required_flags control unlocking
- Uses cached formatted text for performance
- first_viewed_timestamp and last_viewed_timestamp track Unix time
- times_viewed increments on each mark_as_viewed() call
- Supports background Texture2D and background_music AudioStream
- Factory methods auto-set required_rank for progression (C→B→A)
"""


class_name SupportConversation
extends Resource

## Support conversation with character IDs, rank enum, structured lines, and unlock conditions

# --- Relationship Rank Enum ---
enum RelationshipRank {
	C = 0,      # Acquaintance
	B = 1,      # Friend
	A = 2,      # Close Friend
	S = 3,      # Best Friend/Soulmate
	A_PLUS = 4  # Exclusive Partner
}

const RANK_NAMES: Dictionary = {
	RelationshipRank.C: "C",
	RelationshipRank.B: "B",
	RelationshipRank.A: "A",
	RelationshipRank.S: "S",
	RelationshipRank.A_PLUS: "A+"
}

const RANK_DISPLAY_NAMES: Dictionary = {
	RelationshipRank.C: "Acquaintance",
	RelationshipRank.B: "Friend",
	RelationshipRank.A: "Close Friend",
	RelationshipRank.S: "Soulmate",
	RelationshipRank.A_PLUS: "Exclusive Partner"
}

# --- Conversation Status ---
enum ConversationStatus {
	LOCKED = 0,
	AVAILABLE = 1,
	VIEWED = 2,
	COMPLETED = 3
}

# --- Validation Constants ---
const MAX_LINES: int = 50
const MIN_LINES: int = 1

# --- Character Info ---
@export_group("Characters")
@export var character_a_id: String = ""  # Unique character ID
@export var character_b_id: String = ""  # Unique character ID
@export var character_a_name: String = ""  # Legacy/display name
@export var character_b_name: String = ""  # Legacy/display name

# --- Relationship Info ---
@export_group("Relationship")
@export var rank: RelationshipRank = RelationshipRank.C
@export var relationship_points_reward: int = 100  # Points gained after viewing

# --- Conversation Content ---
@export_group("Content")
@export var conversation_id: String = ""
@export var display_name: String = ""  # For UI
@export_multiline var description: String = ""  # Developer notes
@export var conversation_lines: Array[String] = []  # Legacy simple lines

# --- Unlock Requirements ---
@export_group("Requirements")
@export var required_chapter: int = 1
@export var required_rank: RelationshipRank = RelationshipRank.C
@export var required_flags: Array[String] = []

# --- Visual/Audio ---
@export_group("Presentation")
@export var background: Texture2D
@export var background_music: AudioStream

# --- Runtime State ---
var status: ConversationStatus = ConversationStatus.LOCKED
var times_viewed: int = 0
var first_viewed_timestamp: int = 0
var last_viewed_timestamp: int = 0

# --- Cache ---
var _formatted_text_cache: String = ""
var _cache_dirty: bool = true


## Get character A display name
## @return: Character name
func get_character_a_name() -> String:
	if not character_a_name.is_empty():
		return character_a_name
	if not character_a_id.is_empty():
		return character_a_id.capitalize()
	return "Unknown"


## Get character B display name
## @return: Character name
func get_character_b_name() -> String:
	if not character_b_name.is_empty():
		return character_b_name
	if not character_b_id.is_empty():
		return character_b_id.capitalize()
	return "Unknown"


## Get rank as string
## @return: Rank letter(s)
func get_rank_string() -> String:
	return RANK_NAMES.get(rank, "?")


## Get rank display name
## @return: Human-readable rank name
func get_rank_display_name() -> String:
	return RANK_DISPLAY_NAMES.get(rank, "Unknown")


## Get formatted conversation text (cached)
## @return: Formatted text
func get_text() -> String:
	if _cache_dirty:
		_refresh_text_cache()
	return _formatted_text_cache


## Refresh text cache
func _refresh_text_cache() -> void:
	var parts: Array[String] = []
	
	parts.append("=== %s + %s Support %s ===" % [
		get_character_a_name(),
		get_character_b_name(),
		get_rank_string()
	])
	parts.append("")
	
	for line in conversation_lines:
		parts.append(line)
	
	_formatted_text_cache = "\n".join(parts)
	_cache_dirty = false


## Mark cache as dirty
func _mark_cache_dirty() -> void:
	_cache_dirty = true


## Check if conversation can be unlocked
## @param game_flags: Current game flags
## @return: true if can unlock
func check_unlock_conditions(game_flags: Dictionary) -> bool:
	# Check required flags
	for flag in required_flags:
		if not game_flags.get(flag, false):
			return false
	
	# All conditions met
	return true


## Mark conversation as viewed
func mark_as_viewed() -> void:
	if times_viewed == 0:
		first_viewed_timestamp = Time.get_unix_time_from_system()
		status = ConversationStatus.VIEWED
	
	times_viewed += 1
	last_viewed_timestamp = Time.get_unix_time_from_system()


## Check if conversation has been viewed
## @return: true if viewed at least once
func is_viewed() -> bool:
	return times_viewed > 0


## Check if conversation is locked
## @return: true if locked
func is_locked() -> bool:
	return status == ConversationStatus.LOCKED


## Check if conversation is available
## @return: true if available to view
func is_available() -> bool:
	return status == ConversationStatus.AVAILABLE


## Unlock conversation
func unlock() -> void:
	if status == ConversationStatus.LOCKED:
		status = ConversationStatus.AVAILABLE


## Lock conversation
func lock() -> void:
	status = ConversationStatus.LOCKED


## Get line count
## @return: Number of lines
func get_line_count() -> int:
	return conversation_lines.size()


## Validate conversation
## @return: Array of error messages (empty if valid)
func validate_conversation() -> Array[String]:
	var errors: Array[String] = []
	
	# Validate IDs
	if character_a_id.is_empty() and character_a_name.is_empty():
		errors.append("Character A has no ID or name")
	
	if character_b_id.is_empty() and character_b_name.is_empty():
		errors.append("Character B has no ID or name")
	
	if (not character_a_id.is_empty() and not character_b_id.is_empty() and 
		character_a_id == character_b_id):
		errors.append("Character A and B cannot be the same")
	
	# Validate rank
	if rank < 0 or rank >= RelationshipRank.size():
		errors.append("Invalid relationship rank: %d" % rank)
	
	# Validate lines
	if conversation_lines.is_empty():
		errors.append("Conversation has no lines")
	elif conversation_lines.size() > MAX_LINES:
		errors.append("Too many lines (%d, max %d)" % [conversation_lines.size(), MAX_LINES])
	
	# Validate each line
	for i in range(conversation_lines.size()):
		var line := conversation_lines[i]
		if line.is_empty():
			errors.append("Line %d is empty" % i)
	
	# Validate requirements
	if required_chapter < 1:
		errors.append("Required chapter must be at least 1")
	
	if required_rank < 0 or required_rank >= RelationshipRank.size():
		errors.append("Invalid required rank: %d" % required_rank)
	
	# Validate rewards
	if relationship_points_reward < 0:
		errors.append("Relationship points reward cannot be negative")
	
	return errors


## Repair invalid conversation data
## @return: true if repaired
func repair_conversation() -> bool:
	var was_repaired := false
	
	# Generate conversation ID if missing
	if conversation_id.is_empty():
		conversation_id = "%s_%s_%s" % [
			character_a_id if not character_a_id.is_empty() else character_a_name.to_snake_case(),
			character_b_id if not character_b_id.is_empty() else character_b_name.to_snake_case(),
			get_rank_string()
		]
		was_repaired = true
	
	# Ensure character IDs if names exist
	if character_a_id.is_empty() and not character_a_name.is_empty():
		character_a_id = character_a_name.to_snake_case()
		was_repaired = true
	
	if character_b_id.is_empty() and not character_b_name.is_empty():
		character_b_id = character_b_name.to_snake_case()
		was_repaired = true
	
	# Remove empty lines
	var valid_lines: Array[String] = []
	for line in conversation_lines:
		if not line.is_empty():
			valid_lines.append(line)
		else:
			was_repaired = true
	conversation_lines = valid_lines
	
	# Fix required chapter
	if required_chapter < 1:
		required_chapter = 1
		was_repaired = true
	
	# Fix relationship points
	if relationship_points_reward < 0:
		relationship_points_reward = 100
		was_repaired = true
	
	if was_repaired:
		_mark_cache_dirty()
	
	return was_repaired


## Clone conversation
## @return: New SupportConversation instance
func clone() -> SupportConversation:
	var new_conv := SupportConversation.new()
	new_conv.character_a_id = character_a_id
	new_conv.character_b_id = character_b_id
	new_conv.character_a_name = character_a_name
	new_conv.character_b_name = character_b_name
	new_conv.rank = rank
	new_conv.relationship_points_reward = relationship_points_reward
	new_conv.conversation_id = conversation_id + "_clone"
	new_conv.display_name = display_name
	new_conv.description = description
	new_conv.conversation_lines = conversation_lines.duplicate()
	new_conv.required_chapter = required_chapter
	new_conv.required_rank = required_rank
	new_conv.required_flags = required_flags.duplicate()
	new_conv.background = background
	new_conv.background_music = background_music
	return new_conv


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	return {
		"conversation_id": conversation_id,
		"status": status,
		"times_viewed": times_viewed,
		"first_viewed_timestamp": first_viewed_timestamp,
		"last_viewed_timestamp": last_viewed_timestamp
	}


## Deserialize from save data
## @param data: Save data dictionary
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	conversation_id = data.get("conversation_id", conversation_id)
	status = data.get("status", ConversationStatus.LOCKED)
	times_viewed = data.get("times_viewed", 0)
	first_viewed_timestamp = data.get("first_viewed_timestamp", 0)
	last_viewed_timestamp = data.get("last_viewed_timestamp", 0)
	
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Support Conversation ===%s\n" % (
		" [%s]" % conversation_id if not conversation_id.is_empty() else ""
	)
	
	summary += "Characters: %s + %s\n" % [
		get_character_a_name(),
		get_character_b_name()
	]
	summary += "Rank: %s (%s)\n" % [get_rank_string(), get_rank_display_name()]
	summary += "Lines: %d\n" % conversation_lines.size()
	summary += "Status: %s\n" % ConversationStatus.keys()[status]
	
	if times_viewed > 0:
		summary += "Viewed: %d times\n" % times_viewed
	
	if relationship_points_reward > 0:
		summary += "Reward: %d relationship points\n" % relationship_points_reward
	
	if required_chapter > 1:
		summary += "Requires: Chapter %d\n" % required_chapter
	
	if required_rank > RelationshipRank.C:
		summary += "Requires: %s rank\n" % RANK_NAMES[required_rank]
	
	if not required_flags.is_empty():
		summary += "Requires flags: %s\n" % ", ".join(required_flags)
	
	if background:
		summary += "Background: Yes\n"
	if background_music:
		summary += "Music: Yes\n"
	
	# Validation
	var errors := validate_conversation()
	if errors.is_empty():
		summary += "\n✓ Conversation valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())


## Create a simple conversation (factory method)
## @param char_a: Character A ID
## @param char_b: Character B ID
## @param conversation_rank: Relationship rank
## @param lines: Array of dialogue lines
## @return: New SupportConversation
static func create_simple(char_a: String, char_b: String, conversation_rank: RelationshipRank, lines: Array) -> SupportConversation:
	var conv := SupportConversation.new()
	conv.character_a_id = char_a
	conv.character_b_id = char_b
	conv.rank = conversation_rank
	conv.conversation_id = "%s_%s_%s" % [char_a, char_b, RANK_NAMES[conversation_rank]]
	
	for line in lines:
		if line is String:
			conv.conversation_lines.append(line)
	
	return conv


## Create a C-rank conversation (factory method)
## @param char_a: Character A ID
## @param char_b: Character B ID
## @param lines: Array of dialogue lines
## @return: New SupportConversation at C rank
static func create_c_rank(char_a: String, char_b: String, lines: Array) -> SupportConversation:
	return create_simple(char_a, char_b, RelationshipRank.C, lines)


## Create a B-rank conversation (factory method)
## @param char_a: Character A ID
## @param char_b: Character B ID
## @param lines: Array of dialogue lines
## @return: New SupportConversation at B rank
static func create_b_rank(char_a: String, char_b: String, lines: Array) -> SupportConversation:
	var conv := create_simple(char_a, char_b, RelationshipRank.B, lines)
	conv.required_rank = RelationshipRank.C  # Requires C to unlock B
	return conv


## Create an A-rank conversation (factory method)
## @param char_a: Character A ID
## @param char_b: Character B ID
## @param lines: Array of dialogue lines
## @return: New SupportConversation at A rank
static func create_a_rank(char_a: String, char_b: String, lines: Array) -> SupportConversation:
	var conv := create_simple(char_a, char_b, RelationshipRank.A, lines)
	conv.required_rank = RelationshipRank.B  # Requires B to unlock A
	return conv


## Get rank from string (helper)
## @param rank_string: Rank string ("C", "B", "A", "S", "A+")
## @return: RelationshipRank enum value
static func string_to_rank(rank_string: String) -> RelationshipRank:
	match rank_string.to_upper():
		"C": return RelationshipRank.C
		"B": return RelationshipRank.B
		"A": return RelationshipRank.A
		"S": return RelationshipRank.S
		"A+", "APLUS": return RelationshipRank.A_PLUS
		_: return RelationshipRank.C
