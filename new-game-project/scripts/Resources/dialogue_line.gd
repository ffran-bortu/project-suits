"""
FILE: dialogue_line.gd
PURPOSE: Represents a single line of dialogue with speaker info, text, localization, and presentation data.

OVERVIEW:
This resource stores one dialogue line with comprehensive support for localization, audio, portraits,
and visual presentation. It includes validation, multiple speaker types (player/NPC/narrator/system),
auto-advance timings, and factory methods for common use cases. Designed to work with dialogue sequences
and support conversation systems.

FUNCTIONS IN THIS FILE:

1. get_display_speaker_name()
   - What it does: Returns localized speaker name with fallbacks
   - Uses: Dialogue UI displays speaker name above portrait
   - Returns: String speaker name (empty for narrator, translated if available)

2. get_display_text()
   - What it does: Returns localized dialogue text with fallbacks
   - Uses: Dialogue UI displays the actual spoken/written text
   - Returns: String dialogue text (translated if translation_key exists)

3. get_portrait()
   - What it does: Returns portrait texture or loads fallback if none assigned
   - Uses: Dialogue UI displays character portrait
   - Returns: Texture2D (loads from FALLBACK_PORTRAIT_PATH if needed)

4. validate_dialogue()
   - What it does: Checks for errors like empty text, missing speaker, invalid audio
   - Uses: Resource creation, debugging, save file loading
   - Returns: Array of error message strings (empty if valid)

5. repair_dialogue()
   - What it does: Fixes invalid data by generating IDs, sanitizing text, fixing delays
   - Uses: Automatically called after loading from saves
   - Returns: true if repairs were made

6. get_safe_dialogue_text()
   - What it does: Returns sanitized, validated, truncated text ready for display
   - Uses: Dialogue rendering that needs guaranteed safe text
   - Returns: String (sanitized, truncated to MAX_DIALOGUE_LENGTH, tabs replaced)

7. get_word_count()
   - What it does: Counts words in dialogue text
   - Uses: Timing calculations, readability analysis
   - Returns: int number of words

8. calculate_reading_time(words_per_minute)
   - What it does: Estimates time needed to read this line
   - Uses: Auto-advance timing, pacing analysis
   - Returns: float seconds (default 200 WPM)

9. should_auto_advance()
   - What it does: Checks if this line auto-advances after delay
   - Uses: Dialogue system determines if awaiting input or auto-advancing
   - Returns: true if auto_advance_delay > 0

10. has_audio()
    - What it does: Checks if voice_clip is assigned
    - Uses: Audio system decides whether to play voice
    - Returns: true if voice clip exists

11. has_portrait()
    - What it does: Checks if portrait texture is assigned
    - Uses: UI layout decisions (show/hide portrait panel)
    - Returns: true if portrait exists

12. has_next_line()
    - What it does: Checks if next_line_id is set
    - Uses: Dialogue flow determines if there's a linked next line
    - Returns: true if next_line_id not empty

13. has_translation()
    - What it does: Checks if translation_key is assigned
    - Uses: Localization system determines translation availability
    - Returns: true if translation_key not empty

14. clone()
    - What it does: Creates deep copy of this dialogue line
    - Uses: Branching dialogue, template creation
    - Returns: New DialogueLine instance (dialogue_id gets "_clone" suffix)

15. serialize()
    - What it does: Converts dialogue line to Dictionary for save files
    - Uses: Save system persists dialogue state
    - Returns: Dictionary with all dialogue data (excludes heavy assets like portraits)

16. deserialize(data)
    - What it does: Loads dialogue line from save data, validates and repairs
    - Uses: Load system restores dialogue state
    - Returns: true if successful

17. get_debug_summary()
    - What it does: Creates formatted multi-line summary with all dialogue info
    - Uses: Development debugging, QA testing
    - Returns: String with speaker, text, audio, timing, validation status

18. debug_print()
    - What it does: Prints debug summary to console
    - Uses: Quick debugging during development
    - Returns: void

19. create_simple(speaker, dialogue_text, portrait_texture) [static]
    - What it does: Factory method creates basic dialogue line quickly
    - Uses: Quick dialogue creation in scripts
    - Returns: New DialogueLine with speaker and text configured

20. create_narrator(narration_text) [static]
    - What it does: Factory method creates narrator line (no speaker name shown)
    - Uses: Story narration, scene descriptions
    - Returns: New DialogueLine with SpeakerType.NARRATOR

21. create_system(message_text) [static]
    - What it does: Factory method creates system message
    - Uses: Tutorial messages, UI notifications
    - Returns: New DialogueLine with SpeakerType.SYSTEM

NOTES:
- Supports localization via translation_key (falls back to raw text)
- MAX_DIALOGUE_LENGTH enforced at 500 characters
- Speaker types: PLAYER, NPC, NARRATOR (no name), SYSTEM (translated name)
- Auto-advance system uses delay in seconds (0 = manual advance)
- Portrait, voice_clip, and text_sound are all optional
- Tags array allows filtering/searching dialogue lines
- Color and expression fields support visual variety
- Includes word count and reading time calculations for pacing
"""


