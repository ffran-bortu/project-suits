# Plan: Converting to 2.5D Grid-Based Terrain with Height

## Overview
Convert the current 2D grid system to a 2.5D system where:
- Units are 2D sprites rendered in 3D space
- Grid positions include height (X, Y, Z coordinates)
- Terrain has varying heights affecting movement and pathfinding
- Visual representation uses isometric or orthographic 3D camera

---

## Phase 1: Core Data Structure Changes

### 1.1 Create GridPosition3D Class/Type
**File**: `scripts/grid_position_3d.gd` (new)
```gdscript
# Custom type for 3D grid positions
class_name GridPosition3D
extends RefCounted

var x: int
var y: int
var z: int  # Height level

func _init(px: int = 0, py: int = 0, pz: int = 0):
    x = px
    y = py
    z = pz

func to_vector3i() -> Vector3i:
    return Vector3i(x, y, z)

func to_vector2i() -> Vector2i:
    return Vector2i(x, y)  # For 2D projection

func equals(other: GridPosition3D) -> bool:
    return x == other.x and y == other.y and z == other.z
```

**Alternative**: Use `Vector3i` directly (simpler, but less explicit)

### 1.2 Update GridManager
**Changes needed**:
- Replace `Vector2i` with `Vector3i` for grid positions
- Add `grid_height` dimension (max Z level)
- Add terrain height data structure
- Update all position-related functions

**Key modifications**:
```gdscript
# grid_manager.gd changes:
var grid_size = Vector3i(8, 8, 4)  # X, Y, Height levels
var terrain_heights: Dictionary = {}  # Key: Vector2i(x,y), Value: int height

# New function:
func get_height_at(x: int, y: int) -> int:
    var key = Vector2i(x, y)
    return terrain_heights.get(key, 0)  # Default height 0

func set_height_at(x: int, y: int, height: int):
    terrain_heights[Vector2i(x, y)] = height
```

---

## Phase 2: Terrain System

### 2.1 Terrain Data Structure
**File**: `scripts/terrain_manager.gd` (new)
```gdscript
extends Node

# Stores height map and terrain properties
var height_map: Dictionary = {}  # Vector2i(x,y) -> int height
var terrain_types: Dictionary = {}  # Vector2i(x,y) -> TerrainType enum

enum TerrainType {
    PLAINS,
    HILLS,
    MOUNTAINS,
    WATER,
    FOREST
}

func get_height_at(pos: Vector2i) -> int:
    return height_map.get(pos, 0)

func get_terrain_type_at(pos: Vector2i) -> TerrainType:
    return terrain_types.get(pos, TerrainType.PLAINS)

func can_unit_stand_at(pos: Vector3i) -> bool:
    # Check if unit can stand at this position
    var terrain = get_terrain_type_at(Vector2i(pos.x, pos.y))
    return terrain != TerrainType.WATER  # Example rule
```

### 2.2 Height-Based Movement Rules
- **Climbing**: Moving up costs extra movement (e.g., +1 per height level)
- **Descending**: Moving down may cost less or same
- **Jumping**: Units might be able to jump down 1-2 levels
- **Blocking**: Units can't move through walls/cliffs

---

## Phase 3: Pathfinding Updates

### 3.1 Replace AStarGrid2D with Custom 3D Pathfinding
**Reason**: `AStarGrid2D` only handles 2D. Need custom A* for 3D.

**File**: `scripts/pathfinder_3d.gd` (new)
```gdscript
extends Node

# Custom A* pathfinding for 3D grid
func find_path(start: Vector3i, target: Vector3i) -> Array:
    # Implement A* algorithm considering height
    # Check movement costs based on height differences
    # Respect movement range and terrain restrictions
    pass

func get_neighbors(pos: Vector3i) -> Array:
    # Return valid neighboring positions considering:
    # - Grid bounds
    # - Height differences (can't climb too high)
    # - Terrain walkability
    pass
```

