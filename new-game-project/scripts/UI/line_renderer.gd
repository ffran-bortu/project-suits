"""
FILE: line_renderer.gd
PURPOSE: 2D line renderer for drawing connection lines between world map nodes with arrows.

OVERVIEW:
Extends Node2D to draw visual connections on world map. Stores array of LineData (inner class: start, end, color, width),
renders lines in _draw() with directional arrows. Supports solid lines and dashed lines. Uses queue_redraw() for updates.
Arrow drawn with two lines at ARROW_ANGLE (45°) from direction vector.

FUNCTIONS: draw_line_connection(start, end, color, width), clear_lines(), get_line_count(), _draw(),
_draw_connection_line(line_data), draw_dashed_line(start, end, color, width, dash_length), refresh() - 7 total

NOTES: class_name LineRenderer, LineData inner class, ARROW_SIZE = 10.0, ARROW_ANGLE = PI/4. Queues redraw when
lines added/cleared. Dashed line draws alternating segments.
"""

# line_renderer.gd - Draws connection lines between map nodes
extends Node2D
class_name LineRenderer

## Renders connection lines between world map nodes with arrows

# --- Line Data ---
class LineData:
	var start: Vector2
	var end: Vector2
	var color: Color
	var width: float
	
	func _init(p_start: Vector2, p_end: Vector2, p_color: Color = Color.WHITE, p_width: float = 2.0) -> void:
		start = p_start
		end = p_end
		color = p_color
		width = p_width

# --- Constants ---
const ARROW_SIZE: float = 10.0
const ARROW_ANGLE: float = PI / 4.0

# --- State ---
var lines: Array[LineData] = []


## Add line to be drawn
## @param start: Start position
## @param end: End position
## @param color: Line color
## @param width: Line width
func draw_line_connection(start: Vector2, end: Vector2, color: Color = Color.WHITE, width: float = 2.0) -> void:
	var line_data := LineData.new(start, end, color, width)
	lines.append(line_data)
	queue_redraw()


## Clear all lines
func clear_lines() -> void:
	lines.clear()
	queue_redraw()


## Get line count
## @return: Number of lines
func get_line_count() -> int:
	return lines.size()


func _draw() -> void:
	for line_data in lines:
		_draw_connection_line(line_data)


## Draw a single connection line with arrow
## @param line_data: Line to draw
func _draw_connection_line(line_data: LineData) -> void:
	# Draw main line
	draw_line(line_data.start, line_data.end, line_data.color, line_data.width)
	
	# Draw arrow at end
	var direction := (line_data.end - line_data.start).normalized()
	
	var arrow_point1 := line_data.end - direction.rotated(ARROW_ANGLE) * ARROW_SIZE
	var arrow_point2 := line_data.end - direction.rotated(-ARROW_ANGLE) * ARROW_SIZE
	
	draw_line(line_data.end, arrow_point1, line_data.color, line_data.width)
	draw_line(line_data.end, arrow_point2, line_data.color, line_data.width)


## Draw dashed line (alternative style)
## @param start: Start position
## @param end: End position
## @param color: Line color
## @param width: Line width
## @param dash_length: Length of each dash
func draw_custom_dashed_line(start: Vector2, end: Vector2, color: Color = Color.WHITE, width: float = 2.0, dash_length: float = 10.0) -> void:
	var direction := (end - start).normalized()
	var distance := start.distance_to(end)
	var dash_count := int(distance / (dash_length * 2))
	
	for i in range(dash_count):
		var dash_start := start + direction * (i * dash_length * 2)
		var dash_end := dash_start + direction * dash_length
		
		if dash_start.distance_to(start) + dash_length > distance:
			dash_end = end
		
		draw_line(dash_start, dash_end, color, width)


## Clear and redraw all
func refresh() -> void:
	queue_redraw()
