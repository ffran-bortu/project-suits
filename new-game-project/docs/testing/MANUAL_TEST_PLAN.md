# Manual Test Plan & Diagnostic Questions

## How to Use This Document

For each test section:
1. **Perform the action** described
2. **Answer all questions** with PASS/FAIL or specific details
3. **Note any unexpected behavior** in the "Notes" section
4. **Take screenshots** of any failures

## 🎮 Section 1: Main Menu & Navigation

### Test 1.1: Game Launch
**Action**: Start the game from Godot

**Questions**:
- Does the main menu appear? (PASS/FAIL):PASS
- Are all menu buttons visible? (PASS/FAIL):PASS
- Do you see any error messages in console? (YES/NO):NO
- If errors, what do they say?: _____________________________________

**Notes**: _____________________________________________________________

---

### Test 1.2: Difficulty Selection
**Action**: Click "New Game" → Select Difficulty

**Questions**:
- Does difficulty selection screen appear? (PASS/FAIL):PASS
- Can you select Normal/Hard/Lunatic? (PASS/FAIL):PASS
- Does clicking a difficulty proceed to world map? (PASS/FAIL):PASS
- Do you see difficulty name displayed anywhere? (YES/NO):NO

**Notes**: _____________________________________________________________

---

### Test 1.3: Options/Settings
**Action**: Open options menu (if available)

**Questions**:
- Can you access options from main menu? (PASS/FAIL/N/A): PASS
- Do settings save and persist? (PASS/FAIL/N/A): N/A

