# Example Support Conversation: Lyn + Eliwood (A Rank)

extends SupportConversation

func _init():
	character_a_id = "lyn"
	character_b_id = "eliwood"
	rank = RelationshipRank.A
	
	conversation_lines = [
		"Lyn: Eliwood, can I ask you something personal?",
		"Eliwood: Of course. What is it?",
		"Lyn: What drives you to fight so hard?",
		"Eliwood: ...I fight for those who can't. For a future where everyone is free.",
		"Lyn: That's beautiful. I fight for the same reason.",
		"Eliwood: I know. That's why I trust you more than anyone.",
		"Lyn: I feel the same way about you.",
		"Eliwood: Then let's make that future a reality. Together.",
		"Lyn: Together."
	]
	
	# Use proper SupportConversation properties
	required_rank = RelationshipRank.B  # Requires B rank to unlock A
	required_chapter = 5  # Available from chapter 5
	relationship_points_reward = 150  # Bond points gained
	status = ConversationStatus.LOCKED  # Starts locked
