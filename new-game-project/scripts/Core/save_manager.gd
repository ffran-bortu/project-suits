"""
FILE: save_manager.gd
PURPOSE: Handles game save/load operations and complete game state persistence.

OVERVIEW:
This manager serializes the entire game state (units, inventory, progression, map state) to disk and
restores it on load. It converts CharacterData, Units, bond levels, completed chapters, and world map
progress into saveable Dictionary format, writes to user://saves/, and provides save slot management.
The system uses save versioning to handle future data format changes gracefully.

FUNCTIONS IN THIS FILE:

1. save_game(slot)
   - What it does: Serializes complete game state and writes to save file
   - Uses: Called when player saves from pause menu or auto-save triggers
   - Returns: bool (true if save succeeded)

2. load_game(slot)
   - What it does: Reads save file and restores game state (units, progression, inventory, etc.)
   - Uses: Called from main menu "Continue" or load game UI
   - Returns: bool (true if load succeeded)

3. save_exists(slot)
   - What it does: Checks if a save file exists for the given slot
   - Uses: For showing/hiding "Continue" button, save slot UI
   - Returns: bool

4. get_save_metadata(slot)
   - What it does: Reads save file metadata without full load (chapter, turn, timestamp)
   - Uses: For save slot UI to display chapter/turn info
   - Returns: Dictionary with version, chapter, turn

5. _serialize_units()
   - What it does: Converts all active units to saveable Dictionary format
   - Uses: Called by save_game() to capture unit state
   - Returns: Array of unit data dictionaries

6. _serialize_character(character)
   - What it does: Converts CharacterData to Dictionary (stats, bonds, equipment)
   - Uses: Helper for _serialize_units() for each character
   - Returns: Dictionary

7. _serialize_map_state()
   - What it does: Captures current map, turn number, terrain changes
   - Uses: Called by save_game() to save battle progress
   - Returns: Dictionary

8. _serialize_inventory()
   - What it does: Saves convoy items and gold
   - Uses: Called by save_game() to persist player resources
   - Returns: Dictionary

9. _serialize_progression()
   - What it does: Saves completed chapters, unlocked characters, support levels
   - Uses: Called by save_game() for campaign progress
   - Returns: Dictionary

10. _serialize_game_state()
    - What it does: Saves current game/phase state
    - Uses: Called by save_game() to restore exact state
    - Returns: Dictionary

11. _deserialize_units(units_data)
    - What it does: Recreates all units from save data (instantiates scenes, restores stats)
    - Uses: Called by load_game() to spawn units
    - Returns: void

12. _deserialize_character(char_data)
    - What it does: Recreates CharacterData from Dictionary
    - Uses: Helper for _deserialize_units()
    - Returns: CharacterData

13. _deserialize_map_state(map_data)
    - What it does: Restores map state (turn number, terrain)
    - Uses: Called by load_game() to continue battle
    - Returns: void

14. _deserialize_inventory(inventory_data)
    - What it does: Restores convoy and gold
    - Uses: Called by load_game()
    - Returns: void

15. _deserialize_progression(progression_data)
    - What it does: Restores campaign progress
    - Uses: Called by load_game()
    - Returns: void

NOTES:
- Singleton-like manager (one instance per game)
- Depends on: UnitManager, ExampleContent (for character creation), WorldMap
- Save location: user://saves/slot_X.sav
- Current save version: 2.0 (tracks version for future compatibility)
- Saves complete state: units (position, HP, stats), bonds, inventory, chapters, map progress
- TODO: Support for version migration if save format changes
"""

extends Node
## Save/load complete game state

const SAVE_DIR = "user://saves/"
const SAVE_EXTENSION = ".sav"
const SAVE_VERSION = "2.0"  # Updated for comprehensive saves

## Save complete game state
func save_game(slot: int) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	
	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_absolute(SAVE_DIR)
	
	# Collect comprehensive save data
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"difficulty": Difficulty.current_level,
		"units": _serialize_units(),
		"map_state": _serialize_map_state(),
		"inventory": _serialize_inventory(),
		"progression": _serialize_progression(),
		"phase": _serialize_phase_state()
	}
	
	# Write to file
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
		DebugLog.success("Game saved to slot %d" % slot)
		return true
	
	DebugLog.error("Failed to save game")
	return false

