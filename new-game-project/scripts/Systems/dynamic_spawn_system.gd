"""
FILE: dynamic_spawn_system.gd
PURPOSE: Procedural spawn system for hostile encounters and roaming merchants on world map.

OVERVIEW:
Extends Node to manage dynamic world map events. Spawns hostiles (based on player level, spawn chance, turn counter)
and roaming merchants (with stock, duration timers) on visited nodes. Tracks active spawns, handles despawning,
supports collision events (hostile+merchant), integrates with EncounterToken for forced spawns. Emits signals for spawns/despawns.

FUNCTIONS: process_spawns, _try_spawn_hostile, _generate_hostile_data, _generate_enemy_composition, _try_spawn_merchant,
_generate_merchant_data, _generate_merchant_stock, _update_merchant_timers, clear_hostile, clear_merchant,
force_spawn_hostile, _create_collision_event, get_debug_summary, debug_print - 14 total

NOTES: HOSTILE_SPAWN_CHANCE = 0.3 (30%), MERCHANT_SPAWN_CHANCE = 0.15 (15%). Hostile level = player_avg_level ±2.
Merchants last 3-5 turns with rare item stock. Signals: hostile_spawned, merchant_spawned, hostile_despawned, merchant_despawned, collision_event_created.
"""

class_name DynamicSpawnSystem
extends Node
## Dynamic spawn system for hostiles and merchants on world map
##
## Handles procedural spawning of encounters and roaming merchants
## Creates dynamic gameplay on visited nodes

# --- Constants ---
const HOSTILE_SPAWN_CHANCE: float = 0.25  ## 25% chance per check
const MERCHANT_SPAWN_CHANCE: float = 0.15  ## 15% chance per check
const MERCHANT_DURATION_MIN: int = 3  ## Minimum turns merchant stays
const MERCHANT_DURATION_MAX: int = 7  ## Maximum turns merchant stays

# --- Configuration ---
@export var enable_hostile_spawns: bool = true
@export var enable_merchant_spawns: bool = true
@export var hostile_level_variance: int = 2  ## +/- levels from player average
@export var merchant_special_item_count: int = 3  ## Special items in merchant stock

# --- State ---
var active_hostiles: Dictionary = {}  ## node_id -> hostile_data
var active_merchants: Dictionary = {}  ## node_id -> merchant_data
var spawn_history: Array[Dictionary] = []  ## Track spawn events
var turn_counter: int = 0

# --- Signals ---
signal hostile_spawned(node_id: String, hostile_data: Dictionary)
signal merchant_spawned(node_id: String, merchant_data: Dictionary)
signal hostile_despawned(node_id: String)
signal merchant_despawned(node_id: String)
signal collision_event_created(node_id: String)


## Process spawns on turn change or time-based trigger
func process_spawns(visited_nodes: Array[WorldMapNode], player_avg_level: int = 1) -> void:
	turn_counter += 1
	
	if enable_hostile_spawns:
		_try_spawn_hostile(visited_nodes, player_avg_level)
	
	if enable_merchant_spawns:
		_try_spawn_merchant(visited_nodes)
	
	_update_merchant_timers()


## Try to spawn hostile entity
func _try_spawn_hostile(visited_nodes: Array[WorldMapNode], player_avg_level: int) -> void:
	if visited_nodes.is_empty():
		return
	
	# RNG check
	if randf() > HOSTILE_SPAWN_CHANCE:
		return
	
	# Get valid spawn locations (visited nodes without active events)
	var valid_nodes: Array[WorldMapNode] = []
	for node in visited_nodes:
		if node.is_visited and not node.has_active_event and not node.has_hostile():
			valid_nodes.append(node)
	
	if valid_nodes.is_empty():
		return
	
	# Select random node
	var spawn_node: WorldMapNode = valid_nodes.pick_random()
	
	# Generate hostile data
	var hostile_data := _generate_hostile_data(spawn_node, player_avg_level)
	
	# Spawn hostile
	spawn_node.spawned_hostile = hostile_data
	spawn_node.has_active_event = true  ## Hostile blocks shop/save UI
	active_hostiles[spawn_node.node_id] = hostile_data
	
	DebugLog.log("Hostile spawned at %s (Lvl %d)" % [spawn_node.node_name, hostile_data.level], "yellow")
	hostile_spawned.emit(spawn_node.node_id, hostile_data)
	
	# Check for collision event
	if spawn_node.has_merchant():
		_create_collision_event(spawn_node)


