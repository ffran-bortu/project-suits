# Deployment Cells Not Showing - Debugging Guide

## Issue Description
When entering deployment phase in the prep screen, the blue deployment cells are not appearing on the grid.

## Signal Flow
1. **PrepScreen** (`prep_screen.gd` line 334): Emits `SignalBus.deployment_started` with `spawn_slots: Array[Vector2i]`
2. **InteractionController** (`interaction_controller.gd` line 171): Receives signal via `_on_deployment_started()`
3. **Grid3D** (`grid_3d.gd` line 481): Should call `highlight_deployment_tiles()` to create visual meshes

## Debugging Steps Added

### 1. PrepScreen Debug Logging (prep_screen.gd lines 329-343)
```gdscript
if spawn_slots.is_empty():
    push_warning("PrepScreen: No spawn slots available for deployment! Visuals will not appear.")
    DebugLog.error("PrepScreen: spawn_slots is empty - check chapter data!")
    return  # Early exit if no spawn slots

print("PrepScreen: Entering deployment with %d spawn slots" % spawn_slots.size())
print("PrepScreen: Spawn slots: ", spawn_slots)
SignalBus.deployment_started.emit(spawn_slots)
print("PrepScreen: deployment_started signal emitted")
```

### 2. InteractionController Debug Logging (interaction_controller.gd lines 171-191)
```gdscript
func _on_deployment_started(tiles: Array[Vector2i]) -> void:
    print("InteractionController: Deployment started with %d spawn tiles" % tiles.size())
    print("InteractionController: Tiles = ", tiles)
    
    if not grid_3d:
        push_error("InteractionController: grid_3d is NULL! Cannot highlight deployment tiles.")
        return
    
    if not grid_3d.has_method("highlight_deployment_tiles"):
        push_error("InteractionController: grid_3d does not have method 'highlight_deployment_tiles'!")
        return
    
    print("InteractionController: Calling grid_3d.highlight_deployment_tiles()")
    grid_3d.highlight_deployment_tiles(tiles)
    print("InteractionController: grid_3d.highlight_deployment_tiles() completed")
```

### 3. Grid3D Debug Logging (grid_3d.gd lines 481-513)
```gdscript
func highlight_deployment_tiles(cells: Array):
    print("Grid3D: highlight_deployment_tiles called with %d cells" % cells.size())
    clear_highlights()
    
    for cell in cells:
        print("Grid3D: Creating deployment highlight for cell: ", cell)
        var world_pos = GridManager.grid_to_world_3d(cell)
        # ... mesh creation ...
        print("Grid3D: Created deployment highlight quad at ", world_pos)
    
    print("Grid3D: highlight_deployment_tiles completed. Total highlights: %d" % highlight_meshes.size())
```

## What to Look For in Console

When you click "Select Units" in the prep screen, you should see this sequence:

1. ✅ `PrepScreen: Entering deployment with X spawn slots`
2. ✅ `PrepScreen: Spawn slots: [(x,y), (x,y), ...]`
3. ✅ `PrepScreen: deployment_started signal emitted`
4. ✅ `InteractionController: Deployment started with X spawn tiles`
5. ✅ `InteractionController: Tiles = [(x,y), (x,y), ...]`
6. ✅ `InteractionController: Calling grid_3d.highlight_deployment_tiles()`
7. ✅ `Grid3D: highlight_deployment_tiles called with X cells`
8. ✅ `Grid3D: Creating deployment highlight for cell: (x,y)` (repeated for each cell)
9. ✅ `Grid3D: Created deployment highlight quad at (x,y,z)` (repeated for each cell)
10. ✅ `Grid3D: highlight_deployment_tiles completed. Total highlights: X`
11. ✅ `InteractionController: grid_3d.highlight_deployment_tiles() completed`

## Possible Failure Points

### A. Empty spawn_slots
**Symptom**: Only see message 1, then returns
**Fix**: Check `chapter_info["spawn_positions"]` in `main.gd` show_prep_screen()

### B. Signal not connected
**Symptom**: See messages 1-3, but not 4-11
**Fix**: Check that `SignalBus.deployment_started` signal is connected in `interaction_controller._connect_signals()`

### C. grid_3d is null
**Symptom**: See messages 1-4, then error "grid_3d is NULL"
**Fix**: Check dependency injection in `main.gd _initialize_controllers()`

### D. Material/mesh creation fails
**Symptom**: See all messages but no visual cells appear
**Fix**: Check `GameConfig.get_material("movement")` and `GameConfig.grid.highlight_offset_movement`

### E. Cells created but not visible
**Symptom**: All debug messages show success
**Possible causes**:
- Meshes created below the grid (check y position)
- Material transparency set to 0
- Cells outside camera view
- Cells obscured by other geometry

## Next Steps

1. **Run the game** and click "Select Units" in prep screen
2. **Check console output** for the debug messages
3. **Identify where the flow stops** using the checklist above
4. **Report back** which messages you see and where it stops
