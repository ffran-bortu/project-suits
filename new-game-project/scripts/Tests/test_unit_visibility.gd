extends Node3D

func _ready() -> void:
	print("=== STARTING UNIT VISIBILITY DIAGNOSIS ===")
	
	# 1. Setup Camera and Light so user can SEE if it works
	var camera = Camera3D.new()
	camera.position = Vector3(0, 5, 5)
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(light)
	
	await get_tree().process_frame
	
	# 2. Test Raw Unit Scene (No Factory)
	print("\n--- TEST 1: Manual Unit Spawn ---")
	var unit_scene = load("res://scenes/unit.tscn")
	if not unit_scene:
		print("ERROR: Could not load res://scenes/unit.tscn")
		return

	var unit = unit_scene.instantiate()
	unit.unit_name = "TestUnit_Manual"
	add_child(unit)
	unit.position = Vector3(-2, 0, 0) # Place on left
	
	# Wait for _ready
	await get_tree().process_frame
	
	_diagnose_unit(unit)
	
	# 3. Test Factory Spawn
	print("\n--- TEST 2: Factory Spawn ---")
	# We need a dummy container and manager mostly to satisfy the factory signature
	var container = Node3D.new()
	name = "UnitsContainer"
	add_child(container)
	
	# Mock UnitManager if needed or pass null if factory handles it (Factory checks for it)
	var unit_manager = Node.new() 
	unit_manager.name = "UnitManager" # Factory looks for methods, we might need a dummy script or just pass this node
	# Add dummy methods to unit_manager to prevent errors
	var script = GDScript.new()
	script.source_code = "extends Node\nfunc add_unit(u): pass\nfunc register_unit(u): pass"
	script.reload()
	unit_manager.set_script(script)
	add_child(unit_manager)
	
	# Use Factory
	var factory_unit = UnitFactory.create_unit(
		null, "TestUnit_Factory", 0, Vector2i(2, 0), container, unit_manager
	)
	
	if factory_unit:
		# Wait for _ready
		await get_tree().process_frame
		_diagnose_unit(factory_unit)
	else:
		print("ERROR: Factory returned null unit")

func _diagnose_unit(unit: Node) -> void:
	print("Diagnosing Unit: ", unit.name)
	print("  Global Position: ", unit.global_position)
	print("  Scale: ", unit.scale)
	print("  Visible: ", unit.visible)
	
	var sprite = unit.get_node_or_null("Sprite3D")
	if sprite:
		print("  Sprite3D: FOUND")
		print("    Visible: ", sprite.visible)
		print("    Texture: ", sprite.texture.resource_path if sprite.texture else "NULL")
		print("    Modulate: ", sprite.modulate)
		print("    Opacity: ", sprite.opacity if "opacity" in sprite else "N/A (use transparency)")
		print("    Pixel Size: ", sprite.pixel_size)
		print("    Billboard: ", sprite.billboard)
		print("    Global Pos: ", sprite.global_position)
	else:
		print("  Sprite3D: NOT FOUND!")
		
	var visual_comp = unit.get_node_or_null("VisualComponent")
	if visual_comp:
		print("  VisualComponent: FOUND")
	else:
		print("  VisualComponent: NOT FOUND")
