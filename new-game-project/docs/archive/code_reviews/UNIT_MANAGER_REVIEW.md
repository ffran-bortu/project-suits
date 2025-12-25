# Unit Manager Review - unit_manager.gd

## Current Implementation Analysis

### ✅ Good Points:
1. Clean unit management with add/remove functions
2. Proper state checking before actions
3. Good separation of concerns

### ❌ Issues Found:

#### 1. **Hardcoded Scene Tree Paths**
- Lines 75-76 and 82-83: Uses hardcoded path `"Main/World/Grid/Grid3D"`
- Fragile - breaks if scene structure changes
- Should use dependency injection

#### 2. **Missing Validation**
- No validation that GridManager exists
- No validation of grid positions
- No null checks for units before accessing properties

#### 3. **Inconsistent Function Signatures**
- `get_path_to_target()` calls `GridManager.get_grid_path()` with 4 parameters
- But `GridManager.get_grid_path()` only takes 3 (start, target, unit)
- Extra `max_climb_height` parameter is redundant

#### 4. **Code Duplication**
- Hardcoded path lookup repeated in `display_movement_range()` and `clear_movement_range()`
- Should cache grid_3d reference

#### 5. **Missing Error Handling**
- No validation for invalid grid positions
- No checks for missing dependencies

## Recommended Improvements

### Fix 1: Use Dependency Injection for Grid3D
```gdscript
var grid_3d: Node = null  # Will be set from main.gd

func set_grid_3d(grid_node: Node):
    grid_3d = grid_node
```

### Fix 2: Fix Function Signature
```gdscript
func get_path_to_target(target_pos: Vector2i) -> Array:
    if selected_unit:
        return GridManager.get_grid_path(
            selected_unit.grid_position, 
            target_pos,
            selected_unit  # Only 3 parameters
        )
    return []
```

### Fix 3: Add Validation
```gdscript
func add_unit(unit_node):
    if not unit_node:
        push_error("UnitManager: Cannot add null unit")
        return
    if unit_node in units:
        push_error("UnitManager: Unit already in list: ", unit_node.unit_name)
        return
    units.append(unit_node)
    print("Added unit: ", unit_node.unit_name)
```

### Fix 4: Cache Grid3D Reference
```gdscript
func display_movement_range():
    if not grid_3d:
        push_error("UnitManager: Grid3D not set!")
        return
    grid_3d.highlight_movement_range(current_reachable_cells)
```

### Fix 5: Add GridManager Validation
```gdscript
func select_unit(unit) -> bool:
    if not GridManager:
        push_error("UnitManager: GridManager not available!")
        return false
    # ... rest of function
```

## Priority Fixes

1. **HIGH**: Remove hardcoded scene paths (use dependency injection)
2. **HIGH**: Fix function signature mismatch
3. **MEDIUM**: Add validation and error handling
4. **MEDIUM**: Cache grid_3d reference
5. **LOW**: Add null checks throughout