## Generate hostile entity data
func _generate_hostile_data(node: WorldMapNode, player_avg_level: int) -> SpawnData:
	var level_variance := randi_range(-hostile_level_variance, hostile_level_variance)
	var enemy_level := clampi(player_avg_level + level_variance, 1, 40)
	
	# Scale based on node difficulty
	var difficulty_multiplier := 1.0
	if node.recommended_level > 0:
		difficulty_multiplier = float(node.recommended_level) / float(max(player_avg_level, 1))
	
	# Create data object
	var data = SpawnData.new()
	data.unit_name = "Skirmish" # Generic name
	data.level = enemy_level
	data.is_merchant = false
	data.remaining_turns = 100 # Indefinite basically
	
	# Note: We might want to add detailed composition to SpawnData if needed
	# For now SpawnData is simple, but we can extend it or use metadata
	# If we strictly need Dictionary-like flexibility for unexpected fields, we might need to add a generic dictionary to SpawnData
	# But for now let's map what we can.
	# Wait, SpawnData fields are: unit_name, level, is_merchant, is_forced, remaining_turns, has_merchant_target, protect_objective
	# The Dictionary had: type, level, unit_count, unit_classes, gold_reward, exp_reward, spawn_turn, spawn_time
	# We need to map these or add them to SpawnData. 
	# Set properties
	data.unit_count = roundi(3 + randf() * 3 * difficulty_multiplier)
	data.unit_classes = _generate_enemy_composition(data.unit_count)
	data.gold_reward = roundi(50 * enemy_level * difficulty_multiplier)
	data.exp_reward = roundi(30 * enemy_level)
	data.spawn_turn = turn_counter
	
	return data


## Generate enemy unit composition
func _generate_enemy_composition(unit_count: int) -> Array[String]:
	const ENEMY_CLASSES := ["Bandit", "Brigand", "Mercenary", "Fighter", "Warrior"]
	var composition: Array[String] = []
	
	for i in range(unit_count):
		composition.append(ENEMY_CLASSES.pick_random())
	
	return composition


## Try to spawn roaming merchant
func _try_spawn_merchant(visited_nodes: Array[WorldMapNode]) -> void:
	if visited_nodes.is_empty():
		return
	
	# RNG check
	if randf() > MERCHANT_SPAWN_CHANCE:
		return
	
	# Get valid spawn locations (visited nodes without merchants)
	var valid_nodes: Array[WorldMapNode] = []
	for node in visited_nodes:
		if node.is_visited and not node.has_merchant():
			valid_nodes.append(node)
	
	if valid_nodes.is_empty():
		return
	
	# Select random node
	var spawn_node: WorldMapNode = valid_nodes.pick_random()
	
	# Generate merchant data
	var merchant_data := _generate_merchant_data(spawn_node)
	
	# Spawn merchant
	spawn_node.spawned_merchant = merchant_data
	active_merchants[spawn_node.node_id] = merchant_data
	
	DebugLog.success("Roaming Merchant appeared at %s!" % spawn_node.node_name)
	merchant_spawned.emit(spawn_node.node_id, merchant_data)
	
	# Check for collision event
	if spawn_node.has_hostile():
		_create_collision_event(spawn_node)