**Notes**: it reacts but we still havent implement options(also when we click "esc" it leaves the new game and goes back to main menu, having to start all over instead of just allowing us to go to options_____________________________________________________________

---

## 🗺️ Section 2: World Map System

### Test 2.1: World Map Loading
**Action**: Start new game → Reach world map

**Questions**:
- Does world map screen load? (PASS/FAIL):PASS
- Can you see map nodes? (PASS/FAIL):PASS
- Can you see connecting lines? (PASS/FAIL):FAIL
- Is your player avatar visible? (PASS/FAIL):PASS
- What color is the first node? (Blue/Green/GraDy/Yellow/Other): N/A

**Notes**: WE SHOULD UNBLOCK THE SECOND NODE(EVEN IF IT LOADS THE SAME CHAPTER AS 1) JUST TO TEST OUT IF THE LINEAR MOVEMENT BETWEEN NODES IS WORKING_____________________________________________________________

---

### Test 2.2: Node Selection
**Action**: Click on different nodes

**Questions**:
- Does clicking a node show info panel? (PASS/FAIL):PASS
- Does info panel show: Node name? (YES/NO): YES
- Does info panel show: Node type? (YES/NO): YES
- Does info panel show: Level/difficulty? (YES/NO): YES
- Are "Enter" and "Close" buttons visible? (PASS/FAIL): PASS

**Notes**: _____________________________________________________________

---

### Test 2.3: Node Entry
**Action**: Select a battle node → Click "Enter"

**Questions**:
- Does the battle scene load? (PASS/FAIL):PASS
- Do you see terrain/grid? (PASS/FAIL):PASS
- Do you see units on the map? (PASS/FAIL):FAIL
- How long does loading take? (seconds): INSTANT

**Notes**: I DONT KNOW IF THE UNITS ARE NOT BEING LOADED (NEITHER PLAYER NOR ENEMIES) OR IF THEY JUST NOT HAVE A VISUAL REPRESENTATION RIGHT NOW, THE OUTPUT SAYS IT SPAWNS BUT I CANT SEE THEM_____________________________________________________________

---

### Test 2.4: Returning to World Map
**Action**: (After battle, if Quit option exists) Return to world map

**Questions**:
- Can you return to world map from battle? (YES/NO): _____
- If yes, how? (Menu/Button/Automatic): _____
- Does world map remember your progress? (PASS/FAIL): _____
- Has the completed node changed color? (YES/NO): _____

**Notes**: _CANT TEST CAUSE CANT GET THROUGH BATTLE____________________________________________________________

---

## ⚔️ Section 3: Battle System - Basic Controls

### Test 3.1: Camera Controls
**Action**: In battle, test camera controls

**Questions**:
- Q key rotates camera left? (PASS/FAIL): PASS
- E key rotates camera right? (PASS/FAIL): PASS
- Mouse wheel zooms in/out? (PASS/FAIL): PASS
- Camera rotation is smooth? (PASS/FAIL): PASS( A BIT TOO FAST)
- Can you see the entire battlefield from any angle? (PASS/FAIL): N/A (YOU'RE NOT SUPPOSED TO)

**Notes**: _____________________________________________________________

---

### Test 3.2: Cursor Movement
**Action**: Move cursor with arrow keys or WASD

**Questions**:
- Arrow keys move cursor? (PASS/FAIL): FAIL
- WASD keys move cursor? (PASS/FAIL): FAIL
- Cursor movement feels responsive? (PASS/FAIL): FAIL
- Cursor stays within grid boundaries? (PASS/FAIL): FAIL
- Does cursor movement follow camera rotation? (YES/NO): NO 
  (i.e., does "up" change direction when camera rotates?)

**Notes**: _____________________________THE CURSOR ISNT MOVING AT ALL________________________________
(CANT TEST ANYTHING FROM HERE ON OUT CAUSE CURSOR AINT MOVING)
---

### Test 3.3: Unit Selection
**Action**: Move cursor to a blue unit → Press Enter or Space

**Questions**:
- Does unit get selected? (PASS/FAIL): _____
- Does movement range highlight appear? (PASS/FAIL): _____
- What color is the movement range? (Blue/Green/Other): _____
- Does selected unit have a visual indicator? (YES/NO): _____
- If yes, describe it: _____________________________________

**Notes**: _____________________________________________________________

---

### Test 3.4: Unit Movement
**Action**: With unit selected, move cursor to valid tile → Press Enter

**Questions**:
- Does unit move to target tile? (PASS/FAIL): _____
- Does unit follow a path? (PASS/FAIL): _____
- Is movement smooth/animated? (PASS/FAIL): _____
- Can you move to tiles outside range? (YES/NO - should be NO): _____
- Can you move onto enemy unit tiles? (YES/NO - should be NO): _____

**Notes**: _____________________________________________________________

---

### Test 3.5: Canceling Selection
**Action**: Select a unit → Press Escape or Backspace

**Questions**:
- Does selection cancel? (PASS/FAIL): _____
- Does movement range disappear? (PASS/FAIL): _____
- Can you select a different unit after? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

## ⚔️ Section 4: Battle System - Combat

### Test 4.1: Action Menu
**Action**: Move a unit → Action menu should appear

**Questions**:
- Does action menu appear after movement? (PASS/FAIL): _____
- Can you see "Attack" button? (PASS/FAIL): _____
- Can you see "End Turn" button? (PASS/FAIL): _____
- Is "Attack" button enabled/clickable? (PASS/FAIL): _____
- If Attack is disabled, are there enemies in range? (YES/NO): _____

**Notes**: _____________________________________________________________

---

### Test 4.2: Attack Initiation
**Action**: Click "Attack" button

**Questions**:
- Does attack targeting mode activate? (PASS/FAIL): _____
- Are enemy units highlighted/indicated? (PASS/FAIL): _____
- Can you move cursor to select target? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

### Test 4.3: Combat Forecast
**Action**: In attack targeting, hover/select an enemy

**Questions**:
- Does combat forecast UI appear? (PASS/FAIL): _____
- Does it show your unit's stats? (PASS/FAIL): _____
- Does it show enemy unit's stats? (PASS/FAIL): _____
- Does it show predicted damage? (PASS/FAIL): _____
- Does it show hit %? (PASS/FAIL): _____
- Does it show who attacks first? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

### Test 4.4: Combat Execution
**Action**: Confirm attack on enemy

**Questions**:
- Does combat animation play? (PASS/FAIL): _____
- Do HP bars update? (PASS/FAIL): _____
- Do damage numbers appear? (PASS/FAIL): _____
- Does damage match forecast? (ROUGHLY/NO): _____
- If enemy can counter, does counter attack happen? (PASS/FAIL/N/A): _____

**Notes**: _____________________________________________________________

---

### Test 4.5: Unit Death
**Action**: Attack until a unit dies (yours or enemy)

**Questions**:
- Does defeated unit disappear/play death animation? (PASS/FAIL): _____
- Does the battlefield update correctly? (PASS/FAIL): _____
- Can you continue playing after a death? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

### Test 4.6: End Turn
**Action**: Select "End Turn" from action menu

**Questions**:
- Does your turn end? (PASS/FAIL): _____
- Does enemy turn start? (PASS/FAIL): _____
- Do enemy units move? (PASS/FAIL): _____
- Do enemies attack your units? (PASS/FAIL): _____
- Does turn return to you after enemy turn? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

## 👥 Section 5: Unit Systems

### Test 5.1: Duo Units
**Action**: Examine units with 2 characters

**Questions**:
- Can you see both character portraits/sprites? (PASS/FAIL): _____
- Do duo units show combined stats? (PASS/FAIL): _____
- Can duo units attack? (PASS/FAIL): _____
- Do duo units have higher HP than solo? (YES/NO): _____

**Notes**: _____________________________________________________________

---

### Test 5.2: Solo Units
**Action**: Look for units with 1 character (especially with "Lone Wolf")

**Questions**:
- Are there any solo units on the map? (YES/NO): _____
- Do they have the "Lone Wolf" skill message in console? (YES/NO): _____
- Do Lone Wolf units seem stronger/weaker? (STRONGER/WEAKER/SAME): _____

**Notes**: _____________________________________________________________

---

### Test 5.3: Unit Info Display
**Action**: Hover over or select units

**Questions**:
- Can you see unit names? (PASS/FAIL): _____
- Can you see unit HP? (PASS/FAIL): _____
- Can you see unit stats (Str, Mag, etc.)? (PASS/FAIL): _____
- Is there a "Strength" stat (not "Str")? (YES/NO): _____

**Notes**: _____________________________________________________________

---

## 🎨 Section 6: UI/UX

### Test 6.1: HP Bars
**Action**: Look at unit HP bars during combat

**Questions**:
- Are HP bars visible above units? (PASS/FAIL): _____
- Do HP bars show current/max HP? (PASS/FAIL): _____
- Do HP bars update smoothly after damage? (PASS/FAIL): _____
- What color are HP bars? (Green/Red/Other): _____

**Notes**: _____________________________________________________________

---

### Test 6.2: Damage Numbers
**Action**: Attack a unit and watch for damage numbers

**Questions**:
- Do damage numbers appear when attacking? (PASS/FAIL): _____
- Are damage numbers legible? (PASS/FAIL): _____
- Do they float/animate? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

### Test 6.3: Visual Feedback
**Action**: Perform various actions and observe feedback

**Questions**:
- Do tiles highlight when cursor moves over them? (PASS/FAIL): _____
- Is selected unit clearly indicated? (PASS/FAIL): _____
- Do buttons change appearance on hover? (PASS/FAIL): _____
- Are all UI text elements readable? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

## 💾 Section 7: Save/Load System

### Test 7.1: Saving
**Action**: Try to save game (from world map or battle)

**Questions**:
- Is there a save option? (YES/NO): _____
- Where is it located?: _____________________________________
- Does save complete without errors? (PASS/FAIL): _____
- Do you see save confirmation? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

### Test 7.2: Loading
**Action**: Quit and reload your save

**Questions**:
- Can you load the saved game? (PASS/FAIL): _____
- Does it load to correct location (world map/battle)? (PASS/FAIL): _____
- Is your progress preserved? (PASS/FAIL): _____
- Are unit positions/HP correct? (PASS/FAIL): _____

**Notes**: _____________________________________________________________

---

## 🐛 Section 8: Error Checking

### Test 8.1: Console Errors
**Action**: Review Godot console during gameplay

**Questions**:
- Are there any RED error messages? (YES/NO): _____
- If yes, list the first 3: _____________________________________
_____________________________________________________________________
- Are there any YELLOW warning messages? (YES/NO): _____
- If yes, how many approximately?: _____

**Notes**: _____________________________________________________________

---

### Test 8.2: Performance
**Action**: Play for 5-10 minutes

**Questions**:
- Does the game run smoothly? (PASS/FAIL): _____
- FPS stays above 30? (YES/NO/DON'T KNOW): _____
- Any noticeable lag or stuttering? (YES/NO): _____
- Does memory usage seem stable? (YES/NO/DON'T KNOW): _____

**Notes**: _____________________________________________________________

---

## 📋 Section 9: Summary & Overall Impressions

### Critical Issues (Must Fix)
List any broken features that prevent gameplay:
_____________________________________________________________________
_____________________________________________________________________

### Warnings (Should Fix Soon)
List any bugs or issues that affect experience but not game-breaking:
_____________________________________________________________________
_____________________________________________________________________

### Quality of Life Issues
List any UI/UX improvements or polish needed:
_____________________________________________________________________
_____________________________________________________________________

### Positive Observations
What works well?:
_____________________________________________________________________
_____________________________________________________________________

### Overall Assessment
On a scale of 1-10:
- Gameplay functionality: _____
- Visual polish: _____
- User experience: _____
- Stability: _____

**Overall Pass/Fail**: (PASS/FAIL): _____

---

## 🔄 Next Steps

After completing this test:
1. Save this document with your answers
2. Share with me the completed checklist
3. I'll analyze results and create prioritized fix list
4. We can address critical issues first, then improvements

**Thank you for thorough testing! 🎮**
