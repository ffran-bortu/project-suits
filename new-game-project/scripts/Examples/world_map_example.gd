"""
FILE: world_map_example.gd
PURPOSE: Campaign creation examples for Fire Emblem-style world maps with MapData and WorldMapNode.
FUNCTIONS: _ready, example_create_linear_campaign, example_create_branching_campaign, example_node_validation, example_save_load - 5 total
NOTES: Demonstrates linear campaign (5 chapters), branching campaign (Eirika/Ephraim routes Sacred Stones-style with side quests), node validation/repair, save/load serialization. Shows node connections, required_nodes, position placement, rewards.
"""


extends Node

## Example showing how to create a complete Fire Emblem-style campaign

func _ready() -> void:
	print("=== World Map System Examples ===\n")
	
	example_create_linear_campaign()
	print("\n" + "=".repeat(50) + "\n")
	
	example_create_branching_campaign()
	print("\n" + "=".repeat(50) + "\n")
	
	example_node_validation()


## Example 1: Linear Campaign
func example_create_linear_campaign() -> void:
	print("EXAMPLE 1: Linear Campaign (Fire Emblem 7 style)")
	print("-" * 30)
	
	var map := MapData.new()
	map.map_id = "lyn_mode"
	map.map_name = "Lyn's Tale"
	map.map_description = "Follow Lyn's journey to reclaim her homeland"
	
	# Create chapters
	var chapters: Array[WorldMapNode] = []
	
	for i in range(1, 6):
		var chapter := WorldMapNode.create_battle_node(
			"Chapter %d" % i,
			"res://maps/chapter%d.tscn" % i,
			i
		)
		chapter.node_id = "chapter_%d" % i
		chapter.position = Vector2(400, 100 * i)
		chapter.gold_reward = 500 * i
		chapter.exp_reward = 50 * i
		chapter.enemy_count = 8 + (i * 2)
		chapter.recommended_level = i
		
		# Connect to previous chapter
		if i > 1:
			chapters[i - 2].next_nodes = [chapter.node_id]
			chapter.required_nodes = [chapters[i - 2].node_id]
		
		chapters.append(chapter)
		map.add_node(chapter)
	
	map.starting_node_id = "chapter_1"
	
	print("Created %d chapters" % chapters.size())
	print("Starting chapter: %s" % map.starting_node_id)
	
	# Validate
	var errors := map.validate_map_data()
	if errors.is_empty():
		print("✓ Campaign valid!")
	else:
		print("✗ Errors found:")
		for error in errors:
			print("  - %s" % error)


## Example 2: Branching Campaign
func example_create_branching_campaign() -> void:
	print("EXAMPLE 2: Branching Campaign (Sacred Stones style)")
	print("-" * 30)
	
	var map := MapData.new()
	map.map_id = "sacred_stones"
	map.map_name = "The Sacred Stones"
	
	# Prologue + Early chapters
	var prologue := WorldMapNode.create_battle_node(
		"Prologue: The Fall of Renais",
		"res://maps/prologue.tscn",
		1
	)
	prologue.node_id = "prologue"
	prologue.position = Vector2(400, 100)
	
	var ch1 := WorldMapNode.create_battle_node(
		"Chapter 1: Escape!",
		"res://maps/chapter1.tscn",
		2
	)
	ch1.node_id = "chapter_1"
	ch1.position = Vector2(400, 200)
	ch1.required_nodes = ["prologue"]
	
	prologue.next_nodes = ["chapter_1"]
	
	# BRANCHING PATHS - Eirika vs Ephraim
	var eirika_path: Array[WorldMapNode] = []
	var ephraim_path: Array[WorldMapNode] = []
	
	# Eirika's route (left side)
	for i in range(2, 10):
		var chapter := WorldMapNode.create_battle_node(
			"Chapter %dA: Eirika's Journey" % i,
			"res://maps/eirika_chapter%d.tscn" % i,
			i + 1
		)
		chapter.node_id = "eirika_%d" % i
		chapter.position = Vector2(250, 200 + (i * 50))
		chapter.description = "Follow Eirika's route"
		
		if i == 2:
			chapter.required_nodes = ["chapter_1"]
		else:
			chapter.required_nodes = [eirika_path.back().node_id]
			eirika_path.back().next_nodes = [chapter.node_id]
		
		eirika_path.append(chapter)
		map.add_node(chapter)
	
	# Ephraim's route (right side)
	for i in range(2, 10):
		var chapter := WorldMapNode.create_battle_node(
			"Chapter %dB: Ephraim's Journey" % i,
			"res://maps/ephraim_chapter%d.tscn" % i,
			i + 1
		)
		chapter.node_id = "ephraim_%d" % i
		chapter.position = Vector2(550, 200 + (i * 50))
		chapter.description = "Follow Ephraim's route"
		
		if i == 2:
			chapter.required_nodes = ["chapter_1"]
		else:
			chapter.required_nodes = [ephraim_path.back().node_id]
			ephraim_path.back().next_nodes = [chapter.node_id]
		
		ephraim_path.append(chapter)
		map.add_node(chapter)
	
	# Chapter 1 branches to both paths
	ch1.next_nodes = ["eirika_2", "ephraim_2"]
	
	# Paths converge at final chapter
	var final_chapter := WorldMapNode.create_battle_node(
		"Final Chapter: Sacred Stone",
		"res://maps/final.tscn",
		15
	)
	final_chapter.node_id = "final"
	final_chapter.position = Vector2(400, 700)
	final_chapter.description = "The final battle"
	final_chapter.required_nodes = [
		eirika_path.back().node_id,
		ephraim_path.back().node_id
	]
	final_chapter.enemy_count = 30
	final_chapter.gold_reward = 10000
	
	eirika_path.back().next_nodes = ["final"]
	ephraim_path.back().next_nodes = ["final"]
	
	map.add_node(prologue)
	map.add_node(ch1)
	map.add_node(final_chapter)
	
	# Add optional side quests
	var side_quest := WorldMapNode.new()
	side_quest.node_id = "tower_of_valni"
	side_quest.node_name = "Tower of Valni"
	side_quest.node_type = WorldMapNode.NodeType.OPTIONAL
	side_quest.position = Vector2(400, 400)
	side_quest.is_optional = true
	side_quest.required_nodes = ["eirika_5"]
	side_quest.item_rewards = ["brave_sword", "silver_lance"]
	
	eirika_path[3].next_nodes.append("tower_of_valni")
	map.add_node(side_quest)
	
	map.starting_node_id = "prologue"
	
	print("Created campaign with:")
	print("  - 1 Prologue")
	print("  - 1 Intro chapter")
	print("  - %d Eirika chapters" % eirika_path.size())
	print("  - %d Ephraim chapters" % ephraim_path.size())
	print("  - 1 Side quest")
	print("  - 1 Final chapter")
	print("  Total: %d nodes" % map.nodes.size())
	
	var errors := map.validate_map_data()
	if errors.is_empty():
		print("✓ Campaign valid!")
	else:
		print("✗ Errors found:")
		for error in errors:
			print("  - %s" % error)


