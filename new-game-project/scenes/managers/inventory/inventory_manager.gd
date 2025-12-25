class_name InventoryManager
extends Node

## Manager for handling global army inventory (Convoy)
##
## Stores items not held by specific units. Supports adding, removing, and transferring items.
## Integrates with SaveManager for persistence.

# --- State ---
var convoy_inventory: Array[Resource] = []

# --- Signals ---
signal convoy_updated(items: Array[Resource])

func _ready() -> void:
	add_to_group("inventory_manager")

# --- Public API ---

## Add an item to the convoy
func add_to_convoy(item: Resource) -> void:
	if not item: return
	convoy_inventory.append(item)
	convoy_updated.emit(convoy_inventory)
	# print("InventoryManager: Added %s to convoy. Total: %d" % [item.get("item_name") if "item_name" in item else "Item", convoy_inventory.size()])

## Remove an item from the convoy by reference
func remove_from_convoy(item: Resource) -> void:
	if item in convoy_inventory:
		convoy_inventory.erase(item)
		convoy_updated.emit(convoy_inventory)

## Remove an item from the convoy by index
func remove_from_convoy_at(index: int) -> Resource:
	if index >= 0 and index < convoy_inventory.size():
		var item = convoy_inventory.pop_at(index)
		convoy_updated.emit(convoy_inventory)
		return item
	return null

## Transfer item from Unit inventory to Convoy
func transfer_unit_to_convoy(unit: Unit, item_index: int) -> bool:
	if not unit or not unit.inventory: return false
	
	if item_index < 0 or item_index >= unit.inventory.items.size():
		return false
		
	var item = unit.inventory.items[item_index]
	
	# Unequip if currently equipped
	if unit.inventory.equipped_item == item:
		unit.inventory.unequip_item()
		
	unit.inventory.remove_item(item)
	add_to_convoy(item)
	return true

## Transfer item from Convoy to Unit inventory
func transfer_convoy_to_unit(convoy_index: int, unit: Unit) -> bool:
	if not unit or not unit.inventory: return false
	
	# Check capacity (Standard specific FE limit is usually 5 or 6, let's assume 5 for now from typical GBA FE, or check Inventory class)
	# Inventory class logic doesn't seemingly enforce limit yet, but let's assume 5 for safety or "Unlimited" if not specified.
	# Let's check if the Unit's Inventory has a max Items.
	# Looking at previous context, Inventory.gd didn't specify a limit, but typically it is 5.
	if unit.inventory.items.size() >= 5:
		print("InventoryManager: Unit inventory full!")
		return false
		
	var item = remove_from_convoy_at(convoy_index)
	if item:
		unit.inventory.add_item(item)
		return true
	return false

## Get all items in convoy
func get_convoy_items() -> Array[Resource]:
	return convoy_inventory

# --- Save/Load ---

## Serialize convoy data for SaveManager
func serialize() -> Array:
	var item_data_list = []
	for item in convoy_inventory:
		var data = {}
		if item is Weapon:
			data = {
				"type": "weapon",
				"id": item.weapon_id if "weapon_id" in item else "", # Assuming generic weapons rely on ID/Name
				"name": item.weapon_name, # Most reliable for factory
				"durability": item.current_durability if "current_durability" in item else 40
			}
		elif item is Consumable:
			data = {
				"type": "consumable",
				"name": item.item_name,
				"uses": item.uses
			}
		
		item_data_list.append(data)
	return item_data_list

## Deserialize convoy data from SaveManager
func deserialize(data: Array) -> void:
	convoy_inventory.clear()
	for item_data in data:
		if item_data.get("type") == "weapon":
			var weapon = WeaponFactory.create_weapon_from_name(item_data.get("name", ""))
			if weapon:
				# Restore durability if possible (WeaponResource might not have mutable durability in resource, usually distinct instance)
				# Assuming Weapon resource is instanced per item:
				if "current_durability" in weapon:
					weapon.current_durability = item_data.get("durability", 40)
				convoy_inventory.append(weapon)
		elif item_data.get("type") == "consumable":
			var consumable = ItemFactory.create_item_from_name(item_data.get("name", ""))
			if consumable:
				consumable.uses = item_data.get("uses", 3)
				convoy_inventory.append(consumable)
