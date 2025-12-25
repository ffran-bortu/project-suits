"""
FILE: debug_log.gd
PURPOSE: Centralized logging system for debug messages with color-coded, spam-free console output.

OVERVIEW:
This static utility class provides professional debug logging with rich-text color formatting and smart
spam prevention (only logs when values change). It offers categorical logging for different game events
(phase changes, combat, AI, movement) with emoji tags and custom colors. The system can be globally
toggled on/off and tracks state changes to prevent console flooding with duplicate messages.

FUNCTIONS IN THIS FILE:

1. set_debug_enabled(enabled)
   - What it does: Globally enables or disables all debug logging
   - Uses: Called at game start or via debug menu to control console verbosity
   - Returns: void

2. debug_nospam(debug_name, argument)
   - What it does: Logs a message only when the value changes from last call (prevents spam)
   - Uses: For tracking state changes like selected unit, current phase, AI target
   - Returns: void

3. debug_log_bool(dict_entry, argument)
   - What it does: Logs boolean values with custom true/false strings and colors
   - Uses: Helper for debug_nospam when tracking boolean states
   - Returns: void

4. debug_log_concat1(dict_entry, argument)
   - What it does: Logs concatenated message + value with emoji tag and color
   - Uses: Helper for debug_nospam for most debug categories
   - Returns: void

5. log(message, color)
   - What it does: Quick one-off log with specified color (always shows, no spam check)
   - Uses: For important one-time messages or non-repeating events
   - Returns: void

6. error(message)
   - What it does: Logs critical error in red with ❌ icon (ALWAYS shows, even if debug disabled)
   - Uses: For reporting errors that need immediate attention
   - Returns: void

7. warn(message)
   - What it does: Logs warning in yellow with ⚠️ icon
   - Uses: For non-critical issues or suspicious states
   - Returns: void

8. success(message)
   - What it does: Logs success message in green with ✓ icon
   - Uses: For confirming successful operations (save complete, battle won, etc.)
   - Returns: void

NOTES:
- Static class (no instantiation needed, call DebugLog.log() directly)
- Uses Godot's print_rich() for BBCode color formatting
- debug_dict contains predefined categories (phase_changed, unit_selected, combat_attacker, etc.)
- Each category has: message template, color, type (bool/concat1), and state tracking (tmp/old)
- Set debug_enabled to false in production builds to silence all logs except errors
- No dependencies (leaf utility node)
"""

class_name DebugLog
extends RefCounted
## Professional debug logging system with color-coded, no-spam output
##
## Adapted from godot-tactical-rpg-development reference project.
## Provides clean, color-coded console output that only logs when values change.

## Enable/disable debug mode globally
static var debug_enabled: bool = true
static var visual_debug: bool = false  # For visual debugging (raycasts, etc)

## Color codes for different message types
const DEBUG_COLORS: Dictionary = {
	"magenta": "FF00FF",
	"yellow": "FFFF00",
	"green": "00FF00",
	"cyan": "00FFFF",
	"purple": "800080",
	"orange": "FFA500",
	"red": "FF0000",
	"blue": "0088FF",
	"white": "FFFFFF"
}

