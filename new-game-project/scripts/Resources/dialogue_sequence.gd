"""
FILE: dialogue_sequence.gd
PURPOSE: Container for dialogue line sequences with branching, state tracking, and flag management.

OVERVIEW:
This resource holds an ordered array of DialogueLine objects representing a conversation, cutscene, or
story segment. Supports linear sequences, branching choices, conditional logic, and cinematic timing.
Tracks playthrough state (current line, visited lines, completion), manages game flags for prerequisites
and consequences, and calculates estimated duration. Integrates with save/load system.

FUNCTIONS IN THIS FILE:

1. get_current_line()
   - What it does: Returns DialogueLine at current_line_index
   - Uses: Dialogue system displays current line
   - Returns: DialogueLine or null if index out of range

2. advance()
   - What it does: Moves current_line_index forward, tracks visited indices
   - Uses: Player advances dialogue, auto-advance triggers
   - Returns: true if advanced, false if at end

3. has_next_line()
   - What it does: Checks if current_line_index < last line index
   - Uses: UI determines if "Next" button should show
   - Returns: bool

4. reset()
   - What it does: Resets current_line_index to start, clears visited_line_indices
   - Uses: Replay conversations, reset to beginning
   - Returns: void

5. start()
   - What it does: Calls reset(), sets status IN_PROGRESS, increments times_played
   - Uses: Beginning a conversation for first or repeat time
   - Returns: void

6. complete()
   - What it does: Sets completion_state to COMPLETED
   - Uses: End of sequence, triggers flag setting and unlocks
   - Returns: void

7. is_completed()
   - What it does: Checks if completion_state == COMPLETED
   - Uses: Save data, unlock checks, replay availability
   - Returns: bool

8. get_progress()
   - What it does: Returns current line position as percentage (0.0-1.0)
   - Uses: Progress bars, UI displays
   - Returns: float

9. get_background()
   - What it does: Returns background texture or loads fallback
   - Uses: Dialogue UI sets scene background
   - Returns: Texture2D

10. check_requirements(flags)
    - What it does: Validates all required_flags are true in flags Dictionary
    - Uses: Unlock system checks if conversation available
    - Returns: bool (true if all requirements met)

11. apply_flags(flags)
    - What it does: Sets all flags in sets_flags array to true in flags Dictionary
    - Uses: After completion, sequence modifies game state
    - Returns: void

12. validate_sequence()
    - What it does: Checks for errors like empty ID, no lines, invalid indices, null lines
    - Uses: Resource creation, save loading, debugging
    - Returns: Array of error message strings

13. repair_sequence()
    - What it does: Fixes invalid data by generating IDs, removing nulls, clamping values
    - Uses: Automatic repair after loading corrupted data
    - Returns: true if repairs made

14. get_line_count()
    - What it does: Returns lines.size()
    - Uses: UI displays, iteration, validation
    - Returns: int

15. get_line_at(index)
    - What it does: Returns DialogueLine at specific index with bounds checking
    - Uses: Random access to lines, choice menus
    - Returns: DialogueLine or null

16. add_line(line)
    - What it does: Appends DialogueLine to lines array
    - Uses: Building sequences programmatically
    - Returns: void

17. remove_line_at(index)
    - What it does: Removes DialogueLine at index
    - Uses: Editing sequences, dynamic content
    - Returns: bool (true if removed)

18. get_estimated_duration(words_per_minute)
    - What it does: Calculates total time including fade durations, reading time, auto-advance delays
    - Uses: Cutscene timing, pacing analysis
    - Returns: float seconds

19. clone()
    - What it does: Creates deep copy of sequence with "_clone" suffix on ID
    - Uses: Branching dialogue templates, variations
    - Returns: New DialogueSequence instance

20. serialize()
    - What it does: Converts runtime state (current line, visited, completion, times played) to Dictionary
    - Uses: Save system persists conversation progress
    - Returns: Dictionary

21. deserialize(data)
    - What it does: Loads runtime state from save data
    - Uses: Restore conversation progress on load
    - Returns: true if successful

22. get_debug_summary()
    - What it does: Creates formatted summary with all metadata and validation status
    - Uses: Development debugging, QA testing
    - Returns: String summary

23. debug_print()
    - What it does: Prints debug summary to console
    - Uses: Quick debugging
    - Returns: void

24. create_simple(id, dialogue_lines, bg) [static]
    - What it does: Factory method creates LINEAR sequence quickly
    - Uses: Simple conversations without branching
    - Returns: New DialogueSequence

25. create_cinematic(id, dialogue_lines, bg, music) [static]
    - What it does: Factory method creates CINEMATIC sequence with music and longer fades
    - Uses: Story cutscenes, important events
    - Returns: New DialogueSequence with cinematic settings

NOTES:
- SequenceType enum: LINEAR, BRANCHING, CONDITIONAL, CINEMATIC
- CompletionState enum: NOT_STARTED, IN_PROGRESS, COMPLETED, FAILED
- MAX_SEQUENCE_LENGTH = 100 lines enforced
- current_line_index tracks position, visited_line_indices tracks history
- required_flags must all be true to start sequence
- sets_flags applied to game state on completion
- Supports background texture and background_music AudioStream
- fade_in_duration and fade_out_duration for scene transitions
- tags array allows categorization and search
- times_played increments on each start() call
- Validates each DialogueLine during validate_sequence()
- Factory methods provide convenient creation patterns
"""


