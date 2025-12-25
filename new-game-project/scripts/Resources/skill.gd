"""
FILE: skill.gd
PURPOSE: TEMPORARILY DISABLED - Skill system for combat/support/utility abilities.

OVERVIEW:
This file contains the Skill resource class system, which has been temporarily disabled to resolve
compilation errors. The skill system is planned to be re-enabled in a future update. When active,
it will provide combat skills, support skills, utility abilities, and passive/triggered effects with
trait requirements, activation chances, cooldowns, and per-battle usage limits.

FUNCTIONS IN THIS FILE:
(All commented out - no active functions)

When re-enabled, this file will include:
- can_use(unit): Check if skill can be used by unit (traits, cooldown, uses)
- _unit_has_trait(unit, trait): Helper to check unit traits
- reset_for_battle(): Reset cooldowns and usage counters at battle start

NOTES:
- Entire file is commented out to prevent compilation errors
- Skill system temporarily disabled due to refactoring conflicts
- Planned enums: SkillCategory, ActivationType, TargetType
- Skill costs (MP/HP), cool downs, and per-battle limits planned
- Will integrate with trait system when re-enabled
"""



## DISABLED: Skill class
# class_name Skill
# extends Resource
# 
# enum SkillCategory { COMBAT, SUPPORT, UTILITY, REACTION, UNIQUE }
# enum ActivationType { ACTIVE, PASSIVE, TRIGGERED, AUTO }
# enum TargetType { SELF, SINGLE_ALLY, SINGLE_ENEMY, ALL_ALLIES, ALL_ENEMIES, AREA }
# 
# # Basic Info
# @export var skill_name: String = "Attack"
# @export var description: String = ""
# @export var skill_id: String = ""
# @export var icon: Texture2D
# 
# # Classification
# @export var skill_category: SkillCategory = SkillCategory.COMBAT
# @export var activation_type: ActivationType = ActivationType.ACTIVE
# @export var target_type: TargetType = TargetType.SINGLE_ENEMY
# 
# # Requirements
# @export var learned_at_level: int = 1
# @export var required_traits: Array = []
# @export var forbidden_traits: Array = []
# 
# # Activation
# @export var activation_chance: int = 100
# @export var range: int = 1
# 
# # Cost
# @export var mp_cost: int = 0
# @export var hp_cost: int = 0
# @export var cooldown_turns: int = 0
# @export var uses_per_battle: int = 0
# 
# # Runtime
# var current_cooldown: int = 0
# var uses_remaining: int = 0
# 
# func can_use(unit: Node) -> bool:
# 	if unit == null:
# 		return false
# 	
# 	# Check required traits
# 	for trait in required_traits:
# 		if not _unit_has_trait(unit, trait):
# 			return false
# 	
# 	# Check forbidden traits
# 	for trait in forbidden_traits:
# 		if _unit_has_trait(unit, trait):
# 			return false
# 	
# 	# Cooldown check
# 	if current_cooldown > 0:
# 		return false
# 	
# 	# Uses per battle check
# 	if uses_per_battle > 0 and uses_remaining <= 0:
# 		return false
# 	
# 	return true
# 
# func _unit_has_trait(unit: Node, trait: String) -> bool:
# 	if unit.has_method("has_trait"):
# 		return unit.has_trait(trait)
# 	return false
# 
# func reset_for_battle() -> void:
# 	current_cooldown = 0
# 	if uses_per_battle > 0:
# 		uses_remaining = uses_per_battle
# 	else:
# 		uses_remaining = 999