## Load complete game state
func load_game(slot: int) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		DebugLog.warn("Save file not found: slot %d" % slot)
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		# Version check
		if save_data.get("version", "1.0") != SAVE_VERSION:
			DebugLog.warn("Save file version mismatch - attempting migration")
		
		# Restore all data
		if save_data.has("difficulty"):
			Difficulty.current_level = save_data.difficulty
		
		if save_data.has("units"):
			_deserialize_units(save_data.units)
		
		if save_data.has("map_state"):
			_deserialize_map_state(save_data.map_state)
		
		if save_data.has("inventory"):
			_deserialize_inventory(save_data.inventory)
		
		if save_data.has("progression"):
			_deserialize_progression(save_data.progression)
		
		if save_data.has("phase"):
			_deserialize_phase_state(save_data.phase)
		
		DebugLog.success("Game loaded from slot %d" % slot)
		return true
	
	return false

## Check if save exists
func save_exists(slot: int) -> bool:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	return FileAccess.file_exists(save_path)

## Get save metadata (for save slot UI)
func get_save_metadata(slot: int) -> Dictionary:
	var save_path = SAVE_DIR + "slot_" + str(slot) + SAVE_EXTENSION
	
	if not FileAccess.file_exists(save_path):
		return {}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		return {
			"timestamp": save_data.get("timestamp", "Unknown"),
			"difficulty": save_data.get("difficulty", "Normal"),
			"version": save_data.get("version", "1.0"),
			"chapter": save_data.get("progression", {}).get("current_chapter", 1),
			"turn": save_data.get("map_state", {}).get("turn_number", 1)
		}
	
	return {}

# === SERIALIZATION HELPERS ===

func _serialize_units() -> Array:
	var units_data = []
	var unit_manager = _get_unit_manager()
	
	if not unit_manager:
		return units_data
	
	# Get all units from unit_manager
	var all_units = unit_manager.get_all_units() if unit_manager.has_method("get_all_units") else []
	for unit in all_units:
		var unit_data = {
			"type": "duo" if unit is DuoUnit else "solo",
			"team": unit.team,
			"grid_position": {"x": unit.grid_position.x, "y": unit.grid_position.y},
			"has_moved": unit.has_moved,
			"has_acted": unit.has_acted,
			"current_health": unit.current_health,
			"max_health": unit.max_health
		}
		
		if unit is DuoUnit:
			# Duo-specific data
			unit_data["frontliner"] = _serialize_character(unit.frontliner)
			unit_data["backliner"] = _serialize_character(unit.backliner)
			unit_data["bond_level"] = unit.bond_level
		else:
			# Solo unit data
			unit_data["character"] = _serialize_character(unit.character)
		
		units_data.append(unit_data)
	
	return units_data

func _serialize_character(character) -> Dictionary:
	if not character:
		return {}
	
	return {
		"char_name": character.char_name,
		"unit_class_name": character.unit_class.class_name if character.unit_class else "",
		"level": character.level,
		"experience": character.experience,
		"stats": {
			"hp": character.hp,
			"strength": character.strength,
			"mag": character.mag,
			"skill": character.skill,
			"spd": character.spd,
			"luck": character.luck,
			"def": character.def,
			"res": character.res
		},
		"weapon_name": character.weapon.weapon_name if character.weapon else ""
	}

