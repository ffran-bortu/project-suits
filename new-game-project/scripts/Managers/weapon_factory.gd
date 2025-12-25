"""
FILE: weapon_factory.gd
PURPOSE: Static factory for creating Fire Emblem weapons with abilities, stats, and validation.

OVERVIEW:
This static factory class creates Weapon instances with proper stats (might, hit, crit, weight, range, rank, cost),
weapon abilities (Brave, Killer, Effective, Lifesteal, Devil), and starter kits for classes. All methods are static
so no instantiation needed. Includes basic weapons (Iron/Steel/Silver for each type), special weapons with abilities,
magic tomes, and validation helpers. Follows Fire Emblem weapon triangle and stat conventions.

FUNCTIONS IN THIS FILE:

1. create_brave_ability()
   - What it does: Creates Brave ability (attacks twice in one round)
   - Uses: For Brave Sword and similar weapons
   - Returns: WeaponAbility

2. create_killer_ability()
   - What it does: Creates Killer ability (+30% crit rate)
   - Uses: For Killer Lance and similar weapons
   - Returns: WeaponAbility

3. create_effective_ability(armor_type)
   - What it does: Creates Effective ability (3x damage vs specific armor type)
   - Uses: For Armorslayer (armored), Horseslayer (cavalry), Hammer (armored)
   - Returns: WeaponAbility

4. create_lifesteal_ability(percent)
   - What it does: Creates Lifesteal ability (heals % of damage dealt)
   - Uses: For Nosferatu tome (50% lifesteal)
   - Returns: WeaponAbility

5. create_devil_ability()
   - What it does: Creates Devil ability (31% chance to backfire and damage user)
   - Uses: For Devil Axe and similar high-risk weapons
   - Returns: WeaponAbility

6. create_iron_sword(), create_steel_sword(), create_silver_sword()
   - What it does: Creates basic swords (5/8/13 might, E/D/A rank)
   - Uses: Standard weapon progression
   - Returns: Weapon

7. create_iron_lance(), create_steel_lance(), create_javelin()
   - What it does: Creates basic lances (7/10/6 might, Javelin has 1-2 range)
   - Uses: Standard lance progression
   - Returns: Weapon

8. create_iron_axe(), create_hand_axe()
   - What it does: Creates basic axes (8/7 might, Hand Axe has 1-2 range)
   - Uses: Standard axe progression
   - Returns: Weapon

9. create_brave_sword(), create_killer_lance(), create_armorslayer(), create_horseslayer(), create_hammer()
   - What it does: Creates special physical weapons with abilities
   - Uses: High-tier weapons with unique effects
   - Returns: Weapon

10. create_fire_tome(), create_elfire_tome(), create_nosferatu_tome()
    - What it does: Creates magic tomes (Fire/Elfire for fire damage, Nosferatu with lifesteal)
    - Uses: Mage weapons (1-2 range, target RES instead of DEF)
    - Returns: Weapon

11. create_knight_starter_kit(), create_fighter_starter_kit(), create_mage_starter_kit(), create_cavalier_starter_kit()
    - What it does: Creates array of starting weapons for each class
    - Uses: For initializing new units
    - Returns: Array[Weapon]

12. validate_weapon(weapon)
    - What it does: Calls weapon.validate_weapon() to check for errors
    - Uses: Quality control after weapon creation
    - Returns: Array[String] (errors, empty if valid)

13. get_all_basic_weapons(), get_all_special_weapons()
    - What it does: Returns arrays of all basic or special weapons
    - Uses: For shop inventories, testing, weapon lists
    - Returns: Array[Weapon]

NOTES:
- Static utility class (all methods static, use WeaponFactory.create_iron_sword() directly)
- Weapon stats follow Fire Emblem conventions: might, hit (adds to base 90), crit, weight (affects speed), range (min-max)
- Proficiency ranks: E (beginner) → D → C → B → A (master)
- Weapon categories: PHYSICAL (Slashing/Piercing/Striking), MAGICAL (Fire/Thunder/Wind/Dark/Light)
- Range: Most melee 1-1, thrown weapons 1-2, magic 1-2
- Abilities integrated via WeaponAbility class with activation rates and effect_data
- No dependencies (leaf utility class)
- Used by: unit initialization, shop systems, loot tables
"""


class_name WeaponFactory
extends Node

