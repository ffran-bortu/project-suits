"""
FILE: default.gd (Beehave Node Template)
PURPOSE: Template for creating custom Beehave behavior tree nodes.

OVERVIEW:
This is a Godot script template that provides the basic structure for custom Beehave nodes. When creating
a new Beehave node script, this template is used to scaffold the tick() function which is the core of
all behavior tree node logic. The template returns SUCCESS by default.

FUNCTIONS IN THIS FILE:

1. tick(actor: Node, blackboard: Blackboard) -> int
   - What it does: Executes node logic each behavior tree tick
   - Uses: Called by Beehave behavior tree system
   - Returns: int - status code (SUCCESS, FAILURE, or RUNNING)

NOTES:
- Template file for Godot editor "Create Script" dialog
- Used when creating scripts that extend Beehave node types
- _BASE_ placeholder replaced with actual base class name
- Default implementation returns SUCCESS
- Behavior tree node types include: ActionLeaf, ConditionLeaf, Decorator, Composite
- Actor is the node executing the behavior, blackboard stores shared state
"""

# meta-name: Default
# meta-default: true
extends _BASE_


func tick(actor: Node, blackboard: Blackboard) -> int:
	return SUCCESS
