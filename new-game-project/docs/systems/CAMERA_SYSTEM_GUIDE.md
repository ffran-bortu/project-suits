# Camera System Documentation

## 📷 **Overview**

Complete tactical camera system for Fire Emblem-style 3D games with:
- **4-Direction Rotation** (North, East, South, West)
- **FOV-Based Zoom** (smooth field of view adjustment)
- **Boundary-Constrained Panning**
- **Camera Presets** (save/load favorite views)
- **Input System** (keyboard + mouse controls)
- **Direction-Aware Controls** (WASD adapts to camera angle)

---

## 📁 **File Structure**

### Core Components
- `scripts/Camera/camera_controller.gd` - Main camera system
- `scripts/Camera/camera_input_handler.gd` - Input processing
- `scripts/Camera/camera_preset_manager.gd` - Preset management
- `scripts/Core/game_config.gd` - Camera configuration (already exists)
- `scripts/Core/grid_manager.gd` - Grid utilities (already exists)

---

## 🎮 **Camera Directions**

### Cardinal Directions:
```
NORTH (0°)   - Default, looking from south
EAST (90°)   - Looking from west
SOUTH (180°) - Looking from north
WEST (270°)  - Looking from east
```

### Usage:
```gdscript
# Rotate to specific direction
camera_controller.set_camera_direction(CameraController.CameraDirection.EAST)

# Rotate clockwise
camera_controller.rotate_camera_clockwise()

# Rotate counterclockwise
camera_controller.rotate_camera_counterclockwise()
```

---

## 🔍 **Zoom System**

### FOV-Based Zoom:
- **Minimum FOV (30°)** = Most zoomed in (close view)
- **Default FOV (60°)** = Balanced view
- **Maximum FOV (90°)** = Most zoomed out (wide view)

### Usage:
```gdscript
# Zoom in
camera_controller.zoom_in(5.0)

# Zoom out
camera_controller.zoom_out(5.0)

# Set specific zoom
camera_controller.set_zoom(45.0)
```

---

## 🗺️ **Pan System**

### Boundary-Constrained:
- Camera can pan within **30.0 units** from grid center (configurable)
- Prevents camera from going too far offscreen
- Direction-aware (WASD adapts to camera rotation)

### Usage:
```gdscript
# Pan by offset
camera_controller.pan_camera(Vector3(5, 0, 0))

# Focus on grid position
camera_controller.focus_on_position(Vector2i(4, 4))

# Reset to center
camera_controller.reset_camera()
```

---

## ⌨️ **Input Controls**

### Keyboard Controls:
| Key | Action |
|-----|--------|
| **Q** | Rotate counterclockwise |
| **E** | Rotate clockwise |
| **R** | Reset camera |
| **F** | Focus on cursor |
| **WASD** | Pan camera (direction-aware) |

### Mouse Controls:
| Input | Action |
|-------|--------|
| **Mouse Wheel Up** | Zoom in |
| **Mouse Wheel Down** | Zoom out |
| **Middle Mouse + Drag** | Pan camera |

---

## 💾 **Camera Presets**

### Default Presets:
1. **Overview** - Default view (FOV 60°)
2. **Close** - Zoomed in (FOV 30°)
3. **Wide** - Zoomed out (FOV 90°)

### Usage:
```gdscript
var preset_manager = $CameraPresetManager

# Save current view
preset_manager.save_current_preset("My View")

# Load preset
preset_manager.load_preset("Overview")

# Get all presets
var presets = preset_manager.get_preset_names()
for preset_name in presets:
    print(preset_name)

# Delete preset
preset_manager.delete_preset("My View")
```

---

## 🔧 **Setup Guide**

### Scene Structure:
```
Main (Node3D)
├── CameraController (Node3D)
│   └── Camera3D
├── CameraInputHandler (Node)
└── CameraPresetManager (Node)
```

### Step 1: Create Camera Controller
```gdscript
# Add to scene tree
var camera_controller = preload("res://scenes/camera/camera_controller.tscn").instantiate()
add_child(camera_controller)

# Or manually:
var camera_ctrl = Node3D.new()
camera_ctrl.set_script(preload("res://scripts/Camera/camera_controller.gd"))
var camera = Camera3D.new()
camera_ctrl.add_child(camera)
```

### Step 2: Add Input Handler
```gdscript
var input_handler = Node.new()
input_handler.set_script(preload("res://scripts/Camera/camera_input_handler.gd"))
input_handler.camera_controller = camera_controller
add_child(input_handler)
```

### Step 3: Add Preset Manager (Optional)
```gdscript
var preset_mgr = Node.new()
preset_mgr.set_script(preload("res://scripts/Camera/camera_preset_manager.gd"))
preset_mgr.camera_controller = camera_controller
add_child(preset_mgr)
```

### Step 4: Add to Groups
```gdscript
# For auto-discovery
camera_controller.add_to_group("camera_controller")
```

---

## ⚙️ **Configuration**

### In `game_config.gd`:
```gdscript
static var camera: Dictionary = {
    "default_fov": 60.0,
    "min_fov": 30.0,
    "max_fov": 90.0,
    "zoom_speed": 5.0,
    "zoom_smoothness": 0.15,
    "pan_speed": 20.0,
    "pan_smoothness": 0.2,
    "boundary_radius": 30.0,
    "distance_multiplier": 0.6,
    "position_x_ratio": 0.7,
    "position_y_ratio": 0.8,
    "position_z_ratio": 0.7
}
```

