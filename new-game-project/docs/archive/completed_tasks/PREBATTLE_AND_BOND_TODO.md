# 📋 Pre-Battle Screen & Bond System - Remaining Tasks

**Project Status**: Save System v2.0 Complete ✅  
**Date**: December 13, 2025

---

## 🎯 **OVERVIEW**

This document outlines the remaining work for:
1. **Pre-Battle/Prep Screen** - Unit deployment and duo formation UI
2. **Bond System Integration** - Support conversation triggers and viewing

---

## 🛡️ **1. PRE-BATTLE SCREEN (PREP SCREEN)**

### Current Status
- **File Location**: `scripts/UI/prep_screen.gd`
- **Scene**: Missing (needs to be created at `scenes/ui/prep_screen.tscn`)
- **Status**: ⚠️ **SKELETON ONLY** - Basic structure exists but functionality not implemented

### What Exists
```gdscript
✅ Basic Control extension
✅ Signal: prep_complete(deployed_units: Array)
✅ Node references: @onready var unit_list, deployment_grid, start_button
✅ Arrays: available_characters, deployed_duos, deployed_solos
✅ setup() function signature
```

### 🔴 **TODO: Implementation Tasks**

#### **Task 1.1: Create Prep Screen Scene**
- [ ] Create `scenes/ui/prep_screen.tscn`
- [ ] Add UI elements:
  - [ ] Panel background
  - [ ] VBoxContainer or GridContainer for `unit_list`
  - [ ] GridContainer for `deployment_grid` (shows deployment slots)
  - [ ] Button for `start_button`
  - [ ] Labels for chapter info, deployment limits, etc.
  - [ ] Duo formation panel (combine two units)

#### **Task 1.2: Implement `refresh_ui()` Function**
**Current**: Empty with TODO comment
```gdscript
# TODO: Populate unit list, allow duo formation
```

**Needs to**:
- [ ] Display all available characters in `unit_list`
- [ ] Show each character's:
  - [ ] Name, portrait, level
  - [ ] Class (primary/secondary)
  - [ ] Current HP, stats
  - [ ] Weapon inventory
- [ ] Make characters selectable/draggable
- [ ] Update deployment grid to show selected units
- [ ] Show deployment limit (e.g., "5/10 units deployed")

#### **Task 1.3: Duo Formation System**
**Integration Point**: Works with `scripts/Units/duo_unit.gd`

- [ ] Add "Form Duo" button/panel
- [ ] Allow player to select two compatible characters
- [ ] Check duo compatibility:
  - [ ] One must support frontline
  - [ ] One must support backline
  - [ ] Both must be available
- [ ] Preview duo stats before confirming
- [ ] Create DuoUnit when confirmed
- [ ] Track formed duos in `deployed_duos` array

#### **Task 1.4: Deployment Grid**
- [ ] Visual grid showing deployment positions
- [ ] Drag-and-drop units to deployment slots
- [ ] Show unit count vs. map limit
- [ ] Allow removing units from deployment
- [ ] Separate solo units and duo units visually

#### **Task 1.5: Integration with Battle Start**
- [ ] Connect to world map → battle transition
- [ ] Pass `deployed_units` array when `prep_complete` emitted
- [ ] Ensure units spawn at correct positions
- [ ] Handle cases where prep screen is skipped (default deployment)

---

## 💕 **2. BOND SYSTEM INTEGRATION**

### Current Status
**Core Implementation**: ✅ **COMPLETE**
- `scripts/Core/bond_system.gd` - Fully implemented
- `scripts/Resources/support_conversation.gd` - Enterprise-grade resource
- `scripts/Resources/character_data.gd` - Bond data integrated

### What Works
```gdscript
✅ Bond point tracking per character pair
✅ Four bond ranks: C, B, A, S/A+
✅ Point thresholds (50, 150, 300, 500)
✅ Automatic rank-up detection
✅ Exclusive partner locking (S/A+ ranks)
✅ Support conversation resource system
✅ Save/load bond data
```

### 🟡 **TODO: UI & Gameplay Integration**

#### **Task 2.1: Support Conversation Viewer UI**
**Needs**: New scene `scenes/ui/support_viewer.tscn`

- [ ] Create support conversation viewer scene
- [ ] Elements needed:
  - [ ] Background panel
  - [ ] Character portraits (left/right)
  - [ ] Dialogue text area
  - [ ] Character name labels
  - [ ] Rank indicator (C/B/A/S/A+)
  - [ ] "Next" button for dialogue progression
  - [ ] "Skip" button
  - [ ] Background music player
