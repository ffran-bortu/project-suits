"""
FILE: world_map_node.gd
PURPOSE: World map campaign node with battles, shops, connections, rewards, and dynamic spawn support.

OVERVIEW:
This resource represents a single node on the world map campaign - can be a BATTLE, STORY, SHOP, REST, or
OPTIONAL event. Tracks unlock/completion/visited status, stores battle data (map scene, objectives, enemy count),
manages connections to other nodes (next_nodes, required_nodes), rewards (gold, exp, items), and supports
dynamic hostile/merchant spawns from DynamicSpawnSystem. Includes validation, serialization, and factory methods.

FUNCTIONS IN THIS FILE:

1. can_access()
   - What it does: Returns true if is_unlocked and not is_completed
   - Uses: World map determines if node is clickable
   - Returns: bool

2. is_available()
   - What it does: Same as can_access (duplicate method)
   - Uses: Legacy compatibility
   - Returns: bool

3. can_backtrack()
   - What it does: Returns true if is_visited and not has_active_event
   - Uses: Determines if player can return for shopping after completing
   - Returns: bool

4. has_hostile()
   - What it does: Checks if spawned_hostile Dictionary is non-empty
   - Uses: World map shows hostile icon, triggers battle on entry
   - Returns: bool

5. has_merchant()
   - What it does: Checks if spawned_merchant Dictionary is non-empty
   - Uses: World map shows merchant icon
   - Returns: bool

6. has_collision_event()
   - What it does: Returns true if both hostile AND merchant present
   - Uses: Special "merchant in danger" event trigger
   - Returns: bool

7. unlock()
   - What it does: Sets is_unlocked = true
   - Uses: Meeting prerequisites unlocks node
   - Returns: void

8. complete(turns_taken)
   - What it does: Sets is_completed, increments times_completed, updates best_clear_turns
   - Uses: Finishing battle/event
   - Returns: void

9. reset()
   - What it does: Sets is_completed = false (preserves is_unlocked)
   - Uses: Replay/reset systems
   - Returns: void

10. get_type_name()
    - What it does: Converts node_type enum to string ("Battle", "Shop", etc.)
    - Uses: UI displays node type
    - Returns: String type name

11. validate_node()
    - What it does: Checks for errors like empty IDs, invalid paths, negative rewards
    - Uses: Resource creation, save loading
    - Returns: Array of error strings

12. repair_node()
    - What it does: Fixes invalid data by generating IDs, clamping values
    - Uses: Automatic repair on load
    - Returns: true if repairs made

13. clone()
    - What it does: Creates deep copy with "_clone" suffix on node_id
    - Uses: Templates, variations
    - Returns: New WorldMapNode

14. serialize()
    - What it does: Converts runtime state to Dictionary
    - Uses: Save system persists progress
    - Returns: Dictionary

15. deserialize(data)
    - What it does: Restores runtime state from save data
    - Uses: Load system
    - Returns: true if successful

16. get_debug_summary()
    - What it does: Formatted summary with all node data
    - Uses: Debugging
    - Returns: String

17. debug_print()
    - What it does: Prints summary to console
    - Uses: Quick debugging
    - Returns: void

18. create_battle_node(name, map_path, level) [static]
    - What it does: Factory method creates BATTLE node
    - Uses: Quick battle node creation
    - Returns: New WorldMapNode

19. create_story_node(name, desc) [static]
    - What it does: Factory method creates STORY node
    - Uses: Quick story node creation
    - Returns: New WorldMapNode

NOTES:
- NodeType enum: BATTLE (0), STORY (1), SHOP (2), REST (3), OPTIONAL (4)
- is_unlocked = player can see and access node
- is_completed = player has finished main event
- is_visited = player has cleared once, enables backtracking
- is_optional = doesn't count toward completion percentage
- has_active_event = triggers scene transition on entry (battle/cutscene)
- map_scene_path required for BATTLE nodes
- battle_objectives is BattleObjectives resource
- recommended_level is 1-40 for difficulty display
- enemy_count for UI display
- next_nodes = Array[String] of node IDs accessible from here
- required_nodes = Array[String] of node IDs that must be completed first
- gold_reward, exp_reward awarded on completion
- item_rewards = Array[String] of item IDs
- shop_inventory = Array[String] of item IDs for SHOP nodes
- shop_tier affects item quality (1-5 typical)
- spawned_hostile and spawned_merchant are Dictionary from DynamicSpawnSystem
- times_completed tracks replay count
- best_clear_turns tracks fastest completion for battles
- position is Vector2 for map placement
- node_icon and node_color for visual customization
- Factory methods auto-set node_id from snake_case name
"""


class_name WorldMapNode
extends Resource

