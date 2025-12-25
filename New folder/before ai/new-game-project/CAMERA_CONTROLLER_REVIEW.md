# Camera Controller Review - camera_controller.gd

## Current Implementation Analysis

### ✅ Good Points:
1. Clean enum-based direction system
2. Proper camera rotation logic
3. Good grid direction mapping functions
4. Uses GridManager for coordinate conversions

### ❌ Issues Found:

#### 1. **Missing Zoom Functionality**
- No zoom_level variable
- No mouse wheel input handling
- Camera distance is fixed

#### 2. **Not Following Cursor**
- Camera centers on map center, not cursor position
- No connection to cursor movement
- Missing cursor_controller reference

#### 3. **Hardcoded Scene Tree Lookup**
- Line 23-24 in cursor_controller.gd uses hardcoded path
- Should use dependency injection pattern

#### 4. **Missing Features from Earlier Implementation**
- Zoom with mouse wheel was implemented but seems missing
- Cursor following was implemented but seems missing

## Recommended Fixes

### Fix 1: Add Zoom Functionality
```gdscript
var zoom_level: float = 1.0
var min_zoom: float = 0.3
var max_zoom: float = 3.0

func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_level = clamp(zoom_level - 0.1, min_zoom, max_zoom)
            update_camera_position()
            get_viewport().set_input_as_handled()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_level = clamp(zoom_level + 0.1, min_zoom, max_zoom)
            update_camera_position()
            get_viewport().set_input_as_handled()
```

### Fix 2: Center Camera on Cursor
```gdscript
var cursor_controller: Node = null

func _ready():
    camera_3d = $Camera3D
    grid_size = GridManager.grid_size
    cell_size = GridManager.cell_size
    
    # Get cursor controller reference
    if get_tree().get_root().has_node("Main/World/Cursor/CursorController"):
        cursor_controller = get_tree().get_root().get_node("Main/World/Cursor/CursorController")
        if cursor_controller.has_signal("cursor_moved"):
            cursor_controller.cursor_moved.connect(_on_cursor_moved)
    
    setup_camera_position()

func _on_cursor_moved(grid_pos: Vector2i):
    update_camera_position()

func update_camera_position():
    # Get cursor position (or default to center if cursor not available)
    var focus_grid_pos: Vector2i
    if cursor_controller and cursor_controller.has_method("get_position"):
        focus_grid_pos = cursor_controller.get_position()
    else:
        focus_grid_pos = Vector2i(grid_size.x / 2, grid_size.y / 2)
    
    # Convert grid position to world 3D position
    var world_pos_3d = GridManager.grid_to_world_3d(focus_grid_pos)
    var focus_height = GridManager.get_height(focus_grid_pos) * GridManager.height_unit_scale
    var look_at_pos = Vector3(world_pos_3d.x, focus_height, world_pos_3d.z)
    
    # Calculate base distance and apply zoom
    var base_distance = max(grid_size.x, grid_size.y) * cell_size.x * 0.6
    var distance = base_distance * zoom_level
    
    # Position camera based on direction
    var camera_pos: Vector3
    match current_direction:
        CameraDirection.NORTH:
            camera_pos = Vector3(look_at_pos.x - distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z - distance * 0.7)
        CameraDirection.EAST:
            camera_pos = Vector3(look_at_pos.x + distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z - distance * 0.7)
        CameraDirection.SOUTH:
            camera_pos = Vector3(look_at_pos.x + distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z + distance * 0.7)
        CameraDirection.WEST:
            camera_pos = Vector3(look_at_pos.x - distance * 0.7, look_at_pos.y + distance * 0.8, look_at_pos.z + distance * 0.7)
    
    camera_3d.position = camera_pos
    camera_3d.look_at(look_at_pos, Vector3.UP)
    
    camera_direction_changed.emit(current_direction)
```

### Fix 3: Use Dependency Injection (Better Pattern)
Instead of hardcoded paths, pass cursor_controller from main.gd:
```gdscript
# In main.gd _ready():
camera_controller.set_cursor_controller(cursor_controller)

# In camera_controller.gd:
func set_cursor_controller(controller: Node):
    cursor_controller = controller
    if cursor_controller and cursor_controller.has_signal("cursor_moved"):
        cursor_controller.cursor_moved.connect(_on_cursor_moved)
```

## Priority Fixes

1. **CRITICAL**: Add zoom functionality (mouse wheel)
2. **HIGH**: Center camera on cursor instead of map center
3. **MEDIUM**: Use dependency injection instead of hardcoded paths
4. **LOW**: Add smooth camera transitions

