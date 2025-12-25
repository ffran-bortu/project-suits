"""
FILE: unit_class.gd
PURPOSE: Legacy simple unit class resource with base stats and combat properties.

OVERVIEW:
This is a simpler, legacy version of character class data that stores base stats and combat properties
without the advanced features of CharacterClass.gd. It defines basic unit types (Soldier, Mage, etc.)
with 8 core stats, movement range, attack range, and damage type. Note that the more comprehensive
CharacterClass resource (character_class.gd) includes growth rates, position bonuses, and caching.

FUNCTIONS IN THIS FILE:
(None - this is a simple data-only Resource with no custom functions)

NOTES:
- Simpler alternative to character_class.gd
- Contains only base stats (no growth rates or level scaling)
- DamageType enum: PHYSICAL or MAGIC
- All 8 core Fire Emblem stats: HP, STR, MAG, SKILL, SPD, LUCK, DEF, RES
- Movement and attack range properties for tactical combat
- No validation or serialization methods (pure Resource)
"""


extends Resource
class_name UnitClass

# Enum for damage type
enum DamageType {
	PHYSICAL,
	MAGIC
}

# Class display name
@export var class_name: String = "Soldier"

# Base stats (all 8 core stats)
@export var base_hp: int = 10  # Base maximum hit points
@export var base_str: int = 5  # Base Strength (physical weapon damage)
@export var base_mag: int = 0  # Base Magic (magical weapon damage)
@export var base_skill: int = 5  # Base Skill (affects hit rate and critical chance)
@export var base_spd: int = 5  # Base Speed (affects avoid and double attacks)
@export var base_luck: int = 0  # Base Luck (affects hit, avoid, crit avoid, skill activation)
@export var base_def: int = 2  # Base Defense (reduces physical damage)
@export var base_res: int = 0  # Base Resistance (reduces magical damage)

# Combat properties
@export var base_movement: int = 4  # Base movement range
@export var attack_range_min: int = 1  # Minimum attack range (1 for melee, 2+ for ranged)
@export var attack_range_max: int = 1  # Maximum attack range
@export var damage_type: DamageType = DamageType.PHYSICAL  # Physical or Magic damage







