@tool
extends RefCounted
class_name StoryBuilder

## Builder for DialogueSequence resources.
## Usage:
## var seq = StoryBuilder.new_sequence("intro")
##     .add_line("Lyn", "Hello world")
##     .add_choice("Go Left", "left_path")
##     .build()

var _sequence: DialogueSequence

static func new_sequence(id: String) -> StoryBuilder:
	var builder = StoryBuilder.new()
	builder._sequence = DialogueSequence.new()
	builder._sequence.sequence_id = id
	return builder

func title(text: String) -> StoryBuilder:
	_sequence.display_name = text
	return self

func background(texture: Texture2D) -> StoryBuilder:
	_sequence.background = texture
	return self

func add_line(speaker: String, text: String, portrait: Texture2D = null) -> StoryBuilder:
	var line = DialogueLine.create_simple(speaker, text, portrait)
	_sequence.add_line(line)
	return self

func add_narrator(text: String) -> StoryBuilder:
	var line = DialogueLine.create_narrator(text)
	_sequence.add_line(line)
	return self

func build() -> DialogueSequence:
	return _sequence
