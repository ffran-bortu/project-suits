# combat_forecast.gd - Optimized combat forecast UI
extends Panel

signal confirmed
signal cancelled

# Use @export for inspector access if needed
@export_category("Attacker Stats")
@onready var attacker_name = $HBox/Attackerstats/Name
@onready var attacker_hp = $HBox/Attackerstats/HP
@onready var attacker_dmg = $HBox/Attackerstats/Dmg
@onready var attacker_hit = $HBox/Attackerstats/Hit
@onready var attacker_crit = $HBox/Attackerstats/Crit

@export_category("Defender Stats")
@onready var defender_name = $HBox/DefenderStats/Name
@onready var defender_hp = $HBox/DefenderStats/HP
@onready var defender_dmg = $HBox/DefenderStats/Dmg
@onready var defender_hit = $HBox/DefenderStats/Hit
@onready var defender_crit = $HBox/DefenderStats/Crit

# Constants for formatting
const HP_FORMAT = "HP: %d -> %d"
const DMG_FORMAT = "Dmg: %d"
const STAT_FORMAT = "%d%%"

func _ready():
	focus_mode = Control.FOCUS_ALL
	set_process_input(false)  # Start disabled

# Override visibility to manage input
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(visible)

func setup(attacker, defender, combat_stats):
	if not attacker or not defender:
		return
	
	# Set attacker stats
	attacker_name.text = attacker.unit_name
	
	# Predict attacker HP after combat (considering counter)
	var attacker_predicted_hp = attacker.current_health
	
	# Set defender stats
	defender_name.text = defender.unit_name
	
	# Predict defender HP after initial attack
	var defender_predicted_hp = max(0, defender.current_health - combat_stats.damage)
	if combat_stats.is_double:
		defender_predicted_hp = max(0, defender_predicted_hp - combat_stats.damage)
	
	# Check if defender can counter-attack
	var combat_manager = get_node("/root").get_node_or_null("Main/GameManager/CombatManager")
	var defender_can_counter = false
	var defender_stats = {}
	
	if combat_manager and combat_manager.has_method("can_counter_attack"):
		defender_can_counter = combat_manager.can_counter_attack(defender, attacker)
		if defender_can_counter and combat_manager.has_method("calculate_battle_stats"):
			defender_stats = combat_manager.calculate_battle_stats(defender, attacker)
			
			# Adjust attacker predicted HP based on counter
			if defender_predicted_hp > 0:  # Defender survives to counter
				attacker_predicted_hp = max(0, attacker_predicted_hp - defender_stats.get("damage", 0))
				if defender_stats.get("is_double", false):
					attacker_predicted_hp = max(0, attacker_predicted_hp - defender_stats.get("damage", 0))
	
	# Display HP predictions with color coding
	attacker_hp.text = HP_FORMAT % [attacker.current_health, attacker_predicted_hp]
	_color_hp_label(attacker_hp, attacker.current_health, attacker_predicted_hp)
	
	defender_hp.text = HP_FORMAT % [defender.current_health, defender_predicted_hp]
	_color_hp_label(defender_hp, defender.current_health, defender_predicted_hp)
	
	# Display attacker stats
	attacker_dmg.text = DMG_FORMAT % combat_stats.damage
	if combat_stats.is_double:
		attacker_dmg.text += " x2"  # Indicate double attack
	
	attacker_hit.text = "Hit: " + STAT_FORMAT % combat_stats.hit_rate
	attacker_crit.text = "Crit: " + STAT_FORMAT % combat_stats.crit_rate
	
	# Display defender counter stats (or dashes if can't counter)
	if defender_can_counter and defender_predicted_hp > 0:
		defender_dmg.text = DMG_FORMAT % defender_stats.get("damage", 0)
		if defender_stats.get("is_double", false):
			defender_dmg.text += " x2"
		defender_hit.text = "Hit: " + STAT_FORMAT % defender_stats.get("hit_rate", 0)
		defender_crit.text = "Crit: " + STAT_FORMAT % defender_stats.get("crit_rate", 0)
	else:
		defender_dmg.text = "Dmg: --"
		defender_hit.text = "Hit: --"
		defender_crit.text = "Crit: --"

# Helper to color HP labels based on damage taken
func _color_hp_label(label: Label, current_hp: int, predicted_hp: int):
	var damage_ratio = 1.0 - (float(predicted_hp) / float(current_hp)) if current_hp > 0 else 0.0
	
	if predicted_hp == 0:
		label.modulate = Color.RED  # Lethal
	elif damage_ratio > 0.5:
		label.modulate = Color.ORANGE  # Heavy damage
	elif damage_ratio > 0.25:
		label.modulate = Color.YELLOW  # Moderate damage
	else:
		label.modulate = Color.WHITE  # Safe

func _input(event):
	# Input processing automatically disabled when hidden via _notification
	
	# Use proper game input actions (matching cursor controls)
	if event.is_action_pressed("select"):  # Z key
		accept_event()
		confirmed.emit()
		hide_forecast()
	elif event.is_action_pressed("cancel"):  # X key
		accept_event()
		cancelled.emit()
		hide_forecast()

func show_forecast():
	visible = true
	grab_focus()  # Ensure this panel receives input

func hide_forecast():
	visible = false
	release_focus()
