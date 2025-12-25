# GAME DESIGN DOCUMENT (GDD)
**Project Name:** Project Suits (Working Title)  
**Genre:** Tactical RPG  
**Target Platform:** PC / Desktop  
**Engine:** Godot 4.x  
**Version:** 0.9 (Pre-Production/Prototype)  
**Date:** 2025-12-21  

---

## 1. EXECUTIVE SUMMARY
Project Suits is a turn-based tactical RPG deeply inspired by the classic *Fire Emblem* series (specifically the GBA era). It combines strategic grid-based combat with character-driven progression and relationship building. The core experience follows a loop of managing an army on a world map, preparing for battle, and engaging in deep tactical combat where terrain, weapon advantages, and unit bonds determine victory.

### 1.1 High Concept
"A modern tactical RPG engine reviving the classic 'Weapon Triangle' mechanics with robust procedural elements and relationship systems."

### 1.2 Key Features
*   **Classic Tactical Combat**: Grid-based movement, weapon triangle mechanics, and turn-based phases (Player/Enemy).
*   **Relationship System**: Units build "Bonds" (Support ranks C to S) that provide distinct combat bonuses when fighting near each other.
*   **Branching Campaign**: A node-based world map allowing for non-linear progression, optional battles, and "Sacred Stones" style traversal.
*   **Deep Customization**: Multi-class system, weapon proficiency leveling, and skill inheritance.

---

## 2. GAMEPLAY MECHANICS

### 2.1 The Weapon Triangle
The core combat resolution relies on a Rock-Paper-Scissors mechanic to encourage strategic unit placement:
*   **Sword/Piercing** beats **Axe/Striking** (Hit +15, Dmg +1)
*   **Axe/Striking** beats **Lance/Slashing** (Hit +15, Dmg +1)
*   **Lance/Slashing** beats **Sword/Piercing** (Hit +15, Dmg +1)
*   *Note: Bows and Magic exist outside or neutral to this primary triangle.*

### 2.2 Unit Stats & Progression
Units are defined by a classic array of statistics:
*   **HP**: Health Points. Unit dies (or retreats) at 0.
*   **Str/Mag**: Physical/Magical attack power.
*   **Skl (Skill)**: Affects Hit Rate and Critical chance.
*   **Spd (Speed)**: Affects Evasion and ability to "Double Attack" (if Spd > enemy Spd + 4).
*   **Lck (Luck)**: Reduces enemy crit chance and affects miscellaneous odds.
*   **Def/Res**: Reduces incoming Physical/Magical damage.
*   **Mov**: Tiles a unit can traverse per turn.

### 2.3 Terrain System
The battlefield is composed of tiles with distinct properties:
*   **Grass/Dirt**: Standard terrain. No bonuses.
*   **Forest**: High Avoid (+20%), Defense (+1), higher movement cost.
*   **Mountain**: Very high Avoid (+30%), Defense (+2), restricted to specific classes.
*   **Fort/Throne**: Healing per turn + High Defense/Avoid.

---

## 3. GAME SYSTEMS

### 3.1 World Map & Campaign
The game uses a **Graph-Based World Map**:
*   **Nodes**: Represent locations (Towns, Dungeons, Battlefields).
*   **Edges**: Paths connecting nodes.
*   **Progression**: Winning battles unlocks adjacent nodes. Some paths are mutually exclusive or require specific keys/items.
*   **Persistence**: The state of the world map (cleared stages, unlocked shops) is saved globally.

### 3.2 Preparation Phase
Before engaging in battle, the player enters the **Prep Screen**:
*   **Unit Selection**: Pick a limited number of units (e.g., 10) from the roster.
*   **Deployment**: Manually place units on valid "Blue Tiles" on the map.
*   **Inventory/Convoy**: Trade items between units or access the army's supply convoy.
*   **Support Viewer**: Watch unlocked support conversations to rank up bonds.

### 3.3 The "Bond" (Support) System
Units that fight adjacently gain **Support Points**.
*   **Ranks**: C → B → A → S (S-rank is exclusive/romantic).
*   **Bonuses**: Higher ranks grant proximity bonuses to Hit, Avoid, Crit, and Dodge.
*   **Conversations**: Unlocking a rank triggers a narrative scene between the characters.

---

## 4. USER INTERFACE (UI) & CONTROLS

### 4.1 Camera Control
A modernized RTS-style camera:
*   **Movement**: WASD or Edge Panning.
*   **Rotation**: Q/E (90-degree increments) or Hold Middle Mouse.
*   **Zoom**: Scroll Wheel (FOV-based zoom from 30° to 90°).

### 4.2 Interaction
*   **Cursor**: A 3D cursor snaps to the grid.
    *   *Green*: Hovering ally.
    *   *Red*: Hovering enemy.
    *   *Blue*: Moving.
*   **Action Menu**: Context-sensitive menu (Attack, Item, Wait, Visit, Trade).
*   **Combat Forecast**: Pre-battle window showing HP, Dmg, Hit%, and Crit% for both combatants.

---

## 5. TECHNICAL ARCHITECTURE

### 5.1 Entities and Managers
*   **Globals**: `GameConfig`, `SignalBus` (Event-driven architecture).
*   **Managers**:
    *   `PhaseManager`: State machine handling Turn Order (Player Phase -> Enemy Phase).
    *   `UnitManager`: Factory for spawning and tracking unit lifecycle.
    *   `GridManager`: A* Pathfinding and spatial queries.
    *   `BattleManager`: Calculates and executes combat logic (RNG resolution).

### 5.2 Data Handling
*   **Resources**: Heavy use of Godot `.tres` resources for defining Weapons (`Weapon.gd`), Classes (`CharacterClass.gd`), and Units (`CharacterData.gd`).
*   **Save System**: JSON-based serialization of World Map state and Unit Roster.

---

## 6. ASSETS & AESTHETICS
*   **Visual Style**: 3D Environments (Tactile, dioramas) with 2D Pixel Art Sprites (Billboarding).
*   **Inspiration**: *Octopath Traveler* HD-2D aesthetic meets *Fire Emblem* GBA sprite work.
*   **Audio**: Dynamic music shifting between Map Theme and Battle Theme (future goal).

---

*This document is a living specification and will evolve as features like the Skill System and Advanced AI are fully implemented.*