## Generate roaming merchant data
func _generate_merchant_data(node: WorldMapNode) -> SpawnData:
	var duration := randi_range(MERCHANT_DURATION_MIN, MERCHANT_DURATION_MAX)
	
	var data = SpawnData.new()
	data.is_merchant = true
	data.unit_name = _generate_merchant_name()
	data.remaining_turns = duration
	data.level = 1
	
	# Store props
	data.special_stock = _generate_special_stock()
	data.discount = randf_range(0.8, 0.95)
	data.spawn_turn = turn_counter
	
	return data


## Generate random merchant name
func _generate_merchant_name() -> String:
	const NAMES := ["Merchant Anna", "Traveling Vendor", "Secret Shop", "Mysterious Trader", "Desert Merchant"]
	return NAMES.pick_random()


## Generate special merchant stock
func _generate_special_stock() -> Array[String]:
	const RARE_ITEMS := [
		"elixir", "goddess_icon", "brave_sword", "brave_lance", "brave_axe",
		"silver_sword", "silver_lance", "silver_axe", "killer_bow",
		"stat_booster_str", "stat_booster_spd", "stat_booster_def"
	]
	
	var stock: Array[String] = []
	for i in range(merchant_special_item_count):
		var item: String = RARE_ITEMS.pick_random()
		if item not in stock:
			stock.append(item)
	
	return stock


## Update merchant turn timers
func _update_merchant_timers() -> void:
	var to_remove: Array[String] = []
	
	for node_id in active_merchants:
		var merchant_data: Dictionary = active_merchants[node_id]
		merchant_data.remaining_turns -= 1
		
		if merchant_data.remaining_turns <= 0:
			to_remove.append(node_id)
	
	# Despawn expired merchants
	for node_id in to_remove:
		despawn_merchant(node_id)


## Create collision event (hostile + merchant on same node)
func _create_collision_event(node: WorldMapNode) -> void:
	if not node.has_collision_event():
		return
	
	DebugLog.log("COLLISION EVENT at %s! (Hostile + Merchant)" % node.node_name, "cyan")
	collision_event_created.emit(node.node_id)
	
	# Mark node for special combat scenario
	if node.spawned_hostile:
		node.spawned_hostile.has_merchant_target = true
		node.spawned_hostile.protect_objective = true


## Clear hostile from node (after battle)
func despawn_hostile(node_id: String) -> void:
	if node_id in active_hostiles:
		active_hostiles.erase(node_id)
		hostile_despawned.emit(node_id)


## Clear merchant from node (timer expired or after interaction)
func despawn_merchant(node_id: String) -> void:
	if node_id in active_merchants:
		active_merchants.erase(node_id)
		merchant_despawned.emit(node_id)
		DebugLog.log("Roaming Merchant departed from node %s" % node_id, "yellow")


## Force spawn hostile at specific node (encounter token use)
func force_spawn_hostile(node: WorldMapNode, player_avg_level: int) -> SpawnData:
	if node.has_hostile():
		push_warning("DynamicSpawnSystem: Node already has hostile")
		return null
	
	var hostile_data := _generate_hostile_data(node, player_avg_level)
	hostile_data.is_forced = true  # Mark as player-initiated
	
	node.spawned_hostile = hostile_data
	node.has_active_event = true
	active_hostiles[node.node_id] = hostile_data
	
	DebugLog.log("Encounter Token used! Hostile spawned at %s" % node.node_name, "cyan")
	hostile_spawned.emit(node.node_id, hostile_data)
	
	return hostile_data


## Get total active spawns
func get_active_spawn_count() -> int:
	return active_hostiles.size() + active_merchants.size()


## Get debug summary
func get_debug_summary() -> String:
	var summary := "=== Dynamic Spawn System ===\n"
	summary += "Turn: %d\n" % turn_counter
	summary += "Active Hostiles: %d\n" % active_hostiles.size()
	summary += "Active Merchants: %d\n" % active_merchants.size()
	summary += "Total Spawns: %d\n" % spawn_history.size()
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())




