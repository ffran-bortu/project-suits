@tool
extends RefCounted
class_name ChapterBuilder

## A fluent builder for creating WorldMapNode resources (Chapters).
## Usage:
## var ch1 = ChapterBuilder.new_chapter("chapter_1", "The Beginning")
##     .battle("res://maps/ch1.tscn", 1)
##     .intro(intro_sequence)
##     .unlocks("chapter_2")
##     .build()

var _node: WorldMapNode

static func new_chapter(id: String, name: String) -> ChapterBuilder:
	var builder = ChapterBuilder.new()
	builder._node = WorldMapNode.new()
	builder._node.node_id = id
	builder._node.node_name = name
	return builder

func battle(map_path: String, level: int = 1) -> ChapterBuilder:
	_node.node_type = WorldMapNode.NodeType.BATTLE
	_node.map_scene_path = map_path
	_node.recommended_level = level
	return self

func story_only(description: String) -> ChapterBuilder:
	_node.node_type = WorldMapNode.NodeType.STORY
	_node.description = description
	return self

func intro(sequence: DialogueSequence, forced: bool = true) -> ChapterBuilder:
	_node.intro_story = sequence
	_node.force_story_playback = forced
	return self

func outro(sequence: DialogueSequence) -> ChapterBuilder:
	_node.outro_story = sequence
	return self

func unlocks(next_node_id: String) -> ChapterBuilder:
	if not _node.next_nodes.has(next_node_id):
		_node.next_nodes.append(next_node_id)
	return self

func requires(prev_node_id: String) -> ChapterBuilder:
	if not _node.required_nodes.has(prev_node_id):
		_node.required_nodes.append(prev_node_id)
	return self

func reward_gold(amount: int) -> ChapterBuilder:
	_node.gold_reward = amount
	return self

func build() -> WorldMapNode:
	return _node