## World map node representing campaign progression points with validation and features

# --- Node Type Enum ---
enum NodeType {
	BATTLE = 0,
	STORY = 1,
	SHOP = 2,
	REST = 3,
	OPTIONAL = 4
}

const NODE_TYPE_NAMES: Dictionary = {
	NodeType.BATTLE: "Battle",
	NodeType.STORY: "Story",
	NodeType.SHOP: "Shop",
	NodeType.REST: "Rest",
	NodeType.OPTIONAL: "Optional"
}

# --- Basic Info ---
@export_group("Basic Info")
@export var node_id: String = ""
@export var node_name: String = "Chapter 1"
@export var node_type: NodeType = NodeType.BATTLE
@export_multiline var description: String = ""
@export var intro_story: DialogueSequence
@export var outro_story: DialogueSequence
@export var force_story_playback: bool = true
@export var position: Vector2 = Vector2.ZERO

# --- State ---
@export_group("State")
@export var is_unlocked: bool = false
@export var is_completed: bool = false
@export var is_visited: bool = false  ## Player has cleared main event, enables backtracking features
@export var is_optional: bool = false
@export var has_active_event: bool = false  ## Triggers scene transition (battle/cutscene) on entry

# --- Battle Data ---
@export_group("Battle Data")
@export var map_scene_path: String = ""
@export var battle_objectives: BattleObjectives
@export_range(1, 40) var recommended_level: int = 1
@export var enemy_count: int = 0

# --- Connections ---
@export_group("Connections")
@export var next_nodes: Array[String] = []      # Node IDs
@export var required_nodes: Array[String] = []  # Must complete these first

# --- Rewards ---
@export_group("Rewards")
@export var gold_reward: int = 0
@export var exp_reward: int = 0
@export var item_rewards: Array[String] = []  # Item IDs

# --- Economy (Localized Shop Inventory) ---
@export_group("Shop Data")
@export var shop_inventory: Array[String] = []  ## Item IDs available at this node's shop
@export var shop_tier: int = 1  ## Shop tier (affects item quality)

# --- Visuals ---
@export_group("Visuals")
@export var node_icon: Texture2D
@export var node_color: Color = Color.WHITE

# --- Runtime State ---
var times_completed: int = 0
var best_clear_turns: int = 0

# --- Dynamic Spawns (Managed by DynamicSpawnSystem) ---
var spawned_hostile: SpawnData = null  ## Hostile entity data if spawned here
var spawned_merchant: SpawnData = null  ## Roaming merchant data if spawned here


## Check if node can be accessed
## @return: true if accessible
func can_access() -> bool:
	return is_unlocked and not is_completed


## Check if node is available to play
## @return: true if available
func is_available() -> bool:
	return is_unlocked and not is_completed


## Check if node can be backtracked to (for shops/economy)
## @return: true if can visit for shopping
func can_backtrack() -> bool:
	return is_visited and not has_active_event


## Check if hostile entity is present
## @return: true if hostile spawned here
func has_hostile() -> bool:
	return spawned_hostile != null


## Check if merchant is present
## @return: true if merchant spawned here
func has_merchant() -> bool:
	return not spawned_merchant.is_empty()


## Check if collision event should trigger (hostile + merchant)
## @return: true if both present
func has_collision_event() -> bool:
	return has_hostile() and has_merchant()


## Mark node as unlocked
func unlock() -> void:
	is_unlocked = true


## Mark node as completed
## @param turns_taken: Turns to complete (for battles)
func complete(turns_taken: int = 0) -> void:
	is_completed = true
	times_completed += 1
	
	if turns_taken > 0:
		if best_clear_turns == 0 or turns_taken < best_clear_turns:
			best_clear_turns = turns_taken


## Reset node state
func reset() -> void:
	is_completed = false
	# Note: Don't reset is_unlocked to allow replaying


## Get node type name
## @return: Human-readable type name
func get_type_name() -> String:
	return NODE_TYPE_NAMES.get(node_type, "Unknown")


## Validate node
## @return: Array of error messages
func validate_node() -> Array[String]:
	var errors: Array[String] = []
	
	if node_id.is_empty():
		errors.append("Node ID is empty")
	
	if node_name.is_empty():
		errors.append("Node name is empty")
	
	if node_type == NodeType.BATTLE:
		if map_scene_path.is_empty():
			errors.append("Battle node has no map scene path")
		elif not ResourceLoader.exists(map_scene_path):
			errors.append("Map scene path does not exist: %s" % map_scene_path)
	
	if recommended_level < 1:
		errors.append("Recommended level must be at least 1")
	
	if gold_reward < 0:
		errors.append("Gold reward cannot be negative")
	
	if exp_reward < 0:
		errors.append("EXP reward cannot be negative")
	
	return errors