- [ ] Script: `scripts/UI/support_viewer.gd`

#### **Task 2.2: Support Viewer Controller**
**File**: Create `scripts/UI/support_viewer.gd`

```gdscript
# Functionality needed:
- Load SupportConversation resource
- Display character names and portraits
- Show dialogue lines one by one
- Handle user input (next line, skip)
- Mark conversation as viewed when complete
- Award relationship points
- Return to previous scene when done
```

#### **Task 2.3: Support List/Menu Screen**
**New Scene**: `scenes/ui/support_menu.tscn`

- [ ] List all unlocked support conversations
- [ ] Filter by:
  - [ ] Character
  - [ ] Rank (C/B/A/S)
  - [ ] Viewed/New
- [ ] Show lock status for unavailable conversations
- [ ] Display requirements (chapter, previous rank)
- [ ] Launch Support Viewer when selected

#### **Task 2.4: In-Battle Support Triggers**
**Integration Points**:
- `scripts/Core/battle_manager.gd`
- `scripts/Core/turn_manager.gd` (or PhaseManager)

**Needs to check**:
- [ ] Characters adjacent during player phase → gain `POINTS_PER_TURN_TOGETHER` (2 points)
- [ ] Dual Strike occurs → gain `POINTS_PER_DUAL_STRIKE` (5 points)
- [ ] Dual Guard occurs → gain `POINTS_PER_DUAL_GUARD` (5 points)
- [ ] Emit notifications when rank unlocked

Suggested Implementation:
```gdscript
# In PhaseManager or BattleManager
func _on_turn_end():
    # Check all friendly unit pairs that are adjacent
    var bond_system = get_node("/root/Main/GameManager/BondSystem")
    
    for unit_a in player_units:
        for unit_b in player_units:
            if unit_a == unit_b:
                continue
            
            if are_adjacent(unit_a, unit_b):
                var char_a = unit_a.character_data
                var char_b = unit_b.character_data
                bond_system.add_bond_points(char_a, char_b, BondSystem.POINTS_PER_TURN_TOGETHER)
```

#### **Task 2.5: Post-Battle Support Unlocks**
**Integration**: Victory screen

- [ ] After battle victory, check for newly unlocked supports
- [ ] Show notification: "New Support Unlocked: Lyn + Eliwood (C)"
- [ ] Allow viewing immediately or save for later
- [ ] Add to support menu

#### **Task 2.6: S-Rank and A+ Choice Dialog**
**Current Issue**: Line 43 in `bond_system.gd` is commented out
```gdscript
#show_s_or_aplus_choice(char_a, char_b)
unlock_support(char_a, char_b, CharacterData.BondRank.A_PLUS, "A+")  # Default to A+ for now
```

**Needs**:
- [ ] Create choice dialog UI
- [ ] When 500 points reached, show:
  - [ ] "Choose S-Rank (Romantic)" 
  - [ ] "Choose A+-Rank (Platonic)"
- [ ] Store choice in CharacterData
- [ ] Lock out other S/A+ options for that character
- [ ] Implement `show_s_or_aplus_choice()` function

#### **Task 2.7: Support Conversation Content Creation**
**Resources Needed**: Create actual support conversations

Example structure:
```gdscript
# data/supports/lyn_eliwood_c.tres
var lyn_eliwood_c = SupportConversation.create_c_rank("lyn", "eliwood", [
    "Lyn: Eliwood, you fight with honor.",
    "Eliwood: Thank you, Lyn. Your skill with the blade is impressive.",
    "Lyn: We make a good team.",
    "Eliwood: Indeed. I'm glad to fight alongside you."
])
```

**Tasks**:
- [ ] Create `data/supports/` folder
- [ ] Write support conversations for each character pair
- [ ] Create C, B, A, S/A+ conversations
- [ ] Set appropriate requirements (previous rank unlocked)
- [ ] Assign background images and music

---

## 🎨 **3. UI/UX POLISH**

### Prep Screen Enhancements
- [ ] Add character preview when hovering
- [ ] Show stat comparison for duos
- [ ] Implement inventory management (equip weapons before battle)
- [ ] Show bond levels between characters (affects duo bonuses)
- [ ] Add animations for unit selection
- [ ] Sound effects for deployment

