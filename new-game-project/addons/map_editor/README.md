# Map Editor Usage Guide

## What is it?
A visual editor for creating tactical battle maps. Paint terrain heights, place unit spawns, and save maps for use in battles.

## How to Enable
1. Go to **Project → Project Settings → Plugins**
2. Enable "Tactical Map Editor"
3. Click the **Map Editor** tab at the bottom of the editor

## Features

### Brush Modes
- **Terrain Height**: Paint elevation (0 = flat, positive = hills, negative = pits)
- **Player Spawn**: Place blue spawn point for player units
- **Enemy Spawn**: Place red spawn point for enemy units
- **Erase**: Remove terrain/spawns from cell

### Controls
- **Left Click**: Paint single cell
- **Click + Drag**: Paint continuously
- **Grid Size**: Change map dimensions (4-20 cells)
- **Height Value**: Set terrain elevation (-5 to 5)

### Visual Feedback
- **Gray grid**: Empty cells
- **Brown cells**: Elevated terrain (height > 0)
- **Blue cells**: Water/pits (height < 0)
- **Blue P**: Player spawn point
- **Red E**: Enemy spawn point
- **Numbers**: Terrain height value

## Saving Maps
1. Design your map
2. Click **Save Map**
3. Map saved to `user://maps/custom_map_[timestamp].json`

Format:
```json
{
  "grid_size": {"x": 8, "y": 8},
  "height_map": [[0, 0, 1, ...], ...],
  "players": [{"x": 1, "y": 2}, ...],
  "enemies": [{"x": 6, "y": 5}, ...]
}
```

## Using Maps in Game
To use your custom maps, update `main.gd` to load from your saved JSON file instead of using `simple_terrain.gd`.

## Tips
- Start with flat terrain (height 0), then add hills/valleys
- Place player spawns on left side, enemies on right
- Create bottlenecks with elevated terrain
- Test in-game to see how movement works with your terrain

## Future Enhancements
- Load existing maps
- Tile-based terrain types (grass, forest, water)
- Object placement (walls, destructibles)
- Victory condition zones
- Export to .tres Resource format
