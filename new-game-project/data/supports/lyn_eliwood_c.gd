# Example Support Conversation: Lyn + Eliwood (C Rank)
# This is a Godot resource file for SupportConversation

extends SupportConversation

func _init():
	character_a_id = "lyn"
	character_b_id = "eliwood"
	rank = RelationshipRank.C
	
	conversation_lines = [
		"Lyn: Eliwood, do you have a moment?",
		"Eliwood: Of course, Lyn. What's on your mind?",
		"Lyn: I've been thinking about our battle strategies.",
		"Eliwood: You fight with such grace. It's inspiring.",
		"Lyn: Thanks! Your tactics are impressive too.",
		"Eliwood: We make a good team.",
		"Lyn: Agreed. Let's keep supporting each other!"
	]
	
	# Use proper SupportConversation properties
	# C rank is the base rank, no prerequisites needed
	required_chapter = 1  # Available from start
	relationship_points_reward = 50  # Bond points gained
	status = ConversationStatus.AVAILABLE  # Available from start for testing
