"""
FILE: bond_trigger_helper.gd
PURPOSE: Provides static helper methods to trigger bond point gains from gameplay events.

OVERVIEW:
This static helper class centralizes bond point triggering logic, making it easy for game systems to
award bond points when specific events occur (healing, duo actions, coordinated attacks). All methods
are static and handle getting BondSystem reference, extracting character data, and calling appropriate
bond system methods.

FUNCTIONS IN THIS FILE:

1. trigger_heal_bond(healer: Node, target: Node) -> void
   - What it does: Awards bond points when one unit heals another
   - Uses: Called by healing ability/item logic
   - Returns: void

2. trigger_duo_action_bond(duo_unit: Node) -> void
   - What it does: Awards bond points when duo unit performs any action
   - Uses: Called after duo unit completes actions
   - Returns: void

3. trigger_combat_range_overlap_bond(attacker: Node, target_pos: Vector2i) -> void
   - What it does: Awards bond points when attacker targets enemy within ally's attack range (coordinated attack)
   - Uses: Called during attack targeting to reward tactical positioning
   - Returns: void

4. _get_bond_system() -> Node
   - What it does: Locates and returns BondSystem reference from scene tree
   - Uses: Helper called by trigger methods
   - Returns: Node - BondSystem or null

5. _get_unit_manager() -> Node
   - What it does: Locates and returns UnitManager reference from scene tree
   - Uses: Helper for finding nearby allies
   - Returns: Node - UnitManager or null

6. _is_position_in_unit_range(unit_pos: Vector2i, target_pos: Vector2i) -> bool
   - What it does: Simple range check using Manhattan distance (within 2 tiles)
   - Uses: Helper for range overlap detection
   - Returns: bool - true if within range

NOTES:
- Static class (all methods static, use BondTriggerHelper.trigger_heal_bond() directly)
- Extracts character_data from units via "character_data" property
- Validates all inputs (returns early if null)
- Uses Engine.get_main_loop().root to access scene tree
- Range overlap checks all player units on same team as attacker
- Validates ally is alive before checking range
- Ensures attacker and ally are different units
- Depends on: BondSystem (/root/Main/GameManager/BondSystem)
- Depends on: UnitManager (/root/Main/GameManager/UnitManager)
"""

extends Node
class_name BondTriggerHelper
## Helper for triggering bond points from various game events
##
## Provides static methods to award bond points when events occur

static func trigger_heal_bond(healer: Node, target: Node) -> void:
	"""Trigger bond points when one unit heals another"""
	if not healer or not target:
		return
	
	# Get BondSystem
	var bond_system = _get_bond_system()
	if not bond_system:
		return
	
	# Get character data
	var healer_data: CharacterData = healer.character_data if "character_data" in healer else null
	var target_data: CharacterData = target.character_data if "character_data" in target else null
	
	if healer_data and target_data and healer_data != target_data:
		bond_system.on_unit_healed(healer_data, target_data)

static func trigger_duo_action_bond(duo_unit: Node) -> void:
	"""Trigger bond points when duo unit performs any action"""
	if not duo_unit:
		return
	
	var bond_system = _get_bond_system()
	if not bond_system:
		return
	
	bond_system.on_duo_action(duo_unit)

static func trigger_combat_range_overlap_bond(attacker: Node, target_pos: Vector2i) -> void:
	"""Trigger bond points when attacking enemy in range of nearby allies"""
	if not attacker:
		return
	
	var bond_system = _get_bond_system()
	if not bond_system:
		return
	
	# Get unit manager to find nearby allies
	var unit_manager = _get_unit_manager()
	if not unit_manager:
		return
	
	# Get attacker's character data
	var attacker_data: CharacterData = attacker.character_data if "character_data" in attacker else null
	if not attacker_data:
		return
	
	# Get attacker's team
	var attacker_team = attacker.team if "team" in attacker else 0
	
	# Get all player units
	var player_units: Array = unit_manager.get_units_by_team(attacker_team)
	
	# Check each ally for range overlap
	for ally in player_units:
		if ally == attacker or not ally:
			continue
		
		if not ally.has_method("is_alive") or not ally.is_alive():
			continue
		
		# Check if target is in ally's attack range
		if _is_position_in_unit_range(ally.grid_position, target_pos):
			var ally_data: CharacterData = ally.character_data if "character_data" in ally else null
			if ally_data:
				bond_system.on_range_overlap_attack(attacker_data, ally_data)

static func _get_bond_system() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Main/GameManager/BondSystem")

static func _get_unit_manager() -> Node:
	return Engine.get_main_loop().root.get_node_or_null("/root/Main/GameManager/UnitManager")

static func _is_position_in_unit_range(unit_pos: Vector2i, target_pos: Vector2i) -> bool:
	# Simple range check - within 2 tiles (Manhattan distance)
	var distance = abs(unit_pos.x - target_pos.x) + abs(unit_pos.y - target_pos.y)
	return distance <= 2
