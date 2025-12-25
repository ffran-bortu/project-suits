# 🤖 AI Assistant Onboarding Guide
**READ THIS FIRST when starting a new conversation session**

## What This Project Is

**Type**: Tactical RPG (Fire Emblem-style)  
**Engine**: Godot 4.x (GDScript)  
**Architecture**: Component-based, service-oriented, manager pattern  
**Status**: Active development

## 🎯 First Steps for New Sessions

### 1. Check These Files IMMEDIATELY
These files contain 90% of what you need to know:

```
📖 MUST READ (in order):
1. .agent/PROJECT_NAVIGATION.md     → Overall structure
2. .agent/SYSTEM_INDEX.md           → System cross-reference
3. scripts/Core/game_config.gd      → All configuration values
4. scripts/Main/main.gd             → Main coordinator + dependencies
```

### 2. Understand the Architecture

**Key Pattern: Dependency Injection**
- Main.gd injects managers into each other
- Don't use `get_node()` for siblings - use injected references
- Autoloads: GridManager, GlobalGameState, SignalBus

**Key Pattern: Component System**
```
Unit (facade) → HealthComponent, MovementComponent, VisualComponent
```

**Key Pattern: Service Layer**
```
CameraController → CameraZoomService, CameraPanningService, etc.
```

### 3. Know the Autoloads (Always Available)
```gdscript
GridManager          # Grid, pathfinding, terrain
GlobalGameState      # State machine (IDLE, TARGETING, etc.)
SignalBus            # Global events
GameConfig           # All constants (static class)
```

## 🔍 Common Request Types → Where to Look

### "Camera is broken / needs tweaking"
**Check in order**:
1. `scripts/Core/game_config.gd` → `camera` dict (config values)
2. `scripts/Camera/camera_controller.gd` → Main logic
3. `scripts/Camera/camera_input_handler.gd` → Input handling
4. `scripts/Camera/Services/` → Specific behaviors

### "Units are positioned wrong / floating"
**Check in order**:
1. `.agent/unit_positioning_docs.md` → Read the 3-layer system
2. `scripts/Core/grid_manager.gd` → Layer 1 (world position)
3. `scripts/Units/unit.gd` → Layer 2 (gameplay offset)
4. `scripts/Components/visual_component.gd` → Layer 3 (sprite offset)
5. `scripts/Core/game_config.gd` → `unit.ground_offset` (should be 0.0)

**Quick Fix Check**: Is `visual_component.gd` sprite offset NEGATIVE? (-h/2, not +h/2)

### "Combat damage is wrong"
**Check in order**:
1. `scripts/Core/game_config.gd` → `combat` section (formulas)
2. `scripts/Managers/combat_manager.gd` → `calculate_damage()`
3. `scripts/Resources/character_data.gd` → Unit stats

### "Input not working"
**Check in order**:
1. `scripts/Core/game_state_manager.gd` → What's the current state?
2. Relevant controller checks `GlobalGameState.current_state`
3. `project.godot` → Input map definitions

### "UI screen not appearing"
**Check in order**:
1. `scripts/Main/main.gd` → Is it instantiated/connected?
2. The UI script → Is `visible = true`? `show()` called?
3. `scripts/Core/game_state_manager.gd` → Does state allow it?

### "Movement/pathfinding issues"
**Check in order**:
1. `scripts/Core/grid_manager.gd` → Pathfinding logic
2. `scripts/Managers/unit_manager.gd` → Unit blocking checks
3. `scripts/Components/movement_component.gd` → Animation execution

### "Compilation errors"
**Common causes**:
1. Missing type hints → Add strict typing
2. Wrong parent class → Check `extends` line
3. Autoload not found → Check `project.godot` autoloads section
4. Resource property mismatch → Check `.gd` script vs `.tres` data

## 📋 Quick Checks for Common Issues

### Units Floating Above Ground?
```gdscript
# Check these values:
GameConfig.unit.ground_offset == 0.0  ✓
visual_component.gd: _sprite.offset.y = -h/2.0  ✓ (NEGATIVE!)
```

