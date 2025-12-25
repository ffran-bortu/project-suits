# Project Navigation Guide
**Fire Emblem Tactical RPG - Quick Reference**

## 🗂️ Directory Structure

```
scripts/
├── Core/           → Game-wide systems (autoloads, managers, config)
├── Managers/       → Specific subsystem coordination (combat, AI, levels)
├── Units/          → Unit classes and components
├── Components/     → Reusable unit components (health, movement, visual)
├── UI/             → All user interface screens and menus
├── Visual/         → Visual effects, animations, cursor
├── Camera/         → Camera system and services
├── Resources/      → Resource types (.gd scripts for .tres files)
├── Main/           → Main scene coordinator
├── Tools/          → Editor tools (chapter builder, etc.)
└── Tests/          → Unit tests

scenes/
├── main.tscn       → Main game scene (coordinator)
├── unit.tscn       → Base unit scene template
├── Maps/           → Battle map scenes
└── UI/             → UI scene prefabs

data/
├── characters/     → Character data (.tres files)
├── chapters/       → Chapter/map data
├── supports/       → Support conversation scripts
└── classes/        → Character class definitions

assets/
├── sprites/        → Character and unit sprites
├── maps/           → Map tilesets and backgrounds
└── ui/             → UI icons and textures
```

## 🔍 Quick Lookup: "I need to find..."

### Game Systems

| What | Where | Key Files |
|------|-------|-----------|
| **Grid/Pathfinding** | `scripts/Core/grid_manager.gd` | Autoload, tile-based A* |
| **Unit Management** | `scripts/Managers/unit_manager.gd` | Spawn, track, query units |
| **Combat Logic** | `scripts/Managers/combat_manager.gd` | Damage calc, battle flow |
| **Turn Flow** | `scenes/managers/phases/phase_manager.gd` | Player/enemy turns |
| **AI Behavior** | `scripts/Managers/enemy_ai.gd` | Enemy decision-making |
| **Camera Controls** | `scripts/Camera/camera_controller.gd` | Pan, zoom, rotate |
| **Cursor Movement** | `scripts/Visual/cursor_controller.gd` | Grid cursor logic |
| **Game State** | `scripts/Core/game_state_manager.gd` | State machine (autoload) |

### Unit Systems

| What | Where | Notes |
|------|-------|-------|
| **Unit Base Class** | `scripts/Units/unit.gd` | Facade pattern |
| **Health System** | `scripts/Components/health_component.gd` | HP, damage, death |
| **Movement Logic** | `scripts/Components/movement_component.gd` | Pathfinding execution |
| **Visual Rendering** | `scripts/Components/visual_component.gd` | Sprites, effects |
| **Positioning** | See `unit_positioning_docs.md` | 3-layer system |

### UI Screens

| Screen | File | Purpose |
|--------|------|---------|
| Main Menu | `scripts/UI/main_menu.gd` | Title screen |
| Prep Screen | `scripts/UI/prep_screen.gd` | Pre-battle unit selection |
| Combat Forecast | `scripts/UI/combat_forecast.gd` | Attack preview popup |
| Action Menu | `scripts/UI/action_menu.gd` | Unit action selection |
| Support Menu | `scripts/UI/support_menu.gd` | Support conversations |
| Options | `scripts/UI/options_menu.gd` | Game settings |

### Configuration

| What | Where | Contains |
|------|-------|----------|
| **All Game Constants** | `scripts/Core/game_config.gd` | Colors, speeds, ranges, etc. |
| **Type Definitions** | `scripts/Core/game_types.gd` | Enums, type aliases |
| **Project Settings** | `project.godot` | Engine config, input maps |

## 🏗️ Architecture Patterns

### Component System (Units)
```
Unit (Facade)
  ├─ HealthComponent    → HP tracking
  ├─ MovementComponent  → Pathfinding
  └─ VisualComponent    → Rendering
```

### Service Pattern (Camera)
```
CameraController (Coordinator)
  ├─ CameraZoomService
  ├─ CameraPanningService
  └─ CameraRotationService
```

### Manager Pattern
```
Main (Coordinator)
  ├─ UnitManager        → Unit lifecycle
  ├─ CombatManager      → Battle resolution
  ├─ PhaseManager       → Turn order
  └─ InteractionController → Player input
```

## 🔗 Dependency Chain (Critical Order)

```
Autoloads (always available)
  ↓
GridManager → TacticalMapData
  ↓
UnitManager → Unit → Components
  ↓
PhaseManager → CombatManager
  ↓
Main (orchestrates everything)
```

## 📝 File Naming Conventions

| Pattern | Example | Meaning |
|---------|---------|---------|
| `*_manager.gd` | `unit_manager.gd` | Coordinates subsystem |
| `*_component.gd` | `health_component.gd` | Attached to parent |
| `*_service.gd` | `camera_zoom_service.gd` | Stateless helper |
| `*_controller.gd` | `cursor_controller.gd` | Handles input/logic |
| `*_data.gd` | `character_data.gd` | Resource script |

## 🎯 Common Tasks

### "Add a new unit stat"
1. `scripts/Resources/character_data.gd` - Add property
2. `scripts/Units/unit.gd` - Add variable
3. `scripts/Managers/combat_manager.gd` - Use in calculations

### "Modify damage calculation"
1. `scripts/Managers/combat_manager.gd` → `calculate_damage()`
2. Test in `scripts/Tests/Unit/test_damage_calculator.gd`

### "Change camera behavior"
1. `scripts/Core/game_config.gd` → `camera` config
2. `scripts/Camera/camera_controller.gd` → Implementation
3. Relevant service in `scripts/Camera/Services/`

### "Fix UI bug"
1. Identify screen in `scripts/UI/`
2. Check signal connections in `scripts/Main/main.gd`
3. Verify state in `scripts/Core/game_state_manager.gd`

### "Adjust movement/pathfinding"
1. `scripts/Core/grid_manager.gd` → Pathfinding logic
2. `scripts/Components/movement_component.gd` → Animation
3. `scripts/Core/game_config.gd` → Movement speeds

## 🚨 Known Gotchas

### Positioning Issues
- **3 layers**: GridManager → Unit → VisualComponent
- See `unit_positioning_docs.md` for details
- Don't mix concerns across layers

### State Management
- **Always check**: `GlobalGameState.current_state`
- Input disabled in certain states
- State transitions in `game_state_manager.gd`

### Scene Tree Dependencies
- **Autoloads ready first**: Use in `_ready()`
- **Main orchestrates**: Don't directly reference siblings
- **Signals preferred**: Decouple systems

## 📚 Key Documentation

| Document | Purpose |
|----------|---------|
| `scaffold.txt` | Original architecture spec |
| `unit_positioning_docs.md` | Positioning system details |
| `camera_system_docs.md` | Camera implementation (if exists) |
| This file | Navigation reference |

## 🔧 Debugging Workflow

1. **Find the system**: Use "Quick Lookup" table above
2. **Check config**: Look in `game_config.gd` first
3. **Trace signals**: Search for `signal` or `.connect(`
4. **Check state**: Print `GlobalGameState.current_state`
5. **Test in isolation**: Relevant file in `scripts/Tests/`

## 💡 Pro Tips

- **Search by responsibility**: "Who handles X?" → Check manager/controller
- **Search by data**: "Where's X stored?" → Check resource scripts
- **Search by event**: "When does X happen?" → Search for signal name
- **Config first**: Most tweaks live in `game_config.gd`

---

**Last Updated**: 2025-12-17  
**Maintained by**: Development team + AI assistant
