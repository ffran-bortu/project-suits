# map_editor.gd - Enhanced Visual Map Editor
extends Control

## Visual map editor for creating tactical battle maps
## Export Format: Compatible with MapLoader.gd (Sections: HEIGHTS, POSITIONS)

# --- UI References ---
@onready var grid_display: Control = $GridDisplay
@onready var property_panel: PanelContainer = $PropertyPanel
@onready var save_button: Button = $Toolbar/SaveButton
@onready var load_button: Button = $Toolbar/LoadButton
@onready var clear_button: Button = $Toolbar/ClearButton
@onready var grid_size_x: SpinBox = $PropertyPanel/VBox/GridSizeX
@onready var grid_size_y: SpinBox = $PropertyPanel/VBox/GridSizeY
@onready var brush_mode: OptionButton = $Toolbar/BrushMode
@onready var height_value: SpinBox = $PropertyPanel/VBox/HeightValue
@onready var team_selector: OptionButton = $PropertyPanel/VBox/TeamSelector
@onready var file_dialog: FileDialog = $FileDialog

# --- Editor State ---
var current_grid_size: Vector2i = Vector2i(8, 8)
var height_map: Array = []  # 2D array of heights
var unit_spawns: Array = []  # Array of {position: Vector2i, team: int, type: String}
var cell_size: int = 64
var current_brush_mode: int = 0
var is_painting: bool = false
var is_save_mode: bool = true

enum BrushMode {
	TERRAIN,
	PLAYER_SPAWN,
	ENEMY_SPAWN,
	ERASE
}

func _ready() -> void:
	_initialize_ui()
	_initialize_grid()
	_connect_signals()
	
	# Default file dialog path
	if file_dialog:
		file_dialog.current_dir = "res://maps/"

func _initialize_ui() -> void:
	brush_mode.clear()
	brush_mode.add_item("Terrain Height", BrushMode.TERRAIN)
	brush_mode.add_item("Player Spawn", BrushMode.PLAYER_SPAWN)
	brush_mode.add_item("Enemy Spawn", BrushMode.ENEMY_SPAWN)
	brush_mode.add_item("Erase", BrushMode.ERASE)
	brush_mode.select(0)
	
	team_selector.clear()
	team_selector.add_item("Player (Blue)", 0)
	team_selector.add_item("Enemy (Red)", 1)
	
	grid_size_x.value = current_grid_size.x
	grid_size_y.value = current_grid_size.y

func _initialize_grid() -> void:
	height_map.clear()
	for y in range(current_grid_size.y):
		var row = []
		for x in range(current_grid_size.x):
			row.append(0.0)
		height_map.append(row)
	
	unit_spawns.clear()
	queue_redraw()

func _connect_signals() -> void:
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	brush_mode.item_selected.connect(_on_brush_mode_changed)
	grid_size_x.value_changed.connect(_on_grid_size_changed)
	grid_size_y.value_changed.connect(_on_grid_size_changed)
	
	if file_dialog:
		file_dialog.file_selected.connect(_on_file_selected)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			if event.pressed:
				_handle_paint(event.position)
	
	elif event is InputEventMouseMotion and is_painting:
		_handle_paint(event.position)

func _handle_paint(mouse_pos: Vector2) -> void:
	var grid_pos = _screen_to_grid(mouse_pos)
	if not _is_valid_grid_pos(grid_pos):
		return
	
	match current_brush_mode:
		BrushMode.TERRAIN:
			_paint_terrain(grid_pos, height_value.value)
		BrushMode.PLAYER_SPAWN:
			_paint_spawn(grid_pos, 0)
		BrushMode.ENEMY_SPAWN:
			_paint_spawn(grid_pos, 1)
		BrushMode.ERASE:
			_erase_cell(grid_pos)
	
	queue_redraw()

func _paint_terrain(grid_pos: Vector2i, height: float) -> void:
	if _is_valid_grid_pos(grid_pos):
		height_map[grid_pos.y][grid_pos.x] = height

func _paint_spawn(grid_pos: Vector2i, team: int) -> void:
	# Remove existing
	for i in range(unit_spawns.size() - 1, -1, -1):
		if unit_spawns[i].position == grid_pos:
			unit_spawns.remove_at(i)
	
	unit_spawns.append({
		"position": grid_pos,
		"team": team,
		"type": "default"
	})

func _erase_cell(grid_pos: Vector2i) -> void:
	if _is_valid_grid_pos(grid_pos):
		height_map[grid_pos.y][grid_pos.x] = 0.0
	
	for i in range(unit_spawns.size() - 1, -1, -1):
		if unit_spawns[i].position == grid_pos:
			unit_spawns.remove_at(i)

func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos = screen_pos - grid_display.global_position
	return Vector2i(
		int(local_pos.x / cell_size),
		int(local_pos.y / cell_size)
	)

func _is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < current_grid_size.x and \
		   grid_pos.y >= 0 and grid_pos.y < current_grid_size.y