## Factory for creating weapons with abilities and proper configuration

# --- Weapon Ability Templates ---
static func create_brave_ability() -> WeaponAbility:
	"""Brave weapons attack twice in one round"""
	var ability := WeaponAbility.new()
	ability.ability_id = "brave"
	ability.ability_name = "Brave"
	ability.description = "Attacks twice in one round"
	ability.ability_type = WeaponAbility.AbilityType.COMBAT_MODIFIER
	ability.activation_rate = 100  # Always active
	ability.effect_data = {"attacks_per_round": 2}
	return ability


static func create_killer_ability() -> WeaponAbility:
	"""Killer weapons have +30% critical hit rate"""
	var ability := WeaponAbility.new()
	ability.ability_id = "killer"
	ability.ability_name = "Killer"
	ability.description = "+30% critical hit rate"
	ability.ability_type = WeaponAbility.AbilityType.STAT_MODIFIER
	ability.activation_rate = 100
	ability.effect_data = {"crit_bonus": 30}
	return ability


static func create_effective_ability(armor_type: String) -> WeaponAbility:
	"""Effective weapons deal 3x damage to specific armor types"""
	var ability := WeaponAbility.new()
	ability.ability_id = "effective_%s" % armor_type
	ability.ability_name = "Effective vs %s" % armor_type.capitalize()
	ability.description = "Deals 3x damage to %s units" % armor_type
	ability.ability_type = WeaponAbility.AbilityType.EFFECTIVENESS
	ability.activation_rate = 100
	ability.effect_data = {
		"armor_type": armor_type,
		"damage_multiplier": 3.0
	}
	return ability


static func create_lifesteal_ability(percent: int = 50) -> WeaponAbility:
	"""Nosferatu-style lifesteal"""
	var ability := WeaponAbility.new()
	ability.ability_id = "lifesteal"
	ability.ability_name = "Lifesteal"
	ability.description = "Heals %d%% of damage dealt" % percent
	ability.ability_type = WeaponAbility.AbilityType.ON_HIT_EFFECT
	ability.activation_rate = 100
	ability.effect_data = {"lifesteal_percent": percent}
	return ability


static func create_devil_ability() -> WeaponAbility:
	"""Devil weapons may backfire and damage user"""
	var ability := WeaponAbility.new()
	ability.ability_id = "devil"
	ability.ability_name = "Devil"
	ability.description = "May damage wielder instead (31% chance)"
	ability.ability_type = WeaponAbility.AbilityType.SPECIAL
	ability.activation_rate = 31
	ability.effect_data = {"backfire": true}
	return ability


# --- Basic Weapons ---
static func create_iron_sword() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Iron Sword"
	weapon.weapon_id = "iron_sword"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.SLASHING
	weapon.might = 5
	weapon.hit_bonus = 90
	weapon.crit_bonus = 0
	weapon.weight = 5
	weapon.range_min = 1
	weapon.range_max = 1
	weapon.required_rank = WeaponProficiency.ProficiencyRank.E
	weapon.cost = 460
	return weapon


static func create_steel_sword() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Steel Sword"
	weapon.weapon_id = "steel_sword"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.SLASHING
	weapon.might = 8
	weapon.hit_bonus = 75
	weapon.crit_bonus = 0
	weapon.weight = 10
	weapon.range_min = 1
	weapon.range_max = 1
	weapon.required_rank = WeaponProficiency.ProficiencyRank.D
	weapon.cost = 600
	return weapon


static func create_silver_sword() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Silver Sword"
	weapon.weapon_id = "silver_sword"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.SLASHING
	weapon.might = 13
	weapon.hit_bonus = 75
	weapon.crit_bonus = 0
	weapon.weight = 8
	weapon.range_min = 1
	weapon.range_max = 1
	weapon.required_rank = WeaponProficiency.ProficiencyRank.A
	weapon.cost = 1200
	return weapon


# --- Lances ---
static func create_iron_lance() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Iron Lance"
	weapon.weapon_id = "iron_lance"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.PIERCING
	weapon.might = 7
	weapon.hit_bonus = 80
	weapon.crit_bonus = 0
	weapon.weight = 8
	weapon.range_min = 1
	weapon.range_max = 1
	weapon.required_rank = WeaponProficiency.ProficiencyRank.E
	weapon.cost = 360
	return weapon


