# unit_class.gd - UnitClass Resource for defining unit classes
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