## Repair invalid node data
## @return: true if repaired
func repair_node() -> bool:
	var was_repaired := false
	
	if node_id.is_empty():
		node_id = node_name.to_snake_case()
		was_repaired = true
	
	if recommended_level < 1:
		recommended_level = 1
		was_repaired = true
	
	if gold_reward < 0:
		gold_reward = 0
		was_repaired = true
	
	if exp_reward < 0:
		exp_reward = 0
		was_repaired = true
	
	return was_repaired


## Clone node
## @return: New WorldMapNode instance
func clone() -> WorldMapNode:
	var new_node := WorldMapNode.new()
	new_node.node_id = node_id + "_clone"
	new_node.node_name = node_name
	new_node.node_type = node_type
	new_node.description = description
	new_node.position = position
	new_node.is_unlocked = is_unlocked
	new_node.is_completed = is_completed
	new_node.is_optional = is_optional
	new_node.map_scene_path = map_scene_path
	new_node.battle_objectives = battle_objectives
	new_node.recommended_level = recommended_level
	new_node.enemy_count = enemy_count
	new_node.next_nodes = next_nodes.duplicate()
	new_node.required_nodes = required_nodes.duplicate()
	new_node.gold_reward = gold_reward
	new_node.exp_reward = exp_reward
	new_node.item_rewards = item_rewards.duplicate()
	new_node.node_icon = node_icon
	new_node.node_color = node_color
	return new_node


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	return {
		"node_id": node_id,
		"is_unlocked": is_unlocked,
		"is_completed": is_completed,
		"is_visited": is_visited,
		"has_active_event": has_active_event,
		"times_completed": times_completed,
		"best_clear_turns": best_clear_turns,
		"spawned_hostile": spawned_hostile,
		"spawned_merchant": spawned_merchant
	}


## Deserialize from save data
## @param data: Save data
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	node_id = data.get("node_id", node_id)
	is_unlocked = data.get("is_unlocked", false)
	is_completed = data.get("is_completed", false)
	is_visited = data.get("is_visited", false)
	has_active_event = data.get("has_active_event", false)
	times_completed = data.get("times_completed", 0)
	best_clear_turns = data.get("best_clear_turns", 0)
	spawned_hostile = data.get("spawned_hostile", {})
	spawned_merchant = data.get("spawned_merchant", {})
	
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== %s ===%s\n" % [node_name, " [%s]" % node_id if not node_id.is_empty() else ""]
	
	summary += "Type: %s\n" % get_type_name()
	summary += "Position: (%.0f, %.0f)\n" % [position.x, position.y]
	summary += "State: %s%s%s\n" % [
		"Unlocked" if is_unlocked else "Locked",
		", Completed" if is_completed else "",
		", Optional" if is_optional else ""
	]
	
	if node_type == NodeType.BATTLE:
		summary += "Recommended Level: %d\n" % recommended_level
		if enemy_count > 0:
			summary += "Enemies: %d\n" % enemy_count
		if map_scene_path:
			summary += "Map: %s\n" % map_scene_path
	
	if not next_nodes.is_empty():
		summary += "Next Nodes: %s\n" % ", ".join(next_nodes)
	
	if not required_nodes.is_empty():
		summary += "Requires: %s\n" % ", ".join(required_nodes)
	
	if gold_reward > 0 or exp_reward > 0:
		summary += "Rewards:"
		if gold_reward > 0:
			summary += " %d gold" % gold_reward
		if exp_reward > 0:
			summary += " %d exp" % exp_reward
		summary += "\n"
	
	if times_completed > 0:
		summary += "Completed: %d times" % times_completed
		if best_clear_turns > 0:
			summary += " (Best: %d turns)" % best_clear_turns
		summary += "\n"
	
	var errors := validate_node()
	if errors.is_empty():
		summary += "\n✓ Node valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())


## Create a battle node (factory method)
## @param name: Node name
## @param map_path: Map scene path
## @param level: Recommended level
## @return: New WorldMapNode configured as battle
static func create_battle_node(name: String, map_path: String, level: int = 1) -> WorldMapNode:
	var node := WorldMapNode.new()
	node.node_id = name.to_snake_case()
	node.node_name = name
	node.node_type = NodeType.BATTLE
	node.map_scene_path = map_path
	node.recommended_level = level
	return node


## Create a story node (factory method)
## @param name: Node name
## @param desc: Description
## @return: New WorldMapNode configured as story
static func create_story_node(name: String, desc: String = "") -> WorldMapNode:
	var node := WorldMapNode.new()
	node.node_id = name.to_snake_case()
	node.node_name = name
	node.node_type = NodeType.STORY
	node.description = desc
	return node