func _serialize_map_state() -> Dictionary:
	var phase_manager = _get_phase_manager()
	var world_map = _get_world_map()
	
	var map_data = {
		"turn_number": 1,
		"current_map": "",
		"terrain_changes": [],
		"active_spawns": {}
	}
	
	if phase_manager and "turn_number" in phase_manager:
		map_data["turn_number"] = phase_manager.turn_number
	
	# Get current map from world_map (visual controller compatible)
	if world_map:
		# Visual controller uses current_node dictionary
		if "current_node" in world_map and world_map.current_node is Dictionary:
			map_data["current_map"] = world_map.current_node.get("node_id", "")
		# Fallback for old WorldMapNode format
		elif "current_node" in world_map and world_map.current_node != null:
			map_data["current_map"] = world_map.current_node.node_id if "node_id" in world_map.current_node else ""
	
	# Serialize active spawns (if WorldMapNode system used)
	if world_map and world_map.has_method("get_all_nodes"):
		for node in world_map.get_all_nodes():
			# Handle both Dictionary nodes (visual controller) and WorldMapNode resources
			var node_id: String = node.get("node_id", "") if node is Dictionary else (node.node_id if "node_id" in node else "")
			
			if node_id.is_empty():
				continue
			
			var node_spawns = {}
			
			# Check for spawned entities (WorldMapNode resources only)
			if not node is Dictionary:
				if "spawned_hostile" in node and node.spawned_hostile:
					if node.spawned_hostile.has_method("to_dictionary"):
						node_spawns["hostile"] = node.spawned_hostile.to_dictionary()
				if "spawned_merchant" in node and node.spawned_merchant:
					if node.spawned_merchant.has_method("to_dictionary"):
						node_spawns["merchant"] = node.spawned_merchant.to_dictionary()
			
			if not node_spawns.is_empty():
				map_data["active_spawns"][node_id] = node_spawns
	
	return map_data

func _serialize_inventory() -> Dictionary:
	var inventory_data = {
		"convoy": [],
		"gold": 0
	}
	
	# Try to get gold from a global inventory manager or player stats
	# For now, check if there's a game manager with gold tracking
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and "gold" in game_manager:
		inventory_data["gold"] = game_manager.gold
	
	# Serialize convoy weapons if inventory system exists
	var inventory_manager = _get_inventory_manager()
	if inventory_manager and inventory_manager.has_method("serialize"):
		inventory_data["convoy"] = inventory_manager.serialize()
	
	return inventory_data

func _serialize_progression() -> Dictionary:
	var world_map = get_tree().get_first_node_in_group("world_map")
	
	var progression_data = {
		"current_chapter": 1,
		"completed_chapters": [],
		"unlocked_characters": [],
		"support_levels": {}
	}
	
	# Get progression from world map
	if world_map:
		# Visual controller uses visited_nodes: Array[String]
		if "visited_nodes" in world_map:
			var visited = world_map.visited_nodes
			if visited is Array:
				progression_data["completed_chapters"] = visited.duplicate()
		
		# Current chapter from current node
		if "current_node" in world_map:
			var curr_node = world_map.current_node
			# Handle Dictionary format (visual controller)
			if curr_node is Dictionary:
				var node_id: String = curr_node.get("node_id", "")
				if not node_id.is_empty():
					progression_data["current_chapter"] = _extract_chapter_number(node_id)
			# Handle WorldMapNode format (old manager)
			elif curr_node != null and "node_id" in curr_node:
				progression_data["current_chapter"] = _extract_chapter_number(curr_node.node_id)
	
	# Serialize support levels from bond system
	var bond_system = get_tree().get_first_node_in_group("bond_system")
	if not bond_system:
		bond_system = get_node_or_null("/root/BondSystem")
	
	# Get all characters and their bonds
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	if unit_manager:
		for unit in unit_manager.get_all_units():
			if unit.character and "bond_data" in unit.character:
				var char_id = unit.character.character_id if "character_id" in unit.character else unit.character.char_name
				# PHASE 4 FIX: Serialize bond resources to simple data
				var bonds_serialized = []
				for bond in unit.character.bond_data:
					bonds_serialized.append({
						"partner_id": bond.partner_id,
						"rank": bond.rank,
						"points": bond.points,
						"conversations": bond.unlocked_conversations.duplicate()
					})
				progression_data["support_levels"][char_id] = bonds_serialized
	
	return progression_data

# Helper to extract chapter number from node ID
func _extract_chapter_number(node_id: String) -> int:
	# Try to parse chapter number from node_id (e.g., "chapter_1" -> 1)
	var parts = node_id.split("_")
	for part in parts:
		if part.is_valid_int():
			return part.to_int()
	return 1

