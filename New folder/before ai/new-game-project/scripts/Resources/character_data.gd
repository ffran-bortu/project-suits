class_name CharacterData
extends Resource
## Character data and progression tracking
##
## BEST PRACTICE: Resource for persistent character data

## Basic info
@export var character_name: String = "Hero"
@export var portrait: Texture2D
@export var frontline_sprite: Texture2D
@export var backline_sprite: Texture2D

## Classes (dual class system)
@export_group("Classes")
@export var primary_class: CharacterClass
@export var secondary_class: CharacterClass
@export var hidden_class: CharacterClass  # Unlockable, can be null

## Class selection
var using_primary: bool = true  # Which class is active

## Levels (separate for each class)
@export_group("Progression")
@export var primary_level: int = 1
@export var secondary_level: int = 1
@export var hidden_level: int = 1

## Experience (separate for positions)
var frontline_exp: int = 0
var backline_exp: int = 0

## Current stats (calculated from class + level)
var current_hp: int = 20
var max_hp: int = 20
var str: int = 5
var mag: int = 3
var spd: int = 5
var skill: int = 5
var luck: int = 5
var def: int = 4
var res: int = 2

## Bond/Support data
@export_group("Bonds")
var bond_levels: Dictionary = {}     # partner_name -> int (0-4)
var bond_points: Dictionary = {}     # partner_name -> int
var s_or_aplus_partner: String = ""  # Exclusive max rank partner

## Support conversations unlocked
var unlocked_conversations: Dictionary = {}  # partner_name -> ["C", "B", "A"]

## Character-specific unique skills
@export var unique_skill_names: Array[String] = []

## Get current active class
##
## @param in_frontline: Whether checking for frontline position
## @return: Active CharacterClass
func get_current_class(in_frontline: bool) -> CharacterClass:
	var current_class = primary_class if using_primary else secondary_class
	
	if not current_class:
		push_error("CharacterData: No class assigned to " + character_name)
		return null
	
	# Validate position compatibility (BEST PRACTICE: fail-fast)
	if in_frontline and not current_class.can_be_frontline:
		push_warning("%s class cannot be frontline!" % current_class.class_name)
	if not in_frontline and not current_class.can_be_backline:
		push_warning("%s class cannot be backline!" % current_class.class_name)
	
	return current_class

## Switch between primary and secondary class
func switch_class():
	using_primary = not using_primary
	# Stats will be recalculated by DuoUnit/SoloUnit

## Get current level for active class
func get_current_level() -> int:
	if using_primary:
		return primary_level
	else:
		return secondary_level

## Gain experience in a position
##
## @param in_frontline: Whether XP is for frontline position
## @param amount: XP amount
func gain_exp(in_frontline: bool, amount: int):
	if in_frontline:
		frontline_exp += amount
	else:
		backline_exp += amount
	
	# Check for level up
	# TODO: Implement level up logic

## Calculate stat for current level and position
##
## @param stat_name: Stat to calculate
## @param in_frontline: Position
## @return: Stat value
func get_stat(stat_name: String, in_frontline: bool) -> int:
	var current_class = get_current_class(in_frontline)
	if not current_class:
		return 0
	
	var level = get_current_level()
	return current_class.get_stat_at_level(stat_name, level, in_frontline)
