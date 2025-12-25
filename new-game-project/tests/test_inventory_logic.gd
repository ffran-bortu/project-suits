extends SceneTree

func _init():
	print("--- Starting Inventory Logic Test ---")
	
	# 1. Setup Unit and Inventory
	var unit = Unit.new()
	unit.inventory = Inventory.new() # In real game this happens in _init
	
	unit.max_health = 20
	unit.current_health = 5
	print("Unit created. HP: %d/%d" % [unit.current_health, unit.max_health])
	
	# 2. Create Item (Vulnerary)
	var vulnerary = Consumable.new()
	vulnerary.item_name = "Test Vuln"
	vulnerary.effect_type = Consumable.EffectType.HEAL
	vulnerary.power = 10
	vulnerary.uses = 1
	
	unit.inventory.add_item(vulnerary)
	print("Added Item: %s (Uses: %d)" % [vulnerary.item_name, vulnerary.uses])
	
	# 3. Use Item
	print("Attempting to use item...")
	if unit.use_item(vulnerary):
		print("SUCCESS: Item used.")
	else:
		print("FAILURE: efficient use failed.")
		
	# 4. Verify HP
	print("Current HP: %d/%d (Expected: 15)" % [unit.current_health, unit.max_health])
	if unit.current_health == 15:
		print("PASS: HP healed correctly.")
	else:
		print("FAIL: HP healed incorrectly.")
		
	# 5. Verify Item Removed (uses = 0)
	if not unit.inventory.items.has(vulnerary):
		print("PASS: Item removed from inventory.")
	else:
		print("FAIL: Item still in inventory.")
		
	quit()
