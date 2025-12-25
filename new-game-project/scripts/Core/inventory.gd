"""
FILE: inventory.gd
PURPOSE: Manages weapon inventory for individual units (max 8 items, no durability system).

OVERVIEW:
This simple inventory class holds a unit's weapons and tracks which one is currently equipped.  
It enforces a MAX_ITEMS limit (8 weapons), automatically equips the first weapon added, and
handles equip/unequip logic. This is attached to each Unit node to give them their own inventory.
No item durability system is implemented.

FUNCTIONS IN THIS FILE:

1. add_weapon(weapon)
   - What it does: Adds a weapon to the inventory if there's space
   - Uses: When unit picks up weapon, starts with weapon, or receives from convoy
   - Returns: bool (true if added successfully, false if inventory full)

2. equip_weapon(weapon)
   - What it does: Sets a weapon as the active/equipped weapon
   - Uses: When player manually changes equipped weapon via UI
   - Returns: void

3. remove_weapon(weapon)
   - What it does: Removes a weapon from inventory, auto-equips next weapon if removed weapon was equipped
   - Uses: When weapon breaks (if durability added), sold, or moved to convoy
   - Returns: void

NOTES:
- Attached to Unit nodes as a component
- No dependencies (uses Weapon resource)
- MAX_ITEMS constant set to 8
- Auto-equips first weapon added to empty inventory
- If equipped weapon removed, automatically equips weapons[0] if available
"""

class_name Inventory
extends Node
## Inventory system for units
##
## Manages weapons and items, no durability

const MAX_ITEMS: int = 8

# "items" can hold both Weapon and Consumable resources
var items: Array[Resource] = []
var equipped_item: Resource = null # Currently equipped item (usually a Weapon)

## Add item (Weapon or Consumable) to inventory
func add_item(item: Resource) -> bool:
	if items.size() >= MAX_ITEMS:
		return false
	
	items.append(item)
	
	# Auto-equip logic:
	# If no item equipped and this is a Weapon, equip it
	if not equipped_item and item is Weapon:
		equip_item(item)
	return true

## Remove item
func remove_item(item: Resource) -> void:
	items.erase(item)
	
	# If we removed the equipped item, try to equip another weapon
	if equipped_item == item:
		equipped_item = null
		_equip_first_available_weapon()

## Equip a specific item (must be in inventory)
func equip_item(item: Resource) -> void:
	if item in items:
		equipped_item = item

## Helper: Find and equip the first available weapon
func _equip_first_available_weapon() -> void:
	for item in items:
		if item is Weapon:
			equipped_item = item
			return

# --- Typed Helpers (Compatibility & Convenience) ---

## [Compatibility] Get all weapons
func get_weapons() -> Array:
	var weapons: Array[Weapon] = []
	for item in items:
		if item is Weapon:
			weapons.append(item)
	return weapons

## Get all consumables
func get_consumables() -> Array:
	var consumables: Array[Consumable] = []
	for item in items:
		if item is Consumable:
			consumables.append(item)
	return consumables

## [Compatibility] Add weapon
func add_weapon(weapon: Weapon) -> bool:
	return add_item(weapon)

## [Compatibility] Remove weapon
func remove_weapon(weapon: Weapon) -> void:
	remove_item(weapon)

## [Compatibility] Get equipped weapon (or null if currently equipped is not a weapon)
func get_equipped_weapon() -> Weapon:
	return equipped_item as Weapon if equipped_item is Weapon else null

# Legacy property access via getters/setters could be added if needed,
# but direct 'inventory.weapons' access would need refactoring globally.
# Given code search showed essentially zero usage of direct property access, this is safe.