### 3.2 Update Movement Range Calculation
**In `grid_manager.gd`**:
- Modify `get_movement_range()` to consider height
- Add height-based movement costs
- Check if unit can climb/descend between cells

```gdscript
func get_movement_cost(from: Vector3i, to: Vector3i) -> int:
    var base_cost = 1
    var height_diff = to.z - from.z
    
    if height_diff > 0:
        # Climbing up costs extra
        base_cost += height_diff * 2
    elif height_diff < 0:
        # Descending costs less (or same)
        base_cost += abs(height_diff)
    
    # Add terrain type costs
    var terrain_cost = get_terrain_cost(to)
    return base_cost + terrain_cost
```

---

## Phase 4: Visual Representation (2.5D)

### 4.1 Switch to 3D Scene Structure
**Changes**:
- Main scene: `Node2D` → `Node3D`
- Units: `Node2D` → `Node3D` with `Sprite3D` or `QuadMesh` + texture
- Grid: `Node2D` → `Node3D` with 3D meshes for terrain

### 4.2 Camera Setup
**Options**:
1. **Isometric Camera**: 45-degree angle, orthographic projection
2. **Top-Down 3D**: Orthographic camera looking down
3. **Perspective**: More dynamic but harder to align with grid

**File**: `scenes/camera_3d.tscn` (new)
```gdscript
# Camera3D with orthographic projection
# Positioned at angle to show height differences
# Or use Camera2D with custom transform (simpler)
```

### 4.3 Sprite Positioning
**Update `unit.gd`**:
```gdscript
extends Node3D  # Changed from Node2D

func update_position_visual():
    var world_pos_2d = GridManager.grid_to_world_2d(grid_position)
    var height_offset = GridManager.get_height_at(grid_position.x, grid_position.y)
    var world_pos_3d = Vector3(world_pos_2d.x, height_offset * height_unit_size, world_pos_2d.y)
    self.position = world_pos_3d
```

### 4.4 Grid Visualization
**Update `simple_grid.gd`**:
- Create 3D meshes (MeshInstance3D) instead of ColorRect
- Position meshes at correct heights
- Use different colors/materials for different heights

---

## Phase 5: Coordinate System Conversion

### 5.1 Grid to World Conversion
**Update `grid_manager.gd`**:
```gdscript
# Convert 3D grid position to 3D world position
func grid_to_world_3d(grid_pos: Vector3i) -> Vector3:
    var base_2d = grid_to_world_2d(Vector2i(grid_pos.x, grid_pos.y))
    var height = get_height_at(grid_pos.x, grid_pos.y) * height_unit_size
    return Vector3(base_2d.x, height, base_2d.y)

# Keep 2D version for compatibility during transition
func grid_to_world_2d(grid_pos: Vector2i) -> Vector2:
    return Vector2(grid_pos) * cell_size + cell_size * 0.5
```

### 5.2 World to Grid Conversion
```gdscript
func world_to_grid_3d(world_pos: Vector3) -> Vector3i:
    var grid_2d = world_to_grid_2d(Vector2(world_pos.x, world_pos.z))
    var height = int(round(world_pos.y / height_unit_size))
    return Vector3i(grid_2d.x, grid_2d.y, height)
```

---

## Phase 6: Unit System Updates

### 6.1 Update Unit Class
**File**: `scripts/unit.gd` changes:
```gdscript
# Change from Vector2i to Vector3i
var grid_position: Vector3i = Vector3i(0, 0, 0)

func set_grid_position(new_position: Vector3i):
    var old_position = grid_position
    grid_position = new_position
    update_position_visual()
    unit_moved.emit(old_position, new_position)

func is_at_position(check_pos: Vector3i) -> bool:
    return grid_position == check_pos
```

### 6.2 Movement Animation
- Animate Z position (height) during movement
- Smooth transitions when climbing/descending
- Consider animation speed based on height change

---

## Phase 7: Cursor System Updates

