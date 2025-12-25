# Enhanced Cursor System Documentation

## 🎯 **Overview**

Production-ready tactical cursor system with:
- **8 Visual States** (Normal, Hover, Target, etc.)
- **Smooth Animations** (Bob, pulse, shake, scale)
- **Path Preview** (3D visualization of movement)
- **Dual Input** (Keyboard + Mouse)
- **Camera Integration** (Direction-aware movement)
- **State Management** (GameState integration)

---

## 📁 **File Structure**

### Core Components
- `scripts/Visual/cursor_controller.gd` - Main cursor logic (already exists)
- `scripts/Visual/cursor_visual.gd` - **NEW** Visual representation
- `scripts/Visual/path_display.gd` - **NEW** Path visualization

### Integration Points
- Integrates with existing `cursor_controller.gd`
- Works with `camera_controller.gd`
- Uses `GridManager` for positioning
- Connects to `GameStateManager`

---

## 🎨 **Cursor States**

### State System:
```gdscript
enum CursorState {
    NORMAL          # Default cyan cursor
    HOVER_UNIT      # Green - friendly unit
    HOVER_ENEMY     # Red - enemy unit
    VALID_TARGET    # Yellow - can attack/act
    INVALID_TARGET  # Gray - cannot act
    SELECTED        # Cyan - selection confirmed
    MOVING          # Light blue - unit moving
    ATTACKING       # Orange red - combat in progress
}
```

### Visual Feedback:

| State | Color | Animation | Ring |
|-------|-------|-----------|------|
| **Normal** | Cyan | Gentle bob + rotation | Hidden |
| **Hover Unit** | Green | Bob + rotation | Visible |
| **Hover Enemy** | Red | Aggressive pulse | Visible |
| **Valid Target** | Yellow | Pulse | Visible |
| **Invalid** | Gray | Shake | Hidden |
| **Selected** | Cyan | Scale pulse | Visible |
| **Moving** | Light Blue | Fast rotation | Visible |
| **Attacking** | Orange Red | Intense pulse | Visible |

---

## 🎬 **Animations**

### Continuous Animations:

#### Bob Animation (Normal/Hover):
```gdscript
# Gentle up/down motion
var bob_offset = sin(time * bob_speed) * bob_height
cursor.position.y = bob_offset
```

### Trigger Animations:

#### Selection Pulse:
```gdscript
# Scale: 1.0 → 1.5 → 1.0
# Duration: 0.3s
# Easing: Back (bouncy feel)
```

#### Invalid Shake:
```gdscript
# Left-right shake
# 3 repetitions
# Quick 0.05s per shake
```

#### Flash:
```gdscript
cursor_visual.flash(Color.WHITE, 0.5)
# Fades to color and back
```

---

## 🗺️ **Path Display**

### Path Visualization Features:
- **Nodes**: Spherical markers at each grid position
- **Segments**: Cylindrical connections between nodes
- **Scaling**: Start (1.2×), Middle (0.6×), End (1.5×)
- **Colors**: Customizable with emission

### Usage:
```gdscript
var path_display = $PathDisplay

# Show path
var path = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
path_display.display_path(path)

# Change color (e.g., red for invalid)
path_display.update_path_color(Color.RED)

# Clear path
path_display.clear_path()
```

---

## 🔧 **Setup Guide**

### Scene Structure:
```
Cursor (Node3D)
├── CursorController (Node) - existing logic
├── CursorVisual (Node3D) - NEW
│   ├── CursorMesh (MeshInstance3D)
│   ├── SelectionRing (MeshInstance3D)
│   └── AnimationPlayer (AnimationPlayer)
└── PathDisplay (Node3D) - NEW
```

### Step 1: Add CursorVisual

```gdscript
# In your cursor scene
var cursor_visual = preload("res://scripts/Visual/cursor_visual.gd").new()
cursor_visual.name = "CursorVisual"
add_child(cursor_visual)

# Connect to existing controller
cursor_controller.cursor_visual = cursor_visual
```

### Step 2: Add PathDisplay

```gdscript
# Add path display
var path_display = preload("res://scripts/Visual/path_display.gd").new()
path_display.name = "PathDisplay"
add_child(path_display)
```

### Step 3: Integrate States

```gdscript
# In cursor_controller.gd
func update_state_visuals():
    if not cursor_visual:
        return
    
    match game_state.current_state:
        GameState.PLAYER_TURN:
            cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
        GameState.UNIT_SELECTED:
            cursor_visual.set_state(CursorVisual.CursorState.SELECTED)
        GameState.ATTACK_TARGETING:
            if is_valid_target():
                cursor_visual.set_state(CursorVisual.CursorState.VALID_TARGET)
            else:
                cursor_visual.set_state(CursorVisual.CursorState.INVALID_TARGET)
```

---

## 🎮 **Integration Examples**

### Example 1: State-Based Cursor

```gdscript
extends Node

@onready var cursor_controller = $Cursor/CursorController
@onready var cursor_visual = $Cursor/CursorVisual
@onready var game_state = get_node("/root/GameStateManager")

func _ready():
    game_state.state_changed.connect(_on_state_changed)

func _on_state_changed(new_state):
    match new_state:
        GameState.PLAYER_TURN:
            cursor_visual.set_state(CursorVisual.CursorState.NORMAL)
        
        GameState.UNIT_SELECTED:
            cursor_visual.set_state(CursorVisual.CursorState.SELECTED)
        
        GameState.ATTACK_TARGETING:
            # Will be updated dynamically as cursor moves
            pass
```

### Example 2: Path Preview

