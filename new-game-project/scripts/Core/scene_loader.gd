"""
FILE: scene_loader.gd
PURPOSE: Centralized utility for loading and instantiating packed scenes safely.

OVERVIEW:
This static utility class standardizes how PackedScenes are loaded and instantiated. 
It wraps the core ResourceLoader and instantiate() calls with proper error handling, 
type validation, and logging. This prevents code duplication across the project where 
scenes need to be loaded (e.g., UI screens, units, projectiles).

FUNCTIONS:
1. load_scene(path: String) -> PackedScene
   - Loads a PackedScene resource safely
   - Returns null if load fails

2. instantiate_scene(path: String) -> Node
   - Loads and instantiates a scene in one step
   - Returns null if load or instantiation fails

3. instantiate_packed(scene: PackedScene) -> Node
   - Instantiates an already loaded PackedScene safely
"""
class_name SceneLoader
extends RefCounted

## Loads a PackedScene from the given path safely
static func load_scene(path: String) -> PackedScene:
	if path.is_empty():
		push_error("SceneLoader: Cannot load empty path")
		return null
		
	if not ResourceLoader.exists(path):
		push_error("SceneLoader: Scene not found at path: %s" % path)
		return null
		
	var scene = load(path)
	if not scene is PackedScene:
		push_error("SceneLoader: Resource at %s is not a PackedScene" % path)
		return null
		
	return scene

## Loads and instantiates a scene from a path
static func instantiate_scene(path: String) -> Node:
	var scene = load_scene(path)
	if not scene:
		return null
	return instantiate_packed(scene)

## Instantiates a PackedScene safely
static func instantiate_packed(scene: PackedScene) -> Node:
	if not scene:
		push_error("SceneLoader: Cannot instantiate null scene")
		return null
		
	var instance = scene.instantiate()
	if not instance:
		push_error("SceneLoader: Failed to instantiate scene")
		return null
		
	return instance