class_name DialogueLine
extends Resource

## Single line of dialogue with speaker, text, portrait, and metadata

# --- Speaker Types ---
enum SpeakerType { PLAYER, NPC, NARRATOR, SYSTEM }

# --- Validation Constants ---
const MAX_DIALOGUE_LENGTH: int = 500
const MIN_DIALOGUE_LENGTH: int = 1

# --- Speaker Information ---
@export_group("Speaker")
@export var speaker_name: String = ""
@export var speaker_id: String = ""  # Unique ID for save/reference
@export var speaker_type: SpeakerType = SpeakerType.NPC

# --- Dialogue Content ---
@export_group("Content")
@export_multiline var text: String = ""
@export var translation_key: String = ""  # For localization (optional)

# --- Visual Presentation ---
@export_group("Visuals")
@export var portrait: Texture2D
@export var expression: String = "neutral"  # "happy", "sad", "angry", etc.
@export var text_color: Color = Color.WHITE

# --- Audio Support ---
@export_group("Audio")
@export var voice_clip: AudioStream
@export var text_sound: AudioStream  # Typing sound effect
@export var auto_advance_delay: float = 0.0  # 0 = manual, >0 = auto-advance

# --- Optional Metadata ---
@export_group("Metadata")
@export var dialogue_id: String = ""  # Unique line ID for branching
@export var next_line_id: String = ""  # Next dialogue in sequence
@export var tags: Array[String] = []  # For filtering/searching

# --- Fallback Portrait ---
const FALLBACK_PORTRAIT_PATH: String = "res://ui/portraits/unknown.png"
var _fallback_portrait: Texture2D = null


## Get display speaker name (with localization support)
## @return: Speaker name to display
func get_display_speaker_name() -> String:
	# Use speaker_id for translation if available
	if not speaker_id.is_empty():
		var translated := tr("speaker_" + speaker_id)
		if translated != "speaker_" + speaker_id:
			return translated
	
	# Fall back to speaker_name
	if not speaker_name.is_empty():
		return speaker_name
	
	# Narrator/System special cases
	if speaker_type == SpeakerType.NARRATOR:
		return ""  # Typically narrator has no name shown
	elif speaker_type == SpeakerType.SYSTEM:
		return tr("system_speaker")
	
	return tr("unknown_speaker")


## Get dialogue text (with localization support)
## @return: Dialogue text to display
func get_display_text() -> String:
	# Use translation key if available
	if not translation_key.is_empty():
		var translated := tr(translation_key)
		if translated != translation_key:
			return translated
	
	# Fall back to raw text
	if not text.is_empty():
		return text
	
	return tr("missing_dialogue_text")


## Get portrait texture with fallback
## @return: Portrait texture
func get_portrait() -> Texture2D:
	if portrait:
		return portrait
	
	# Load fallback portrait if needed
	if not _fallback_portrait:
		if ResourceLoader.exists(FALLBACK_PORTRAIT_PATH):
			_fallback_portrait = load(FALLBACK_PORTRAIT_PATH)
	
	return _fallback_portrait