func _serialize_phase_state() -> Dictionary:
	var game_state = get_node_or_null("/root/GlobalGameState")
	var phase_manager = get_tree().get_first_node_in_group("phase_manager")
	
	return {
		"current_state": game_state.current_state if game_state else 0,
		"current_phase": phase_manager.current_phase if phase_manager else 0
	}

# === DESERIALIZATION HELPERS ===

func _deserialize_units(units_data: Array) -> void:
	var unit_manager = get_tree().get_first_node_in_group("unit_manager")
	var main_node = get_tree().get_first_node_in_group("main")
	
	if not unit_manager or not main_node:
		DebugLog.error("Cannot deserialize units - managers not found")
		return
	
	# Clear existing units
	unit_manager.clear_all_units()
	
	# Recreate units from save data
	for unit_data in units_data:
		var grid_pos = Vector2i(unit_data.grid_position.x, unit_data.grid_position.y)
		
		if unit_data.type == "duo":
			var frontliner = _deserialize_character(unit_data.frontliner)
			var backliner = _deserialize_character(unit_data.backliner)
			
			# Create duo unit
			var duo_scene = load("res://scenes/duo_unit.tscn")
			var duo = duo_scene.instantiate()
			duo.team = unit_data.team
			duo.grid_position = grid_pos
			duo.position = GridManager.grid_to_world_3d(grid_pos)
			duo.has_moved = unit_data.has_moved
			duo.has_acted = unit_data.has_acted
			duo.current_health = unit_data.current_health
			
			main_node.units_container.add_child(duo)
			duo.setup_duo(frontliner, backliner, unit_data.frontliner.weapon != null)
			duo.bond_level = unit_data.get("bond_level", 1)
			duo.setup_visual(3.0, unit_data.team == 0)
			unit_manager.register_unit(duo)
			
		else:
			var character = _deserialize_character(unit_data.character)
			
			# Create solo unit
			var solo_scene = load("res://scenes/solo_unit.tscn")
			var solo = solo_scene.instantiate()
			solo.team = unit_data.team
			solo.grid_position = grid_pos
			solo.position = GridManager.grid_to_world_3d(grid_pos)
			solo.has_moved = unit_data.has_moved
			solo.has_acted = unit_data.has_acted
			solo.current_health = unit_data.current_health
			
			main_node.units_container.add_child(solo)
			solo.setup_solo(character, character.weapon != null)
			solo.setup_visual(2.0, unit_data.team == 0)
			unit_manager.register_unit(solo)

func _deserialize_character(char_data: Dictionary):
	if char_data.is_empty():
		return null
	
	# Manually reconstruct CharacterData since ExampleContent is for testing
	var character = CharacterData.new()
	character.character_name = char_data.char_name
	
	# Restore class (simplified)
	var unit_class_name = char_data.get("unit_class_name", "Warrior")
	var unit_class = CharacterClass.new()
	unit_class.display_name = unit_class_name
	# Try to match archetype from name
	if "Mage" in unit_class_name:
		unit_class.archetype = CharacterClass.ClassArchetype.MAGE
	elif "Commander" in unit_class_name:
		unit_class.archetype = CharacterClass.ClassArchetype.COMMANDER
	else:
		unit_class.archetype = CharacterClass.ClassArchetype.WARRIOR
		
	character.primary_class = unit_class
	character.using_primary = true
	
	character.level = char_data.get("level", 1)
	character.experience = char_data.get("experience", 0)
	
	# Restore stats
	if char_data.has("stats"):
		var stats = char_data.stats
		character.max_hp = stats.get("hp", 20) # CharacterData uses max_hp/current_hp
		character.current_hp = character.max_hp # Fully heal on load for now, or save current_hp
		character.strength = stats.get("strength", 5)
		character.mag = stats.get("mag", 0)
		character.skill = stats.get("skill", 5)
		character.spd = stats.get("spd", 5)
		character.luck = stats.get("luck", 0)
		character.def = stats.get("def", 3)
		character.res = stats.get("res", 0)
	
	# Restore weapon using factory
	if char_data.has("weapon_name") and char_data.weapon_name != "":
		character.weapon = WeaponFactory.create_weapon_from_name(char_data.weapon_name)
	
	return character

