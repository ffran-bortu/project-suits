"""
FILE: weapon_inventory.gd
PURPOSE: Manages weapon inventory slots, equipment, durability, proficiency, and weapon triangle mechanics.

OVERVIEW:
Resource for character weapon management. Stores weapons array (max 5 slots), tracks durability per weapon, handles equipping,
validates range/proficiency, calculates weapon triangle advantage (Slashing>Piercing>Striking>Slashing), integrates with
WeaponProficiency for rank bonuses. Supports auto-break on zero durability, validates proficiency requirements, serializes for saves.

FUNCTIONS: add_weapon, remove_weapon, equip_weapon, unequip_weapon, get_weapon_durability, use_weapon, repair_weapon, is_weapon_broken,
is_in_range, can_use_weapon, get_attack_bonus, get_proficiency, calculate_triangle_advantage, validate_inventory, repair_inventory,
serialize, deserialize, get_debug_summary, debug_print - 19 total

NOTES: DEFAULT_MAX_WEAPONS = 5, DEFAULT_DURABILITY = 30. Weapon triangle: hit ±15, damage ±1. Magic weapons skip proficiency checks.
Breaks weapon when durability hits 0. Signals: weapon_equipped, weapon_broken, inventory_full.
"""


class_name WeaponInventory
extends Resource

## Manages weapon inventory, equipment, durability, and proficiency

# --- Constants ---
const DEFAULT_MAX_WEAPONS: int = 5
const DEFAULT_DURABILITY: int = 40
const MIN_DURABILITY: int = 0
const MAX_DURABILITY: int = 100

# --- Weapon Triangle Bonuses ---
const TRIANGLE_HIT_BONUS: int = 15
const TRIANGLE_DAMAGE_BONUS: int = 1

# --- Inventory ---
@export var max_weapon_slots: int = DEFAULT_MAX_WEAPONS
var weapons: Array[Weapon] = []
var equipped_weapon: Weapon = null
var weapon_durability: Dictionary = {}  # Weapon instance ID -> durability

# --- Proficiency ---
var proficiency: WeaponProficiency = null

# --- Signals ---
signal weapon_equipped(weapon: Weapon)
signal weapon_broken(weapon: Weapon)
signal inventory_full()


func _init() -> void:
	proficiency = WeaponProficiency.new()


## Add weapon to inventory
## @param weapon: Weapon to add
## @param durability: Initial durability
## @return: true if added successfully
func add_weapon(weapon: Weapon, durability: int = DEFAULT_DURABILITY) -> bool:
	if not weapon:
		push_warning("WeaponInventory: Cannot add null weapon")
		return false
	
	if weapons.size() >= max_weapon_slots:
		push_warning("WeaponInventory: Inventory full!")
		inventory_full.emit()
		return false
	
	# DUPLICATION FIX: Ensure weapon is unique so durability is not shared
	# across multiple units with the same weapon resource
	var new_weapon = weapon.duplicate()
	
	weapons.append(new_weapon)
	weapon_durability[new_weapon.get_instance_id()] = clamp(durability, MIN_DURABILITY, MAX_DURABILITY)
	return true


## Remove weapon from inventory
## @param weapon: Weapon to remove
## @return: true if removed
func remove_weapon(weapon: Weapon) -> bool:
	if not weapon:
		return false
	
	var index := weapons.find(weapon)
	if index == -1:
		return false
	
	# Unequip if currently equipped
	if equipped_weapon == weapon:
		equipped_weapon = null
	
	weapons.remove_at(index)
	weapon_durability.erase(weapon.get_instance_id())
	return true


## Equip weapon from inventory
## @param weapon: Weapon to equip
## @return: true if equipped
func equip_weapon(weapon: Weapon) -> bool:
	if not weapon:
		push_warning("WeaponInventory: Cannot equip null weapon")
		return false
	
	if not weapons.has(weapon):
		push_warning("WeaponInventory: Weapon not in inventory")
		return false
	
	# Check proficiency if system available
	if proficiency and weapon.category == Weapon.WeaponCategory.PHYSICAL:
		if not can_use_weapon(weapon):
			push_warning("WeaponInventory: Insufficient proficiency for %s" % weapon.weapon_name)
			return false
	
	equipped_weapon = weapon
	weapon_equipped.emit(weapon)
	return true


## Equip weapon by index
## @param index: Inventory index
## @return: true if equipped
func equip_weapon_by_index(index: int) -> bool:
	if index < 0 or index >= weapons.size():
		return false
	return equip_weapon(weapons[index])