### 7.1 3D Cursor Movement
**File**: `scripts/cursor_controller.gd` changes:
```gdscript
var grid_position: Vector3i = Vector3i(4, 4, 0)

# Add height navigation
func handle_input():
    # ... existing X/Y movement ...
    if Input.is_action_pressed("move_up_height"): 
        grid_position.z += 1
    elif Input.is_action_pressed("move_down_height"):
        grid_position.z -= 1
```

### 7.2 Cursor Visual Updates
- Show cursor at correct height level
- Highlight current height level
- Maybe show height indicator

---

## Phase 8: Gameplay Features

### 8.1 Height-Based Combat Rules
- **High Ground Advantage**: Units on higher ground get bonuses
- **Range**: Height affects attack range (can shoot down but not up?)
- **Line of Sight**: Height blocks vision

### 8.2 Movement Restrictions
- Units can't move through walls (height differences > threshold)
- Flying units ignore height restrictions
- Some units can climb, others can't

---

## Phase 9: Implementation Order

### Recommended Sequence:
1. **Phase 1**: Create GridPosition3D type, update data structures
2. **Phase 2**: Implement terrain system with height map
3. **Phase 5**: Update coordinate conversion functions
4. **Phase 3**: Replace pathfinding with 3D version
5. **Phase 6**: Update unit system to use Vector3i
6. **Phase 4**: Switch to 3D scene structure and camera
7. **Phase 7**: Update cursor for 3D navigation
8. **Phase 8**: Add gameplay features

---

## Migration Strategy

### Option A: Gradual Migration
- Keep 2D system working
- Add 3D alongside it
- Switch over component by component
- **Pros**: Less risky, can test incrementally
- **Cons**: More code duplication temporarily

### Option B: Complete Rewrite
- Convert everything at once
- **Pros**: Cleaner code, no legacy code
- **Cons**: Higher risk, harder to debug

**Recommendation**: Option A (Gradual Migration)

---

## Key Considerations

### Performance
- 3D pathfinding is more expensive than 2D
- Consider caching pathfinding results
- Limit height levels (e.g., 0-4) to keep it manageable

### Visual Clarity
- Ensure height differences are visually clear
- Use shadows, outlines, or height indicators
- Consider isometric view for better depth perception

### Backward Compatibility
- Keep 2D functions available during transition
- Use wrapper functions that convert 2D→3D automatically
- Gradually deprecate 2D functions

---

## Files That Need Major Changes

1. `scripts/grid_manager.gd` - Core grid system
2. `scripts/unit.gd` - Unit positioning
3. `scripts/unit_manager.gd` - Unit management
4. `scripts/cursor_controller.gd` - Cursor system
5. `scripts/simple_grid.gd` - Grid visualization
6. `scenes/main.tscn` - Scene structure
7. `scenes/unit.tscn` - Unit scene structure

## New Files to Create

1. `scripts/grid_position_3d.gd` - 3D position type
2. `scripts/terrain_manager.gd` - Terrain system
3. `scripts/pathfinder_3d.gd` - 3D pathfinding
4. `scenes/camera_3d.tscn` - 3D camera setup

---

## Testing Checklist

- [ ] Units position correctly at different heights
- [ ] Pathfinding respects height differences
- [ ] Movement costs calculated correctly
- [ ] Cursor navigates all height levels
- [ ] Visual representation shows height clearly
- [ ] Units can't move through impassable height differences
- [ ] Terrain types affect movement correctly
- [ ] Enemy AI considers height in pathfinding

---

## Example: Height-Based Movement Cost

```gdscript
# Moving from (2,3,1) to (2,4,2) - climbing up 1 level
# Base cost: 1
# Height cost: +2 (climbing)
# Total: 3 movement points

# Moving from (2,3,2) to (2,4,1) - descending 1 level  
# Base cost: 1
# Height cost: +1 (descending)
# Total: 2 movement points
```

---

This plan provides a roadmap for converting your 2D grid system to a 2.5D system with height. Start with Phase 1 and work through systematically, testing each phase before moving to the next.


