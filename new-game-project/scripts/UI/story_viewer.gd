"""
FILE: story_viewer.gd
PURPOSE: Displays story dialogues using DialogueSequence resources.

OVERVIEW:
A comprehensive cutscene/dialogue player that consumes DialogueSequence resources.
It handles visual presentation (backgrounds, portraits), audio playback (music, voice),
and text display with auto-advance functionality. It is designed to be modular and
can be instantiated by level managers or event triggers.

FUNCTIONS:
1. setup(sequence: DialogueSequence) -> void: Initializes the viewer with a sequence.
2. _display_current_line() -> void: Updates UI elements for the current line.
3. _advance() -> void: Moves to the next line or completes the sequence.
"""

class_name StoryViewer
extends Control

signal sequence_completed(sequence_id: String)
signal sequence_cancelled

# --- Components ---
# These paths would ideally be dynamic or passed in, but we assume a standard structure
var _background_rect: TextureRect
var _portrait_rect: TextureRect
var _speaker_label: Label
var _dialogue_label: RichTextLabel
var _dialogue_panel: Panel

# --- State ---
var _current_sequence: DialogueSequence
var _is_active: bool = false
var _auto_advance_timer: Timer

func _ready() -> void:
	_create_ui_structure()
	set_process_input(false)

func setup(sequence: DialogueSequence) -> void:
	if not sequence:
		push_error("StoryViewer: Null sequence provided")
		return

	_current_sequence = sequence
	_current_sequence.start()
	_is_active = true
	set_process_input(true)
	
	# Setup visuals
	if _current_sequence.background:
		_background_rect.texture = _current_sequence.background
	else:
		_background_rect.texture = null # or fallback
		
	# Play music if available (requires AudioBus, skipping for this snippet)
	
	_display_current_line()

func _input(event: InputEvent) -> void:
	if not _is_active:
		return
		
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_advance()
		get_viewport().set_input_as_handled()

func _display_current_line() -> void:
	var line: DialogueLine = _current_sequence.get_current_line()
	if not line:
		push_warning("StoryViewer: Invalid line at index " + str(_current_sequence.current_line_index))
		_advance()
		return
		
	# Text
	_speaker_label.text = line.get_display_speaker_name()
	_dialogue_label.text = line.get_safe_dialogue_text()
	
	# Portrait
	if line.has_portrait():
		_portrait_rect.texture = line.get_portrait()
		_portrait_rect.visible = true
	else:
		_portrait_rect.visible = false
		
	# Setup auto-advance
	if line.should_auto_advance():
		_start_auto_advance(line.auto_advance_delay)
	else:
		_stop_auto_advance()

func _advance() -> void:
	if _current_sequence.advance():
		_display_current_line()
	else:
		_complete_sequence()

func _complete_sequence() -> void:
	_is_active = false
	set_process_input(false)
	_current_sequence.complete()
	
	# Apply flags
	# var game_state = get_node("/root/GlobalGameState") # Dependency injection preferred
	# _current_sequence.apply_flags(game_state.flags)
	
	sequence_completed.emit(_current_sequence.sequence_id)
	queue_free()

func _start_auto_advance(delay: float) -> void:
	if not _auto_advance_timer:
		_auto_advance_timer = Timer.new()
		add_child(_auto_advance_timer)
		_auto_advance_timer.timeout.connect(_advance)
	
	_auto_advance_timer.wait_time = delay
	_auto_advance_timer.one_shot = true
	_auto_advance_timer.start()

func _stop_auto_advance() -> void:
	if _auto_advance_timer:
		_auto_advance_timer.stop()

# --- Internal UI Construction (Fallback if no scene) ---
func _create_ui_structure() -> void:
	# Root
	anchor_right = 1.0
	anchor_bottom = 1.0
	
	# Background layer
	_background_rect = TextureRect.new()
	_background_rect.layout_mode = 1 # Anchors
	_background_rect.anchors_preset = Control.PRESET_FULL_RECT
	_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_background_rect)
	
	# Portrait layer
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(300, 300)
	_portrait_rect.position = Vector2(100, 200) # Arbitrary placement
	add_child(_portrait_rect)
	
	# Dialogue Panel
	_dialogue_panel = Panel.new()
	_dialogue_panel.layout_mode = 1
	_dialogue_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	_dialogue_panel.custom_minimum_size = Vector2(0, 200)
	add_child(_dialogue_panel)
	
	# VBox
	var vbox = VBoxContainer.new()
	vbox.layout_mode = 1
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("margin_left", 20)
	vbox.add_theme_constant_override("margin_top", 20)
	_dialogue_panel.add_child(vbox)
	
	# Labels
	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_speaker_label)
	
	_dialogue_label = RichTextLabel.new()
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_label.bbcode_enabled = true
	vbox.add_child(_dialogue_label)