## Get equipped weapon
## @return: Currently equipped weapon or null
func get_equipped_weapon() -> Weapon:
	return equipped_weapon


## Get weapon durability
## @param weapon: Weapon to check
## @return: Current durability
func get_weapon_durability(weapon: Weapon) -> int:
	if not weapon:
		return 0
	return weapon_durability.get(weapon.get_instance_id(), DEFAULT_DURABILITY)


## Use equipped weapon (reduce durability)
## @return: true if weapon still usable
func use_weapon() -> bool:
	if not equipped_weapon:
		return false
	
	var weapon_id := equipped_weapon.get_instance_id()
	var current_durability: int = weapon_durability.get(weapon_id, DEFAULT_DURABILITY)
	
	current_durability = max(MIN_DURABILITY, current_durability - 1)
	weapon_durability[weapon_id] = current_durability
	
	# Add proficiency experience on use
	if proficiency and equipped_weapon.category == Weapon.WeaponCategory.PHYSICAL:
		proficiency.add_experience(equipped_weapon.physical_type, 1)
	
	# Check if broken
	if current_durability <= MIN_DURABILITY:
		weapon_broken.emit(equipped_weapon)
		remove_weapon(equipped_weapon)
		return false
	
	return true


## Repair weapon
## @param weapon: Weapon to repair
## @param amount: Durability to restore
func repair_weapon(weapon: Weapon, amount: int = MAX_DURABILITY) -> void:
	if not weapon:
		return
	
	var weapon_id := weapon.get_instance_id()
	var current: int = weapon_durability.get(weapon_id, DEFAULT_DURABILITY)
	weapon_durability[weapon_id] = min(MAX_DURABILITY, current + amount)


## Check if can attack at distance
## @param distance: Target distance
## @return: true if in range
func can_attack_at_distance(distance: int) -> bool:
	if not equipped_weapon:
		return false
	return distance >= equipped_weapon.range_min and distance <= equipped_weapon.range_max


## Check if can use weapon (proficiency check)
## @param weapon: Weapon to check
## @return: true if proficient
func can_use_weapon(weapon: Weapon) -> bool:
	if not weapon:
		return false
	
	# Magical weapons don't require proficiency in this system
	if weapon.category == Weapon.WeaponCategory.MAGICAL:
		return true
	
	if not proficiency:
		return true
	
	return proficiency.can_use_weapon(weapon.physical_type, weapon.required_rank)


## Get weapon list
## @return: Array of all weapons
func get_weapon_list() -> Array[Weapon]:
	return weapons.duplicate()


## Check if has weapon type
## @param category: Weapon category
## @return: true if has any
func has_weapon_type(category: Weapon.WeaponCategory) -> bool:
	for weapon in weapons:
		if weapon.category == category:
			return true
	return false


## Get proficiency system
## @return: WeaponProficiency instance
func get_proficiency() -> WeaponProficiency:
	return proficiency


## Calculate weapon triangle advantage
## @param attacker_weapon: Attacking weapon
## @param defender_weapon: Defending weapon
## @return: Dictionary with hit_bonus and damage_bonus
func calculate_triangle_advantage(attacker_weapon: Weapon, defender_weapon: Weapon) -> Dictionary:
	var result := {"hit_bonus": 0, "damage_bonus": 0}
	
	if not attacker_weapon or not defender_weapon:
		return result
	
	# Only physical weapons have triangle
	if attacker_weapon.category != Weapon.WeaponCategory.PHYSICAL:
		return result
	if defender_weapon.category != Weapon.WeaponCategory.PHYSICAL:
		return result
	
	var attacker_type := attacker_weapon.physical_type
	var defender_type := defender_weapon.physical_type
	
	# Piercing > Slashing > Striking > Piercing
	var has_advantage := false
	
	match attacker_type:
		Weapon.PhysicalDamageType.PIERCING:
			has_advantage = (defender_type == Weapon.PhysicalDamageType.SLASHING)
		Weapon.PhysicalDamageType.SLASHING:
			has_advantage = (defender_type == Weapon.PhysicalDamageType.STRIKING)
		Weapon.PhysicalDamageType.STRIKING:
			has_advantage = (defender_type == Weapon.PhysicalDamageType.PIERCING)
	
	if has_advantage:
		result.hit_bonus = TRIANGLE_HIT_BONUS
		result.damage_bonus = TRIANGLE_DAMAGE_BONUS
	else:
		# Check if at disadvantage (reverse)
		var has_disadvantage := false
		match attacker_type:
			Weapon.PhysicalDamageType.PIERCING:
				has_disadvantage = (defender_type == Weapon.PhysicalDamageType.STRIKING)
			Weapon.PhysicalDamageType.SLASHING:
				has_disadvantage = (defender_type == Weapon.PhysicalDamageType.PIERCING)
			Weapon.PhysicalDamageType.STRIKING:
				has_disadvantage = (defender_type == Weapon.PhysicalDamageType.SLASHING)
		
		if has_disadvantage:
			result.hit_bonus = -TRIANGLE_HIT_BONUS
			result.damage_bonus = -TRIANGLE_DAMAGE_BONUS
	
	return result


