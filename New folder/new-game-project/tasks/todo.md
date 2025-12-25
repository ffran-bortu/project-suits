# Task Plan: Fix HP Bars and Attack System

## Problem Analysis

Based on code review, I've identified potential issues with:
1. **HP Bars not showing** - Possible initialization timing issues
2. **Attack system not working** - Z key might not be triggering attacks properly
3. **Action menu requiring Enter** - Should use Z key instead

## Errors Fixed

✅ **Fixed unused parameter warnings** in `get_movement_cost()` - prefixed with underscore
⚠️ **Signal warnings** - `unit_selected` and `action_menu_requested` ARE being used (emitted/connected), these appear to be false positives from Godot's analyzer
✅ **Syntax error** - Fixed the `get()` call in `unit_hp_bar.gd`

## Questions Before Starting

**Please clarify:**
1. When you say "HP bars aren't working" - do you mean:
   - They don't appear at all?
   - They appear but don't update when units take damage?
   - They appear but are invisible/too small?

2. When you say "attack system isn't working" - do you mean:
   - Pressing Z in attack targeting does nothing?
   - Attack range doesn't show?
   - Attacks happen but don't deal damage?
   - Something else?

3. For the action menu - does Z key work now, or does it still require Enter?

## Todo List

### Phase 1: Fix HP Bar Visibility Issues
- [x] Fix property check in unit_hp_bar.gd (has() method issue)
- [x] Change HP bars from flat to vertical (standing up)
- [x] Position HP bars well above unit sprite (0.5 units)
- [x] Set render priority and no_depth_test for always-on-top rendering
- [x] Add debug logging to trace HP bar creation
- [ ] Test HP bar appears above units
- [ ] Verify HP bar updates when damage is taken

### Phase 2: Verify Attack Damage System
- [ ] Add debug output to confirm damage is applied
- [ ] Verify take_damage() is being called
- [ ] Check HP bar updates after attack
- [ ] Test complete attack flow

### Phase 3: Code Review and Testing
- [ ] Review all changes for best practices
- [ ] Check for syntax errors
- [ ] Test complete flow: Select → Move → Attack → HP Update
- [ ] Verify no regressions in other systems

## Review Section

_To be filled after completion_

