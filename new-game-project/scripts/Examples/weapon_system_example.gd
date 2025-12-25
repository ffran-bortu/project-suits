"""
FILE: weapon_system_example.gd
PURPOSE: Complete weapon system usage examples: setup, triangle, proficiency, abilities, save/load.
FUNCTIONS: _ready, example_basic_setup, example_weapon_triangle, example_proficiency_progression, example_weapon_abilities, example_save_load, example_combat_calculation - 7 total
NOTES: Demonstrates WeaponInventory, WeaponProficiency, WeaponFactory. Shows weapon triangle calculations (Slashing>Striking>Piercing>Slashing), rank progression (E→D→C with XP), special abilities (Brave, Killer, Armorslayer, Nosferatu/Lifesteal), serialization/deserialization.
"""


extends Node

## Examples demonstrating the complete weapon system

func _ready() -> void:
	print("=== Weapon System Examples ===\n")
	
	example_basic_setup()
	print("\n" + "=".repeat(50) + "\n")
	
	example_weapon_triangle()
	print("\n" + "=".repeat(50) + "\n")
	
	example_proficiency_progression()
	print("\n" + "=".repeat(50) + "\n")
	
	example_weapon_abilities()
	print("\n" + "=".repeat(50) + "\n")
	
	example_save_load()


## Example 1: Basic Setup
func example_basic_setup() -> void:
	print("EXAMPLE 1: Basic Weapon Setup")
	print("-" * 30)
	
	# Create inventory
	var inventory = WeaponInventory.new()
	
	# Add weapons using factory
	inventory.add_weapon(WeaponFactory.create_iron_sword())
	inventory.add_weapon(WeaponFactory.create_iron_lance())
	inventory.add_weapon(WeaponFactory.create_fire_tome())
	
	# Equip first weapon
	inventory.equip_weapon_by_index(0)
	
	# Display inventory
	print("Inventory created with 3 weapons")
	print("Equipped: %s" % inventory.get_equipped_weapon().weapon_name)
	
	# Use weapon
	for i in range(3):
		inventory.use_weapon()
		print("Used weapon - Durability now: %d" % inventory.get_weapon_durability(inventory.get_equipped_weapon()))


## Example 2: Weapon Triangle
func example_weapon_triangle() -> void:
	print("EXAMPLE 2: Weapon Triangle")
	print("-" * 30)
	
	# Create different weapon types
	var sword = WeaponFactory.create_iron_sword()  # Slashing
	var lance = WeaponFactory.create_iron_lance()  # Piercing
	var axe = WeaponFactory.create_iron_axe()      # Striking
	
	var inventory = WeaponInventory.new()
	
	# Lance vs Sword (Lance has advantage)
	print("\nLance vs Sword (Piercing > Slashing):")
	var triangle1 = inventory.calculate_triangle_advantage(lance, sword)
	print("  Hit Bonus: %+d" % triangle1.hit_bonus)
	print("  Damage Bonus: %+d" % triangle1.damage_bonus)
	
	# Sword vs Axe (Sword has advantage)
	print("\nSword vs Axe (Slashing > Striking):")
	var triangle2 = inventory.calculate_triangle_advantage(sword, axe)
	print("  Hit Bonus: %+d" % triangle2.hit_bonus)
	print("  Damage Bonus: %+d" % triangle2.damage_bonus)
	
	# Axe vs Lance (Axe has advantage)
	print("\nAxe vs Lance (Striking > Piercing):")
	var triangle3 = inventory.calculate_triangle_advantage(axe, lance)
	print("  Hit Bonus: %+d" % triangle3.hit_bonus)
	print("  Damage Bonus: %+d" % triangle3.damage_bonus)
	
	# Reverse (disadvantage)
	print("\nSword vs Lance (Slashing < Piercing):")
	var triangle4 = inventory.calculate_triangle_advantage(sword, lance)
	print("  Hit Bonus: %+d" % triangle4.hit_bonus)
	print("  Damage Bonus: %+d" % triangle4.damage_bonus)