static func create_steel_lance() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Steel Lance"
	weapon.weapon_id = "steel_lance"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.PIERCING
	weapon.might = 10
	weapon.hit_bonus = 70
	weapon.crit_bonus = 0
	weapon.weight = 13
	weapon.range_min = 1
	weapon.range_max = 1
	weapon.required_rank = WeaponProficiency.ProficiencyRank.D
	weapon.cost = 480
	return weapon


static func create_javelin() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Javelin"
	weapon.weapon_id = "javelin"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.PIERCING
	weapon.might = 6
	weapon.hit_bonus = 65
	weapon.crit_bonus = 0
	weapon.weight = 11
	weapon.range_min = 1
	weapon.range_max = 2  # Can attack at range!
	weapon.required_rank = WeaponProficiency.ProficiencyRank.E
	weapon.cost = 300
	return weapon


# --- Axes ---
static func create_iron_axe() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Iron Axe"
	weapon.weapon_id = "iron_axe"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.STRIKING
	weapon.might = 8
	weapon.hit_bonus = 75
	weapon.crit_bonus = 0
	weapon.weight = 10
	weapon.range_min = 1
	weapon.range_max = 1
	weapon.required_rank = WeaponProficiency.ProficiencyRank.E
	weapon.cost = 270
	return weapon


static func create_hand_axe() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Hand Axe"
	weapon.weapon_id = "hand_axe"
	weapon.category = Weapon.WeaponCategory.PHYSICAL
	weapon.physical_type = Weapon.PhysicalDamageType.STRIKING
	weapon.might = 7
	weapon.hit_bonus = 60
	weapon.crit_bonus = 0
	weapon.weight = 12
	weapon.range_min = 1
	weapon.range_max = 2  # Can attack at range!
	weapon.required_rank = WeaponProficiency.ProficiencyRank.E
	weapon.cost = 300
	return weapon


# --- Special Weapons with Abilities ---
static func create_brave_sword() -> Weapon:
	var weapon := create_steel_sword()
	weapon.weapon_name = "Brave Sword"
	weapon.weapon_id = "brave_sword"
	weapon.might = 9
	weapon.weight = 11
	weapon.required_rank = WeaponProficiency.ProficiencyRank.C
	weapon.cost = 2000
	weapon.abilities = [create_brave_ability()]
	return weapon


static func create_killer_lance() -> Weapon:
	var weapon := create_iron_lance()
	weapon.weapon_name = "Killer Lance"
	weapon.weapon_id = "killer_lance"
	weapon.might = 9
	weapon.hit_bonus = 75
	weapon.crit_bonus = 30
	weapon.weight = 9
	weapon.required_rank = WeaponProficiency.ProficiencyRank.C
	weapon.cost = 1200
	weapon.abilities = [create_killer_ability()]
	return weapon


static func create_armorslayer() -> Weapon:
	var weapon := create_iron_sword()
	weapon.weapon_name = "Armorslayer"
	weapon.weapon_id = "armorslayer"
	weapon.might = 8
	weapon.weight = 11
	weapon.required_rank = WeaponProficiency.ProficiencyRank.D
	weapon.cost = 1260
	weapon.abilities = [create_effective_ability("armored")]
	weapon.effectiveness_types = ["armored"]
	return weapon


static func create_horseslayer() -> Weapon:
	var weapon := create_iron_lance()
	weapon.weapon_name = "Horseslayer"
	weapon.weapon_id = "horseslayer"
	weapon.might = 7
	weapon.weight = 9
	weapon.required_rank = WeaponProficiency.ProficiencyRank.D
	weapon.cost = 940
	weapon.abilities = [create_effective_ability("cavalry")]
	weapon.effectiveness_types = ["cavalry"]
	return weapon


static func create_hammer() -> Weapon:
	var weapon := create_iron_axe()
	weapon.weapon_name = "Hammer"
	weapon.weapon_id = "hammer"
	weapon.might = 10
	weapon.hit_bonus = 55
	weapon.weight = 15
	weapon.required_rank = WeaponProficiency.ProficiencyRank.D
	weapon.cost = 800
	weapon.abilities = [create_effective_ability("armored")]
	weapon.effectiveness_types = ["armored"]
	return weapon


