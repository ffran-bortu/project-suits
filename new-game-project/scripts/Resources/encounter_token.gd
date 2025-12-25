"""
FILE: encounter_token.gd
PURPOSE: Consumable item for forcing hostile enemy spawns at current world map nodes.

OVERVIEW:
This resource represents an encounter token, a purchasable item that summons enemies to the player's
current location for controlled grinding. It's an economic balancing tool that can be configured for
low difficulty (profitable grinding) or high difficulty (gold drain to discourage overuse). Tokens modify
enemy rewards through multipliers and track inventory quantity with stack limits.

FUNCTIONS IN THIS FILE:

1. use(world_map, current_node, player_avg_level)
   - What it does: Consumes token, spawns hostile encounter at current node with modifiers
   - Uses: Player uses token from inventory to force a battle
   - Returns: true if spawn successful, false if no tokens/already hostile/system error

2. add(amount)
   - What it does: Adds tokens to inventory up to max_stack limit
   - Uses: Shop purchases, quest rewards, token acquisition
   - Returns: void (clamps to max_stack)

3. remove(amount)
   - What it does: Removes tokens from inventory, cannot go below 0
   - Uses: Administrative removal, quest costs
   - Returns: void (clamps to 0 minimum)

4. get_full_description()
   - What it does: Formats description with cost, sell value, and reward multipliers
   - Uses: Shop UI, inventory tooltips
   - Returns: String with complete item info

5. get_profitability_rating(avg_battle_reward)
   - What it does: Evaluates if using token is profitable based on average gold rewards
   - Uses: Game balance analysis, player economy tooltips
   - Returns: String like "Profitable (Grinding Enabled)" or "Balanced"

6. serialize()
   - What it does: Converts token inventory data to Dictionary
   - Uses: Save system persists token quantity
   - Returns: Dictionary with quantity field

7. deserialize(data)
   - What it does: Restores token quantity from save data
   - Uses: Load system restores inventory
   - Returns: void

NOTES:
- Config A (Low Difficulty): cost < avg_battle_reward → enables infinite grinding
- Config B (High Difficulty): cost > avg_battle_reward → gold drain discourages overuse
- guaranteed_spawn flag ensures 100% spawn (no RNG failure)
- level_bonus adds extra challenge (default +1 level above player average)
- gold_reward_multiplier and exp_reward_multiplier allow tuning rewards
- Integrates with DynamicSpawnSystem on the world map
- max_stack prevents inventory overflow (default 99)
- uses_per_token is always 1 (single-use consumable)
"""

class_name EncounterToken
extends Resource
## Encounter Token - Consumable item for forcing hostile spawns
##
## Economic balancing tool for controlled grinding

# --- Item Data ---
@export var token_name: String = "Encounter Token"
@export_multiline var description: String = "Summons enemies to your current location for training."
@export var icon: Texture2D

# --- Economic Balance ---
@export var purchase_cost: int = 150  ## Cost to buy from shop
@export var sell_value: int = 50  ## Sell value

## Config A (Low Difficulty): cost < avg_battle_reward → Infinite Grinding
## Config B (High Difficulty): cost > avg_battle_reward → Drain gold, discourage overuse

# --- Usage Effect ---
@export var guaranteed_spawn: bool = true  ## Always spawns hostile
@export var level_bonus: int = 1  ## Enemies are +1 level above average
@export var gold_reward_multiplier: float = 1.0  ## Modify rewards
@export var exp_reward_multiplier: float = 1.0  ## Modify EXP

# --- Limits ---
@export var max_stack: int = 99  ## Maximum in inventory
@export var uses_per_token: int = 1  ## Single use

# --- Runtime ---
var quantity: int = 0


## Use the encounter token
## @return: true if successfully used
func use(world_map: Node, current_node: WorldMapNode, player_avg_level: int, spawn_system: DynamicSpawnSystem) -> bool:
	if quantity <= 0:
		push_warning("EncounterToken: No tokens available")
		return false
	
	if not current_node:
		push_error("EncounterToken: No current node")
		return false
	
	if current_node.has_hostile():
		push_warning("EncounterToken: Node already has hostile encounter")
		return false
	
	if not spawn_system:
		push_error("EncounterToken: DynamicSpawnSystem not provided")
		return false
	
	# Force spawn hostile
	var hostile_data = spawn_system.force_spawn_hostile(current_node, player_avg_level)
	
	if not hostile_data:
		return false
	
	# Apply token modifiers
	hostile_data.gold_reward = roundi(hostile_data.gold_reward * gold_reward_multiplier)
	hostile_data.exp_reward = roundi(hostile_data.exp_reward * exp_reward_multiplier)
	hostile_data.is_token_spawn = true
	
	# Consume token
	quantity -= 1
	
	DebugLog.success("Encounter Token used! (%d remaining)" % quantity)
	return true


## Add tokens to inventory
func add(amount: int) -> void:
	quantity = min(quantity + amount, max_stack)


## Remove tokens from inventory
func remove(amount: int) -> void:
	quantity = max(quantity - amount, 0)


## Get formatted description with usage info
func get_full_description() -> String:
	var desc := description
	desc += "\n\n"
	desc += "Cost: %d gold\n" % purchase_cost
	desc += "Sell: %d gold\n" % sell_value
	
	if gold_reward_multiplier != 1.0:
		desc += "Gold Reward: x%.1f\n" % gold_reward_multiplier
	if exp_reward_multiplier != 1.0:
		desc += "EXP Reward: x%.1f\n" % exp_reward_multiplier
	
	return desc


## Calculate profitability (for AI economy balancing)
func get_profitability_rating(avg_battle_reward: int) -> String:
	if purchase_cost < avg_battle_reward:
		return "Profitable (Grinding Enabled)"
	elif purchase_cost > avg_battle_reward * 1.5:
		return "Unprofitable (Grinding Discouraged)"
	else:
		return "Balanced"


## Serialize for save
func serialize() -> Dictionary:
	return {
		"quantity": quantity
	}


## Deserialize from save
func deserialize(data: Dictionary) -> void:
	quantity = data.get("quantity", 0)




