# map_loader.gd - Loads map data from text files
extends Node

class_name MapLoader

# Parse a map file and return structured data
static func load_map_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("MapLoader: Could not open file: " + file_path)
		return {}
	
	var height_map_data = []
	var enemies = []
	var players = []
	
	var current_section = "height"  # height, enemies, players
	var line_number = 0
	
	while file.get_position() < file.get_length():
		var line = file.get_line().strip_edges()
		line_number += 1
		
		# Skip empty lines (separator between sections)
		if line.is_empty():
			continue
		
		# Check for section headers
		if line.begins_with("enemies:"):
			current_section = "enemies"
			var enemy_positions = line.substr(8).strip_edges()  # Remove "enemies:"
			if not enemy_positions.is_empty():
				enemies = _parse_positions(enemy_positions)
			continue
		elif line.begins_with("players:"):
			current_section = "players"
			var player_positions = line.substr(8).strip_edges()  # Remove "players:"
			if not player_positions.is_empty():
				players = _parse_positions(player_positions)
			continue
		
		# Parse height map rows
		if current_section == "height":
			var row = _parse_height_row(line)
			if row.size() > 0:
				height_map_data.append(row)
	
	file.close()
	
	# Determine grid size from height map
	var grid_size = Vector2i(0, 0)
	if height_map_data.size() > 0:
		grid_size.y = height_map_data.size()  # Number of rows
		grid_size.x = height_map_data[0].size()  # Number of columns
	
	return {
		"grid_size": grid_size,
		"height_map": height_map_data,
		"enemies": enemies,
		"players": players
	}

# Parse a row of height values
static func _parse_height_row(line: String) -> Array:
	var heights = []
	var parts = line.split(" ", false)
	for part in parts:
		if part.is_valid_float():
			heights.append(float(part))
	return heights

# Parse position string like "1A" or "5D" into Vector2i
# Format: rowLetter where row is 1-indexed, letter is column (A=0, B=1, etc.)
static func _parse_positions(positions_string: String) -> Array:
	var positions = []
	var parts = positions_string.split(" ", false)
	
	for part in parts:
		if part.length() < 2:
			continue
		
		# Extract row number (all digits at start)
		var row_str = ""
		var col_letter = ""
		for i in range(part.length()):
			if part[i].is_valid_int():
				row_str += part[i]
			else:
				col_letter = part.substr(i)
				break
		
		if row_str.is_empty() or col_letter.is_empty():
			continue
		
		var row = int(row_str) - 1  # Convert to 0-indexed
		var col = _letter_to_column(col_letter)
		
		if col >= 0:
			positions.append(Vector2i(col, row))  # x=col, y=row
	
	return positions

# Convert letter (A, B, C, D...) to column index (0, 1, 2, 3...)
static func _letter_to_column(letter: String) -> int:
	if letter.length() == 0:
		return -1
	
	var upper_letter = letter.to_upper()
	var col = ord(upper_letter[0]) - ord("A")
	
	# Handle multi-letter columns (AA, AB, etc.) if needed
	if letter.length() > 1:
		# For now, just use first letter
		# Could extend to support AA=26, AB=27, etc.
		pass
	
	return col