## Example 3: Proficiency Progression
func example_proficiency_progression() -> void:
	print("EXAMPLE 3: Proficiency Progression")
	print("-" * 30)
	
	var proficiency = WeaponProficiency.new()
	
	# Initialize starting proficiency
	proficiency.initialize_proficiency(
		Weapon.PhysicalDamageType.SLASHING,
		WeaponProficiency.ProficiencyRank.E
	)
	
	print("Starting proficiency: Rank E")
	print("Experience: %d" % proficiency.get_experience(Weapon.PhysicalDamageType.SLASHING))
	
	# Simulate using weapon
	print("\nUsing weapon in combat...")
	for i in range(35):
		var ranked_up = proficiency.add_experience(Weapon.PhysicalDamageType.SLASHING, 1)
		if ranked_up:
			var new_rank = proficiency.get_rank(Weapon.PhysicalDamageType.SLASHING)
			print("  RANK UP! Now Rank %s" % WeaponProficiency.RANK_NAMES[new_rank])
	
	# Final status
	var final_rank = proficiency.get_rank(Weapon.PhysicalDamageType.SLASHING)
	var final_exp = proficiency.get_experience(Weapon.PhysicalDamageType.SLASHING)
	var progress = proficiency.get_rank_progress(Weapon.PhysicalDamageType.SLASHING) * 100
	var bonus = proficiency.get_rank_bonus(final_rank)
	
	print("\nFinal Status:")
	print("  Rank: %s" % WeaponProficiency.RANK_NAMES[final_rank])
	print("  Experience: %d" % final_exp)
	print("  Progress to next: %.0f%%" % progress)
	print("  Hit/Avoid Bonus: +%d" % bonus)


## Example 4: Weapon Abilities
func example_weapon_abilities() -> void:
	print("EXAMPLE 4: Weapon Abilities")
	print("-" * 30)
	
	# Create weapons with abilities
	var brave_sword = WeaponFactory.create_brave_sword()
	var killer_lance = WeaponFactory.create_killer_lance()
	var armorslayer = WeaponFactory.create_armorslayer()
	var nosferatu = WeaponFactory.create_nosferatu_tome()
	
	print("\n1. Brave Sword:")
	print("   Abilities: %d" % brave_sword.abilities.size())
	if brave_sword.has_ability("brave"):
		var ability = brave_sword.get_ability("brave")
		print("   - %s: %s" % [ability.ability_name, ability.description])
		print("   - Attacks per round: %d" % ability.get_effect("attacks_per_round", 1))
	
	print("\n2. Killer Lance:")
	print("   Abilities: %d" % killer_lance.abilities.size())
	if killer_lance.has_ability("killer"):
		var ability = killer_lance.get_ability("killer")
		print("   - %s: %s" % [ability.ability_name, ability.description])
		print("   - Crit bonus: +%d%%" % ability.get_effect("crit_bonus", 0))
	
	print("\n3. Armorslayer:")
	print("   Abilities: %d" % armorslayer.abilities.size())
	print("   - Effective vs: %s" % ", ".join(armorslayer.effectiveness_types))
	print("   - Damage multiplier: ×%.1f" % armorslayer.effectiveness_multiplier)
	print("   - Effectiveness vs armored: ×%.1f" % armorslayer.get_effectiveness("armored"))
	print("   - Effectiveness vs cavalry: ×%.1f" % armorslayer.get_effectiveness("cavalry"))
	
	print("\n4. Nosferatu:")
	print("   Abilities: %d" % nosferatu.abilities.size())
	if nosferatu.has_ability("lifesteal"):
		var ability = nosferatu.get_ability("lifesteal")
		print("   - %s: %s" % [ability.ability_name, ability.description])
		print("   - Lifesteal: %d%%" % ability.get_effect("lifesteal_percent", 0))


