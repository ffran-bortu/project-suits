# Weapon System Documentation

## 🎯 **Overview**

Comprehensive Fire Emblem-style weapon system with:
- **Weapon Triangle** (Piercing > Slashing > Striking > Piercing)
- **Proficiency System** (Ranks E through S)
- **Weapon Abilities** (Brave, Killer, Effective, Lifesteal, etc.)
- **Durability Management**
- **Full Integration** with existing Unit system

---

## 📁 **File Structure**

### Core Resources
- `scripts/Resources/weapon.gd` - Weapon resource with abilities
- `scripts/Systems/weapon_inventory.gd` - Inventory & equipment management
- `scripts/Systems/weapon_proficiency.gd` - Proficiency tracking
- `scripts/Managers/weapon_factory.gd` - Weapon creation & templates

---

## 🔺 **Weapon Triangle System**

### Triangle Rules:
```
Piercing > Slashing > Striking > Piercing
(Lances) > (Swords)  > (Axes)   > (Lances)
```

### Bonuses:
- **Advantage**: +15 Hit, +1 Damage
- **Disadvantage**: -15 Hit, -1 Damage
- **Neutral**: No bonus/penalty

### Code Example:
```gdscript
var triangle = inventory.calculate_triangle_advantage(my_weapon, enemy_weapon)
# Returns: {"hit_bonus": 15, "damage_bonus": 1} if advantage
```

---

## 📊 **Proficiency System**

### Proficiency Ranks:
| Rank | Name | Experience Required | Hit/Avoid Bonus |
|------|------|---------------------|------------------|
| E | Beginner | 0 | +0 |
| D | Novice | 30 | +0 |
| C | Adequate | 80 | +1 |
| B | Skilled | 150 | +2 |
| A | Expert | 250 | +3 |
| S | Master | 400 | +5 |

### Gaining Proficiency:
- **+1 EXP** per weapon use in combat
- Automatic rank-up when thresholds reached
- Emits `rank_increased` signal

### Code Example:
```gdscript
# Check proficiency
if proficiency.can_use_weapon(weapon_type, WeaponProficiency.ProficiencyRank.C):
    # Can equip

# Gain experience (automatic on weapon use)
proficiency.add_experience(weapon_type, 1)
```

---

## ⚔️ **Weapon Abilities**

### Ability Types:
1. **COMBAT_MODIFIER** - Changes combat behavior
2. **STAT_MODIFIER** - Modifies stats
3. **ON_HIT_EFFECT** - Triggers on successful hit
4. **EFFECTIVENESS** - Bonus vs specific unit types
5. **SPECIAL** - Unique mechanics

### Pre-Configured Abilities:

#### Brave (Combat Modifier)
- Attacks twice in one round
- Examples: Brave Sword, Brave Lance

#### Killer (Stat Modifier)
- +30% Critical Hit rate
- Examples: Killer Lance, Killer Axe

#### Effective (Effectiveness)
- 3x damage to specific armor types
- Examples: Armorslayer, Horseslayer, Hammer

#### Lifesteal (On-Hit Effect)
- Heals 50% of damage dealt
- Examples: Nosferatu

#### Devil (Special)
- 31% chance to damage wielder instead
- High risk, high reward

### Creating Custom Abilities:
```gdscript
var ability = WeaponAbility.new()
ability.ability_id = "custom_ability"
ability.ability_name = "My Ability"
ability.description = "Does something cool"
ability.ability_type = WeaponAbility.AbilityType.COMBAT_MODIFIER
ability.activation_rate = 100
ability.effect_data = {"custom_value": 42}

weapon.abilities.append(ability)
```

---

## 🎒 **Weapon Inventory**

### Features:
- **Max 5 weapons** (configurable)
- **Durability tracking** (40 uses default)
- **Equipment management**
- **Proficiency integration**
- **Save/Load support**

### Usage Examples:

#### Adding Weapons:
```gdscript
var inventory = WeaponInventory.new()

# Add weapon with default durability (40)
inventory.add_weapon(WeaponFactory.create_iron_sword())

# Add weapon with custom durability
inventory.add_weapon(WeaponFactory.create_steel_lance(), 50)
```

#### Equipping Weapons:
```gdscript
# Equip by reference
inventory.equip_weapon(my_weapon)

# Equip by index
inventory.equip_weapon_by_index(0)
```