class_name DialogueSequence
extends Resource

## Sequence of dialogue lines with branching, conditions, and state management

# --- Sequence Type Enum ---
enum SequenceType {
	LINEAR = 0,        # Simple sequence of lines
	BRANCHING = 1,     # Contains choice points
	CONDITIONAL = 2,   # Has logic gates
	CINEMATIC = 3      # Includes events/timing
}

# --- Completion State ---
enum CompletionState {
	NOT_STARTED = 0,
	IN_PROGRESS = 1,
	COMPLETED = 2,
	FAILED = 3
}

# --- Validation Constants ---
const MAX_SEQUENCE_LENGTH: int = 100
const MIN_SEQUENCE_LENGTH: int = 1

# --- Identification ---
@export_group("Identification")
@export var sequence_id: String = ""
@export var sequence_type: SequenceType = SequenceType.LINEAR
@export var display_name: String = ""
@export_multiline var description: String = ""

# --- Content ---
@export_group("Content")
@export var lines: Array[DialogueLine] = []
@export var start_line_index: int = 0

# --- Visuals ---
@export_group("Visuals")
@export var background: Texture2D
@export var background_music: AudioStream
@export var fade_in_duration: float = 0.5
@export var fade_out_duration: float = 0.5

# --- Metadata ---
@export_group("Metadata")
@export var tags: Array[String] = []
@export var required_flags: Array[String] = []  # Flags needed to play
@export var sets_flags: Array[String] = []      # Flags set on completion

# --- State Tracking (Runtime) ---
var current_line_index: int = 0
var visited_line_indices: Array[int] = []
var completion_state: CompletionState = CompletionState.NOT_STARTED
var times_played: int = 0

# --- Fallback Resources ---
const FALLBACK_BACKGROUND_PATH: String = "res://ui/backgrounds/default.png"
var _fallback_background: Texture2D = null


## Get current dialogue line
## @return: Current DialogueLine or null
func get_current_line() -> DialogueLine:
	if current_line_index < 0 or current_line_index >= lines.size():
		return null
	return lines[current_line_index]


## Advance to next line
## @return: true if advanced, false if at end
func advance() -> bool:
	if current_line_index < lines.size() - 1:
		current_line_index += 1
		if current_line_index not in visited_line_indices:
			visited_line_indices.append(current_line_index)
		return true
	return false


## Check if sequence has more lines
## @return: true if more lines available
func has_next_line() -> bool:
	return current_line_index < lines.size() - 1


## Reset sequence to beginning
func reset() -> void:
	current_line_index = start_line_index
	visited_line_indices.clear()
	completion_state = CompletionState.NOT_STARTED


## Start sequence
func start() -> void:
	reset()
	completion_state = CompletionState.IN_PROGRESS
	times_played += 1


## Complete sequence
func complete() -> void:
	completion_state = CompletionState.COMPLETED


## Check if sequence is completed
## @return: true if completed
func is_completed() -> bool:
	return completion_state == CompletionState.COMPLETED


