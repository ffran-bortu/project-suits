# Testing Guide - Critical Fixes

## Quick Start Testing

After the critical fixes, run these quick tests to verify everything works:

### 1. Camera Controls (5 minutes)
**What was fixed:** Removed undefined `zoom_level` variable

**Test Steps:**
1. Launch the game
2. **Mouse Wheel:** Scroll up/down - camera should zoom in/out smoothly
3. **WASD:** Move camera around - should pan within boundaries
4. **Q/E:** Rotate camera - should rotate 90° at a time
5. **Arrow Keys:** Move cursor - camera should track correctly

**Expected:** No errors in console, smooth camera movement

---

### 2. Unit Movement (10 minutes)
**What was fixed:** Tile-based pathfinding replaces AStar2D

#### Test 2.1: Basic Movement
1. Start game (default map or test map)
2. Click on player unit
3. **Check:** Blue movement range appears
4. Move cursor over highlighted tiles
5. **Check:** Path preview (blue arrows) appears
6. Click on a tile within range
7. **Check:** Unit moves along the path

**Expected:** Movement works as before, no console errors

#### Test 2.2: Height Movement
1. If using test map with varied heights:
   - Select unit on low ground
   - Try moving to high ground
   - **Check:** Unit can climb 1 level but not 2+
   - **Check:** Movement costs more uphill (fewer tiles reachable)

**Expected:** Height restrictions work correctly

#### Test 2.3: Enemy Blocking
1. Select player unit
2. **Check:** Enemy positions are NOT highlighted in blue
3. Try clicking on enemy position
4. **Check:** Unit won't move there

**Expected:** Can't move through enemies

---

### 3. Combat & AI (10 minutes)

#### Test 3.1: Player Attack
1. Select player unit
2. Click "Attack" in action menu
3. **Check:** Red attack range appears
4. Click on enemy in range
5. **Check:** Combat forecast shows
6. Confirm attack
7. **Check:** Combat executes correctly

**Expected:** Attack range and combat work as before

#### Test 3.2: Enemy Turn
1. End all player unit turns
2. **Check:** Enemy turn starts automatically
3. Watch enemy units move and attack
4. **Check:** Enemies pathfind correctly
5. **Check:** Enemies attack if in range

**Expected:** Enemy AI works correctly

---

## Console Error Checks

**No errors should appear for:**
- `zoom_level` not found
- Invalid tile type
- Null tile references
- Missing neighbors
- Invalid grid positions

**Acceptable warnings:**
- "No tile at start position" (only if map not loaded)
- Pathfinding debug messages (if debug enabled)

---

## Performance Checks

### Frame Rate
- **Before:** Note FPS during movement range display
- **After:** FPS should be same or better

### Movement Range Calculation
1. Select unit
2. Check console for timing (if debug enabled)
3. **Expected:** <16ms for 8×8 grid

---

## Rollback Instructions

If major issues occur:

### Quick Rollback (Temporary)
1. Open `scripts/Core/grid_manager.gd`
2. Find `get_movement_range()` function
3. Comment out new implementation
4. Uncomment old CARDINAL_DIRECTIONS code from git history

### Full Rollback
```bash
git checkout HEAD~1 scripts/Core/grid_manager.gd
git checkout HEAD~1 scripts/Visual/camera_controller.gd
```

---

## Reporting Issues

If you find bugs, please note:
1. Which test failed (e.g., "Test 2.2: Height Movement")
2. Console error messages (full text)
3. Steps to reproduce
4. Expected vs actual behavior

---

## Success Criteria

✅ **All tests pass**  
✅ **No console errors**  
✅ **Performance same or better**  
✅ **Gameplay feels identical**

If all criteria met: **Fixes are successful!** 🎉

---

## Next Steps After Testing

Once testing is complete and successful:

1. ✅ Mark fixes as verified
2. 📝 Update documentation (if needed)
3. 🗑️ Schedule AStar2D removal (after 1-2 weeks)
4. 🚀 Continue with other improvements from code review

---

## Quick Reference: Key Files Changed

- ✏️ `scripts/Visual/camera_controller.gd` - Fixed zoom_level
- ✏️ `scripts/Core/grid_manager.gd` - Tile-based pathfinding
- 📄 `CRITICAL_FIXES_SUMMARY.md` - Detailed change log
- 📄 `TESTING_GUIDE.md` - This file




