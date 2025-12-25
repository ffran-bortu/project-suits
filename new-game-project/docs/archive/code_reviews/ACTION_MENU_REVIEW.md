# Action Menu Review - action_menu.gd

## Current Implementation Analysis

### ✅ Good Points:
1. Clean signal-based architecture
2. Proper button connections
3. Input handling for Z/X keys
4. Menu closes on outside click

### ❌ Issues Found:

#### 1. **Positioning Problems**
- `unproject_position()` can fail if unit is off-screen
- No bounds checking - menu can appear outside viewport
- Hardcoded offset (+50, 0) may not work for all screen positions
- No fallback positioning strategy

#### 2. **Input Handling Issues**
- Using `_input()` can conflict with other input handlers
- No keyboard navigation (arrow keys) between buttons
- Mouse click detection might interfere with game input when menu is visible

#### 3. **Button Logic Issue**
- Line 69: `attack_button.disabled = unit_has_acted or not unit_has_moved`
- **Problem**: This disables attack if unit hasn't moved, which is incorrect
- **Should be**: Attack should be available if unit hasn't acted (regardless of movement)
- **Correct logic**: `attack_button.disabled = unit_has_acted`

#### 4. **Missing Features**
- No visual feedback for disabled buttons
- No keyboard navigation (Up/Down arrows)
- No sound effects
- No smooth transitions
- No error handling

#### 5. **Code Quality**
- Missing null checks for buttons
- No validation of world_position parameter
- Could use constants for offsets

## Recommended Improvements

### Fix 1: Correct Button Logic
```gdscript
func update_actions(unit_has_moved: bool, unit_has_acted: bool):
    # Attack is available if unit hasn't acted yet
    attack_button.disabled = unit_has_acted
    
    # End turn is always available (but might be disabled if unit hasn't acted)
    end_turn_button.disabled = false  # Always allow ending turn
```

### Fix 2: Better Positioning with Bounds Checking
```gdscript
func show_at_position(world_position: Vector3):
    var camera = get_viewport().get_camera_3d()
    if camera == null:
        # Fallback: show at center of screen
        position = get_viewport_rect().size * 0.5 - size * 0.5
        show()
        attack_button.grab_focus()
        return
    
    # Convert 3D to screen position
    var screen_pos = camera.unproject_position(world_position)
    
    # Check if position is on screen
    var viewport_size = get_viewport_rect().size
    var menu_size = size
    
    # Adjust position to keep menu on screen
    screen_pos.x = clamp(screen_pos.x, 0, viewport_size.x - menu_size.x)
    screen_pos.y = clamp(screen_pos.y, 0, viewport_size.y - menu_size.y)
    
    # If unit is off-screen, show menu at edge pointing toward unit
    if screen_pos.x < 0 or screen_pos.x > viewport_size.x:
        screen_pos.x = viewport_size.x * 0.5 - menu_size.x * 0.5
    if screen_pos.y < 0 or screen_pos.y > viewport_size.y:
        screen_pos.y = viewport_size.y * 0.5 - menu_size.y * 0.5
    
    position = screen_pos
    show()
    attack_button.grab_focus()
```

### Fix 3: Add Keyboard Navigation
```gdscript
func _input(event):
    if not visible:
        return
    
    # Handle Z key to confirm focused button
    if event.is_action_pressed("select"):
        var focused = get_viewport().gui_get_focus_owner()
        if focused == attack_button and not attack_button.disabled:
            _on_attack_pressed()
            get_viewport().set_input_as_handled()
        elif focused == end_turn_button and not end_turn_button.disabled:
            _on_end_turn_pressed()
            get_viewport().set_input_as_handled()
    
    # Handle X key to cancel
    if event.is_action_pressed("cancel"):
        menu_closed.emit()
        hide()
        get_viewport().set_input_as_handled()
    
    # Handle arrow keys for navigation
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_UP or event.keycode == KEY_DOWN:
            var current_focus = get_viewport().gui_get_focus_owner()
            if current_focus == attack_button:
                end_turn_button.grab_focus()
            elif current_focus == end_turn_button:
                attack_button.grab_focus()
            get_viewport().set_input_as_handled()
    
    # Close menu if clicked outside (only on release to avoid conflicts)
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos = get_global_mouse_position()
        if not get_global_rect().has_point(mouse_pos):
            menu_closed.emit()
            hide()
            get_viewport().set_input_as_handled()
```

### Fix 4: Add Null Checks
```gdscript
func _ready():
    if not attack_button:
        push_error("ActionMenu: AttackButton not found!")
        return
    if not end_turn_button:
        push_error("ActionMenu: EndTurnButton not found!")
        return
    
    attack_button.pressed.connect(_on_attack_pressed)
    end_turn_button.pressed.connect(_on_end_turn_pressed)
    hide()
```

### Fix 5: Better Visual Feedback
```gdscript
func update_actions(unit_has_moved: bool, unit_has_acted: bool):
    if not attack_button or not end_turn_button:
        return
    
    # Attack is available if unit hasn't acted
    attack_button.disabled = unit_has_acted
    if attack_button.disabled:
        attack_button.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray out
    else:
        attack_button.modulate = Color.WHITE
    
    # End turn is always available
    end_turn_button.disabled = false
    end_turn_button.modulate = Color.WHITE
```

## Priority Fixes

1. **CRITICAL**: Fix button logic (line 69) - Attack should not require movement
2. **HIGH**: Add bounds checking for menu positioning
3. **MEDIUM**: Add keyboard navigation (arrow keys)
4. **MEDIUM**: Add null checks
5. **LOW**: Add visual feedback for disabled buttons

