"""
FILE: character_status_panel.gd
PURPOSE: Bottom-screen UI overlay displaying character info on unit hover during combat.

OVERVIEW:
This panel appears when the player hovers the cursor over a unit, showing the character's portrait,
stats, HP bar, and basic info. It uses smooth fade animations and updates in real-time if the unit's
HP changes. The panel is anchored to the bottom of the screen and styled with team colors.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Initializes panel as hidden, sets up animations
   - Uses: Called when panel is added to scene tree
   - Returns: void

2. show_character_info(character_data, unit)
   - What it does: Populates panel with character data and displays it with fade-in
   - Uses: Called when cursor hovers over a unit
   - Returns: void

3. hide_panel()
   - What it does: Fades out and hides the panel
   - Uses: Called when cursor moves away from unit
   - Returns: void

4. update_stats(unit)
   - What it does: Refreshes stat values (for live HP updates)
   - Uses: Called if hovered unit takes damage
   - Returns: void

5. _populate_character_info(character_data)
   - What it does: Sets name, class, level labels
   - Uses: Internal helper for setup
   - Returns: void

6. _populate_stats(character_data, unit)
   - What it does: Fills stat grid with current values
   - Uses: Internal helper for setup
   - Returns: void

7. _update_hp_bar(current_hp, max_hp)
   - What it does: Updates HP progress bar and label
   - Uses: Internal helper for HP display
   - Returns: void

NOTES:
- Panel uses PRESET_BOTTOM_WIDE anchor
- Fade duration from GameConfig.ui.status_panel_fade_duration
- Portrait placeholder used until character portraits are created
- Team color applied to panel border (blue/red)
"""

class_name CharacterStatusPanel
extends PanelContainer

signal panel_shown(character: CharacterData)
signal panel_hidden()

# UI Node References
@onready var character_name_label: Label = $VBox/Header/NameLabel
@onready var class_label: Label = $VBox/Header/ClassLabel
@onready var level_label: Label = $VBox/Header/LevelLabel
@onready var hp_bar: ProgressBar = $VBox/HPSection/HPBar
@onready var hp_label: Label = $VBox/HPSection/HPLabel
@onready var stat_grid: GridContainer = $VBox/StatsSection/StatGrid
@onready var portrait: TextureRect = $VBox/PortraitSection/Portrait

# Current displayed data
var current_character: CharacterData = null
var current_unit: Unit = null

# Animation
var tween: Tween = null


func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	visible = false
	
	# Setup portrait placeholder
	if portrait and not portrait.texture:
		_create_portrait_placeholder()


## Display character information with fade-in
## @param character_data: Character to display
## @param unit: Unit instance for live stats
func show_character_info(character_data: CharacterData, unit: Unit) -> void:
	if not character_data or not unit:
		push_warning("CharacterStatusPanel: Invalid data provided")
		return
	
	current_character = character_data
	current_unit = unit
	
	# Populate data
	_populate_character_info(character_data)
	_populate_stats(character_data, unit)
	
	# Apply team color border
	_apply_team_color(unit.team)
	
	# Fade in
	visible = true
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, GameConfig.ui.get("status_panel_fade_duration", 0.2))
	
	panel_shown.emit(character_data)


## Hide panel with fade-out
func hide_panel() -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, GameConfig.ui.get("status_panel_fade_duration", 0.2))
	tween.tween_callback(func(): visible = false)
	
	current_character = null
	current_unit = null
	panel_hidden.emit()


## Update stats for currently displayed unit
## @param unit: Unit to refresh stats for
func update_stats(unit: Unit) -> void:
	if unit != current_unit:
		return
	
	if current_character:
		_populate_stats(current_character, unit)


func _populate_character_info(character_data: CharacterData) -> void:
	if character_name_label:
		character_name_label.text = character_data.character_name
	
	if class_label and character_data.primary_class:
		class_label.text = character_data.primary_class.display_name
	
	if level_label:
		level_label.text = "Lv. %d" % character_data.get_current_level()


func _populate_stats(character_data: CharacterData, unit: Unit) -> void:
	# Update HP bar
	_update_hp_bar(unit.current_health, unit.max_health)
	
	# Clear and populate stat grid
	if stat_grid:
		for child in stat_grid.get_children():
			child.queue_free()
		
		# Get stats from character data
		var stats_to_show = [
			["STR", GameTypes.StatType.STR],
			["MAG", GameTypes.StatType.MAG],
			["SPD", GameTypes.StatType.SPD],
			["SKL", GameTypes.StatType.SKILL],
			["LCK", GameTypes.StatType.LUCK],
			["DEF", GameTypes.StatType.DEF],
			["RES", GameTypes.StatType.RES],
		]
		
		for stat_pair in stats_to_show:
			var stat_name = stat_pair[0]
			var stat_type = stat_pair[1]
			var stat_value = character_data.get_stat_typed(stat_type, true)
			
			# Create label for stat
			var stat_label = Label.new()
			stat_label.text = "%s: %d" % [stat_name, stat_value]
			stat_grid.add_child(stat_label)


func _update_hp_bar(current_hp: int, max_hp: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		
		# Color gradient (green → yellow → red)
		var hp_ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		if hp_ratio > 0.6:
			hp_bar.modulate = Color.GREEN
		elif hp_ratio > 0.3:
			hp_bar.modulate = Color.YELLOW
		else:
			hp_bar.modulate = Color.RED
	
	if hp_label:
		hp_label.text = "%d / %d" % [current_hp, max_hp]


func _apply_team_color(team: int) -> void:
	# Add colored border based on team
	var border_color = Color.BLUE if team == 0 else Color.RED
	# Subtle tint on panel border
	add_theme_stylebox_override("panel", _create_bordered_panel(border_color))


func _create_bordered_panel(border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Dark semi-transparent
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	return style


func _create_portrait_placeholder() -> void:
	# Create simple placeholder texture
	var placeholder = PlaceholderTexture2D.new()
	placeholder.size = Vector2(200, 250)
	if portrait:
		portrait.texture = placeholder
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
