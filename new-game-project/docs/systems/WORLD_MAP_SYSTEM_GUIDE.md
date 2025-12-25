# World Map System Documentation

## 🗺️ **Overview**

Complete Fire Emblem-style campaign map system with:
- **Node-Based Progression** (Battle, Story, Shop, Rest)
- **Branching Paths** with prerequisites
- **Save/Load System** for campaign progress
- **Visual Connection Lines** showing progression
- **Validation & Error Handling**
- **Completion Tracking** with rewards

---

## 📁 **File Structure**

### Core Components
- `scripts/Resources/world_map_node.gd` - Individual map node resource
- `scripts/Resources/map_data.gd` - Map data container
- `scripts/Managers/world_map.gd` - Main map manager
- `scripts/UI/line_renderer.gd` - Connection line renderer

---

## 🎯 **Node Types**

| Type | Purpose | Features |
|------|---------|----------|
| **BATTLE** | Combat missions | Map scene, objectives, level recommendation |
| **STORY** | Narrative events | Dialogue, cutscenes |
| **SHOP** | Item purchasing | Weapon/item shops |
| **REST** | Party recovery | Heal HP, remove status |
| **OPTIONAL** | Side content | Skippable, bonus rewards |

---

## 📊 **Node States**

### State Flow:
```
LOCKED → UNLOCKED → COMPLETED
  ↓         ↓          ↓
Gray     White      Green
```

### State Properties:
- **is_unlocked**: Can be selected and viewed
- **is_completed**: Has been finished
- **is_optional**: Not required for campaign completion

---

## 🔗 **Node Connections**

### Connection Types:

#### 1. **Next Nodes** (`next_nodes`)
- Nodes that unlock **after** this one completes
- Can have multiple next nodes (branching paths)

#### 2. **Required Nodes** (`required_nodes`)
- Must complete these **before** unlocking this node
- Used for converging paths or prerequisites

### Example Structure:
```
Chapter 1 (start)
    ↓
Chapter 2A ← Optional Side Quest
    ↓              ↓
Chapter 3 ←————————┘
    ↓
Chapter 4 (requires 2A AND Side Quest)
```

---

## 💾 **Creating Map Data**

### Method 1: Resource Files (.tres)

```gdscript
# 1. Create MapData resource
var map = MapData.new()
map.map_id = "main_campaign"
map.map_name = "The Sacred Stones"

# 2. Create nodes
var ch1 = WorldMapNode.create_battle_node(
    "Chapter 1: The Fall of Renais",
    "res://maps/chapter1.tscn",
    1
)
ch1.node_id = "chapter_1"
ch1.position = Vector2(100, 100)
ch1.gold_reward = 1000
ch1.exp_reward = 50

var ch2 = WorldMapNode.create_battle_node(
    "Chapter 2: The Protected",
    "res://maps/chapter2.tscn",
    2
)
ch2.node_id = "chapter_2"
ch2.position = Vector2(200, 150)

# 3. Connect nodes
ch1.next_nodes = ["chapter_2"]

# 4. Add to map
map.add_node(ch1)
map.add_node(ch2)
map.starting_node_id = "chapter_1"

# 5. Save as resource
ResourceSaver.save(map, "res://data/main_campaign.tres")
```

### Method 2: Factory Methods

```gdscript
# Battle node
var battle = WorldMapNode.create_battle_node(
    "Prologue",
    "res://maps/prologue.tscn",
    1
)

# Story node
var story = WorldMapNode.create_story_node(
    "Village Scene",
    "Meet the villagers and learn about the crisis"
)
```

---

## 🎮 **Using the World Map**

### Scene Setup:

```
WorldMap (Node2D)
├── Camera2D
├── MapContainer (Node2D)
│   └── [Node instances created at runtime]
├── LineRenderer (Node2D)
├── UILayer (CanvasLayer)
└── AudioStreamPlayer
```

### Script Setup:

```gdscript
# In world_map.tscn
@export var map_data: MapData  # Assign your map resource
@export var starting_node_id: String = "chapter_1"
```

### Programmatic Usage:

```gdscript
# Get reference to world map
var world_map = $WorldMap

# Complete a node (e.g., after battle)
world_map.complete_node(current_node, turns_taken)

# Select a node
world_map.select_node("chapter_2")

# Check progress
var progress = world_map.map_data.get_completion_percentage()
print("Campaign %.1f%% complete" % progress)
```

---

## 🏆 **Rewards System**

### Node Rewards:

```gdscript
var node = WorldMapNode.new()
node.gold_reward = 1500
node.exp_reward = 100
node.item_rewards = ["iron_sword", "vulnerary", "door_key"]
```

### Applying Rewards (in your battle completion code):

```gdscript
func on_battle_victory(node: WorldMapNode):
    # Award gold
    player_party.add_gold(node.gold_reward)
    
    # Award EXP (distribute to party)
    for unit in player_party.units:
        unit.gain_exp(node.exp_reward / player_party.units.size())
    
    # Award items
    for item_id in node.item_rewards:
        player_inventory.add_item(item_id)
    
    # Complete node
    world_map.complete_node(node, turns_taken)
```

---

## 💾 **Save/Load System**

### Automatic Saving:
```gdscript
# World map automatically saves on:
- Node completion
- Before battle transition
```

### Manual Save/Load:
```gdscript
# Save
world_map.save_map_state()

# Load
if world_map.load_map_state():
    print("Progress restored!")
```

### Save Data Includes:
- ✅ Unlocked nodes
- ✅ Completed nodes  
- ✅ Available nodes
- ✅ Current node
- ✅ Completion times (for battles)
- ✅ Times completed (for replays)

---

## 🎨 **Visual Customization**

### Node Appearance:

```gdscript
var node = WorldMapNode.new()
node.node_icon = preload("res://icons/battle_hard.png")
node.node_color = Color.RED  # For hard mode chapters
node.position = Vector2(300, 200)
```

### Connection Line Colors:

The system automatically colors connections:
- **Gray**: Locked path
- **Yellow**: Available after current completion
- **Green**: Unlocked and ready

---

## 🔍 **Validation & Debug**

### Validate Map Data:

```gdscript
var errors = map_data.validate_map_data()
if not errors.is_empty():
    for error in errors:
        print("ERROR: %s" % error)
```

### Auto-Repair:

```gdscript
if map_data.repair_map_data():
    print("Map data repaired!")
```

### Debug Output:

```gdscript
# Print node info
node.debug_print()
# === Chapter 1: The Fall of Renais === [chapter_1]
# Type: Battle
# Position: (100, 100)
# State: Unlocked, Completed
# Recommended Level: 1
# ...

# Print map info
map_data.debug_print()
# === Map: The Sacred Stones === [main_campaign]
# Nodes: 25
# Unlocked: 8
# Completed: 5
# Progress: 20.0%
# ...

# Print world map state
world_map.debug_print()
# === World Map State ===
# Map: The Sacred Stones
# Nodes: 25
# Visited: 5
# Available: 3
# Current: Chapter 6
# Progress: 20.0%
```

---

## 📋 **Complete Example**

### Creating a Campaign:

