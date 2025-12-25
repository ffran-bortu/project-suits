# Example Support Conversation: Lyn + Eliwood (B Rank)

extends SupportConversation

func _init():
	character_a_id = "lyn"
	character_b_id = "eliwood"
	rank = RelationshipRank.B
	
	conversation_lines = [
		"Eliwood: Lyn, I wanted to thank you.",
		"Lyn: Thank me? For what?",
		"Eliwood: For watching my back in that last battle.",
		"Lyn: That's what friends do, right?",
		"Eliwood: Friends... yes. I'm glad we met.",
		"Lyn: Me too. You remind me that there's good in this world.",
		"Eliwood: Together, we'll protect what matters most.",
		"Lyn: Always."
	]
	
	# Use proper SupportConversation properties
	required_rank = RelationshipRank.C  # Requires C rank to unlock B
	required_chapter = 3  # Available from chapter 3
	relationship_points_reward = 100  # Bond points gained
	status = ConversationStatus.LOCKED  # Starts locked