## Example 3: Validation
func example_node_validation() -> void:
	print("EXAMPLE 3: Node Validation")
	print("-" * 30)
	
	# Create valid node
	print("\n1. Valid Node:")
	var valid_node := WorldMapNode.create_battle_node(
		"Prologue",
		"res://maps/prologue.tscn",
		1
	)
	valid_node.node_id = "prologue"
	valid_node.position = Vector2(100, 100)
	
	var errors := valid_node.validate_node()
	if errors.is_empty():
		print("  ✓ Node is valid")
	
	# Create invalid node
	print("\n2. Invalid Node (missing required data):")
	var invalid_node := WorldMapNode.new()
	invalid_node.node_type = WorldMapNode.NodeType.BATTLE
	# Missing: node_id, node_name, map_scene_path
	
	errors = invalid_node.validate_node()
	print("  Found %d errors:" % errors.size())
	for error in errors:
		print("    ! %s" % error)
	
	# Auto-repair
	print("\n3. Auto-Repair:")
	print("  Before repair:")
	print("    Node ID: '%s'" % invalid_node.node_id)
	print("    Node Name: '%s'" % invalid_node.node_name)
	
	if invalid_node.repair_node():
		print("  After repair:")
		print("    Node ID: '%s'" % invalid_node.node_id)
	
	# Map validation
	print("\n4. Map Validation:")
	var map := MapData.new()
	map.map_id = "test_map"
	map.map_name = "Test Campaign"
	
	# Add valid node
	map.add_node(valid_node)
	
	# Add node with broken connection
	var broken_node := WorldMapNode.create_battle_node(
		"Chapter 1",
		"res://maps/ch1.tscn",
		2
	)
	broken_node.node_id = "chapter_1"
	broken_node.next_nodes = ["non_existent_node"]  # BROKEN!
	map.add_node(broken_node)
	
	map.starting_node_id = "prologue"
	
	errors = map.validate_map_data()
	print("  Found %d errors:" % errors.size())
	for error in errors:
		print("    ! %s" % error)


## Bonus: Save/Load Example
func example_save_load() -> void:
	print("BONUS: Save/Load Example")
	print("-" * 30)
	
	# Create simple campaign
	var map := MapData.new()
	map.map_id = "test"
	map.map_name = "Test"
	
	var node1 := WorldMapNode.create_battle_node("Ch1", "res://maps/ch1.tscn", 1)
	node1.node_id = "ch1"
	node1.is_unlocked = true
	
	var node2 := WorldMapNode.create_battle_node("Ch2", "res://maps/ch2.tscn", 2)
	node2.node_id = "ch2"
	
	node1.next_nodes = ["ch2"]
	
	map.add_node(node1)
	map.add_node(node2)
	map.starting_node_id = "ch1"
	
	print("Original state:")
	print("  Ch1 unlocked: %s" % node1.is_unlocked)
	print("  Ch1 completed: %s" % node1.is_completed)
	print("  Ch2 unlocked: %s" % node2.is_unlocked)
	
	# "Complete" chapter 1
	node1.complete(15)  # Completed in 15 turns
	node2.unlock()
	
	print("\nAfter completing Ch1:")
	print("  Ch1 completed: %s" % node1.is_completed)
	print("  Ch1 best time: %d turns" % node1.best_clear_turns)
	print("  Ch2 unlocked: %s" % node2.is_unlocked)
	
	# Serialize
	var save_data := {
		"ch1": node1.serialize(),
		"ch2": node2.serialize()
	}
	
	print("\nSerialized data:")
	print("  %s" % save_data)
	
	# Create new nodes and deserialize
	var loaded_node1 := WorldMapNode.new()
	var loaded_node2 := WorldMapNode.new()
	
	loaded_node1.deserialize(save_data["ch1"])
	loaded_node2.deserialize(save_data["ch2"])
	
	print("\nLoaded state:")
	print("  Ch1 completed: %s" % loaded_node1.is_completed)
	print("  Ch1 best time: %d turns" % loaded_node1.best_clear_turns)
	print("  Ch2 unlocked: %s" % loaded_node2.is_unlocked)
	print("\n✓ Save/Load successful!")