### Configuration Parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `default_fov` | Starting field of view | 60.0 |
| `min_fov` | Minimum zoom (closest) | 30.0 |
| `max_fov` | Maximum zoom (farthest) | 90.0 |
| `zoom_speed` | FOV change per scroll | 5.0 |
| `zoom_smoothness` | Zoom interpolation speed | 0.15 |
| `pan_speed` | WASD movement speed | 20.0 |
| `pan_smoothness` | Pan interpolation speed | 0.2 |
| `boundary_radius` | Max distance from center | 30.0 |

---

## 📊 **Complete Example**

### Creating a Tactical Camera:

```gdscript
extends Node3D

var camera_controller: CameraController
var input_handler: CameraInputHandler
var preset_manager: CameraPresetManager

func _ready():
    # Setup camera
    camera_controller = CameraController.new()
    var camera = Camera3D.new()
    camera.name = "Camera3D"
    camera_controller.add_child(camera)
    camera_controller.add_to_group("camera_controller")
    add_child(camera_controller)
    
    # Setup input
    input_handler = CameraInputHandler.new()
    input_handler.camera_controller = camera_controller
    add_child(input_handler)
    
    # Setup presets
    preset_manager = CameraPresetManager.new()
    preset_manager.camera_controller = camera_controller
    add_child(preset_manager)
    
    # Connect signals
    camera_controller.camera_direction_changed.connect(_on_direction_changed)
    camera_controller.camera_zoomed.connect(_on_camera_zoomed)
    
    print("Camera system ready!")

func _on_direction_changed(direction: CameraController.CameraDirection):
    print("Camera rotated to: %s" % CameraController.CameraDirection.keys()[direction])

func _on_camera_zoomed(fov: float):
    print("Camera FOV: %.1f" % fov)
```

---

## 🎯 **Advanced Features**

### Direction-Aware Panning:

When camera is rotated, WASD controls adapt:
- **North (0°)**: W=forward, A=left, S=back, D=right
- **East (90°)**: W=left, A=back, S=right, D=forward
- **South (180°)**: W=back, A=right, S=forward, D=left
- **West (270°)**: W=right, A=forward, S=left, D=back

### Focus on Cursor:

```gdscript
# Assuming you have a cursor controller
camera_controller.focus_on_position(cursor.get_position())

# Or use input handler's built-in F key
# It automatically finds and focuses on cursor
```

### Save Current View:

```gdscript
# After positioning camera perfectly
preset_manager.save_current_preset("Battle View")

# Later, restore it
preset_manager.load_preset("Battle View")
```

---

## 🐛 **Debug Tools**

### Camera State:
```gdscript
camera_controller.debug_print()
# === Camera State ===
# Direction: NORTH (0°)
# FOV: 60.0 (Target: 60.0)
# Offset: (0.0, 0.0, 0.0)
# Position: (0.0, 50.0, 0.0)
```

### Presets:
```gdscript
preset_manager.debug_print()
# === Camera Presets ===
# Presets: 3
# Current: Overview
#
# Available Presets:
#   - Overview [*]
#       Direction: NORTH
#       FOV: 60.0
#   - Close
#       Direction: NORTH
#       FOV: 30.0
#   - Wide
#       Direction: NORTH
#       FOV: 90.0
```

---

## 🎮 **Integration with Gameplay**

### During Unit Selection:
```gdscript
# Auto-focus on selected unit
func on_unit_selected(unit):
    var grid_pos = unit.grid_position
    camera_controller.focus_on_position(grid_pos)
```

### During Combat:
```gdscript
# Zoom in for combat
func start_combat():
    preset_manager.save_current_preset("_temp_before_combat")
    camera_controller.set_zoom(40.0)  # Close view

func end_combat():
    preset_manager.load_preset("_temp_before_combat")
```

### Cutscenes:
```gdscript
# Save player's view
preset_manager.save_current_preset("_player_view")

# Cinematic camera
camera_controller.set_camera_direction(CameraController.CameraDirection.EAST)
camera_controller.set_zoom(35.0)
camera_controller.focus_on_position(cutscene_focus_point)

# After cutscene
await cutscene_finished
preset_manager.load_preset("_player_view")
```

---

## ⚡ **Performance Tips**

1. **Smooth interpolation** prevents jarring movements
2. **Boundary system** keeps camera performant
3. **Cached FOV** avoids redundant calculations
4. **Input handling** is event-based, not polling-heavy

---

## 📋 **Input Actions**

Add these to your `project.godot` input map:

```ini
camera_pan_up="ui_up" or "W"
camera_pan_down="ui_down" or "S"
camera_pan_left="ui_left" or "A"
camera_pan_right="ui_right" or "D"
```

Or use the existing `ui_*` actions for backward compatibility.

---

## 🎊 **System Complete!**

The camera system is **fully integrated and production-ready** with:
- ✅ 4-direction rotation (North/East/South/West)
- ✅ FOV-based zoom (30°-90°)
- ✅ Boundary-constrained panning
- ✅ Direction-aware controls
- ✅ Mouse and keyboard input
- ✅ Preset save/load system
- ✅ Cursor integration support
- ✅ Smooth interpolation
- ✅ Configuration system
- ✅ Debug utilities

Ready for your Fire Emblem tactical camera! 📷⚔️🎮
