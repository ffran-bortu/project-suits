class_name CharacterClass
extends Resource
## Defines a character class with stats, growth rates, and position bonuses
##
## BEST PRACTICE: Resource for data, can be created in editor

enum ClassArchetype {
	WARRIOR,      # Physical attacker
	MAGE,         # Magic attacker
	SUPPORT,      # Healer/buffer
	COMMANDER,    # Leader/buffer
	TANK,         # High defense
	ASSASSIN,     # High crit/speed
	ARCHER,       # Ranged physical
	CLERIC        # Healing specialist
}

## Class identification
@export var class_name: String = "Fighter"
@export var archetype: ClassArchetype = ClassArchetype.WARRIOR
@export var description: String = ""

## Position compatibility (BEST PRACTICE: explicit flags)
@export var can_be_frontline: bool = true
@export var can_be_backline: bool = true

## Base stats at level 1
@export_group("Base Stats")
@export var base_hp: int = 20
@export var base_str: int = 5
@export var base_mag: int = 3
@export var base_spd: int = 5
@export var base_skill: int = 5
@export var base_luck: int = 5
@export var base_def: int = 4
@export var base_res: int = 2

## Position-based stat bonuses (applied when in that position)
@export_group("Frontline Bonuses")
@export var frontline_str_bonus: int = 2
@export var frontline_def_bonus: int = 3
@export var frontline_hp_bonus: int = 5

@export_group("Backline Bonuses")
@export var backline_mag_bonus: int = 2
@export var backline_spd_bonus: int = 2
@export var backline_res_bonus: int = 3

## Growth rates (percentage chance to gain +1 on level up)
@export_group("Growth Rates")
@export var hp_growth: int = 50
@export var str_growth: int = 45
@export var mag_growth: int = 30
@export var spd_growth: int = 40
@export var skill_growth: int = 35
@export var luck_growth: int = 40
@export var def_growth: int = 30
@export var res_growth: int = 25

## Equipment restrictions
@export_group("Equipment")
@export var usable_weapon_types: Array[String] = ["Sword"]

## Get stat at specific level
##
## @param stat_name: Name of stat (hp, str, etc)
## @param level: Current level
## @param is_frontline: Whether unit is in frontline position
## @return: Calculated stat value
func get_stat_at_level(stat_name: String, level: int, is_frontline: bool) -> int:
	var base_stat = get_base_stat(stat_name)
	var growth = get_growth_rate(stat_name)
	
	# Random growth per level (average)
	var growth_bonus = int((level - 1) * growth / 100.0)
	
	var total = base_stat + growth_bonus
	
	# Apply position bonuses
	if is_frontline:
		total += get_frontline_bonus(stat_name)
	else:
		total += get_backline_bonus(stat_name)
	
	return total

func get_base_stat(stat_name: String) -> int:
	match stat_name:
		"hp": return base_hp
		"str": return base_str
		"mag": return base_mag
		"spd": return base_spd
		"skill": return base_skill
		"luck": return base_luck
		"def": return base_def
		"res": return base_res
	return 0

func get_growth_rate(stat_name: String) -> int:
	match stat_name:
		"hp": return hp_growth
		"str": return str_growth
		"mag": return mag_growth
		"spd": return spd_growth
		"skill": return skill_growth
		"luck": return luck_growth
		"def": return def_growth
		"res": return res_growth
	return 0

func get_frontline_bonus(stat_name: String) -> int:
	match stat_name:
		"str": return frontline_str_bonus
		"def": return frontline_def_bonus
		"hp": return frontline_hp_bonus
	return 0

func get_backline_bonus(stat_name: String) -> int:
	match stat_name:
		"mag": return backline_mag_bonus
		"spd": return backline_spd_bonus
		"res": return backline_res_bonus
	return 0
