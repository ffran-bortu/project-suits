"""
FILE: support_menu.gd
PURPOSE: Displays a filterable list of support conversations and launches the viewer when selected.

OVERVIEW:
This menu shows all available support conversations between characters with filtering options by
character and rank. Players can browse conversations, select one to view, and the menu handles
loading the support viewer scene. It validates character data and manages the conversation lifecycle.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects UI button signals and filter change handlers
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. setup(characters: Array[CharacterData])
   - What it does: Initializes the menu with character data, builds lookup table, loads conversations, and populates filters
   - Uses: Called when opening the support menu to configure it with current party
   - Returns: void

3. _load_all_conversations()
   - What it does: Loads all support conversation resources from data files
   - Uses: Called during setup to populate available conversations
   - Returns: void

4. _populate_filters()
   - What it does: Fills filter dropdowns with character names and relationship ranks
   - Uses: Called during setup after character data is loaded
   - Returns: void

5. refresh_list()
   - What it does: Clears and rebuilds the conversation list based on current filters
   - Uses: Called when filters change or conversations are updated
   - Returns: void

6. _apply_filters() -> Array[SupportConversation]
   - What it does: Returns filtered list of conversations based on selected character and rank filters
   - Uses: Called by refresh_list to determine which conversations to display
   - Returns: Array[SupportConversation] - filtered conversation list

7. _create_conversation_button(conv: SupportConversation) -> Button
   - What it does: Creates a button UI element for a conversation with formatted text showing characters and rank
   - Uses: Called for each conversation when building the list
   - Returns: Button - configured button for the conversation

8. _get_rank_string(rank: int) -> String
   - What it does: Converts relationship rank enum to letter string (C, B, A, S)
   - Uses: Called when formatting conversation button text
   - Returns: String - rank letter or "?" for unknown

9. _on_conversation_selected(conv: SupportConversation)
   - What it does: Sets the selected conversation and enables the view button
   - Uses: Signal callback when player clicks a conversation button
   - Returns: void

10. _on_view_pressed()
    - What it does: Validates selection, loads support viewer scene, and starts the conversation
	- Uses: Signal callback when player clicks the "View" button
    - Returns: void

11. _on_conversation_completed(conv: SupportConversation)
    - What it does: Refreshes the conversation list and shows menu after viewing
    - Uses: Signal callback when support viewer finishes displaying conversation
    - Returns: void

12. _on_filter_changed(_value = null)
    - What it does: Triggers list refresh when filter selections change
    - Uses: Signal callback for filter dropdown and checkbox changes
    - Returns: void

13. _on_back_pressed()
    - What it does: Emits menu_closed signal to return to previous screen
	- Uses: Signal callback when player clicks the "Back" button
    - Returns: void

NOTES:
- Depends on CharacterData for character information
- Depends on SupportConversation resource for conversation data
- Requires SupportViewer scene (res://scenes/ui/support_viewer.tscn) for displaying conversations
PURPOSE: Support conversation menu - list available conversations between characters.
NOTES: Support system UI - conversation list.
"""
extends Control
class_name SupportMenu
## Support conversation list and launcher
##
## Displays all available support conversations with filtering

signal conversation_viewed(conversation: SupportConversation)
signal menu_closed

# UI references
@onready var conversation_list = $VBoxContainer/ScrollContainer/ConversationList
@onready var character_filter = $VBoxContainer/Filters/CharacterFilter
@onready var rank_filter = $VBoxContainer/Filters/RankFilter
@onready var show_locked = $VBoxContainer/Filters/ShowLocked
@onready var view_button = $VBoxContainer/Controls/ViewButton
@onready var back_button = $VBoxContainer/Controls/BackButton

# Data
var all_conversations: Array[SupportConversation] = []
var character_lookup: Dictionary = {}  # character_id -> CharacterData
var selected_conversation: SupportConversation = null

# const SUPPORT_VIEWER_SCENE = preload("res://scenes/ui/support_viewer.tscn") # Legacy

