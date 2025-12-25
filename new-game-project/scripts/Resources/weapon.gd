"""
FILE: weapon.gd
PURPOSE: Weapon resource with combat stats, damage types, effectiveness, and special abilities.

OVERVIEW:
This file contains TWO classes: Weapon (main) and WeaponAbility (nested).
Weapon defines combat equipment with might, hit/crit bonuses, weight, range, and special abilities. Supports
physical (Slashing/Piercing/Striking) and magical (Fire/Ice/Lightning/Dark/Light) damage types, effectiveness
multipliers against armor types, proficiency requirements, and cost. WeaponAbility provides special effects
like Brave (double attack), Killer (crit bonus), Lifesteal, etc.

WEAPON CLASS FUNCTIONS:

1. validate_weapon()
   - What it does: Checks for errors like empty name, negative stats, invalid range
   - Uses: Resource creation, save loading
   - Returns: Array of error strings

2. get_effectiveness(armor_type)
   - What it does: Returns damage multiplier if armor_type in effectiveness_types
   - Uses: Combat calculations apply bonus vs cavalry/armored/flying
   - Returns: float (effectiveness_multiplier or 1.0)

3. has_ability(ability_id)
   -What it does: Checks if abilities array contains ability with matching ID
   - Uses: Combat checks for special effects
   - Returns: bool

4. get_ability(ability_id)
   - What it does: Returns WeaponAbility object by ID
   - Uses: Fetching specific ability for activation
   - Returns: WeaponAbility or null

5. get_all_abilities()
   - What it does: Returns duplicate of abilities array
   - Uses: Displaying weapon abilities in UI
   - Returns: Array[WeaponAbility]

6. get_type_name()
   - What it does: Returns human-readable damage type ("Slashing", "Fire", etc.)
   - Uses: UI displays weapon type
   - Returns: String type name

7. clone()
   - What it does: Creates deep copy with "_clone" suffix on weapon_id
   - Uses: Templates, variations
   - Returns: New Weapon

8. get_debug_summary()
   - What it does: Formatted summary with all weapon stats and abilities
   - Uses: Debugging
   - Returns: String

9. debug_print()
   - What it does: Prints summary to console
   - Uses: Quick debugging
   - Returns: void

WEAPONABILITY CLASS FUNCTIONS:

10. check_activation()
    - What it does: RNG check for activation_rate percentage
    - Uses: Combat determines if ability triggers
    - Returns: bool (true if activates)

11. get_effect(key, default)
    - What it does: Returns value from effect_data Dictionary by key
    - Uses: Fetching ability-specific parameters
    - Returns: Variant (effect value or default)

12. validate_ability()
    - What it does: Checks for empty IDs, invalid activation rate
    - Uses: Resource creation
    - Returns: Array of error strings

13. clone()
    - What it does: Creates deep copy of ability
    - Uses: Weapon cloning
    - Returns: New WeaponAbility

NOTES:
- WeaponCategory enum: PHYSICAL, MAGICAL
- PhysicalDamageType enum: SLASHING, PIERCING, STRIKING
- MagicalDamageType enum: FIRE, ICE, LIGHTNING, DARK, LIGHT
- might = base damage (0-30 typical)
- hit_bonus = accuracy modifier (-20 to +100)
- crit_bonus = critical hit modifier (-20 to +50)
- weight affects unit speed (heavier = slower)
- range_min and range_max define attack range (1-1 for melee, 2-3 for bows, etc.)
- required_rank uses WeaponProficiency.ProficiencyRank enum (E=0, D=1 through S=5)
- effectiveness_types is Array[String] like ["armored", "cavalry", "flying"]
- effectiveness_multiplier typically 2.0-3.0 for super effective damage
- abilities is Array[WeaponAbility] for special effects
- AbilityType enum: COMBAT_MODIFIER, STAT_MODIFIER, ON_HIT_EFFECT, EFFECTIVENESS, SPECIAL
- activation_rate is 0-100 percentage for RNG abilities  
- effect_data Dictionary stores ability-specific parameters
"""


class_name Weapon
extends Resource

## Weapon with stats, damage types, abilities, and proficiency requirements

# --- Weapon Category Enum ---
enum WeaponCategory {
	PHYSICAL,
	MAGICAL
}

# --- Physical Damage Type Enum ---
enum PhysicalDamageType {
	SLASHING,   # Swords
	PIERCING,   # Lances, Bows
	STRIKING    # Axes, Hammers
}

const PHYSICAL_TYPE_NAMES: Dictionary = {
	PhysicalDamageType.SLASHING: "Slashing",
	PhysicalDamageType.PIERCING: "Piercing",
	PhysicalDamageType.STRIKING: "Striking"
}

# --- Magical Damage Type Enum ---
enum MagicalDamageType {
	FIRE,
	ICE,
	LIGHTNING,
	DARK,
	LIGHT
}

const MAGICAL_TYPE_NAMES: Dictionary = {
	MagicalDamageType.FIRE: "Fire",
	MagicalDamageType.ICE: "Ice",
	MagicalDamageType.LIGHTNING: "Lightning",
	MagicalDamageType.DARK: "Dark",
	MagicalDamageType.LIGHT: "Light"
}