## Validate dialogue line
## @return: Array of error messages (empty if valid)
func validate_dialogue() -> Array[String]:
	var errors: Array[String] = []
	
	# Validate speaker
	if speaker_name.is_empty() and speaker_id.is_empty():
		if speaker_type != SpeakerType.NARRATOR and speaker_type != SpeakerType.SYSTEM:
			errors.append("Dialogue line has no speaker name or ID")
	
	# Validate text content
	var display_text := get_display_text()
	if display_text.is_empty() or display_text == tr("missing_dialogue_text"):
		errors.append("Dialogue line has no text content")
	elif display_text.length() > MAX_DIALOGUE_LENGTH:
		errors.append("Dialogue text too long (%d chars, max %d)" % [
			display_text.length(), MAX_DIALOGUE_LENGTH
		])
	elif display_text.length() < MIN_DIALOGUE_LENGTH:
		errors.append("Dialogue text too short")
	
	# Validate portrait
	if portrait:
		var size := portrait.get_size()
		if size.x == 0 or size.y == 0:
			errors.append("Portrait texture has zero size")
	
	# Validate audio
	if voice_clip and not voice_clip is AudioStream:
		errors.append("Voice clip is not a valid AudioStream")
	if text_sound and not text_sound is AudioStream:
		errors.append("Text sound is not a valid AudioStream")
	
	# Validate auto-advance
	if auto_advance_delay < 0:
		errors.append("Auto-advance delay cannot be negative")
	
	return errors


## Repair invalid dialogue data
## @return: true if repaired, false if unfixable
func repair_dialogue() -> bool:
	var was_repaired := false
	
	# Generate IDs if missing
	if speaker_id.is_empty() and not speaker_name.is_empty():
		speaker_id = speaker_name.to_snake_case()
		was_repaired = true
	
	if dialogue_id.is_empty():
		dialogue_id = "line_%d" % get_instance_id()
		was_repaired = true
	
	# Sanitize text
	if not text.is_empty():
		var sanitized := text.strip_edges()
		if sanitized != text:
			text = sanitized
			was_repaired = true
	
	# Fix auto-advance
	if auto_advance_delay < 0:
		auto_advance_delay = 0.0
		was_repaired = true
	
	return was_repaired


## Get safe dialogue text (sanitized and validated)
## @return: Safe text for display
func get_safe_dialogue_text() -> String:
	var display_text := get_display_text()
	
	# Sanitize
	display_text = display_text.strip_edges()
	
	# Ensure non-empty
	if display_text.is_empty():
		return tr("missing_dialogue_text")
	
	# Truncate if too long
	if display_text.length() > MAX_DIALOGUE_LENGTH:
		display_text = display_text.left(MAX_DIALOGUE_LENGTH) + "..."
	
	# Replace tabs with spaces
	display_text = display_text.replace("\t", "    ")
	
	return display_text


## Get word count (useful for timing)
## @return: Number of words
func get_word_count() -> int:
	var display_text := get_display_text()
	if display_text.is_empty():
		return 0
	
	var words := display_text.split(" ", false)
	return words.size()


## Calculate reading time in seconds
## @param words_per_minute: Reading speed
## @return: Estimated reading time
func calculate_reading_time(words_per_minute: int = 200) -> float:
	var word_count := get_word_count()
	if word_count == 0:
		return 0.0
	
	return (word_count / float(words_per_minute)) * 60.0


## Check if dialogue should auto-advance
## @return: true if auto-advance enabled
func should_auto_advance() -> bool:
	return auto_advance_delay > 0.0


## Check if has audio
## @return: true if voice clip exists
func has_audio() -> bool:
	return voice_clip != null


## Check if has portrait
## @return: true if portrait exists
func has_portrait() -> bool:
	return portrait != null


## Check if has next line
## @return: true if next_line_id set
func has_next_line() -> bool:
	return not next_line_id.is_empty()


## Check if has translation
## @return: true if translation key exists
func has_translation() -> bool:
	return not translation_key.is_empty()