```gdscript
extends Node

func create_campaign() -> MapData:
    var map = MapData.new()
    map.map_id = "sacred_stones"
    map.map_name = "The Sacred Stones"
    map.map_description = "Follow Eirika and Ephraim's journey"
    
    # Prologue
    var prologue = WorldMapNode.create_battle_node(
        "Prologue: The Fall of Renais",
        "res://maps/prologue.tscn",
        1
    )
    prologue.node_id = "prologue"
    prologue.position = Vector2(400, 100)
    prologue.description = "Renais is under attack!"
    prologue.enemy_count = 8
    prologue.gold_reward = 500
    prologue.exp_reward = 50
    
    # Chapter 1
    var ch1 = WorldMapNode.create_battle_node(
        "Chapter 1: Escape!",
        "res://maps/chapter1.tscn",
        2
    )
    ch1.node_id = "chapter_1"
    ch1.position = Vector2(400, 200)
    ch1.description = "Flee the castle before it falls"
    ch1.required_nodes = ["prologue"]
    ch1.enemy_count = 12
    ch1.gold_reward = 1000
    ch1.exp_reward = 100
    
    # Chapter 2 (branching path)
    var ch2a = WorldMapNode.create_battle_node(
        "Chapter 2A: The Protected",
        "res://maps/chapter2a.tscn",
        3
    )
    ch2a.node_id = "chapter_2a"
    ch2a.position = Vector2(300, 300)
    ch2a.description = "Eirika's route"
    ch2a.required_nodes = ["chapter_1"]
    
    var ch2b = WorldMapNode.create_battle_node(
        "Chapter 2B: The Departure",
        "res://maps/chapter2b.tscn",
        3
    )
    ch2b.node_id = "chapter_2b"
    ch2b.position = Vector2(500, 300)
    ch2b.description = "Ephraim's route"
    ch2b.required_nodes = ["chapter_1"]
    
    # Side quest (optional)
    var side1 = WorldMapNode.new()
    side1.node_id = "side_village"
    side1.node_name = "Village of the Oracles"
    side1.node_type = WorldMapNode.NodeType.SHOP
    side1.position = Vector2(250, 250)
    side1.is_optional = true
    side1.required_nodes = ["chapter_1"]
    side1.item_rewards = ["silver_sword", "elixir"]
    
    # Connect nodes
    prologue.next_nodes = ["chapter_1"]
    ch1.next_nodes = ["chapter_2a", "chapter_2b", "side_village"]
    
    # Add all nodes
    map.add_node(prologue)
    map.add_node(ch1)
    map.add_node(ch2a)
    map.add_node(ch2b)
    map.add_node(side1)
    
    map.starting_node_id = "prologue"
    
    # Validate
    var errors = map.validate_map_data()
    if not errors.is_empty():
        push_error("Campaign has errors!")
        for error in errors:
            push_error("  - %s" % error)
    
    return map
```

---

## 🔧 **Integration with Battle System**

### After Battle Victory:

```gdscript
# In your battle victory handler
func on_victory():
    var node = current_battle_node  # Your current node
    
    # Get turns taken
    var turns = battle_manager.current_turn
    
    # Complete node (this unlocks next nodes)
    world_map.complete_node(node, turns)
    
    # Award rewards
    award_rewards(node)
    
    # Return to world map
    get_tree().change_scene_to_file("res://scenes/world_map.tscn")
```

### Battle Scene Setup:

```gdscript
# Store which node started this battle
var current_battle_node: WorldMapNode

# When loading battle from world map
func load_battle(node: WorldMapNode):
    current_battle_node = node
    # ... rest of battle setup
```

---

## ⚡ **Performance Tips**

1. **Cache Node Lookups**: MapData caches nodes by ID
2. **Batch Updates**: Update visuals once after multiple state changes
3. **Lazy Loading**: Load map scenes only when needed
4. **Efficient Save**: Only saves changed state

---

## 🎯 **Best Practices**

1. **Always validate map data** in editor
2. **Use unique node IDs** (snake_case recommended)
3. **Set proper prerequisites** to avoid sequence breaking
4. **Mark side content as optional** for accurate progress tracking
5. **Save before battles** in case of crashes
6. **Provide visual feedback** for unlocks and completions

---

## 📊 **Quick Reference**

### Node Creation:
```gdscript
WorldMapNode.create_battle_node(name, map_path, level)
WorldMapNode.create_story_node(name, description)
```

### Map Operations:
```gdscript
map_data.add_node(node)
map_data.get_node(node_id)
map_data.get_completion_percentage()
```

### World Map:
```gdscript
world_map.select_node(node_id)
world_map.complete_node(node, turns)
world_map.save_map_state()
world_map.load_map_state()
```

---

## 🎊 **System Complete!**

The world map system is **fully integrated and production-ready** with:
- ✅ Multiple node types (Battle, Story, Shop, Rest, Optional)
- ✅ Branching campaign paths
- ✅ Complete save/load system
- ✅ Validation & auto-repair
- ✅ Progress tracking
- ✅ Reward system
- ✅ Debug utilities
- ✅ Visual connection rendering

Ready for your Fire Emblem campaign! 🗺️⚔️🏰