func _ready():
	# Connect button signals
	view_button.pressed.connect(_on_view_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	if character_filter:
		character_filter.item_selected.connect(_on_filter_changed)
	if rank_filter:
		rank_filter.item_selected.connect(_on_filter_changed)
	if show_locked:
		show_locked.toggled.connect(_on_filter_changed)

## Setup with character data
## @param characters: Array of CharacterData
func setup(characters: Array[CharacterData]):
	# Validate input
	if characters.is_empty():
		push_error("SupportMenu: No characters provided")
		return
	
	# Build character lookup
	character_lookup.clear()
	for char in characters:
		if not char:
			push_warning("SupportMenu: Null character in array, skipping")
			continue
		if not char.character_id or char.character_id.is_empty():
			push_warning("SupportMenu: Character missing character_id, skipping")
			continue
		character_lookup[char.character_id] = char
	
	if character_lookup.is_empty():
		push_error("SupportMenu: No valid characters after filtering")
		return
	
	# Load conversations (TODO: from data folder)
	_load_all_conversations()
	
	# Populate filters
	_populate_filters()
	
	# Refresh list
	refresh_list()

func _load_all_conversations():
	all_conversations.clear()
	var dir_path = "res://data/supports/"
	var dir = DirAccess.open(dir_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap") or file_name.ends_with(".gd")):
				# Handle export remap extension
				var clean_name = file_name.replace(".remap", "")
				var full_path = dir_path + clean_name
				var resource = load(full_path)
				
				var conversation_instance = null
				
				if resource is GDScript:
					conversation_instance = resource.new()
				elif resource is Resource:
					conversation_instance = resource
					
				if conversation_instance is SupportConversation:
					all_conversations.append(conversation_instance)
			file_name = dir.get_next()
	else:
		# Directory doesn't exist, try to create it or just fallback
		push_warning("SupportMenu: Support directory not found at " + dir_path)
		
	# Fallback if no files found
	if all_conversations.is_empty():
		var test_conv = SupportConversation.new()
		test_conv.character_a_id = "char_001"
		test_conv.character_b_id = "char_002" 
		test_conv.rank = SupportConversation.RelationshipRank.C
		test_conv.conversation_lines.assign([
			"Lyn: Hey Eliwood, ready for battle?",
			"Eliwood: Always, Lyn. Let's protect our friends."
		])
		all_conversations = [test_conv]

func _populate_filters():
	if character_filter:
		character_filter.clear()
		character_filter.add_item("All Characters", -1)
		
		for char_id in character_lookup:
			var char: CharacterData = character_lookup[char_id]
			character_filter.add_item(char.character_name)
	
	if rank_filter:
		rank_filter.clear()
		rank_filter.add_item("All Ranks", -1)
		rank_filter.add_item("C Rank", SupportConversation.RelationshipRank.C)
		rank_filter.add_item("B Rank", SupportConversation.RelationshipRank.B)
		rank_filter.add_item("A Rank", SupportConversation.RelationshipRank.A)

func refresh_list():
	if not conversation_list:
		return
	
	# Clear list
	for child in conversation_list.get_children():
		child.queue_free()
	
	# Apply filters
	var filtered = _apply_filters()
	
	# Create button for each conversation
	for conv in filtered:
		var button = _create_conversation_button(conv)
		conversation_list.add_child(button)

func _apply_filters() -> Array[SupportConversation]:
	var filtered: Array[SupportConversation] = []
	
	for conv in all_conversations:
		# Check if unlocked/locked
		# TODO: Check actual unlock status from character bond data
		filtered.append(conv)
	
	return filtered

func _create_conversation_button(conv: SupportConversation) -> Button:
	var button = Button.new()
	
	# Format: "Lyn + Eliwood (C)"
	var rank_str = _get_rank_string(conv.rank)
	button.text = "%s + %s (%s)" % ["CharA", "CharB", rank_str]  # TODO: Get names
	
	button.pressed.connect(_on_conversation_selected.bind(conv))
	
	return button

func _get_rank_string(rank: int) -> String:
	match rank:
		SupportConversation.RelationshipRank.C: return "C"
		SupportConversation.RelationshipRank.B: return "B"
		SupportConversation.RelationshipRank.A: return "A"
		SupportConversation.RelationshipRank.S: return "S"
		_: return "?"

func _on_conversation_selected(conv: SupportConversation):
	selected_conversation = conv
	if view_button:
		view_button.disabled = false

func _on_view_pressed():
	if not selected_conversation:
		push_warning("SupportMenu: No conversation selected")
		return
	
	# Get character data
	var char_a = character_lookup.get(selected_conversation.character_a_id)
	var char_b = character_lookup.get(selected_conversation.character_b_id)
	
	if not char_a:
		push_error("SupportMenu: Character A not found: %s" % selected_conversation.character_a_id)
		return
	
	if not char_b:
		push_error("SupportMenu: Character B not found: %s" % selected_conversation.character_b_id)
		return
	
	# Instantiate support viewer
	var support_viewer_path = GameConfig.ui.support_viewer
	var support_viewer = SceneLoader.instantiate_scene(support_viewer_path)
	
	if not support_viewer:
		return
		
	# Add to scene
	add_child(support_viewer)
	support_viewer.setup(selected_conversation, char_a, char_b)
	
	# Connect closing signal
	if support_viewer.has_signal("conversation_complete"):
		support_viewer.conversation_complete.connect(_on_conversation_completed.bind(support_viewer))
	else:
		push_warning("SupportMenu: Viewer missing conversation_complete signal")
	
	# Hide this menu temporarily
	hide()

func _on_conversation_completed(conv: SupportConversation):
	# Refresh list
	refresh_list()
	show()
	emit_signal("conversation_viewed", conv)

func _on_filter_changed(_value = null):
	refresh_list()

func _on_back_pressed():
	emit_signal("menu_closed")