## Get progress percentage
## @return: Progress from 0.0 to 1.0
func get_progress() -> float:
	if lines.is_empty():
		return 0.0
	return float(current_line_index + 1) / float(lines.size())


## Get background texture with fallback
## @return: Background texture
func get_background() -> Texture2D:
	if background:
		return background
	
	# Load fallback if needed
	if not _fallback_background:
		if ResourceLoader.exists(FALLBACK_BACKGROUND_PATH):
			_fallback_background = load(FALLBACK_BACKGROUND_PATH)
	
	return _fallback_background


## Check if all required flags are set
## @param flags: Dictionary of current flags
## @return: true if all required flags are set
func check_requirements(flags: Dictionary) -> bool:
	for required_flag in required_flags:
		if not flags.get(required_flag, false):
			return false
	return true


## Apply flags set by this sequence
## @param flags: Dictionary to modify
func apply_flags(flags: Dictionary) -> void:
	for flag in sets_flags:
		flags[flag] = true


## Validate sequence
## @return: Array of error messages (empty if valid)
func validate_sequence() -> Array[String]:
	var errors: Array[String] = []
	
	# Validate ID
	if sequence_id.is_empty():
		errors.append("Sequence has no ID")
	
	# Validate lines
	if lines.is_empty():
		errors.append("Sequence has no dialogue lines")
	elif lines.size() > MAX_SEQUENCE_LENGTH:
		errors.append("Sequence too long (%d lines, max %d)" % [lines.size(), MAX_SEQUENCE_LENGTH])
	
	# Validate each line
	for i in range(lines.size()):
		var line := lines[i]
		if not line:
			errors.append("Line at index %d is null" % i)
		# No need to check 'is DialogueLine' with typed array
		else:
			var line_errors := line.validate_dialogue()
			for line_error in line_errors:
				errors.append("Line %d: %s" % [i, line_error])
	
	# Validate start index
	if start_line_index < 0 or start_line_index >= lines.size():
		errors.append("Invalid start_line_index: %d (valid range: 0-%d)" % [
			start_line_index, lines.size() - 1
		])
	
	# Validate background
	if background:
		var size := background.get_size()
		if size.x == 0 or size.y == 0:
			errors.append("Background texture has zero size")
	
	# Validate audio
	if background_music and not background_music is AudioStream:
		errors.append("Background music is not a valid AudioStream")
	
	# Validate durations
	if fade_in_duration < 0:
		errors.append("Fade in duration cannot be negative")
	if fade_out_duration < 0:
		errors.append("Fade out duration cannot be negative")
	
	return errors


## Repair invalid sequence data
## @return: true if repaired
func repair_sequence() -> bool:
	var was_repaired := false
	
	# Generate ID if missing
	if sequence_id.is_empty():
		sequence_id = "seq_%d" % get_instance_id()
		was_repaired = true
	
	# Remove null lines
	var valid_lines: Array[DialogueLine] = []
	for line in lines:
		if line:
			valid_lines.append(line)
		else:
			was_repaired = true
	lines = valid_lines
	
	# Fix start index
	if start_line_index < 0 or start_line_index >= lines.size():
		start_line_index = 0
		was_repaired = true
	
	# Fix durations
	if fade_in_duration < 0:
		fade_in_duration = 0.5
		was_repaired = true
	if fade_out_duration < 0:
		fade_out_duration = 0.5
		was_repaired = true
	
	return was_repaired


## Get line count
## @return: Number of lines
func get_line_count() -> int:
	return lines.size()


## Get line at index
## @param index: Line index
## @return: DialogueLine or null
func get_line_at(index: int) -> DialogueLine:
	if index < 0 or index >= lines.size():
		return null
	return lines[index]


## Add line to sequence
## @param line: DialogueLine to add
func add_line(line: DialogueLine) -> void:
	if line and line is DialogueLine:
		lines.append(line)


## Remove line at index
## @param index: Line index to remove
## @return: true if removed
func remove_line_at(index: int) -> bool:
	if index < 0 or index >= lines.size():
		return false
	lines.remove_at(index)
	return true


