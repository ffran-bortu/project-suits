## QUICK CONTENT CREATION GUIDE

### Creating Character Classes (10 min each)
1. In Godot: Right-click `data/classes` folder
2. New Resource → Resource → CharacterClass
3. Use template from `warrior_template.txt` or `mage_template.txt`
4. Adjust stats for balance:
   - Base stats: 1-10 range
   - Growth rates: 20-70% (50% = average)
   - Position bonuses: 0-5
5. Save as `.tres` file

### Creating Characters (5 min each)
1. Right-click `data/characters`
2. New Resource → CharacterData
3. Assign primary/secondary classes (drag .tres files)
4. Set level (usually 1 for player, varies for enemies)
5. Add unique_skill_names if special (e.g., ["Lone Wolf"])
6. Save as `.tres`

### Creating Duos in Battle
```gdscript
# In your battle setup:
var char_a = load("res://data/characters/arden.tres")
var char_b = load("res://data/characters/lyndis.tres")

var duo = DuoFactory.create_duo(
    char_a, char_b,
    true,  # char_a is frontliner
    Vector2i(2, 2),  # grid position
    0,  # team (0=player)
    $World/Units,  # parent node
    unit_manager  # unit manager reference
)
```

### Creating Solo Units
```gdscript
var solo_char = load("res://data/characters/solo_warrior.tres")
solo_char.unique_skill_names = ["Lone Wolf"]  # Makes them strong solo!

var solo = DuoFactory.create_solo(
    solo_char,
    true,  # frontline
    Vector2i(5, 5),
    0,
    $World/Units,
    unit_manager
)
```

### Recommended Starter Roster
**Player Team** (6 characters = 3 duos):
1. Warrior + Mage (balanced offensive)
2. Commander + Archer (support + ranged)
3. Tank + Cleric (defense + healing)

**Enemy Team** (start simple):
1-2 enemy duos with lower stats
OR 3-4 solo enemies with 70% penalty

### Quick Balance Tips
- **Frontline classes**: High HP/DEF, medium STR
- **Backline classes**: Medium HP, high MAG or support
- **Growth rates**: Total ~300-350% per class
- **Duo vs Solo**: Duo is stronger, solo needs good skill or Lone Wolf
