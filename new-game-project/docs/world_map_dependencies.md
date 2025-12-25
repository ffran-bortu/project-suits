# World Map Dependencies Analysis

## Summary

The world map transformation created **breaking changes** that affect two major systems:
1. `WorldMap` manager (`scripts/Managers/world_map.gd`)
2. `SaveManager` (`scripts/Core/save_manager.gd`)

---

## Conflicting Implementations

### Current Situation
There are **TWO** world map implementations in the codebase:

#### Implementation A: Visual Controller (NEW)
- **File**: `scripts/Main/world_map_visual_controller.gd`
- **Scene**: `scenes/world_map_visual.tscn`
- **Data Structure**: Graph-based (`map_data` with nodes dict + connections array)
- **Node Type**: Simple Dictionary, not Resource
- **Group**: None (not in a group)
- **Use Case**: Visual/UI focused

#### Implementation B: Manager (EXISTING)
- **File**: `scripts/Managers/world_map.gd`
- **Class**: `WorldMap` extends Node2D
- **Data Structure**: Array-based with `MapData` resource
- **Node Type**: `WorldMapNode` Resource with full serialization
- **Group**: `"world_map"` group
- **Use Case**: Complete campaign management with save/load
- **Features**:
  - Save/load to `user://world_map_save.dat`
  - Node progression tracking
  - Shop/Story/Rest event handling
  - Scene transitions

---

## Affected Systems

### 1. Save Manager (CRITICAL)

**File**: [save_manager.gd](file:///c:/Users/dudog/Documents/Fire%20Emblem/project-suits/new-game-project/scripts/Core/save_manager.gd)

**How it breaks**:
```gdscript
// Lines 263-330: Expects WorldMap manager
var world_map = get_tree().get_first_node_in_group("world_map")

if world_map.current_node:  // Expects WorldMapNode class
    map_data["current_map"] = world_map.current_node.node_id

if world_map.has_method("get_all_nodes"):  // Specific to manager
    for node in world_map.get_all_nodes():
        // Serializes WorldMapNode resources
```

**What it needs**:
- Node in `"world_map"` group
- `current_node` property (WorldMapNode type)
- `get_all_nodes()` method
- `visited_nodes` array
- WorldMapNode serialization support

**Visual controller provides**: None of the above

---

### 2. Encounter Token System

**File**: [encounter_token.gd](file:///c:/Users/dudog/Documents/Fire%20Emblem/project-suits/new-game-project/scripts/Resources/encounter_token.gd)

**How it's used**: Line 93
```gdscript
func use(world_map: Node, current_node: WorldMapNode, player_avg_level: int, spawn_system: DynamicSpawnSystem) -> bool:
```

**Dependency**: Expects `WorldMapNode` typed parameter

---

### 3. Main Menu

**File**: [menu_main.gd](file:///c:/Users/dudog/Documents/Fire%20Emblem/project-suits/new-game-project/scripts/Main/menu_main.gd)

**Status**: ✅ **Compatible**

Uses GameConfig path, doesn't care about implementation:
```gdscript
var world_map_path = GameConfig.assets.get("world_map_scene", "res://scenes/world_map_visual.tscn")
```

---

## Resolution Options

### Option A: Fully Migrate to Visual Controller ⭐ **Recommended**

**Benefits**:
- Cleaner, simpler graph structure
- Better visual fidelity (Fire Emblem style)
- Easier to modify campaign layout

**Required Changes**:
1. **Add to group**: Put `world_map_visual_controller` in `"world_map"` group
2. **Add group to scene**: In `world_map_visual.tscn`, add group to root node
3. **Update SaveManager** to handle new structure:
   - Replace `current_node` (WorldMapNode) with `current_node_id` (String)
   - Update serialization to use `map_data["nodes"]` 
   - Change `visited_nodes` to track string IDs instead of WorldMapNode
4. **Delete or archive**: `scripts/Managers/world_map.gd`
5. **Update EncounterToken**: Change signature to not require WorldMapNode

**Estimated Effort**: 3-4 file changes

---

### Option B: Keep WorldMap Manager, Discard Visual Changes

**Benefits**:
- No breaking changes
- Save/load continues to work
- Full campaign management features

**Required Changes**:
1. **Revert all visual controller changes**
2. **Delete**: New `world_map_visual_controller.gd` changes
3. **Enhance WorldMap manager** rendering instead

**Estimated Effort**: Revert work

---

### Option C: Hybrid Approach

**Concept**: Use WorldMap manager for logic, visual controller for rendering

**Benefits**:
- Best of both worlds (management + visuals)
- No breaking changes to save system

**Required Changes**:
1. WorldMap manager instantiates visual controller for rendering
2. Visual controller becomes a component, not standalone
3. Manager syncs data to visual controller's graph
4. Keep WorldMapNode resources

**Estimated Effort**: 6-8 file changes, higher complexity

---

## Recommendation

**Choose Option A**: Fully migrate to visual controller

**Reasons**:
1. ✅ Cleaner architecture (graph > resource array)
2. ✅ Better visual quality (already implemented)
3. ✅ Easier campaign authoring
4. ✅ WorldMap manager has TODOs for shop/story implementation anyway
5. ✅ Save system needs update regardless (v2.0 changes)

**Migration Checklist**:
- [ ] Add `world_map_visual_controller` to `"world_map"` group
- [ ] Add `current_node_id: String` property
- [ ] Add `visited_nodes: Array[String]` property  
- [ ] Add `get_all_nodes()` helper returning array of node dicts
- [ ] Update `SaveManager._serialize_map_state()` for new structure
- [ ] Update `SaveManager._deserialize_map_state()` for new structure
- [ ] Test save/load with new world map
- [ ] Archive `Managers/world_map.gd` to docs/archived/

---

## Next Steps

**If choosing Option A**:
1. I can create the migration plan
2. Update visual controller with needed methods
3. Update SaveManager serialization
4. Create migration test

**If choosing Option B or C**:
1. Provide guidance on alternative approach
2. Help integrate systems

**Which option would you like to pursue?**
