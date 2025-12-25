"""
FILE: combat_forecast.gd
PURPOSE: Combat forecast UI panel showing predicted battle outcome before committing to attack.

OVERVIEW:
Extends Panel to display real-time combat predictions when targeting enemies. Shows attacker and defender stats
side-by-side (HP before→after, damage, hit%, crit%), calculates counter-attack if defender survives and is in range,
color-codes HP changes (red=lethal, orange=heavy, yellow=moderate, white=safe), handles Z to confirm attack or X to
cancel. Updates as cursor hovers different targets. Grabs focus to capture input, sets high process priority.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Sets focus_mode, mouse_filter, process_mode, disables input initially
   - Uses: Initialization
   - Returns: void

2. _notification(what)
   - What it does: Enables/disables input processing based on visibility, grabs focus, sets high priority
   - Uses: Called on visibility changes
   - Returns: void

3. setup(attacker, defender, combat_stats)
   - What it does: Populates forecast with names, HP predictions, damage, hit%, crit%, double attack indicators
   - Uses: Called by combat system when hovering target
   - Returns: void

4. _color_hp_label(label, current_hp, predicted_hp)
   - What it does: Colors label based on damage ratio (red/orange/yellow/white)
   - Uses: Visual feedback for survivability
   - Returns: void

5. _input(event)
   - What it does: Handles Z (confirmed signal), X (cancelled signal), hides forecast
   - Uses: Player input while forecast visible
   - Returns: void

6. show_forecast()
   - What it does: Sets visible true, grabs focus
   - Uses: Displaying forecast
   - Returns: void

7. hide_forecast()
   - What it does: Sets visible false, releases focus
   - Uses: Hiding forecast
   - Returns: void

NOTES:
- Extends Panel (Control)
- Signals: confirmed, cancelled
- Attacker stats: name, HP, damage, hit%, crit%
- Defender stats: name, HP, counter damage, counter hit%, counter crit%
- HP format: "HP: current → predicted"
- Shows "x2" indicator for double attacks
- Shows "--" for stats when defender cannot counter
- Counter-attack calculated via CombatManager.can_counter_attack()
- Defender must survive initial attack to counter
- Color coding: RED (0 HP), ORANGE (>50% damage), YELLOW (>25%), WHITE (safe)
- focus_mode = FOCUS_ALL required for input
- mouse_filter = MOUSE_FILTER_STOP blocks clicks below
- process_mode = PROCESS_MODE_ALWAYS works even when paused
- process_priority = 100 for high input priority
- Uses input actions "select" (Z) and "cancel" (X)
- Requires CombatManager at /root/Main/GameManager/CombatManager
"""

## Combat Forecast - Preview battle outcome before committing to attack
##
## Shows predicted damage, hit rates, and HP changes for both attacker and defender
## Updates in real-time as cursor hovers over different targets
extends Panel

signal confirmed
signal cancelled

# Use @export for inspector access if needed
@export_category("Attacker Stats")
@onready var attacker_name: Label = $HBox/Attackerstats/Name
@onready var attacker_hp: Label = $HBox/Attackerstats/HP
@onready var attacker_dmg: Label = $HBox/Attackerstats/Dmg
@onready var attacker_hit: Label = $HBox/Attackerstats/Hit
@onready var attacker_crit: Label = $HBox/Attackerstats/Crit

@export_category("Defender Stats")
@onready var defender_name: Label = $HBox/DefenderStats/Name
@onready var defender_hp: Label = $HBox/DefenderStats/HP
@onready var defender_dmg: Label = $HBox/DefenderStats/Dmg
@onready var defender_hit: Label = $HBox/DefenderStats/Hit
@onready var defender_crit: Label = $HBox/DefenderStats/Crit

# Constants for formatting
const HP_FORMAT: String = "HP: %d -> %d"
const DMG_FORMAT: String = "Dmg: %d"
const STAT_FORMAT: String = "%d%%"

func _ready() -> void:
	# MUST set focus_mode before grab_focus() will work
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to nodes below
	process_mode = Node.PROCESS_MODE_ALWAYS  # Process even when paused
	set_process_input(false)  # Start disabled
	
	SignalBus.combat_forecast_requested.connect(_on_signal_bus_forecast_requested)


func _on_signal_bus_forecast_requested(attacker: Node, defender: Node, stats: Dictionary) -> void:
	setup(attacker, defender, stats)
	show_forecast()

# Override visibility to manage input
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(visible)
		if visible:
			# Grab focus and set to top of input priority
			focus_mode = Control.FOCUS_ALL
			grab_focus()
			set_process_priority(100)  # High priority to capture input first

## Setup forecast display with combat predictions
## @param attacker: Attacking unit
## @param defender: Defending unit  
## @param combat_stats: Calculated combat statistics
func setup(attacker: Unit, defender: Unit, combat_stats: Dictionary) -> void:
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
	var combat_manager = get_node("/root/GlobalGameState").get_node_or_null("../Main/GameManager/CombatManager") # Fallback or use autoload
	# Better: use group or unique name if available, but for now strict path is risky. 
	# Assuming CombatManager is autoloaded or we can find it via Main.
	if not combat_manager:
		combat_manager = get_tree().get_first_node_in_group("combat_manager")
	
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
		label.modulate = GameConfig.get_color("hp_red")  # Lethal
	elif damage_ratio > 0.5:
		label.modulate = Color.ORANGE  # Heavy damage
	elif damage_ratio > 0.25:
		label.modulate = GameConfig.get_color("hp_yellow")  # Moderate damage
	else:
		label.modulate = GameConfig.get_color("hp_green") if current_hp == predicted_hp else Color.WHITE

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
