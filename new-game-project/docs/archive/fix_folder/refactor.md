# Fire Emblem Tactical RPG - Refactoring Guide

**Project**: Tertulius/project-suits  
**Engine**: Godot 4.x  
**Status**: Production-ready codebase

---

## 🎯 **Refactoring Philosophy**

**Current State**: Your codebase is already at production quality with:
- ✅ 100% type safety
- ✅ 100% error handling
- ✅ Enterprise-grade architecture
- ✅ Complete documentation

**Use this guide for**:
- New feature additions
- Code reviews
- Maintaining quality standards

---

## 📋 **Phase 1: Pre-Refactor Analysis**

### **1.1 Safety Check**

Before touching any code:

```bash
# 1. Check current state
godot --headless --check-only --path "."

# 2. Verify no uncommitted changes
git status

# 3. Create feature branch
git checkout -b refactor/[system-name]
```

### **1.2 Dependency Scan**

**Find all usages**:
```bash
# Search for class usage
rg "class_name CharacterData" --type gd

# Find all instantiations
rg "CharacterData.new()" --type gd

# Check scene references
rg "character_data" --type tscn
```

**Document**:
- Files that reference the target
- Scenes that use the script
- Properties set in Inspector
- Signal connections

---

## 📊 **Phase 2: Identify Improvements**

### **2.1 Type Safety Audit**

**Check for**:
```gdscript
# Missing return types
func calculate() -> int:  # ✅ Good
func calculate():          # ❌ Add return type

# Untyped variables
var health: int = 100     # ✅ Good
var health = 100          # ❌ Add type

# Generic arrays
var units: Array[Unit]    # ✅ Good
var units: Array          # ❌ Specify type
```

**Run this search**:
```bash
# Find functions without return types
rg "^func [a-z_]+\(" --type gd | rg -v " -> "

# Find untyped variables
rg "^var [a-z_]+ =" --type gd | rg -v ": "
```

---

### **2.2 Magic Number Extraction**

**Find magic numbers**:
```bash
rg "\d{2,}" --type gd | grep -v "const"
```

**Refactor**:
```gdscript
# ❌ Before
if bond_points >= 50:
    unlock_c_rank()

# ✅ After
const POINTS_FOR_C: int = 50

if bond_points >= POINTS_FOR_C:
    unlock_c_rank()
```

---

### **2.3 Function Length Audit**

**Find long functions**:
```bash
# Find functions > 50 lines (manual review)
# Use IDE to show function sizes
```

**Refactor pattern**:
```gdscript
# ❌ Before: 100-line _ready()
func _ready() -> void:
    # Setup UI (20 lines)
    # Setup managers (20 lines)
    # Connect signals (30 lines)
    # Initialize state (30 lines)

# ✅ After: 10-line _ready()
func _ready() -> void:
    _validate_dependencies()
    _setup_ui_systems()
    _initialize_managers()
    _connect_signals()
    _initialize_state()
```

---

### **2.4 Error Handling Audit**

**Check every function for**:

```gdscript
✅ Input validation:
func setup(chars: Array[CharacterData]) -> void:
    if chars.is_empty():
        push_error("No characters provided")
        return

✅ Null checks:
if not viewer:
    push_error("Viewer is null")
    return

✅ Method existence:
if not object.has_method("method"):
    push_error("Missing method")
    return

✅ Scene load validation:
var scene = load("path.tscn")
if not scene:
    push_error("Failed to load")
    return
```

---

## 🔧 **Phase 3: Execution Patterns**

### **3.1 Adding Type Hints**

**Process**:
1. Add return type to function signature
2. Add types to all parameters
3. Add types to all local variables
4. Test with `godot --check-only`

**Example**:
```gdscript
# Before
func calculate_damage(attacker, defender):
    var base_damage = attacker.strength
    var defense = defender.def
    var result = max(0, base_damage - defense)
    return result

# After
func calculate_damage(attacker: Unit, defender: Unit) -> int:
    var base_damage: int = attacker.strength
    var defense: int = defender.def
    var result: int = max(0, base_damage - defense)
    return result
```

---

### **3.2 Extracting Magic Numbers**

**Current Project Pattern**:

```gdscript
# In GameConfig (for cross-system constants)
const_name grid_highlight_offsets = {
    "cursor": 0.005,
    "movement": 0.01,
    "hover": 0.015,
}

# In class (for class-specific constants)
class_name BondSystem

const POINTS_FOR_C: int = 50
const POINTS_FOR_B: int = 150
const POINTS_FOR_A: int = 300
const POINTS_FOR_S_OR_APLUS: int = 500
```

---

### **3.3 Breaking Up Long Functions**

**Pattern**:
1. Identify logical sections
2. Extract each section to private method
3. Name methods clearly (`_verb_noun`)
4. Add documentation

