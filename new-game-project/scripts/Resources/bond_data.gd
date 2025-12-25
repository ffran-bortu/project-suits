"""
FILE: bond_data.gd
PURPOSE: Typed resource to store bond progression with a single partner.
"""
class_name BondData
extends Resource

@export var partner_id: String = ""
@export var rank: CharacterData.BondRank = CharacterData.BondRank.NONE
@export var points: int = 0
@export var unlocked_conversations: Array[String] = []  # IDs of unlocked convos
