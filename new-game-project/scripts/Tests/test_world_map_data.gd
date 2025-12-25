"""
FILE: test_world_map_data.gd
PURPOSE: Unit tests for world map graph data structure and node state logic
PUBLIC API:
- test_graph_has_12_nodes() - Verifies campaign has correct node count
- test_all_nodes_have_required_fields() - Validates node data structure
- test_connections_are_valid() - Ensures all connections reference valid nodes
- test_initial_unlock_state() - Checks starting unlock configuration
- test_node_color_unlocked() - Validates color logic for unlocked nodes
- test_node_color_special() - Validates color logic for special nodes
- test_node_color_completed() - Validates color logic for completed nodes
- test_node_color_locked() - Validates color logic for locked nodes
"""

extends UnitTest
## Unit tests for world map controller graph structure

# --- Constants ---
const EXPECTED_NODE_COUNT: int = 12
const EXPECTED_CONNECTION_COUNT: int = 13

# --- Test State ---
var controller: Node2D

## Setup before each test
func before_each() -> void:
	var script := load("res://scripts/Main/world_map_visual_controller.gd")
	controller = script.new()
	controller._create_sample_campaign()

## Cleanup after each test
func after_each() -> void:
	if controller:
		controller.queue_free()
		controller = null

## Test: Graph has correct number of nodes
func test_graph_has_12_nodes() -> void:
	assert_eq(
		controller.map_data["nodes"].size(),
		EXPECTED_NODE_COUNT,
		"Campaign should have 12 nodes"
	)

## Test: Graph has correct number of connections
func test_graph_has_13_connections() -> void:
	assert_eq(
		controller.map_data["connections"].size(),
		EXPECTED_CONNECTION_COUNT,
		"Campaign should have 13 connections"
	)

## Test: All nodes have required fields
func test_all_nodes_have_required_fields() -> void:
	for node_id in controller.map_data["nodes"]:
		var node: Dictionary = controller.map_data["nodes"][node_id]
		
		assert_true("pos" in node, "Node '%s' missing 'pos' field" % node_id)
		assert_true("label" in node, "Node '%s' missing 'label' field" % node_id)
		assert_true("name" in node, "Node '%s' missing 'name' field" % node_id)
		assert_true("type" in node, "Node '%s' missing 'type' field" % node_id)
		assert_true("level" in node, "Node '%s' missing 'level' field" % node_id)
		assert_true("is_unlocked" in node, "Node '%s' missing 'is_unlocked' field" % node_id)
		assert_true("is_completed" in node, "Node '%s' missing 'is_completed' field" % node_id)
		assert_true("is_special" in node, "Node '%s' missing 'is_special' field" % node_id)

## Test: All connections reference valid nodes
func test_connections_are_valid() -> void:
	for connection in controller.map_data["connections"]:
		var from_id: String = connection[0]
		var to_id: String = connection[1]
		
		assert_true(
			from_id in controller.map_data["nodes"],
			"Connection references invalid 'from' node: %s" % from_id
		)
		assert_true(
			to_id in controller.map_data["nodes"],
			"Connection references invalid 'to' node: %s" % to_id
		)

## Test: Initial unlock state is correct
func test_initial_unlock_state() -> void:
	assert_true(
		controller.map_data["nodes"]["1"]["is_unlocked"],
		"Node '1' should start unlocked"
	)
	assert_false(
		controller.map_data["nodes"]["2"]["is_unlocked"],
		"Node '2' should start locked"
	)
	assert_false(
		controller.map_data["nodes"]["End"]["is_unlocked"],
		"Node 'End' should start locked"
	)

## Test: Node color for unlocked state
func test_node_color_unlocked() -> void:
	var node_data := {
		"is_special": false,
		"is_completed": false,
		"is_unlocked": true
	}
	var color: Color = controller._get_node_color(node_data)
	var expected := Color(1.0, 1.0, 1.0)  # White
	
	assert_eq(color, expected, "Unlocked node should be white")

## Test: Node color for special node
func test_node_color_special() -> void:
	var node_data := {
		"is_special": true,
		"is_completed": false,
		"is_unlocked": false
	}
	var color: Color = controller._get_node_color(node_data)
	var expected := Color(1.0, 0.3, 0.3)  # Red
	
	assert_eq(color, expected, "Special node should be red")

## Test: Node color for completed state
func test_node_color_completed() -> void:
	var node_data := {
		"is_special": false,
		"is_completed": true,
		"is_unlocked": true
	}
	var color: Color = controller._get_node_color(node_data)
	var expected := Color(0.6, 0.6, 0.6)  # Light gray
	
	assert_eq(color, expected, "Completed node should be light gray")

## Test: Node color for locked state
func test_node_color_locked() -> void:
	var node_data := {
		"is_special": false,
		"is_completed": false,
		"is_unlocked": false
	}
	var color: Color = controller._get_node_color(node_data)
	var expected := Color(0.4, 0.4, 0.4)  # Dark gray
	
	assert_eq(color, expected, "Locked node should be dark gray")

## Test: All special nodes are properly marked
func test_special_nodes_marked() -> void:
	assert_true(
		controller.map_data["nodes"]["Pro"]["is_special"],
		"'Pro' node should be marked as special"
	)
	assert_true(
		controller.map_data["nodes"]["End"]["is_special"],
		"'End' node should be marked as special"
	)
	assert_false(
		controller.map_data["nodes"]["1"]["is_special"],
		"Node '1' should not be special"
	)
