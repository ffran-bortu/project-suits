# Map Editor Plugin
tool
extends EditorPlugin

const MapEditor = preload("res://addons/map_editor/map_editor.tscn")
var editor_instance

func _enter_tree():
	# Add as bottom panel (accessible via bottom toolbar)
	editor_instance = MapEditor.instantiate()
	add_control_to_bottom_panel(editor_instance, "Map Editor")

func _exit_tree():
	if editor_instance:
		remove_control_from_bottom_panel(editor_instance)
		editor_instance.queue_free()