### Camera Not Following Cursor?
```gdscript
# Check:
camera_controller.gd: cursor tracking enabled? (check _update_cursor_focus)
main.gd: camera_controller.set_cursor_reference(cursor_controller) called?
```

### Input Not Responding?
```gdscript
# Check:
GlobalGameState.current_state → Should match expected state
GlobalGameState.is_input_blocked() → Should be false
```

## 🎨 Code Conventions

### File Headers
All GDScript files have comprehensive header comments:
```gdscript
"""
FILE: filename.gd
PURPOSE: One-line description
OVERVIEW: Detailed explanation
FUNCTIONS IN THIS FILE: [numbered list with signatures]
NOTES: Dependencies, gotchas, etc.
"""
```

### Type Safety
```gdscript
# ALWAYS use type hints:
var health: int = 100
func calculate_damage(attacker: Unit, defender: Unit) -> int:
```

### Configuration Pattern
```gdscript
# Don't hardcode - use GameConfig:
var speed = GameConfig.unit.get("walk_speed", 5)  # ✓
var speed = 5  # ✗
```

## 🚨 Critical Gotchas

### 1. Position Offset Signs
**WRONG**: `offset.y = height / 2.0` (positive = floats above ground)  
**RIGHT**: `offset.y = -height / 2.0` (negative = extends downward)

### 2. State Checks
Always verify state before input:
```gdscript
if GlobalGameState.current_state != GlobalGameState.GameState.TARGETING:
    return  # Don't process input
```

### 3. Scene Tree Dependencies
```gdscript
# ✓ Use dependency injection:
func setup(unit_manager: Node) -> void:
    self.unit_manager = unit_manager

# ✗ Don't search scene tree:
var unit_manager = get_node("/root/Main/UnitManager")  # Fragile!
```

### 4. Autoload Timing
```gdscript
# GridManager needs manual init:
func _ready():
    GridManager.initialize()  # Called by Main, not automatic
```

## 📖 Essential Documentation Files

| File | When to Read |
|------|--------------|
| `.agent/PROJECT_NAVIGATION.md` | Finding any file/system |
| `.agent/SYSTEM_INDEX.md` | Understanding cross-system interactions |
| `.agent/unit_positioning_docs.md` | Any positioning issue |
| `scaffold.txt` | Original architecture requirements |

## 🔧 Debugging Workflow

1. **Identify the system** → Use PROJECT_NAVIGATION.md
2. **Check configuration** → Look in game_config.gd first
3. **Check state** → Print GlobalGameState.current_state
4. **Trace signals** → Search for signal name in codebase
5. **Read file header** → Each file explains its purpose

## 💡 Pro Tips for AI Assistants

### When User Says "X is broken"
1. Ask clarifying questions if ambiguous
2. Check relevant config in `game_config.gd` first
3. Use grep_search to find all references
4. Read file headers to understand purpose

### When Making Changes
1. **Check GameConfig first** - Can it be solved with config change?
2. **Preserve patterns** - Follow existing architecture
3. **Update docs** - If adding major features, document them
4. **Think layers** - Is this world, gameplay, or visual concern?

### When Stuck
1. Read the file header documentation
2. Check SYSTEM_INDEX.md for cross-references
3. Search for signal connections (`.connect(`)
4. Check main.gd for initialization order

## 📝 Quick Reference Card

```
CONFIG:     scripts/Core/game_config.gd
MAIN:       scripts/Main/main.gd
GRID:       scripts/Core/grid_manager.gd
STATE:      scripts/Core/game_state_manager.gd (autoload: GlobalGameState)
UNITS:      scripts/Units/unit.gd
CAMERA:     scripts/Camera/camera_controller.gd
COMBAT:     scripts/Managers/combat_manager.gd
PATHFIND:   scripts/Core/grid_manager.gd (get_grid_path, get_movement_range)
CURSOR:     scripts/Visual/cursor_controller.gd
```

---

**Remember**: This project follows strict typing, dependency injection, and separation of concerns. When in doubt, check the pattern used in existing files!

**Last Updated**: 2025-12-17