# --- Basic Info ---
@export_group("Basic Info")
@export var weapon_name: String = "Iron Sword"
@export var weapon_id: String = ""
@export_multiline var description: String = ""

# --- Category ---
@export_group("Type")
@export var category: WeaponCategory = WeaponCategory.PHYSICAL
@export var physical_type: PhysicalDamageType = PhysicalDamageType.SLASHING
@export var magical_type: MagicalDamageType = MagicalDamageType.FIRE

# --- Stats ---
@export_group("Stats")
@export_range(0, 30) var might: int = 5
@export_range(-20, 100) var hit_bonus: int = 0
@export_range(-20, 50) var crit_bonus: int = 0
@export_range(0, 20) var weight: int = 5

# --- Range ---
@export_group("Range")
@export_range(1, 10) var range_min: int = 1
@export_range(1, 10) var range_max: int = 1

# --- Requirements ---
@export_group("Requirements")
@export var required_rank: int = 0  # WeaponProficiency.ProficiencyRank.E
@export_range(0, 10000) var cost: int = 100

# --- Effectiveness ---
@export_group("Effectiveness")
@export var effectiveness_types: Array[String] = []  # e.g., ["armored", "cavalry", "flying"]
@export var effectiveness_multiplier: float = 3.0

# --- Abilities ---
@export_group("Abilities")
@export var abilities: Array[WeaponAbility] = []


## Validate weapon
## @return: Array of error messages
func validate_weapon() -> Array[String]:
	var errors: Array[String] = []
	
	if weapon_name.is_empty():
		errors.append("Weapon name is empty")
	
	if might < 0:
		errors.append("Might cannot be negative")
	
	if range_min < 1:
		errors.append("Minimum range must be at least 1")
	
	if range_max < range_min:
		errors.append("Maximum range must be >= minimum range")
	
	if weight < 0:
		errors.append("Weight cannot be negative")
	
	if cost < 0:
		errors.append("Cost cannot be negative")
	
	if effectiveness_multiplier < 1.0:
		errors.append("Effectiveness multiplier should be >= 1.0")
	
	return errors


## Check effectiveness against armor type
## @param armor_type: Armor type to check
## @return: Damage multiplier
func get_effectiveness(armor_type: String) -> float:
	if armor_type in effectiveness_types:
		return effectiveness_multiplier
	return 1.0


## Check if has specific ability
## @param ability_id: Ability ID to check
## @return: true if has ability
func has_ability(ability_id: String) -> bool:
	for ability in abilities:
		if ability and ability.ability_id == ability_id:
			return true
	return false


## Get ability by ID
## @param ability_id: Ability ID
## @return: WeaponAbility or null
func get_ability(ability_id: String) -> WeaponAbility:
	for ability in abilities:
		if ability and ability.ability_id == ability_id:
			return ability
	return null


## Get all active abilities
## @return: Array of abilities
func get_all_abilities() -> Array[WeaponAbility]:
	return abilities.duplicate()


## Get weapon type name
## @return: String type name
func get_type_name() -> String:
	if category == WeaponCategory.PHYSICAL:
		return PHYSICAL_TYPE_NAMES.get(physical_type, "Unknown")
	else:
		return MAGICAL_TYPE_NAMES.get(magical_type, "Unknown")


## Clone weapon
## @return: New Weapon instance
func clone() -> Weapon:
	var new_weapon := Weapon.new()
	new_weapon.weapon_name = weapon_name
	new_weapon.weapon_id = weapon_id + "_clone"
	new_weapon.description = description
	new_weapon.category = category
	new_weapon.physical_type = physical_type
	new_weapon.magical_type = magical_type
	new_weapon.might = might
	new_weapon.hit_bonus = hit_bonus
	new_weapon.crit_bonus = crit_bonus
	new_weapon.weight = weight
	new_weapon.range_min = range_min
	new_weapon.range_max = range_max
	new_weapon.required_rank = required_rank
	new_weapon.cost = cost
	new_weapon.effectiveness_types = effectiveness_types.duplicate()
	new_weapon.effectiveness_multiplier = effectiveness_multiplier
	new_weapon.abilities = abilities.duplicate()
	return new_weapon


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== %s ===%s\n" % [weapon_name, " [%s]" % weapon_id if not weapon_id.is_empty() else ""]
	
	summary += "Type: %s (%s)\n" % [
		"Physical" if category == WeaponCategory.PHYSICAL else "Magical",
		get_type_name()
	]
	summary += "Might: %d | Hit: %+d | Crit: %+d | Weight: %d\n" % [might, hit_bonus, crit_bonus, weight]
	summary += "Range: %d-%d\n" % [range_min, range_max]
	summary += "Cost: %d\n" % cost
	
	if not effectiveness_types.is_empty():
		summary += "Effective vs: %s (×%.1f)\n" % [", ".join(effectiveness_types), effectiveness_multiplier]
	
	if not abilities.is_empty():
		summary += "Abilities:\n"
		for ability in abilities:
			if ability:
				summary += "  - %s: %s\n" % [ability.ability_name, ability.description]
	
	var errors := validate_weapon()
	if errors.is_empty():
		summary += "\n✓ Weapon valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())