### Support System Enhancements
- [ ] Visual indicator when units gain bond points (hearts, sparkles)
- [ ] Bond level indicators above adjacent units in battle
- [ ] Support counter in base/hub menu
- [ ] Gallery to re-watch conversations
- [ ] Character relationship web/chart

---

## 📊 **PRIORITY RECOMMENDATIONS**

### High Priority (Core Gameplay)
1. ✅ **Prep Screen Basic Implementation** (Tasks 1.1-1.4)
   - Essential for unit deployment
   - Blocks battle start flow
   
2. ✅ **In-Battle Bond Point Tracking** (Task 2.4)
   - Core mechanic integration
   - Players earn bonds during gameplay

### Medium Priority (User Experience)
3. ⚠️ **Support Viewer UI** (Tasks 2.1-2.2)
   - Allows viewing unlocked conversations
   - Improves narrative experience

4. ⚠️ **Duo Formation in Prep Screen** (Task 1.3)
   - Already have DuoUnit class
   - Just needs UI integration

### Low Priority (Polish)
5. 🔵 **Support Menu/List** (Task 2.3)
   - Nice-to-have for organization
   - Can be deferred

6. 🔵 **S/A+ Choice Dialog** (Task 2.6)
   - Minor feature
   - System defaults to A+ currently

7. 🔵 **Content Creation** (Task 2.7)
   - Time-consuming writing
   - Can be added incrementally

---

## 🔧 **TECHNICAL NOTES**

### Prep Screen Integration Path
```
WorldMap → Chapter Selected → PrepScreen → Battle Scene
                                   ↓
                          deployed_units array
                                   ↓
                          UnitManager.spawn_units()
```

### Bond System Data Flow
```
Battle Events (adjacent, dual strike, dual guard)
    ↓
BondSystem.add_bond_points()
    ↓
CharacterData.bond_data updated
    ↓
BondSystem.check_support_unlock()
    ↓
SupportConversation.unlock()
    ↓
SaveManager.save_game() (persists)
```

### Key Files Reference
| System | Core File | Scene | Status |
|--------|-----------|-------|--------|
| Prep Screen | `scripts/UI/prep_screen.gd` | `scenes/ui/prep_screen.tscn` | ❌ Missing Scene |
| Bond System | `scripts/Core/bond_system.gd` | N/A | ✅ Complete |
| Support Resource | `scripts/Resources/support_conversation.gd` | N/A | ✅ Complete |
| Support Viewer | `scripts/UI/support_viewer.gd` | `scenes/ui/support_viewer.tscn` | ❌ Not Created |
| Support Menu | `scripts/UI/support_menu.gd` | `scenes/ui/support_menu.tscn` | ❌ Not Created |

---

## 🚀 **SUGGESTED IMPLEMENTATION ORDER**

### Phase 1: Prep Screen MVP (2-4 hours)
1. Create `prep_screen.tscn` with basic layout
2. Implement character list display
3. Add simple unit selection (no duos yet)
4. Wire up to world map → battle transition
5. Test deployment flow

### Phase 2: Bond System Integration (2-3 hours)
1. Add bond point tracking to turn end
2. Create basic support viewer UI
3. Test unlocking C-rank conversations
4. Add post-battle support notifications

### Phase 3: Duo Formation (2-3 hours)
1. Add duo formation panel to prep screen
2. Implement duo compatibility checks
3. Create duo preview
4. Test duo units in battle

### Phase 4: Support Content (Ongoing)
1. Create support conversation database
2. Write dialogue for character pairs
3. Add portraits and backgrounds
4. Implement full support menu

---

## ✅ **WHAT'S ALREADY DONE**

Your save system (v2.0) **already handles**:
- ✅ Character bond data (ranks, points, conversations viewed)
- ✅ Support progress persistence
- ✅ Character exclusive partners (S/A+ locks)
- ✅ All unit stats and inventory

**This means**: Once you build the UI, the backend will just work! 🎉

---

## 📝 **QUICK START CHECKLIST**

To get started immediately:

- [ ] Open Godot 4.5
- [ ] Create `scenes/ui/prep_screen.tscn`
- [ ] Add Panel → VBoxContainer → ItemList for units
- [ ] Add Button "Start Battle"
- [ ] Edit `prep_screen.gd` → implement `refresh_ui()`
- [ ] Test by loading from world map

---

**Good luck! You've got a solid foundation. The UI work is the final piece!** 🔥⚔️
