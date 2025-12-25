class_name WeaponAbility
extends Resource

## Special ability attached to weapons

# --- Ability Type Enum ---
enum AbilityType {
	COMBAT_MODIFIER,    # Modifies combat behavior (Brave, etc.)
	STAT_MODIFIER,      # Modifies stats (Killer, etc.)
	ON_HIT_EFFECT,      # Triggers on hit (Lifesteal, etc.)
	EFFECTIVENESS,      # Effective vs certain units
	SPECIAL             # Special mechanics
}

# --- Basic Info ---
@export var ability_id: String = ""
@export var ability_name: String = ""
@export_multiline var description: String = ""

# --- Ability Properties ---
@export var ability_type: AbilityType = AbilityType.COMBAT_MODIFIER
@export_range(0, 100) var activation_rate: int = 100  # % chance to activate
@export var effect_data: Dictionary = {}  # Ability-specific data


## Check if ability activates
## @return: true if activates
func check_activation() -> bool:
	if activation_rate >= 100:
		return true
	return randi() % 100 < activation_rate


## Get effect value
## @param key: Effect key
## @param default: Default value
## @return: Effect value
func get_effect(key: String, default: Variant = null) -> Variant:
	return effect_data.get(key, default)


## Validate ability
## @return: Array of errors
func validate_ability() -> Array[String]:
	var errors: Array[String] = []
	
	if ability_id.is_empty():
		errors.append("Ability ID is empty")
	
	if ability_name.is_empty():
		errors.append("Ability name is empty")
	
	if activation_rate < 0 or activation_rate > 100:
		errors.append("Activation rate must be 0-100")
	
	return errors


## Clone ability
## @return: New WeaponAbility
func clone() -> WeaponAbility:
	var new_ability := WeaponAbility.new()
	new_ability.ability_id = ability_id
	new_ability.ability_name = ability_name
	new_ability.description = description
	new_ability.ability_type = ability_type
	new_ability.activation_rate = activation_rate
	new_ability.effect_data = effect_data.duplicate(true)
	return new_ability