## Clone dialogue line
## @return: New DialogueLine instance
func clone() -> DialogueLine:
	var new_line := DialogueLine.new()
	new_line.speaker_name = speaker_name
	new_line.speaker_id = speaker_id
	new_line.speaker_type = speaker_type
	new_line.text = text
	new_line.translation_key = translation_key
	new_line.portrait = portrait
	new_line.expression = expression
	new_line.text_color = text_color
	new_line.voice_clip = voice_clip
	new_line.text_sound = text_sound
	new_line.auto_advance_delay = auto_advance_delay
	new_line.dialogue_id = dialogue_id + "_clone"
	new_line.next_line_id = next_line_id
	new_line.tags = tags.duplicate()
	return new_line


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	return {
		"speaker_name": speaker_name,
		"speaker_id": speaker_id,
		"speaker_type": speaker_type,
		"text": text,
		"translation_key": translation_key,
		"expression": expression,
		"text_color": text_color,
		"auto_advance_delay": auto_advance_delay,
		"dialogue_id": dialogue_id,
		"next_line_id": next_line_id,
		"tags": tags.duplicate()
	}


## Deserialize from save data
## @param data: Save data dictionary
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	speaker_name = data.get("speaker_name", "")
	speaker_id = data.get("speaker_id", "")
	speaker_type = data.get("speaker_type", SpeakerType.NPC)
	text = data.get("text", "")
	translation_key = data.get("translation_key", "")
	expression = data.get("expression", "neutral")
	text_color = data.get("text_color", Color.WHITE)
	auto_advance_delay = data.get("auto_advance_delay", 0.0)
	dialogue_id = data.get("dialogue_id", "")
	next_line_id = data.get("next_line_id", "")
	tags = data.get("tags", [])
	
	# Validate after loading
	var errors := validate_dialogue()
	if not errors.is_empty():
		push_warning("Deserialized dialogue has errors: %s" % ", ".join(errors))
		repair_dialogue()
	
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Dialogue Line ===%s\n" % (" [%s]" % dialogue_id if not dialogue_id.is_empty() else "")
	
	summary += "Speaker: %s" % get_display_speaker_name()
	if not speaker_id.is_empty():
		summary += " (%s)" % speaker_id
	summary += " [%s]\n" % SpeakerType.keys()[speaker_type]
	
	summary += "Text: \"%s\"\n" % get_safe_dialogue_text()
	
	if not translation_key.is_empty():
		summary += "Translation: %s\n" % translation_key
	
	summary += "Portrait: %s\n" % ("Yes" if has_portrait() else "No")
	summary += "Audio: %s\n" % ("Yes" if has_audio() else "No")
	summary += "Auto-advance: %s\n" % (
		"Yes (%.1fs)" % auto_advance_delay if should_auto_advance() else "No"
	)
	
	if has_next_line():
		summary += "Next: %s\n" % next_line_id
	
	if tags.size() > 0:
		summary += "Tags: %s\n" % ", ".join(tags)
	
	summary += "Word count: %d (%.1fs reading time)\n" % [
		get_word_count(),
		calculate_reading_time()
	]
	
	# Validation status
	var errors := validate_dialogue()
	if errors.is_empty():
		summary += "\n✓ Dialogue valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())


## Create a simple dialogue line (factory method)
## @param speaker: Speaker name
## @param dialogue_text: Dialogue text
## @param portrait_texture: Optional portrait
## @return: New DialogueLine
static func create_simple(speaker: String, dialogue_text: String, portrait_texture: Texture2D = null) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_name = speaker
	line.speaker_id = speaker.to_snake_case()
	line.text = dialogue_text
	line.portrait = portrait_texture
	return line


## Create a narrator line (factory method)
## @param narration_text: Narration text
## @return: New DialogueLine configured as narrator
static func create_narrator(narration_text: String) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_type = SpeakerType.NARRATOR
	line.text = narration_text
	return line


## Create a system message (factory method)
## @param message_text: System message
## @return: New DialogueLine configured as system
static func create_system(message_text: String) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_type = SpeakerType.SYSTEM
	line.text = message_text
	return line
