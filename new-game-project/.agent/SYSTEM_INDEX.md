# System Cross-Reference Index
**Quick "What file affects X?" lookup**

## Core Systems

### GridManager (Autoload)
**Purpose**: Tactical grid, pathfinding, terrain  
**File**: `scripts/Core/grid_manager.gd`  
**Affects**:
- Unit movement (`get_grid_path()`, `get_movement_range()`)
- Cursor positioning (`grid_to_world_3d()`)
- Attack targeting (`get_attack_range()`)
- Tile visuals (`get_tile_at()`)

**Affected by**:
- `TacticalMapData` - map dimensions, heights
- `UnitManager` - enemy blocking checks

---

### UnitManager (Injected)
**Purpose**: Unit lifecycle, tracking, queries  
**File**: `scripts/Managers/unit_manager.gd`  
**Affects**:
- Combat (`get_unit_at_position()`)
- AI (`get_units_by_team()`)
- Deployment (`spawn_unit()`)

**Affected by**:
- `GridManager` - position validation
- `PhaseManager` - turn tracking

---

### GameStateManager (Autoload: GlobalGameState)
**Purpose**: Global state machine  
**File**: `scripts/Core/game_state_manager.gd`  
**States**: `IDLE`, `UNIT_SELECTED`, `MOVING`, `TARGETING`, `DEPLOYMENT`, etc.  
**Affects**:
- Input blocking (`cursor_controller.gd`, `camera_input_handler.gd`)
- UI visibility (`prep_screen.gd`, `action_menu.gd`)
- Phase transitions (`phase_manager.gd`)

---

### CombatManager (Injected)
**Purpose**: Damage calculation, battle execution  
**File**: `scripts/Managers/combat_manager.gd`  
**Key Functions**:
- `calculate_damage()` - Triangle, crits, RNG
- `execute_attack()` - Apply damage, effects
- `calculate_hit_chance()` - Accuracy

**Affected by**:
- `GameConfig.combat` - Formulas, multipliers
- Unit stats - Str, Mag, Def, Res, Skill, Luck

---

### PhaseManager (Scene-based)
**Purpose**: Turn order, AI automation  
**File**: `scenes/managers/phases/phase_manager.gd`  
**Key Functions**:
- `start_player_phase()`
- `start_enemy_phase()`
- `execute_enemy_turn()`

**Affects**:
- Turn counter
- AI activation
- State transitions

---

## Camera System

### CameraController
**File**: `scripts/Camera/camera_controller.gd`  
**Affects**: View angle, zoom, rotation  
**Config**: `GameConfig.camera`  
**Services**:
- `CameraZoomService` - FOV/size management
- `CameraPanningService` - WASD + edge pan
- `CameraRotationService` - Q/E rotation

### CameraInputHandler
**File**: `scripts/Camera/camera_input_handler.gd`  
**Affects**: User camera controls  
**Blocked by**: `GlobalGameState` (no pan during combat)

---

## Input Flow

### CursorController
**File**: `scripts/Visual/cursor_controller.gd`  
**Entry Point**: Arrow keys → grid movement  
**Emits**:
- `cursor_moved(Vector2i)`
- `tile_selected(Vector2i)`

**Blocked by**: `GlobalGameState` in certain states

### InteractionController
**File**: `scripts/Managers/interaction_controller.gd`  
**Entry Point**: Z/X keys, click events  
**State-dependent**: Different behavior per `GlobalGameState`

---

## Visual Systems

### VFXManager
**File**: `scripts/Visual/vfx_manager.gd`  
**Purpose**: Spawn effects (damage numbers, explosions)  
**Usage**: Called by `CombatManager`, `Unit`

### AnimationSystem
**Files**: `movement_component.gd`, `visual_component.gd`  
**Animations**: IDLE, JUMP, DAMAGE  
**Configured by**: AnimationPlayer in unit scenes

---

## UI Flow

### PrepScreen → Deployment
**Trigger**: Battle start  
**File**: `scripts/UI/prep_screen.gd`  
**Spawns**: `DeploymentHUD` (top-right button)  
**State**: Sets `GlobalGameState.DEPLOYMENT`  
**Exit**: C key or "Finish & Return" button

### ActionMenu → Combat
**Trigger**: Unit selected + Z key  
**File**: `scripts/UI/action_menu.gd`  
**Options**: Attack, Wait, Items, etc.  
**Connects to**: `InteractionController`

### CombatForecast → Attack
**Trigger**: "Attack" selected  
**File**: `scripts/UI/combat_forecast.gd`  
**Shows**: Hit%, damage preview  
**Confirms to**: `CombatManager.execute_attack()`

---

## Data Flow: Attack Example

```
1. Player presses Z on enemy
   ↓ cursor_controller.gd emits tile_selected
2. InteractionController checks state
   ↓ Shows ActionMenu
3. Player selects "Attack"
   ↓ Shows CombatForecast
4. Player confirms
   ↓ CombatManager.execute_attack()
5. Damage applied
   ↓ Unit.take_damage()
   ↓ HealthComponent.take_damage()
   ↓ VisualComponent.play_hit_effect()
6. Check death
   ↓ HealthComponent.died signal
   ↓ SignalBus.unit_died
   ↓ UnitManager removes unit
```

---

## Configuration Hotspots

### game_config.gd Sections

| Section | Controls |
|---------|----------|
| `colors` | Team tints, UI colors |
| `unit` | Movement speed, ground offset |
| `camera` | FOV, pan speed, angles |
| `combat` | Damage formulas, crit chance |
| `enemy_ai` | Aggression, search radius |
| `grid` | Cell size, height scale |
| `visual` | Animation speeds, effect durations |

### project.godot Input Maps
- `ui_*` - Menu navigation
- `move_*` - Cursor movement
- `camera_pan_*` - Camera WASD
- Custom actions: `confirm`, `cancel`, `menu`

---

## Signal Flow

### SignalBus (Autoload)
**Purpose**: Global event broadcasting  
**Key Signals**:
- `unit_health_changed`
- `unit_died`
- `battle_started` / `battle_ended`
- `turn_phase_changed`

**Listeners**: UI updates, stat tracking

---

## Common Cross-File Changes

### "Add a new combat stat"
1. `scripts/Resources/character_data.gd` - Add export var
2. `scripts/Units/unit.gd` - Add property
3. `scripts/Managers/combat_manager.gd` - Use in formulas
4. `scripts/UI/stat_display.gd` - Show in UI

### "Create new AI behavior"
1. `scripts/Managers/enemy_ai.gd` - Add decision logic
2. `scripts/Core/game_config.gd` - Add AI parameters
3. Test in `scripts/Tests/test_enemy_ai.gd`

### "Add new game phase"
1. `scripts/Core/game_state_manager.gd` - Add state enum
2. `scenes/managers/phases/phase_manager.gd` - Add phase logic
3. Update input handlers to check new state

---

**Use this index when**:
- Tracking down a bug across systems
- Planning a feature that spans multiple files
- Understanding how data flows through the game
