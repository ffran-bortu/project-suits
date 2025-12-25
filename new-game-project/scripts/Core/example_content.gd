"""
FILE: example_content.gd
PURPOSE: Provides static factory methods to create example classes and characters for testing.

OVERVIEW:
This static utility class creates pre-configured example content programmatically: Warrior, Mage, and
Commander classes with stats/growth rates, and character instances using those classes. Used for
rapid testing without needing to create resource files. All methods are static for easy access.

FUNCTIONS IN THIS FILE:

1. create_warrior_class() -> CharacterClass
   - What it does: Creates physical frontline fighter class with high STR/HP/DEF
   - Uses: Testing and example scenarios
   - Returns: CharacterClass configured as Warrior

2. create_mage_class() -> CharacterClass
   - What it does: Creates magical backline attacker with high MAG/RES
   - Uses: Testing and example scenarios
   - Returns: CharacterClass configured as Mage

3. create_commander_class() -> CharacterClass
   - What it does: Creates balanced leader class that can be frontline or backline
   - Uses: Testing and example scenarios
   - Returns: CharacterClass configured as Commander

4. create_character(char_name: String, primary: CharacterClass, secondary: CharacterClass, unique_skills: Array[String] = []) -> CharacterData
   - What it does: Creates character with given name, classes, and optional unique skills, initializes stats from primary class
   - Uses: Creating test characters for battles
   - Returns: CharacterData fully configured

NOTES:
- Static class (all methods static, use ExampleContent.create_warrior_class() directly)
- Warrior: Can be frontline only, uses Sword/Axe, high STR/HP/DEF growth
- Mage: Can be backline only, uses Tome, high MAG/RES growth
- Commander: Can be both positions, uses Sword/Lance, balanced growth
- Base stats boosted for testing (includes implicit weapon attack)
- Character initialization copies primary class base stats to character
- Skill system temporarily disabled (commented out functions for basic attack, power strike, lone wolf)
- No dependencies (leaf utility class)
"""

class_name ExampleContent
extends RefCounted
## Example content creator and loader
##
## Creates example classes, characters, and skills programmatically for testing
## All methods are static - this class doesn't need to be instantiated

static func create_warrior_class() -> CharacterClass:
	var warrior = CharacterClass.new()
	warrior.display_name = "Warrior"
	warrior.archetype = CharacterClass.ClassArchetype.WARRIOR
	warrior.description = "Physical frontline fighter"
	warrior.can_be_frontline = true
	warrior.can_be_backline = false
	
	# Base stats
	warrior.base_hp = 25
	warrior.base_str = 15  # Boosted for testing (includes implicit weapon attack)
	warrior.base_mag = 1
	warrior.base_spd = 4
	warrior.base_skill = 5
	warrior.base_luck = 4
	warrior.base_def = 5
	warrior.base_res = 2
	
	# Frontline bonuses
	warrior.frontline_str_bonus = 2
	warrior.frontline_def_bonus = 3
	warrior.frontline_hp_bonus = 5
	
	# Growth rates
	warrior.hp_growth = 60
	warrior.str_growth = 50
	warrior.mag_growth = 10
	warrior.spd_growth = 30
	warrior.skill_growth = 35
	warrior.luck_growth = 35
	warrior.def_growth = 40
	warrior.res_growth = 20
	
	var warrior_weapons: Array[String] = ["Sword", "Axe"]
	warrior.usable_weapon_types = warrior_weapons
	return warrior

static func create_mage_class() -> CharacterClass:
	var mage = CharacterClass.new()
	mage.display_name = "Mage"
	mage.archetype = CharacterClass.ClassArchetype.MAGE
	mage.description = "Magical backline attacker"
	mage.can_be_frontline = false
	mage.can_be_backline = true
	
	# Base stats
	mage.base_hp = 18
	mage.base_str = 10  # Boosted for testing (includes implicit weapon attack)
	mage.base_mag = 15  # Boosted for testing
	mage.base_spd = 5
	mage.base_skill = 6
	mage.base_luck = 4
	mage.base_def = 2
	mage.base_res = 6
	
	# Backline bonuses
	mage.backline_mag_bonus = 3
	mage.backline_spd_bonus = 2
	mage.backline_res_bonus = 3
	
	# Growth rates
	mage.hp_growth = 40
	mage.str_growth = 10
	mage.mag_growth = 60
	mage.spd_growth = 40
	mage.skill_growth = 40
	mage.luck_growth = 30
	mage.def_growth = 20
	mage.res_growth = 50
	
	var mage_weapons: Array[String] = ["Tome"]
	mage.usable_weapon_types = mage_weapons
	return mage

