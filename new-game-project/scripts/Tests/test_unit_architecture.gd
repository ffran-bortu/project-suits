extends Node

# test_unit_architecture.gd
# Self-contained test to verify Phase 4 Architecture changes

func _ready() -> void:
	print("\n=== STARTING UNIT ARCHITECTURE VERIFICATION ===\n")
	
	test_base_unit_components()
	test_solo_unit_inheritance()
	
	print("\n=== VERIFICATION COMPLETE: ALL CHECKS PASSED ===\n")
	get_tree().quit()

func test_base_unit_components() -> void:
	print("TEST 1: Base Unit Component Initialization")
	
	# Instantiate Unit
	var unit = Unit.new()
	# Manually trigger ready for components (since we aren't adding to tree in this simple test, or we simulate it)
	# Ideally we add to tree to get _ready calls, but unit.gd does component setup in _init too for some parts?
	# No, components are created in _init, but setup() is in _ready.
	# We must add to tree.
	add_child(unit)
	
	# 1. Verify Components Exist
	assert(unit.health_component != null, "HealthComponent missing!")
	assert(unit.movement_component != null, "MovementComponent missing!")
	assert(unit.visual_component != null, "VisualComponent missing!")
	print("  [OK] Components instantiated.")
	
	# 2. Verify Proxy Access (Getter)
	unit.max_health = 50
	assert(unit.health_component.max_health == 50, "Proxy max_health -> Component failed")
	print("  [OK] Proxy Setter works.")
	
	# 3. Verify Proxy Access (Setter)
	unit.health_component.current_health = 25
	assert(unit.current_health == 25, "Component -> Proxy current_health failed")
	print("  [OK] Proxy Getter works.")
	
	# 4. Verify Facade Method (take_damage)
	# Initial: 25
	unit.take_damage(5)
	assert(unit.current_health == 20, "take_damage() facade failed")
	assert(unit.health_component.current_health == 20, "Component logic failed")
	print("  [OK] Facade Method (take_damage) works.")
	
	# Cleanup
	unit.queue_free()

func test_solo_unit_inheritance() -> void:
	print("\nTEST 2: SoloUnit Inheritance (Backward Compatibility)")
	
	var solo = SoloUnit.new()
	add_child(solo)
	
	# Verify it still has Unit components
	assert(solo.health_component != null, "SoloUnit inheritance broke components!")
	
	# Mock Character Data for Solo Setup
	var char_data = CharacterData.new()
	char_data.max_hp = 100
	char_data.strength = 10
	# ... populate other needed fields or mock them if strict typing allows
	
	# Setup Solo
	# We can't easily strictly test setup_solo without a full defined CharacterData resource
	# But we can test the properties it writes to.
	
	solo.max_health = 100 # Direct write to proxy
	solo.strength = 15    # Direct write to property
	
	assert(solo.health_component.max_health == 100, "SoloUnit writing to max_health proxy failed")
	assert(solo.strength == 15, "SoloUnit normal property write failed")
	
	print("  [OK] SoloUnit inherited proxies work.")
	solo.queue_free()
