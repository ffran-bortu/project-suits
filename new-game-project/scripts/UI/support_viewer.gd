"""
FILE: support_viewer.gd
PURPOSE: Displays support conversations between two characters with visual presentation and dialogue.

OVERVIEW:
This viewer presents support conversations in a visual novel style with character sprites displayed
side-by-side and dialogue text below. It parses conversation lines, highlights the currently speaking
character, and allows players to advance through dialogue by pressing accept. Integrates with the
dialogue manager addon for enhanced presentation.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Gets reference to dialogue manager addon and enables input processing
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. setup(conversation: SupportConversation, char_a: CharacterData, char_b: CharacterData)
   - What it does: Initializes the viewer with conversation data and character information, then displays first line
   - Uses: Called by SupportMenu when player selects a conversation to view
   - Returns: void

3. _load_character_sprites()
   - What it does: Loads and displays portrait images for both characters
   - Uses: Called during setup to show character visuals
   - Returns: void

4. _display_current_line()
   - What it does: Parses current dialogue line, extracts speaker name, displays text, and highlights speaking character
   - Uses: Called to show each line of dialogue as player progresses through conversation
   - Returns: void

5. _highlight_speaker(speaker: String)
   - What it does: Adjusts character sprite opacity to emphasize who is currently speaking
   - Uses: Called by _display_current_line to provide visual feedback
   - Returns: void

6. _animate_text_in()
   - What it does: Fades dialogue text in with a smooth animation
   - Uses: Called when displaying new dialogue lines
   - Returns: void

7. _input(event)
   - What it does: Listens for accept/select input to advance dialogue
   - Uses: Godot input callback processed each frame
   - Returns: void

8. _next_line()
   - What it does: Increments dialogue index and displays next line
   - Uses: Called when player presses accept button
   - Returns: void

9. _complete_conversation()
   - What it does: Marks conversation as viewed, emits completion signal, and closes viewer
   - Uses: Called when all dialogue lines have been displayed
   - Returns: void

NOTES:
- Depends on SupportConversation resource for dialogue data
- Depends on CharacterData for character portraits and information
- Optionally uses DialogueManager addon if available for enhanced features
- Emits conversation_complete signal when viewing finishes
- Parses dialogue format as "Speaker: text" to identify who is talking
- Uses fade animations and sprite highlighting for visual polish
- Self-destructs (queue_free) after conversation completes
"""

"""
FILE: support_viewer.gd
PURPOSE: Support conversation viewer - displays full dialogue for selected support.
NOTES: Support system UI - dialogue display.
"""
extends Control
class_name SupportViewer
## Support conversation viewer using dialogue manager addon
##
## Displays side-by-side character sprites with dialogue panel

signal conversation_complete(conversation: SupportConversation)

# UI references
@onready var background = $Background
@onready var character_left = $CharacterSprites/CharacterLeft
@onready var character_right = $CharacterSprites/CharacterRight
@onready var dialogue_panel = $DialoguePanel
@onready var speaker_name = $DialoguePanel/VBoxContainer/SpeakerName
@onready var dialogue_text = $DialoguePanel/VBoxContainer/DialogueText
@onready var next_indicator = $NextIndicator

# Data
var current_conversation: SupportConversation
var character_a_data: CharacterData
var character_b_data: CharacterData
var dialogue_lines: Array[String] = []
var current_line_index: int = 0
var dialogue_manager: Node
var active_tween: Tween = null

func _ready() -> void:
	# Get dialogue manager autoload
	dialogue_manager = get_node_or_null("/root/DialogueManager")
	if not dialogue_manager:
		push_warning("SupportViewer: DialogueManager addon not found")
	
	# Enable input processing
	set_process_input(true)

## Setup conversation
## @param conversation: SupportConversation resource
## @param char_a: CharacterData for first character
## @param char_b: CharacterData for second character
func setup(conversation: SupportConversation, char_a: CharacterData, char_b: CharacterData) -> void:
	# Validate inputs
	if not conversation:
		push_error("SupportViewer: Null conversation provided")
		queue_free()
		return
	
	if not char_a or not char_b:
		push_error("SupportViewer: Null character data provided")
		queue_free()
		return
	
	if not conversation.conversation_lines or conversation.conversation_lines.is_empty():
		push_error("SupportViewer: Conversation has no dialogue lines")
		queue_free()
		return
	
	current_conversation = conversation
	character_a_data = char_a
	character_b_data = char_b
	
	# Load character sprites (full body if available)
	_load_character_sprites()
	
	# Get dialogue lines from conversation
	dialogue_lines = conversation.conversation_lines.duplicate()
	
	# Display first line
	current_line_index = 0
	_display_current_line()

func _load_character_sprites() -> void:
	# Load character portraits/sprites
	# TODO: Use actual sprite paths from CharacterData
	# For now, just show placeholder
	if character_a_data and "portrait" in character_a_data and character_a_data.portrait:
		character_left.texture = character_a_data.portrait
	
	if character_b_data and "portrait" in character_b_data and character_b_data.portrait:
		character_right.texture = character_b_data.portrait

func _display_current_line() -> void:
	# Validate index
	if current_line_index < 0 or current_line_index >= dialogue_lines.size():
		_complete_conversation()
		return
	
	var line = dialogue_lines[current_line_index]
	if not line or line.is_empty():
		push_warning("SupportViewer: Empty dialogue line at index %d" % current_line_index)
		current_line_index += 1
		_display_current_line()
		return
	
	# Parse speaker (format: "Name: dialogue")
	var parts = line.split(":", true, 1)
	if parts.size() >= 2:
		var speaker = parts[0].strip_edges()
		var text = parts[1].strip_edges()
		
		speaker_name.text = speaker
		dialogue_text.text = text
		
		# Highlight speaking character
		_highlight_speaker(speaker)
	else:
		# No speaker prefix, just show text
		speaker_name.text = ""
		dialogue_text.text = line
	
	# Animate text in
	_animate_text_in()

func _highlight_speaker(speaker: String) -> void:
	# Determine which character is speaking
	var char_a_speaking = speaker.to_lower() == character_a_data.character_name.to_lower()
	
	if char_a_speaking:
		character_left.modulate.a = 1.0
		character_right.modulate.a = 0.6
	else:
		character_left.modulate.a = 0.6
		character_right.modulate.a = 1.0

func _animate_text_in() -> void:
	# Simple fade in for text
	dialogue_text.modulate.a = 0
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	
	active_tween.tween_property(dialogue_text, "modulate:a", 1.0, 0.3)

func _input(event) -> void:
	# Advance on accept input
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_next_line()
		accept_event()

func _next_line() -> void:
	current_line_index += 1
	_display_current_line()

func _complete_conversation() -> void:
	# Mark as viewed
	if current_conversation and current_conversation.has_method("mark_as_viewed"):
		current_conversation.mark_as_viewed()
	
	# Emit completion signal
	emit_signal("conversation_complete", current_conversation)
	
	# Close viewer
	queue_free()
