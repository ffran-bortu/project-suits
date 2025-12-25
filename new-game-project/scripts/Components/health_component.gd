class_name HealthComponent
extends Node

## Component for managing health, damage, and death state
##
## Encapsulates all HP-related logic including max HP, current HP,
## damage calculation, healing, and death triggers.

signal health_changed(new_hp: int, old_hp: int, max_hp: int)
signal died()
signal healed(amount: int)
signal damaged(amount: int)

@export var max_health: int = 20
@export var current_health: int = 20

var is_dead: bool = false

func initialize(base_hp: int) -> void:
	max_health = base_hp
	current_health = base_hp
	is_dead = false

func take_damage(amount: int) -> void:
	if is_dead:
		return
		
	var old_hp = current_health
	current_health -= amount
	current_health = max(0, current_health)
	
	calculate_damage_signals(amount, old_hp)

func heal(amount: int) -> void:
	if is_dead:
		return
		
	var old_hp = current_health
	current_health += amount
	current_health = min(max_health, current_health)
	
	if current_health > old_hp:
		healed.emit(current_health - old_hp)
		health_changed.emit(current_health, old_hp, max_health)

func calculate_damage_signals(amount: int, old_hp: int) -> void:
	if amount > 0:
		damaged.emit(amount)
	
	if current_health != old_hp:
		health_changed.emit(current_health, old_hp, max_health)
	
	if current_health <= 0 and not is_dead:
		die()

func die() -> void:
	is_dead = true
	died.emit()

func is_alive() -> bool:
	return current_health > 0