# --- Magic Weapons ---
static func create_fire_tome() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Fire"
	weapon.weapon_id = "fire_tome"
	weapon.category = Weapon.WeaponCategory.MAGICAL
	weapon.magical_type = Weapon.MagicalDamageType.FIRE
	weapon.might = 5
	weapon.hit_bonus = 90
	weapon.crit_bonus = 0
	weapon.weight = 4
	weapon.range_min = 1
	weapon.range_max = 2
	weapon.required_rank = WeaponProficiency.ProficiencyRank.E
	weapon.cost = 530
	return weapon


static func create_elfire_tome() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Elfire"
	weapon.weapon_id = "elfire_tome"
	weapon.category = Weapon.WeaponCategory.MAGICAL
	weapon.magical_type = Weapon.MagicalDamageType.FIRE
	weapon.might = 10
	weapon.hit_bonus = 85
	weapon.crit_bonus = 0
	weapon.weight = 7
	weapon.range_min = 1
	weapon.range_max = 2
	weapon.required_rank = WeaponProficiency.ProficiencyRank.C
	weapon.cost = 1150
	return weapon


static func create_nosferatu_tome() -> Weapon:
	var weapon := Weapon.new()
	weapon.weapon_name = "Nosferatu"
	weapon.weapon_id = "nosferatu_tome"
	weapon.category = Weapon.WeaponCategory.MAGICAL
	weapon.magical_type = Weapon.MagicalDamageType.DARK
	weapon.might = 10
	weapon.hit_bonus = 70
	weapon.crit_bonus = 0
	weapon.weight = 12
	weapon.range_min = 1
	weapon.range_max = 2
	weapon.required_rank = WeaponProficiency.ProficiencyRank.B
	weapon.cost = 3900
	weapon.abilities = [create_lifesteal_ability(50)]
	return weapon


# --- Starter Kits ---
static func create_knight_starter_kit() -> Array[Weapon]:
	"""Starting weapons for a knight"""
	return [
		create_iron_sword(),
		create_iron_lance()
	]


static func create_fighter_starter_kit() -> Array[Weapon]:
	"""Starting weapons for a fighter"""
	return [
		create_iron_axe()
	]


static func create_mage_starter_kit() -> Array[Weapon]:
	"""Starting weapons for a mage"""
	return [
		create_fire_tome()
	]


static func create_cavalier_starter_kit() -> Array[Weapon]:
	"""Starting weapons for a cavalier"""
	return [
		create_iron_sword(),
		create_javelin()
	]


# --- Validation Helper ---
static func validate_weapon(weapon: Weapon) -> Array[String]:
	"""Validate a created weapon"""
	if not weapon:
		return ["Weapon is null"]
	return weapon.validate_weapon()


## Get all basic weapons (for shop, testing, etc.)
static func get_all_basic_weapons() -> Array[Weapon]:
	return [
		create_iron_sword(),
		create_steel_sword(),
		create_silver_sword(),
		create_iron_lance(),
		create_steel_lance(),
		create_javelin(),
		create_iron_axe(),
		create_hand_axe(),
		create_fire_tome()
	]


## Get all special weapons
static func get_all_special_weapons() -> Array[Weapon]:
	return [
		create_brave_sword(),
		create_killer_lance(),
		create_armorslayer(),
		create_horseslayer(),
		create_hammer(),
		create_elfire_tome(),
		create_nosferatu_tome()
	]


## Create weapon from name or ID (for save/load)
static func create_weapon_from_name(name: String) -> Weapon:
	var n = name.to_lower().replace(" ", "_")
	
	match n:
		"iron_sword": return create_iron_sword()
		"steel_sword": return create_steel_sword()
		"silver_sword": return create_silver_sword()
		"brave_sword": return create_brave_sword()
		"armorslayer": return create_armorslayer()
		
		"iron_lance": return create_iron_lance()
		"steel_lance": return create_steel_lance()
		"javelin": return create_javelin()
		"killer_lance": return create_killer_lance()
		"horseslayer": return create_horseslayer()
		
		"iron_axe": return create_iron_axe()
		"hand_axe": return create_hand_axe()
		"hammer": return create_hammer()
		
		"fire", "fire_tome": return create_fire_tome()
		"elfire", "elfire_tome": return create_elfire_tome()
		"nosferatu", "nosferatu_tome": return create_nosferatu_tome()
		
	push_warning("WeaponFactory: Unknown weapon name '%s'" % name)
	return null