#### Using Weapons:
```gdscript
# Use equipped weapon (reduces durability)
if inventory.use_weapon():
    print("Weapon used successfully")
else:
    print("Weapon broke!")
```

#### Repairing Weapons:
```gdscript
# Full repair
inventory.repair_weapon(weapon)

# Partial repair
inventory.repair_weapon(weapon, 20)
```

---

## 🏭 **Weapon Factory**

### Pre-Configured Weapons:

#### Basic Weapons:
- `create_iron_sword()` - E rank, 5 Might
- `create_steel_sword()` - D rank, 8 Might
- `create_silver_sword()` - A rank, 13 Might
- `create_iron_lance()` - E rank, 7 Might
- `create_steel_lance()` - D rank, 10 Might
- `create_iron_axe()` - E rank, 8 Might

#### Special Weapons:
- `create_brave_sword()` - Attacks twice
- `create_killer_lance()` - +30 Crit
- `create_armorslayer()` - 3x vs Armored
- `create_horseslayer()` - 3x vs Cavalry
- `create_hammer()` - 3x vs Armored
- `create_nosferatu_tome()` - Lifesteal

#### Ranged Weapons:
- `create_javelin()` - Range 1-2
- `create_hand_axe()` - Range 1-2

#### Magic:
- `create_fire_tome()` - Basic fire magic
- `create_elfire_tome()` - Advanced fire

### Starter Kits:
```gdscript
# Get starting weapons for class
var knight_weapons = WeaponFactory.create_knight_starter_kit()
# Returns: [Iron Sword, Iron Lance]

var mage_weapons = WeaponFactory.create_mage_starter_kit()
# Returns: [Fire Tome]
```

---

## 🔧 **Integration Guide**

### Setting Up a Unit with Weapons:

```gdscript
# Create unit
var unit = Unit.new()

# Create inventory
var inventory = WeaponInventory.new()

# Add starting weapons
for weapon in WeaponFactory.create_knight_starter_kit():
    inventory.add_weapon(weapon)

# Equip first weapon
inventory.equip_weapon_by_index(0)

# Set inventory on unit
unit.weapon_inventory = inventory
```

### Combat with Weapon Triangle:

```gdscript
# Calculate triangle advantage
var triangle = attacker_inventory.calculate_triangle_advantage(
    attacker_inventory.equipped_weapon,
    defender_inventory.equipped_weapon
)

# Apply bonuses
var hit_chance = base_hit + triangle.hit_bonus
var damage = base_damage + triangle.damage_bonus
```

### Checking Weapon Abilities:

```gdscript
# Check if weapon has Brave ability
if weapon.has_ability("brave"):
    attacks_per_round = 2

# Check Killer for crit bonus
if weapon.has_ability("killer"):
    var ability = weapon.get_ability("killer")
    crit_bonus += ability.get_effect("crit_bonus", 0)
```

---

## 💾 **Save/Load System**

### Saving:
```gdscript
var save_data = inventory.serialize()
# Returns full inventory state including:
# - Weapons in inventory
# - Durability values
# - Equipped weapon
# - Proficiency data
```

### Loading:
```gdscript
inventory.deserialize(save_data)
# Restores complete inventory state
```

---

## 🐛 **Debug Tools**

### Weapon Debug:
```gdscript
weapon.debug_print()
# === Iron Sword ===
# Type: Physical (Slashing)
# Might: 5 | Hit: +0 | Crit: +0 | Weight: 5
# Range: 1-1
# ✓ Weapon valid
```

### Inventory Debug:
```gdscript
inventory.debug_print()
# === Weapon Inventory ===
# Slots: 3/5
# Equipped: Iron Sword (Durability: 35)
# Weapons:
#   1. Iron Sword (Dur: 35) [E]
#   2. Steel Lance (Dur: 40)
#   3. Fire Tome (Dur: 40)
# === Weapon Proficiencies ===
# Slashing: Rank C (95 exp, 42% to next)
# Piercing: Rank E (5 exp, 17% to next)
```

### Proficiency Debug:
```gdscript
proficiency.debug_print()
# === Weapon Proficiencies ===
# Slashing: Rank B (175 exp, 30% to next)
# Piercing: Rank D (45 exp, 30% to next)
# Striking: Rank E (15 exp, 50% to next)
```