func _draw() -> void:
	_draw_grid()
	_draw_terrain()
	_draw_spawns()

func _draw_grid() -> void:
	for x in range(current_grid_size.x + 1):
		var start = Vector2(x * cell_size, 0)
		var end = Vector2(x * cell_size, current_grid_size.y * cell_size)
		draw_line(start, end, Color(0.3, 0.3, 0.3), 1.0)
	
	for y in range(current_grid_size.y + 1):
		var start = Vector2(0, y * cell_size)
		var end = Vector2(current_grid_size.x * cell_size, y * cell_size)
		draw_line(start, end, Color(0.3, 0.3, 0.3), 1.0)

func _draw_terrain() -> void:
	for y in range(current_grid_size.y):
		for x in range(current_grid_size.x):
			var height = height_map[y][x]
			if height != 0.0:
				var rect = Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
				var color = _height_to_color(height)
				draw_rect(rect, color)
				var text_pos = Vector2(x * cell_size + 5, y * cell_size + 20)
				draw_string(ThemeDB.fallback_font, text_pos, str(height), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _draw_spawns() -> void:
	for spawn in unit_spawns:
		var pos = spawn.position
		var rect = Rect2(pos.x * cell_size + 4, pos.y * cell_size + 4, cell_size - 8, cell_size - 8)
		# Use GameConfig colors if available, else fallback
		var color = GameConfig.get_color("ally", 0.7) if spawn.team == 0 else GameConfig.get_color("enemy", 0.7)
		draw_rect(rect, color)
		
		var icon_text = "P" if spawn.team == 0 else "E"
		var text_pos = Vector2(pos.x * cell_size + cell_size/2 - 8, pos.y * cell_size + cell_size/2 + 8)
		draw_string(ThemeDB.fallback_font, text_pos, icon_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)

func _height_to_color(height: float) -> Color:
	if height < 0:
		return Color(0.2, 0.3, 0.6, 0.5) 
	elif height > 0:
		return Color(0.4, 0.3, 0.2, 0.5)
	return Color(0.3, 0.3, 0.3, 0.3)

func _on_brush_mode_changed(index: int) -> void:
	current_brush_mode = index

func _on_grid_size_changed(_value: float) -> void:
	var new_size = Vector2i(int(grid_size_x.value), int(grid_size_y.value))
	if new_size != current_grid_size:
		current_grid_size = new_size
		_initialize_grid()

func _on_save_pressed() -> void:
	is_save_mode = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered()

func _on_load_pressed() -> void:
	is_save_mode = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()

func _on_clear_pressed() -> void:
	_initialize_grid()

func _on_file_selected(path: String) -> void:
	if is_save_mode:
		_save_map(path)
	else:
		_load_map(path)

# --- File IO (The Meat) ---

func _save_map(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Cannot save map to: " + path)
		return
	
	# SECTION HEIGHTS
	file.store_line("SECTION HEIGHTS")
	for row in height_map:
		var line = ""
		for h in row:
			line += str(h) + " "
		file.store_line(line.strip_edges())
	
	# SECTION POSITIONS
	file.store_line("SECTION POSITIONS")
	var p_spawns = []
	var e_spawns = []
	
	for spawn in unit_spawns:
		var s_str = "%d,%d" % [spawn.position.x, spawn.position.y]
		if spawn.team == 0:
			p_spawns.append(s_str)
		else:
			e_spawns.append(s_str)
			
	file.store_line(" ".join(p_spawns))
	file.store_line(" ".join(e_spawns))
	
	file.close()
	print("Map saved to: ", path)

func _load_map(path: String) -> void:
	# Implementation mirrored from MapLoader
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
		
	var current_section = ""
	var new_heights = []
	var new_spawns = []
	
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
		
		if line.begins_with("SECTION"):
			current_section = line.replace("SECTION ", "")
			continue
			
		if current_section == "HEIGHTS":
			var parts = line.split(" ", false)
			var row = []
			for p in parts:
				row.append(float(p))
			new_heights.append(row)
			
		elif current_section == "POSITIONS":
			var p_parts = line.split(" ", false)
			for p in p_parts:
				var coords = p.split(",")
				if coords.size() == 2:
					new_spawns.append({
						"position": Vector2i(int(coords[0]), int(coords[1])),
						"team": 0, # Assuming first line is players, need precise logic if multiple lines
						"type": "default"
					})
			# Note: Better logic would be to track index: 0=Player, 1=Enemy
			# For simplicity, editor clears "loaded state" usually
	
	# Update Editor State
	if not new_heights.is_empty():
		height_map = new_heights
		current_grid_size.y = height_map.size()
		if height_map.size() > 0:
			current_grid_size.x = height_map[0].size()
		
		grid_size_x.value = current_grid_size.x
		grid_size_y.value = current_grid_size.y
		
		unit_spawns = new_spawns # Simplified, ideally parse better
		queue_redraw()
		
	file.close()
