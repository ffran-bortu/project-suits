"""
FILE: world_map_controller.gd
PURPOSE: Chapter selection UI - lists chapters with buttons, transitions to battle scene.
FUNCTIONS: _ready, _connect_signals, _on_chapter1/2/test_map_pressed, _on_back_pressed, _start_battle, _return_to_main_menu, set_unlocked_chapters - 9 total
NOTES: Preloads BATTLE_SCENE and MAIN_MENU_SCENE. Prevents transitions during _is_transitioning. Emits chapter_selected and return_to_menu signals.
"""

extends Control
## World Map Controller - Chapter/Map Selection
##
## Manages chapter selection and transitions to battle scenes

# --- Signals ---
signal chapter_selected(chapter_id: String)
signal return_to_menu

# --- Constants ---
# Scenes loaded from GameConfig at runtime

# --- Node References ---
@onready var chapter1_button: Button = $Panel/VBoxContainer/MarginContainer/Content/ChapterList/Chapter1Button
@onready var chapter2_button: Button = $Panel/VBoxContainer/MarginContainer/Content/ChapterList/Chapter2Button
@onready var test_map_button: Button = $Panel/VBoxContainer/MarginContainer/Content/ChapterList/TestMapButton
@onready var back_button: Button = $Panel/VBoxContainer/MarginContainer/Content/BackButton

# --- State ---
var _is_transitioning: bool = false
var selected_difficulty: int = 1  # Default to Normal


func _ready() -> void:
	_connect_signals()
	DebugLog.log("World Map Ready", "cyan")


## Connect button signals
func _connect_signals() -> void:
	if chapter1_button:
		chapter1_button.pressed.connect(_on_chapter1_pressed)
	if chapter2_button:
		chapter2_button.pressed.connect(_on_chapter2_pressed)
	if test_map_button:
		test_map_button.pressed.connect(_on_test_map_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


## Handle Chapter 1 selection
func _on_chapter1_pressed() -> void:
	if _is_transitioning:
		return
	
	DebugLog.success("Loading Chapter 1...")
	_start_battle("chapter_1")


## Handle Chapter 2 selection
func _on_chapter2_pressed() -> void:
	if _is_transitioning:
		return
	
	DebugLog.success("Loading Chapter 2...")
	_start_battle("chapter_2")


## Handle Test Map selection
func _on_test_map_pressed() -> void:
	if _is_transitioning:
		return
	
	DebugLog.success("Loading Test Map...")
	_start_battle("test_map")


## Handle back to main menu
func _on_back_pressed() -> void:
	if _is_transitioning:
		return
	
	DebugLog.log("Returning to main menu", "cyan")
	_return_to_main_menu()


## Start battle scene
func _start_battle(chapter_id: String) -> void:
	_is_transitioning = true
	
	# Emit signal for tracking
	chapter_selected.emit(chapter_id)
	
	# TODO: Pass chapter_id to battle scene for map loading
	var battle_scene_path: String = GameConfig.assets.get("battle_scene", "res://scenes/main.tscn")
	if not ResourceLoader.exists(battle_scene_path):
		push_error("WorldMap: Battle scene not found at %s" % battle_scene_path)
		_is_transitioning = false
		return

	var error := get_tree().change_scene_to_file(battle_scene_path)
	if error != OK:
		push_error("WorldMap: Failed to load battle scene! Error: %d" % error)
		_is_transitioning = false


## Return to main menu
func _return_to_main_menu() -> void:
	_is_transitioning = true
	return_to_menu.emit()
	
	var menu_scene_path: String = GameConfig.assets.get("main_menu_scene", "res://scenes/menu_main.tscn")
	var error := get_tree().change_scene_to_file(menu_scene_path)
	if error != OK:
		push_error("WorldMap: Failed to return to main menu! Error: %d" % error)
		_is_transitioning = false


## Set which chapters are unlocked
## @param unlocked_chapters: Array of chapter IDs that should be unlocked
func set_unlocked_chapters(unlocked_chapters: Array[String]) -> void:
	# For now, just unlock Chapter 2 if it's in the list
	if chapter2_button and "chapter_2" in unlocked_chapters:
		chapter2_button.disabled = false
		chapter2_button.text = "Chapter 2: Unlocked!"