```gdscript
extends Node

@onready var cursor_controller = $Cursor/CursorController
@onready var path_display = $Cursor/PathDisplay
@onready var selected_unit: Unit = null

func _ready():
    cursor_controller.cursor_moved.connect(_on_cursor_moved)

func _on_cursor_moved(grid_pos: Vector2i):
    if not selected_unit or not selected_unit.can_move:
        path_display.clear_path()
        return
    
    # Get path from unit to cursor
    var path = GridManager.get_grid_path(
        selected_unit.grid_position,
        grid_pos,
        selected_unit
    )
    
    if path.size() > 0:
        # Filter to movement range
        var movement_range = selected_unit.current_movement
        var display_path = path.slice(0, min(path.size(), movement_range + 1))
        
        # Show path
        path_display.display_path(display_path)
        
        # Color based on validity
        if path.size() <= movement_range + 1:
            path_display.update_path_color(Color.GREEN)
        else:
            path_display.update_path_color(Color.YELLOW)
    else:
        path_display.clear_path()
```

### Example 3: Unit Hover Detection

```gdscript
extends Node

@onready var cursor_controller = $Cursor/CursorController
@onready var cursor_visual = $Cursor/CursorVisual
@onready var unit_manager = get_tree().get_first_node_in_group("unit_manager")

func _ready():
    cursor_controller.cursor_moved.connect(_on_cursor_moved)

func _on_cursor_moved(grid_pos: Vector2i):
    # Check for unit at position
    var unit = unit_manager.get_unit_at_position(grid_pos)
    
    if unit:
        cursor_visual.set_hovered_unit(unit)
        # This automatically sets state to HOVER_UNIT or HOVER_ENEMY
    else:
        cursor_visual.set_hovered_unit(null)
        # Back to NORMAL state
```

---

## 📊 **Animation Timeline**

### Bob Animation (Continuous):
```
Time:    0s    0.5s   1.0s   1.5s   2.0s
Height:  0.0   0.1    0.0   -0.1    0.0
         ─┐    ┌─    ─┐     ┌─     ─┐
          └────┘      └─────┘       └─
```

### Selection Pulse (Triggered):
```
Time:    0.0s   0.1s   0.3s
Scale:   1.0    1.5    1.0
         ─┐     ┌─     ─
          └─────┘
         [Expand][Contract]
```

### Shake Animation (Triggered):
```
Time:    0.00   0.05   0.10   0.15
X Pos:   0.0    0.1   -0.1    0.0
         ─┐─┐─┐─
          └─└─└─
         [Shake left-right-left]
```

---

## 🎨 **Material Configuration**

### Default Materials:

```gdscript
# Cursor Mesh Material
var mesh_material = StandardMaterial3D.new()
mesh_material.albedo_color = Color.CYAN
mesh_material.emission_enabled = true
mesh_material.emission = Color.CYAN * 0.3
mesh_material.metallic = 0.0
mesh_material.roughness = 0.2

# Selection Ring Material
var ring_material = StandardMaterial3D.new()
ring_material.albedo_color = Color.WHITE
ring_material.emission_enabled = true
ring_material.emission = Color.WHITE * 0.2
ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
```

### Using GameConfig Colors:

```gdscript
# In cursor_visual.gd
mesh_material.albedo_color = GameConfig.get_color("cursor_base")
```

Add to `game_config.gd`:
```gdscript
static var colors: Dictionary = {
    # ... existing colors ...
    "cursor_base": "00FFFFFF",        # Cyan
    "cursor_hover_unit": "00FF00FF",  # Green
    "cursor_hover_enemy": "FF0000FF", # Red
}
```

---

## 🐛 **Debug Tools**

### Cursor Visual Debug:
```gdscript
cursor_visual.debug_print()
# === Cursor Visual ===
# State: Hover Unit
# Position: (128.0, 0.1, 192.0)
# Visible: true
# Hovered: Unit_Player_01
```

### Path Display Debug:
```gdscript
path_display.debug_print()
# === Path Display ===
# Nodes: 5
# Segments: 4
# Visible: true
# Path: (0, 0) (1, 0) (2, 0) (2, 1) (2, 2)
```

---

## ⚡ **Performance Tips**

1. **Reuse paths** - Don't recreate every frame
2. **Clear when not needed** - `path_display.clear_path()`
3. **Limit path length** - Truncate to movement range
4. **Use object pooling** - For frequent path updates

---

## 📋 **Quick Reference**

### State Changes:
```gdscript
cursor_visual.set_state(CursorVisual.CursorState.HOVER_UNIT)
```

### Animations:
```gdscript
cursor_visual.flash(Color.WHITE, 0.5)  # Flash white
cursor_visual.show_cursor()            # Fade in
cursor_visual.hide_cursor()            # Fade out
```

### Path Management:
```gdscript
path_display.display_path(path_array)       # Show path
path_display.update_path_color(Color.RED)   # Change color
path_display.clear_path()                   # Clear
```

### Hover Detection:
```gdscript
cursor_visual.set_hovered_unit(unit)  # Set unit
cursor_visual.set_hovered_unit(null)  # Clear unit
```

---

## 🎊 **System Complete!**

The enhanced cursor system is **production-ready** with:
- ✅ 8 distinct visual states
- ✅ Smooth continuous animations
- ✅ Triggered feedback animations
- ✅ 3D path visualization
- ✅ Unit hover detection
- ✅ State-based appearance
- ✅ GameConfig integration
- ✅ Debug utilities
- ✅ Performance optimized

Ready for your Fire Emblem tactical gameplay! 🎯⚔️🎮