## Debug state tracking - prevents spam by only logging on change
static var debug_dict: Dictionary = {
	"phase_changed": {
		"tmp": null, "old": null,
		"message": "[ 🎮 Phase ] ",
		"color": "magenta",
		"type": "concat1"
	},
	"unit_selected": {
		"tmp": null, "old": null,
		"message": "[ 👾 Unit Selected ] ",
		"color": "green",
		"type": "concat1"
	},
	"combat_attacker": {
		"tmp": null, "old": null,
		"message": "[ ⚔️ Attacker ] ",
		"color": "orange",
		"type": "concat1"
	},
	"combat_defender": {
		"tmp": null, "old": null,
		"message": "[ 🛡️ Defender ] ",
		"color": "cyan",
		"type": "concat1"
	},
	"combat_damage": {
		"tmp": null, "old": null,
		"message": "[ 💥 Damage Dealt ] ",
		"color": "red",
		"type": "concat1"
	},
	"ai_target": {
		"tmp": null, "old": null,
		"message": "[ 🤖 AI Target ] ",
		"color": "yellow",
		"type": "concat1"
	},
	"movement_path": {
		"tmp": null, "old": null,
		"message": "[ 👣 Moving to ] ",
		"color": "blue",
		"type": "concat1"
	},
	"unit_died": {
		"tmp": null, "old": null,
		"message": "[ 💀 Unit Defeated ] ",
		"color": "red",
		"type": "concat1"
	},
	"turn_number": {
		"tmp": null, "old": null,
		"message": "[ 📋 Turn ] ",
		"color": "purple",
		"type": "concat1"
	},
	"camera_focus": {
		"tmp": null, "old": null,
		"message": "[ 📷 Camera Focus ] ",
		"color": "cyan",
		"type": "concat1"
	}
}

## Enable or disable debug logging
##
## @param enabled: true to enable, false to disable
static func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	if enabled:
		print_rich("[color=#00FF00]✓ Debug logging ENABLED[/color]")
	else:
		print_rich("[color=#FF0000]✗ Debug logging DISABLED[/color]")

## Log debug message without spamming console
##
## Only logs when the value changes from previous call.
##
## @param debug_name: Category name (must exist in debug_dict)
## @param argument: Value to log
static func debug_nospam(debug_name: String, argument: Variant) -> void:
	if not debug_enabled:
		return
	
	if debug_name in debug_dict:
		var _d: Dictionary = debug_dict[debug_name]
		
		match _d.type:
			"bool":
				debug_log_bool(_d, argument)
			"concat1":
				debug_log_concat1(_d, argument)

## Log boolean value with custom strings
static func debug_log_bool(dict_entry: Dictionary, argument: Variant) -> void:
	dict_entry.tmp = argument
	
	if dict_entry.old != dict_entry.tmp:
		var open_color: String = "[color=#" + DEBUG_COLORS[dict_entry.color] + "]"
		var close_color: String = "[/color]"
		
		var parse_bool: String = dict_entry.bool_strings[0] if argument else dict_entry.bool_strings[1]
		
		if dict_entry.has('message'):
			print_rich(open_color, dict_entry.message, "[i][u]", parse_bool, "[/u][/i]", close_color)
		
	if dict_entry.old == null or dict_entry.old != dict_entry.tmp:
		dict_entry.old = dict_entry.tmp

## Log concatenated value
static func debug_log_concat1(dict_entry: Dictionary, argument: Variant) -> void:
	dict_entry.tmp = argument
	
	if dict_entry.old != dict_entry.tmp:
		var open_color: String = "[color=#" + DEBUG_COLORS[dict_entry.color] + "]"
		var close_color: String = "[/color]"
		
		if dict_entry.has('message'):
			print_rich(open_color, dict_entry.message, "[i][u]", dict_entry.tmp, "[/u][/i]", close_color)
		
	if dict_entry.old == null or dict_entry.old != dict_entry.tmp:
		dict_entry.old = dict_entry.tmp

## Quick log for one-off messages (always shows)
##
## @param message: Message to log
## @param color: Color name from DEBUG_COLORS
static func log(message: String, color: String = "white") -> void:
	if not debug_enabled:
		return
	
	if color in DEBUG_COLORS:
		var open_color: String = "[color=#" + DEBUG_COLORS[color] + "]"
		print_rich(open_color, message, "[/color]")
	else:
		print(message)

## Log error in red
static func error(message: String) -> void:
	print_rich("[color=#FF0000]❌ ERROR: ", message, "[/color]")

## Log warning in yellow
static func warn(message: String) -> void:
	if not debug_enabled:
		return
	print_rich("[color=#FFFF00]⚠️ WARNING: ", message, "[/color]")

## Log success in green
static func success(message: String) -> void:
	if not debug_enabled:
		return
	print_rich("[color=#00FF00]✓ ", message, "[/color]")
