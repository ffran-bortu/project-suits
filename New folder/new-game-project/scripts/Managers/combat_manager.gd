# combat_manager.gd - Optimized for clean phase management
extends Node

@onready var unit_manager = get_node("../UnitManager")

var grid_3d: Node = null
var phase_manager: Node = null

# Signal for attack completion
signal attack_completed(attacker, target, damage)

func set_dependencies(grid_node: Node, phase_mgr: Node):
	grid_3d = grid_node
	phase_manager = phase_mgr

func handle_attack_target_selection(grid_pos: Vector2i, attacker):
	if not attacker:
		return
	
	# Get attack range
	var attack_cells = GridManager.get_attack_range(attacker.grid_position, attacker.attack_range)
	
	# Validate target
	if grid_pos not in attack_cells:
		return
	
	var target_unit = unit_manager.get_unit_at_position(grid_pos)
	if not target_unit or target_unit.team == attacker.team:
		return
	
	# Perform attack
	perform_attack(attacker, target_unit)

func perform_attack(attacker, target):
	print("=== ATTACK ===")
	print(attacker.unit_name, " attacks ", target.unit_name)
	
	# Calculate damage
	var damage = 5 + randi_range(-2, 2)
	damage = max(1, damage)
	
	print("Damage: ", damage)
	
	# Apply damage
	target.take_damage(damage)
	
	# Check if target died
	if not target.is_alive():
		print(target.unit_name, " has been defeated!")
		unit_manager.remove_unit(target)
		target.queue_free()
	
	# Mark attacker as acted
	attacker.mark_as_acted()
	
	# Clean up
	if grid_3d:
		grid_3d.clear_attack_highlights()
	
	# Emit signal for any listeners
	attack_completed.emit(attacker, target, damage)
	
	# If player unit attacked, end their turn immediately
	if attacker.team == 0:  # Player unit
		print("Player unit attacked, ending turn")
		if phase_manager:
			phase_manager.end_current_unit_turn()