## Get estimated playthrough time
## @param words_per_minute: Reading speed
## @return: Estimated time in seconds
func get_estimated_duration(words_per_minute: int = 200) -> float:
	var total_time := 0.0
	
	# Add fade times
	total_time += fade_in_duration + fade_out_duration
	
	# Add reading time for each line
	for line in lines:
		if line and line.has_method("calculate_reading_time"):
			total_time += line.calculate_reading_time(words_per_minute)
		
		# Add auto-advance delay if present
		if line and "auto_advance_delay" in line:
			total_time += line.auto_advance_delay
		else:
			total_time += 2.0  # Default advance time
	
	return total_time


## Clone sequence
## @return: New DialogueSequence instance
func clone() -> DialogueSequence:
	var new_seq := DialogueSequence.new()
	new_seq.sequence_id = sequence_id + "_clone"
	new_seq.sequence_type = sequence_type
	new_seq.display_name = display_name
	new_seq.description = description
	new_seq.start_line_index = start_line_index
	new_seq.background = background
	new_seq.background_music = background_music
	new_seq.fade_in_duration = fade_in_duration
	new_seq.fade_out_duration = fade_out_duration
	new_seq.tags = tags.duplicate()
	new_seq.required_flags = required_flags.duplicate()
	new_seq.sets_flags = sets_flags.duplicate()
	
	# Clone lines
	for line in lines:
		if line and line.has_method("clone"):
			new_seq.lines.append(line.clone())
		else:
			new_seq.lines.append(line)
	
	return new_seq


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"current_line_index": current_line_index,
		"visited_line_indices": visited_line_indices.duplicate(),
		"completion_state": completion_state,
		"times_played": times_played
	}


## Deserialize from save data
## @param data: Save data dictionary
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	sequence_id = data.get("sequence_id", sequence_id)
	current_line_index = data.get("current_line_index", 0)
	visited_line_indices = data.get("visited_line_indices", [])
	completion_state = data.get("completion_state", CompletionState.NOT_STARTED)
	times_played = data.get("times_played", 0)
	
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Dialogue Sequence ===%s\n" % (" [%s]" % sequence_id if not sequence_id.is_empty() else "")
	
	if not display_name.is_empty():
		summary += "Name: %s\n" % display_name
	
	summary += "Type: %s\n" % SequenceType.keys()[sequence_type]
	summary += "Lines: %d\n" % lines.size()
	summary += "Progress: %d/%d (%.0f%%)\n" % [
		current_line_index + 1,
		lines.size(),
		get_progress() * 100
	]
	summary += "State: %s\n" % CompletionState.keys()[completion_state]
	summary += "Times played: %d\n" % times_played
	
	if background:
		summary += "Background: Yes\n"
	if background_music:
		summary += "Music: Yes\n"
	
	if not required_flags.is_empty():
		summary += "Required flags: %s\n" % ", ".join(required_flags)
	if not sets_flags.is_empty():
		summary += "Sets flags: %s\n" % ", ".join(sets_flags)
	if not tags.is_empty():
		summary += "Tags: %s\n" % ", ".join(tags)
	
	summary += "Estimated duration: %.1f seconds\n" % get_estimated_duration()
	
	# Validation
	var errors := validate_sequence()
	if errors.is_empty():
		summary += "\n✓ Sequence valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())


## Create a simple sequence (factory method)
## @param id: Sequence ID
## @param dialogue_lines: Array of DialogueLines
## @param bg: Optional background
## @return: New DialogueSequence
static func create_simple(id: String, dialogue_lines: Array, bg: Texture2D = null) -> DialogueSequence:
	var seq := DialogueSequence.new()
	seq.sequence_id = id
	seq.sequence_type = SequenceType.LINEAR
	seq.background = bg
	
	for line in dialogue_lines:
		if line and line is DialogueLine:
			seq.lines.append(line)
	
	return seq


## Create a cinematic sequence (factory method)
## @param id: Sequence ID
## @param dialogue_lines: Array of DialogueLines
## @param bg: Background texture
## @param music: Background music
## @return: New DialogueSequence configured as cinematic
static func create_cinematic(id: String, dialogue_lines: Array, bg: Texture2D = null, music: AudioStream = null) -> DialogueSequence:
	var seq := create_simple(id, dialogue_lines, bg)
	seq.sequence_type = SequenceType.CINEMATIC
	seq.background_music = music
	seq.fade_in_duration = 1.0
	seq.fade_out_duration = 1.0
	return seq