## Validate inventory
## @return: Array of error messages
func validate_inventory() -> Array[String]:
	var errors: Array[String] = []
	
	if max_weapon_slots < 1:
		errors.append("Max weapon slots must be at least 1")
	
	if weapons.size() > max_weapon_slots:
		errors.append("Weapon count (%d) exceeds max slots (%d)" % [weapons.size(), max_weapon_slots])
	
	for i in range(weapons.size()):
		var weapon := weapons[i]
		if not weapon:
			errors.append("Weapon at index %d is null" % i)
	
	if equipped_weapon and not weapons.has(equipped_weapon):
		errors.append("Equipped weapon not in inventory")
	
	return errors


## Repair inventory issues
## @return: true if repaired
func repair_inventory() -> bool:
	var was_repaired := false
	
	# Remove null weapons
	var valid_weapons: Array[Weapon] = []
	for weapon in weapons:
		if weapon:
			valid_weapons.append(weapon)
		else:
			was_repaired = true
	weapons = valid_weapons
	
	# Unequip if not in inventory
	if equipped_weapon and not weapons.has(equipped_weapon):
		equipped_weapon = null
		was_repaired = true
	
	# Clamp max slots
	if max_weapon_slots < 1:
		max_weapon_slots = DEFAULT_MAX_WEAPONS
		was_repaired = true
	
	return was_repaired


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	var weapon_data: Array = []
	for weapon in weapons:
		if weapon and weapon.resource_path:
			weapon_data.append({
				"path": weapon.resource_path,
				"durability": get_weapon_durability(weapon)
			})
	
	return {
		"max_weapon_slots": max_weapon_slots,
		"weapons": weapon_data,
		"equipped_index": weapons.find(equipped_weapon),
		"proficiency": proficiency.serialize() if proficiency else {}
	}


## Deserialize from save data
## @param data: Save data
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	max_weapon_slots = data.get("max_weapon_slots", DEFAULT_MAX_WEAPONS)
	
	# Load weapons
	weapons.clear()
	weapon_durability.clear()
	
	var weapon_data: Array = data.get("weapons", [])
	for weapon_info in weapon_data:
		if weapon_info is Dictionary:
			var weapon_path: String = weapon_info.get("path", "")
			if ResourceLoader.exists(weapon_path):
				var weapon: Weapon = load(weapon_path)
				if weapon:
					weapons.append(weapon)
					weapon_durability[weapon.get_instance_id()] = weapon_info.get("durability", DEFAULT_DURABILITY)
	
	# Restore equipped weapon
	var equipped_index: int = data.get("equipped_index", -1)
	if equipped_index >= 0 and equipped_index < weapons.size():
		equipped_weapon = weapons[equipped_index]
	
	# Restore proficiency
	if proficiency:
		var prof_data: Dictionary = data.get("proficiency", {})
		proficiency.deserialize(prof_data)
	
	return true


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Weapon Inventory ===\n"
	summary += "Slots: %d/%d\n" % [weapons.size(), max_weapon_slots]
	
	if equipped_weapon:
		summary += "Equipped: %s (Durability: %d)\n" % [
			equipped_weapon.weapon_name,
			get_weapon_durability(equipped_weapon)
		]
	else:
		summary += "Equipped: None\n"
	
	summary += "\nWeapons:\n"
	for i in range(weapons.size()):
		var weapon := weapons[i]
		var durability := get_weapon_durability(weapon)
		var equipped_mark := " [E]" if weapon == equipped_weapon else ""
		summary += "  %d. %s (Dur: %d)%s\n" % [i + 1, weapon.weapon_name, durability, equipped_mark]
	
	if proficiency:
		summary += "\n" + proficiency.get_debug_summary()
	
	var errors := validate_inventory()
	if errors.is_empty():
		summary += "\n✓ Inventory valid\n"
	else:
		summary += "\n✗ Validation errors:\n"
		for error in errors:
			summary += "  ! %s\n" % error
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
