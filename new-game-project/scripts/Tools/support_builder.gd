@tool
extends RefCounted
class_name SupportConversationBuilder

## A fluent builder for quick Support Conversation creation
## Usage:
## var builder = SupportConversationBuilder.new()
## var conv = builder.between("lyn", "hector").rank("C").line("Lyn: Hi").line("Hector: Ho").build()
## ResourceSaver.save(conv, "path.tres")

var _conv: SupportConversation

func _init():
	_conv = SupportConversation.new()

func between(char_a: String, char_b: String) -> SupportConversationBuilder:
	_conv.character_a_id = char_a
	_conv.character_b_id = char_b
	return self

func rank(rank_str: String) -> SupportConversationBuilder:
	_conv.rank = SupportConversation.string_to_rank(rank_str)
	return self

func line(text: String) -> SupportConversationBuilder:
	_conv.conversation_lines.append(text)
	return self

func lines(text_array: Array[String]) -> SupportConversationBuilder:
	_conv.conversation_lines.append_array(text_array)
	return self

func unlock_at_chapter(chapter: int) -> SupportConversationBuilder:
	_conv.required_chapter = chapter
	return self

func build() -> SupportConversation:
	_conv.conversation_id = "%s_%s_%s" % [_conv.character_a_id, _conv.character_b_id, _conv.get_rank_string()]
	return _conv

static func create_c(char_a: String, char_b: String, lines_arr: Array[String]) -> SupportConversation:
	return SupportConversationBuilder.new().between(char_a, char_b).rank("C").lines(lines_arr).build()
