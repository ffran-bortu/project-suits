extends SceneTree

func _init():
	print("--- Starting Convoy Logic Test ---")
	
	# 1. Setup Managers/Units
	var inv_mgr = InventoryManager.new()
	var unit = Unit.new()
	unit.inventory = Inventory.new()
	
	# 2. Add Item to Unit
	var sword = Weapon.new()
	sword.weapon_name = "Iron Sword"
	unit.inventory.add_item(sword)
	print("Unit has: %s" % unit.inventory.items[0].weapon_name)
	
	# 3. Transfer Unit -> Convoy
	print("Transferring Unit -> Convoy...")
	if inv_mgr.transfer_unit_to_convoy(unit, 0):
		print("SUCCESS: Transfer returned true")
	else:
		print("FAIL: Transfer returned false")
		
	# Verify
	if unit.inventory.items.is_empty():
		print("PASS: Unit inventory empty")
	else:
		print("FAIL: Unit inventory not empty")
		
	if inv_mgr.convoy_inventory.size() == 1:
		print("PASS: Convoy has 1 item")
		print("Convoy Item: %s" % inv_mgr.convoy_inventory[0].weapon_name)
	else:
		print("FAIL: Convoy size incorrect")
		
	# 4. Transfer Convoy -> Unit
	print("Transferring Convoy -> Unit...")
	if inv_mgr.transfer_convoy_to_unit(0, unit):
		print("SUCCESS: Transfer returned true")
	else:
		print("FAIL: Transfer returned false")
		
	# Verify
	if unit.inventory.items.size() == 1:
		print("PASS: Unit has 1 item")
	else:
		print("FAIL: Unit inventory incorrect")
		
	if inv_mgr.convoy_inventory.is_empty():
		print("PASS: Convoy empty")
	else:
		print("FAIL: Convoy not empty")
	
	quit()
