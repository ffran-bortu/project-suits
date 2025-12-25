class_name SpawnData
extends Resource

## Data container for dynamic spawns on the world map

@export var unit_name: String = ""
@export var level: int = 1
@export var is_merchant: bool = false
@export var is_forced: bool = false
@export var remaining_turns: int = 0
@export var has_merchant_target: bool = false # For hostiles targeting merchants
@export var protect_objective: bool = false   # For hostiles with protect objectives

@export var gold_reward: int = 0
@export var exp_reward: int = 0
@export var is_token_spawn: bool = false
@export var unit_count: int = 0
@export var unit_classes: Array[String] = []
@export var spawn_turn: int = 0

# Merchant specific
@export var discount: float = 0.0
@export var special_stock: Array[String] = []

# Optional strict typing for inventory could go here
@export var inventory: Array[String] = []


## Convert to dictionary for saving
func to_dictionary() -> Dictionary:
	return {
		"unit_name": unit_name,
		"level": level,
		"is_merchant": is_merchant,
		"is_forced": is_forced,
		"remaining_turns": remaining_turns,
		"has_merchant_target": has_merchant_target,
		"protect_objective": protect_objective,
		"gold_reward": gold_reward,
		"exp_reward": exp_reward,
		"is_token_spawn": is_token_spawn,
		"unit_count": unit_count,
		"unit_classes": unit_classes,
		"spawn_turn": spawn_turn,
		"discount": discount,
		"special_stock": special_stock,
		"inventory": inventory
	}


## Create from dictionary (static)
static func from_dictionary(data: Dictionary) -> SpawnData:
	var spawn := SpawnData.new()
	spawn.unit_name = data.get("unit_name", "")
	spawn.level = int(data.get("level", 1))
	spawn.is_merchant = data.get("is_merchant", false)
	spawn.is_forced = data.get("is_forced", false)
	spawn.remaining_turns = int(data.get("remaining_turns", 0))
	spawn.has_merchant_target = data.get("has_merchant_target", false)
	spawn.protect_objective = data.get("protect_objective", false)
	spawn.gold_reward = int(data.get("gold_reward", 0))
	spawn.exp_reward = int(data.get("exp_reward", 0))
	spawn.is_token_spawn = data.get("is_token_spawn", false)
	spawn.unit_count = int(data.get("unit_count", 0))
	spawn.unit_classes.assign(data.get("unit_classes", []))
	spawn.spawn_turn = int(data.get("spawn_turn", 0))
	spawn.discount = float(data.get("discount", 0.0))
	spawn.special_stock.assign(data.get("special_stock", []))
	spawn.inventory.assign(data.get("inventory", []))
	return spawn 