func _deserialize_map_state(map_data: Dictionary) -> void:
	var phase_manager = get_tree().get_first_node_in_group("phase_manager")
	var world_map = get_tree().get_first_node_in_group("world_map")
	
	if phase_manager and map_data.has("turn_number"):
		phase_manager.turn_number = map_data.turn_number
	
	# Restore active spawns
	if map_data.has("active_spawns") and world_map:
		var active_spawns = map_data.active_spawns
		if world_map.has_method("get_node_by_id"):
			for node_id in active_spawns:
				var node = world_map.get_node_by_id(node_id)
				if node:
					var spawns = active_spawns[node_id]
					if spawns.has("hostile"):
						node.spawned_hostile = SpawnData.from_dictionary(spawns.hostile)
					if spawns.has("merchant"):
						node.spawned_merchant = SpawnData.from_dictionary(spawns.merchant)

func _deserialize_inventory(inventory_data: Dictionary) -> void:
	# Restore gold
	if inventory_data.has("gold"):
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager and "gold" in game_manager:
			game_manager.gold = inventory_data.gold
	
	# Restore convoy
	if inventory_data.has("convoy"):
		var inventory_manager = _get_inventory_manager()
		if inventory_manager and inventory_manager.has_method("deserialize"):
			inventory_manager.deserialize(inventory_data.convoy)

func _deserialize_progression(progression_data: Dictionary) -> void:
	var world_map = get_tree().get_first_node_in_group("world_map")
	
	# Restore world map progression
	if world_map:
		if progression_data.has("completed_chapters"):
			world_map.visited_nodes = progression_data.completed_chapters.duplicate()
		
		# Restore current chapter/node
		if progression_data.has("current_chapter"):
			var chapter_num = progression_data.current_chapter
			# World map will handle restoring current node from its own save
	
	# Restore support levels
	if progression_data.has("support_levels"):
		var support_data = progression_data.support_levels
		var unit_manager = get_tree().get_first_node_in_group("unit_manager")
		
		if unit_manager:
			for unit in unit_manager.get_all_units():
				if unit.character:
					var char_id = unit.character.character_id if "character_id" in unit.character else unit.character.char_name
					if char_id in support_data:
						# PHASE 4 FIX: Deserialize bond data properly
						unit.character.bond_data.clear()
						var saved_bonds = support_data[char_id]
						if typeof(saved_bonds) == TYPE_ARRAY:
							for b_data in saved_bonds:
								var bond = BondData.new()
								bond.partner_id = b_data.get("partner_id", "")
								bond.rank = b_data.get("rank", 0)
								bond.points = b_data.get("points", 0)
								bond.unlocked_conversations.assign(b_data.get("conversations", []))
								unit.character.bond_data.append(bond)
						elif typeof(saved_bonds) == TYPE_DICTIONARY:
							# Legacy support
							for pid in saved_bonds:
								var d = saved_bonds[pid]
								var bond = BondData.new()
								bond.partner_id = pid
								bond.rank = d.get("rank", 0)
								bond.points = d.get("points", 0)
								bond.unlocked_conversations.assign(d.get("conversations", []))
								unit.character.bond_data.append(bond)

func _deserialize_phase_state(phase_data: Dictionary) -> void:
	var game_state = get_node_or_null("/root/GlobalGameState")
	var phase_manager = get_tree().get_first_node_in_group("phase_manager")
	
	if game_state and phase_data.has("current_state"):
		game_state.current_state = phase_data.current_state
	
	if phase_manager and phase_data.has("current_phase"):
		phase_manager.current_phase = phase_data.current_phase

# --- Safe Manager Access Helpers ---

func _get_unit_manager() -> Node:
	return get_tree().get_first_node_in_group("unit_manager")

func _get_phase_manager() -> Node:
	return get_tree().get_first_node_in_group("phase_manager")

func _get_world_map() -> Node:
	return get_tree().get_first_node_in_group("world_map")

func _get_inventory_manager() -> Node:
	return get_tree().get_first_node_in_group("inventory_manager")

func _get_bond_system() -> Node:
	var sys = get_tree().get_first_node_in_group("bond_system")
	if not sys:
		sys = get_node_or_null("/root/BondSystem")
	return sys