static func create_commander_class() -> CharacterClass:
	var commander = CharacterClass.new()
	commander.display_name = "Commander"
	commander.archetype = CharacterClass.ClassArchetype.COMMANDER
	commander.description = "Frontline leader and buffer"
	commander.can_be_frontline = true
	commander.can_be_backline = true
	
	# Base stats - balanced
	commander.base_hp = 22
	commander.base_str = 5
	commander.base_mag = 4
	commander.base_spd = 5
	commander.base_skill = 6
	commander.base_luck = 5
	commander.base_def = 4
	commander.base_res = 4
	
	# Position bonuses
	commander.frontline_str_bonus = 1
	commander.frontline_def_bonus = 2
	commander.frontline_hp_bonus = 3
	commander.backline_mag_bonus = 1
	commander.backline_spd_bonus = 2
	commander.backline_res_bonus = 2
	
	# Growth rates - balanced
	commander.hp_growth = 50
	commander.str_growth = 40
	commander.mag_growth = 35
	commander.spd_growth = 45
	commander.skill_growth = 50
	commander.luck_growth = 40
	commander.def_growth = 35
	commander.res_growth = 35
	
	var commander_weapons: Array[String] = ["Sword", "Lance"]
	commander.usable_weapon_types = commander_weapons
	return commander

static func create_character(char_name: String, primary: CharacterClass, secondary: CharacterClass, unique_skills: Array[String] = []) -> CharacterData:
	var character = CharacterData.new()
	character.character_name = char_name
	character.primary_class = primary
	character.secondary_class = secondary
	character.using_primary = true
	character.primary_level = 1
	character.secondary_level = 1
	character.unique_skill_names = unique_skills
	
	# Initialize stats from class
	character.max_hp = primary.base_hp
	character.current_hp = character.max_hp
	character.strength = primary.base_str
	character.mag = primary.base_mag
	character.spd = primary.base_spd
	character.skill = primary.base_skill
	character.luck = primary.base_luck
	character.def = primary.base_def
	character.res = primary.base_res
	
	print("ExampleContent.create_character: %s created with STR=%d (from class base_str=%d)" % [char_name, character.strength, primary.base_str])
	
	return character

## DISABLED: Skill system temporarily disabled
# static func create_basic_attack_skill() -> Skill:
# 	var skill = Skill.new()
# 	skill.skill_name = "Basic Attack"
# 	skill.description = "Standard weapon attack"
# 	skill.skill_type = Skill.SkillType.COMBAT
# 	skill.learned_at_level = 1
# 	skill.damage_bonus = 0
# 	skill.hit_bonus = 0
# 	skill.crit_bonus = 0
# 	skill.activation_chance = 100
# 	return skill

## DISABLED: Skill system temporarily disabled
# static func create_power_strike_skill() -> Skill:
# 	var skill = Skill.new()
# 	skill.skill_name = "Power Strike"
# 	skill.description = "+3 damage on hit"
# 	skill.skill_type = Skill.SkillType.COMBAT
# 	skill.learned_at_level = 3
# 	skill.damage_bonus = 3
# 	skill.hit_bonus = -5
# 	skill.crit_bonus = 0
# 	skill.activation_chance = 100
# 	return skill

## DISABLED: Skill system temporarily disabled
# static func create_lone_wolf_skill() -> Skill:
# 	var skill = Skill.new()
# 	skill.skill_name = "Lone Wolf"
# 	skill.description = "+20% all stats when solo"
# 	skill.skill_type = Skill.SkillType.PASSIVE
# 	skill.learned_at_level = 1
# 	skill.str_bonus = 2
# 	skill.spd_bonus = 2
# 	skill.def_bonus = 2
# 	skill.activation_chance = 100
# 	return skill