## Example 5: Save/Load
func example_save_load() -> void:
	print("EXAMPLE 5: Save/Load System")
	print("-" * 30)
	
	# Create inventory with weapons
	var inventory = WeaponInventory.new()
	inventory.add_weapon(WeaponFactory.create_iron_sword(), 35)
	inventory.add_weapon(WeaponFactory.create_steel_lance(), 28)
	inventory.equip_weapon_by_index(0)
	
	# Add proficiency
	var proficiency = inventory.get_proficiency()
	proficiency.initialize_proficiency(Weapon.PhysicalDamageType.SLASHING, WeaponProficiency.ProficiencyRank.C)
	proficiency.add_experience(Weapon.PhysicalDamageType.SLASHING, 45)
	
	print("Original Inventory:")
	print("  Weapons: %d" % inventory.weapons.size())
	print("  Equipped: %s" % inventory.get_equipped_weapon().weapon_name)
	print("  Durability: %d" % inventory.get_weapon_durability(inventory.get_equipped_weapon()))
	print("  Proficiency: Rank %s" % WeaponProficiency.RANK_NAMES[proficiency.get_rank(Weapon.PhysicalDamageType.SLASHING)])
	
	# Serialize
	var save_data = inventory.serialize()
	print("\nSerialized to save data")
	
	# Create new inventory and deserialize
	var loaded_inventory = WeaponInventory.new()
	loaded_inventory.deserialize(save_data)
	
	var loaded_proficiency = loaded_inventory.get_proficiency()
	
	print("\nLoaded Inventory:")
	print("  Weapons: %d" % loaded_inventory.weapons.size())
	print("  Equipped: %s" % loaded_inventory.get_equipped_weapon().weapon_name)
	print("  Durability: %d" % loaded_inventory.get_weapon_durability(loaded_inventory.get_equipped_weapon()))
	print("  Proficiency: Rank %s" % WeaponProficiency.RANK_NAMES[loaded_proficiency.get_rank(Weapon.PhysicalDamageType.SLASHING)])
	
	print("\n✓ Save/Load successful!")


## Bonus: Complete Combat Example
func example_combat_calculation() -> void:
	print("BONUS: Complete Combat Calculation")
	print("-" * 30)
	
	# Setup attacker
	var attacker_inv = WeaponInventory.new()
	attacker_inv.add_weapon(WeaponFactory.create_steel_lance())  # Piercing
	attacker_inv.equip_weapon_by_index(0)
	
	var attacker_prof = attacker_inv.get_proficiency()
	attacker_prof.initialize_proficiency(Weapon.PhysicalDamageType.PIERCING, WeaponProficiency.ProficiencyRank.B)
	
	# Setup defender
	var defender_inv = WeaponInventory.new()
	defender_inv.add_weapon(WeaponFactory.create_iron_sword())  # Slashing
	defender_inv.equip_weapon_by_index(0)
	
	# Calculate triangle
	var triangle = attacker_inv.calculate_triangle_advantage(
		attacker_inv.get_equipped_weapon(),
		defender_inv.get_equipped_weapon()
	)
	
	# Calculate bonuses
	var prof_bonus = attacker_prof.get_rank_bonus(attacker_prof.get_rank(Weapon.PhysicalDamageType.PIERCING))
	
	print("Attacker: Steel Lance (Piercing)")
	print("Defender: Iron Sword (Slashing)")
	print("\nTriangle: Piercing > Slashing")
	print("  Triangle Hit Bonus: %+d" % triangle.hit_bonus)
	print("  Triangle Damage Bonus: %+d" % triangle.damage_bonus)
	print("  Proficiency Bonus (B Rank): %+d" % prof_bonus)
	print("\nTotal Hit Bonus: %+d" % (triangle.hit_bonus + prof_bonus))
	print("Total Damage Bonus: %+d" % triangle.damage_bonus)