---

## 📈 **Weapon Stats Reference**

### Weapon Type Comparison:

| Weapon | Type | Might | Hit | Weight | Range | Rank | Cost |
|--------|------|-------|-----|--------|-------|------|------|
| Iron Sword | Slashing | 5 | +90 | 5 | 1-1 | E | 460 |
| Steel Sword | Slashing | 8 | +75 | 10 | 1-1 | D | 600 |
| Silver Sword | Slashing | 13 | +75 | 8 | 1-1 | A | 1200 |
| Iron Lance | Piercing | 7 | +80 | 8 | 1-1 | E | 360 |
| Javelin | Piercing | 6 | +65 | 11 | 1-2 | E | 300 |
| Iron Axe | Striking | 8 | +75 | 10 | 1-1 | E | 270 |
| Hand Axe | Striking | 7 | +60 | 12 | 1-2 | E | 300 |
| Brave Sword | Slashing | 9 | +75 | 11 | 1-1 | C | 2000 |
| Killer Lance | Piercing | 9 | +75 | 9 | 1-1 | C | 1200 |

---

## ✨ **Advanced Features**

### Weapon Triangle Calculator:
```gdscript
# Returns advantage info
var result = WeaponInventory.calculate_triangle_advantage(lance, sword)
# Piercing > Slashing, so result = {"hit_bonus": 15, "damage_bonus": 1}
```

### Proficiency Bonus:
```gdscript
# Get bonus from proficiency rank
var bonus = proficiency.get_rank_bonus(WeaponProficiency.ProficiencyRank.A)
# Returns: 3 (applied to hit/avoid)
```

### Effectiveness System:
```gdscript
# Check if weapon is effective
var multiplier = weapon.get_effectiveness("armored")
# Armorslayer returns: 3.0
# Regular weapon returns: 1.0
```

---

## 🎯 **Quick Start Example**

Complete setup for a knight unit:

```gdscript
# 1. Create unit with inventory
var knight = Unit.new()
var inventory = WeaponInventory.new()

# 2. Add starting weapons
inventory.add_weapon(WeaponFactory.create_iron_sword())
inventory.add_weapon(WeaponFactory.create_iron_lance())

# 3. Equip sword
inventory.equip_weapon_by_index(0)

# 4. Set proficiency
var proficiency = inventory.get_proficiency()
proficiency.initialize_proficiency(Weapon.PhysicalDamageType.SLASHING, WeaponProficiency.ProficiencyRank.D)
proficiency.initialize_proficiency(Weapon.PhysicalDamageType.PIERCING, WeaponProficiency.ProficiencyRank.E)

# 5. Attach to unit
knight.weapon_inventory = inventory

# 6. Ready for combat!
print("Knight ready with %s" % inventory.get_equipped_weapon().weapon_name)
```

---

## 📚 **Best Practices**

1. **Always validate weapons after creation:**
   ```gdscript
   var errors = weapon.validate_weapon()
   if not errors.is_empty():
       push_error("Invalid weapon!")
   ```

2. **Check proficiency before equipping:**
   ```gdscript
   if not inventory.can_use_weapon(weapon):
       print("Cannot use - insufficient proficiency!")
   ```

3. **Track durability:**
   ```gdscript
   if inventory.get_weapon_durability(weapon) < 10:
       print("Warning: Low durability!")
   ```

4. **Use weapon triangle:**
   ```gdscript
   var advantage = inventory.calculate_triangle_advantage(my_weapon, enemy_weapon)
   if advantage.hit_bonus > 0:
       print("Triangle advantage!")
   ```

5. **Save inventory state:**
   ```gdscript
   var save_data = inventory.serialize()
   save_file.store_var(save_data)
   ```

---

## 🎊 **System Complete!**

The weapon system is now **fully integrated and production-ready** with:
- ✅ Weapon triangle (Piercing > Slashing > Striking)
- ✅ Proficiency ranks (E-S)
- ✅ Weapon abilities (Brave, Killer, Effective, etc.)
- ✅ Durability management
- ✅ Save/load support
- ✅ Complete validation
- ✅ Debug utilities
- ✅ Factory presets

Ready for tactical RPG combat! ⚔️🛡️