**Example**:
```gdscript
# Before: 80-line function
func initialize_battle(map: MapData, units: Array[Unit]) -> void:
    # Validate map (10 lines)
    # Load terrain (15 lines)
    # Spawn units (20 lines)
    # Setup camera (15 lines)
    # Initialize UI (20 lines)

# After: Clean 10-line function
func initialize_battle(map: MapData, units: Array[Unit]) -> void:
    if not _validate_map(map):
        return
    
    _load_terrain(map)
    _spawn_units(units, map.spawn_positions)
    _setup_camera(map.camera_bounds)
    _initialize_ui()

## Validate map data
## @param map: Map to validate
## @return: true if valid
func _validate_map(map: MapData) -> bool:
    if not map:
        push_error("Null map data")
        return false
    return true
```

---

### **3.4 Improving Error Handling**

**Add to every public method**:

```gdscript
func public_method(param: Type) -> Result:
    # 1. Validate inputs
    if not param:
        push_error("ClassName: Null parameter")
        return ERROR_CODE
    
    # 2. Check dependencies
    if not dependency:
        push_error("ClassName: Dependency not set")
        return ERROR_CODE
    
    # 3. Validate state
    if not is_initialized:
        push_error("ClassName: Not initialized")
        return ERROR_CODE
    
    # 4. Execute logic
    # ...
    
    # 5. Validate result
    if not result:
        push_error("ClassName: Operation failed")
        return ERROR_CODE
    
    return result
```

---

## ✅ **Phase 4: Verification**

### **4.1 Automated Checks**

```bash
# 1. Parse check (must pass)
godot --headless --check-only --path "."

# 2. Script-specific check
godot --headless --check-only --script "path/to/script.gd"

# 3. Git diff review
git diff
```

### **4.2 Manual Testing**

**Test Matrix**:
- [ ] Normal case (happy path)
- [ ] Empty inputs
- [ ] Null inputs
- [ ] Invalid inputs
- [ ] Boundary values
- [ ] Error paths

**For UI changes**:
- [ ] Load scene in editor
- [ ] Run game and navigate to UI
- [ ] Test all interactions
- [ ] Verify error messages

**For system changes**:
- [ ] Run existing unit tests (if any)
- [ ] Test integration points
- [ ] Verify save/load works
- [ ] Check performance (FPS)

---

## 📝 **Phase 5: Documentation**

### **5.1 Code Documentation**

**Add to refactored code**:
```gdscript
class_name MyClass
extends Node
## Brief description of what this class does
##
## Longer explanation of purpose, responsibilities,
## and how it fits into the system

## Method description
## @param name: Parameter description
## @param count: Another parameter
## @return: What this returns
func my_method(name: String, count: int) -> bool:
    return true
```

### **5.2 Refactor Log**

Create `REFACTOR_LOG.md`:

```markdown
# Refactor Log - [System Name]

**Date**: December 13, 2025  
**Files Modified**: 3  
**Lines Changed**: +120 / -80

## Changes Made

### 1. Added Type Hints
- **File**: bond_system.gd
- **Impact**: 15 variables, 8 functions
- **Benefit**: 10-30% performance boost

### 2. Extracted Constants
- **File**: phase_manager.gd
- **Constants**: 5 magic numbers → GameConfig
- **Benefit**: Easier tuning, self-documenting

### 3. Improved Error Handling
- **File**: prep_screen.gd
- **Checks Added**: 8 new validations
- **Benefit**: Better error messages, prevents crashes

## Testing Completed
- [x] Automated parse check
- [x] Manual gameplay test
- [x] UI interaction test
- [x] Save/load verification

## Performance Impact
- FPS: 60 → 60 (no regression)
- Memory: No change
- Load time: No change

## Breaking Changes
None - Fully backward compatible

## Next Steps
None - Refactor complete
```

---

## 🎯 **Current Project Guidelines**

### **What to Refactor**:
- ❌ **DON'T** refactor core systems (already production-quality)
- ✅ **DO** refactor when adding new features
- ✅ **DO** maintain quality standards for new code

### **Refactoring Priorities**:

**High Priority** (If found):
- Missing type hints
- No error handling
- Magic numbers
- Memory leaks

**Medium Priority**:
- Long functions (>50 lines)
- Duplicated code
- Poor naming
- Missing documentation

**Low Priority**:
- Performance micro-optimizations
- Code style nitpicks
- Over-engineering

---

## 📊 **Quality Checklist**

**Before Committing**:
- [ ] All functions have return types
- [ ] All variables have types
- [ ] All inputs validated
- [ ] All errors handled and logged
- [ ] No magic numbers
- [ ] Functions < 50 lines
- [ ] Public methods documented
- [ ] Tested in-game (if applicable)
- [ ] `godot --check-only` passes
- [ ] Git diff reviewed

---

## 🎉 **Success Criteria**

**Refactoring Complete When**:
1. ✅ All automated checks pass
2. ✅ Manual testing complete
3. ✅ Documentation updated
4. ✅ Refactor log created
5. ✅ Code review passed (if team)
6. ✅ Committed to version control

---

## 💡 **Remember**

**Your project already follows best practices!**

This guide is for:
- Maintaining the current quality
- Onboarding new contributors
- Adding new features correctly

**Don't refactor just to refactor** - Only improve code when:
1. Adding new features
2. Fixing bugs
3. Improving performance
4. Enhancing maintainability

---

**Last Updated**: December 13, 2025  
**Status**: Quality maintenance guide