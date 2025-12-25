"""
FILE: bond_system.gd
PURPOSE: Manages the bond/support relationship system between characters in the game.

OVERVIEW:
This system tracks bond points earned between character pairs through gameplay actions
(adjacency, duo units, healing, combat). When enough points accumulate, support ranks
unlock (C → B → A → S/A+), providing stat bonuses and unlocking support conversations.
The system enforces S/A+ exclusivity (one romantic/close partner per character).

FUNCTIONS IN THIS FILE:

1. add_bond_points(char_a, char_b, amount)
   - What it does: Awards bond points between two characters and checks for rank-up
   - Uses: Called whenever characters perform bond-worthy actions
   - Returns: void

2. check_support_unlock(char_a, char_b)
   - What it does: Evaluates current points and unlocks the next support rank if threshold met
   - Uses: Automatically called after bond points change
   - Returns: void

3. unlock_support(char_a, char_b, rank, rank_name)
   - What it does: Unlocks a specific support rank, updates data, emits signals
   - Uses: Called by check_support_unlock or manual unlock commands
   - Returns: void

4. on_duo_action(duo_unit)
   - What it does: Awards POINTS_PER_DUO_ACTION when duo unit acts
   - Uses: Called by combat/action systems when duo units perform actions
   - Returns: void

5. on_unit_healed(healer_data, target_data)
   - What it does: Awards POINTS_PER_HEAL when one unit heals another
   - Uses: Called by healing system
   - Returns: void

6. on_range_overlap_attack(attacker_data, nearby_ally_data)
   - What it does: Awards POINTS_PER_RANGE_OVERLAP_ATTACK for teamwork attacks
   - Uses: Called when attacking enemy in both units' ranges
   - Returns: void

NOTES:
- Depends on CharacterData for bond_data storage
- Emits signals: support_unlocked, s_or_aplus_locked
- S/A+ ranks lock exclusive_partner, blocking other S/A+ bonds
- Bond points are bidirectional (both characters gain points)
"""

class_name BondSystem
extends Node
## Manages bond/support relationships between characters
##
## Tracks bond points, unlocks support conversations, handles S/A+ exclusivity

const POINTS_FOR_C: int = int(GameConfig.Bond.get("POINTS_FOR_C", 100))
const POINTS_FOR_B: int = int(GameConfig.Bond.get("POINTS_FOR_B", 200))
const POINTS_FOR_A: int = int(GameConfig.Bond.get("POINTS_FOR_A", 300))
const POINTS_FOR_S_OR_APLUS: int = int(GameConfig.Bond.get("POINTS_FOR_S_OR_APLUS", 450))

const POINTS_PER_TURN_TOGETHER: int = int(GameConfig.Bond.get("POINTS_PER_TURN_TOGETHER", 2))
const POINTS_PER_DUO_ACTION: int = int(GameConfig.Bond.get("POINTS_PER_DUO_ACTION", 5))
const POINTS_PER_HEAL: int = int(GameConfig.Bond.get("POINTS_PER_HEAL", 5))
const POINTS_PER_RANGE_OVERLAP_ATTACK: int = int(GameConfig.Bond.get("POINTS_PER_RANGE_OVERLAP_ATTACK", 3))


signal support_unlocked(char_a: String, char_b: String, rank: String)
signal s_or_aplus_locked(character: String, partner: String)

## Add bond points between two characters
func add_bond_points(char_a: CharacterData, char_b: CharacterData, amount: int) -> void:
	var partner_id = char_b.character_id
	
	# Use CharacterData's add_bond_points method
	var ranked_up = char_a.add_bond_points(partner_id, amount)
	
	if ranked_up:
		check_support_unlock(char_a, char_b)

## Check if support rank should unlock
func check_support_unlock(char_a: CharacterData, char_b: CharacterData) -> void:
	var partner_id = char_b.character_id
	var points = char_a.get_bond_points(partner_id)
	var current_rank = char_a.get_bond_rank(partner_id)
	
	if current_rank == CharacterData.BondRank.NONE and points >= POINTS_FOR_C:
		unlock_support(char_a, char_b, CharacterData.BondRank.C, "C")
	elif current_rank == CharacterData.BondRank.C and points >= POINTS_FOR_B:
		unlock_support(char_a, char_b, CharacterData.BondRank.B, "B")
	elif current_rank == CharacterData.BondRank.B and points >= POINTS_FOR_A:
		unlock_support(char_a, char_b, CharacterData.BondRank.A, "A")
	elif current_rank == CharacterData.BondRank.A and points >= POINTS_FOR_S_OR_APLUS:
		if char_a.exclusive_partner == "":
			#show_s_or_aplus_choice(char_a, char_b)
			unlock_support(char_a, char_b, CharacterData.BondRank.A_PLUS, "A+")  # Default to A+ for now

## Unlock a support rank
func unlock_support(char_a: CharacterData, char_b: CharacterData, rank: CharacterData.BondRank, rank_name: String) -> void:
	var partner_id = char_b.character_id
	
	# Update bond_data with new rank
	# Since bond_data is now Array[BondData], we must find the object
	var bond: BondData = null
	# Helper not accessible here (it's internal to CharacterData), so we rely on explicit search or API
	# Best way: Use a helper on CharacterData if exposed, or manual search
	
	# We can't easily access the internal helper _get_bond_data_object from here if it's not public.
	# But we can iterate.
	for b in char_a.bond_data:
		if b.partner_id == partner_id:
			bond = b
			break
	
	if not bond:
		bond = BondData.new()
		bond.partner_id = partner_id
		bond.rank = CharacterData.BondRank.NONE
		bond.points = 0
		char_a.bond_data.append(bond)
	
	bond.rank = rank
	bond.unlocked_conversations.append(rank_name)
	
	support_unlocked.emit(char_a.character_name, char_b.character_name, rank_name)
	DebugLog.success("%s + %s unlocked %s support!" % [char_a.character_name, char_b.character_name, rank_name])
	
	# Lock S/A+ if this is rank S or A+
	if rank == CharacterData.BondRank.S or rank == CharacterData.BondRank.A_PLUS:
		char_a.exclusive_partner = partner_id
		char_b.exclusive_partner = char_a.character_id
		s_or_aplus_locked.emit(char_a.character_name, char_b.character_name)

## Award points when duo unit performs any action
## @param duo_unit: DuoUnit instance
func on_duo_action(duo_unit: Node) -> void:
	if not duo_unit:
		return
	
	# Get both characters from duo unit
	var char_a: CharacterData = null
	var char_b: CharacterData = null
	
	if duo_unit.has_method("get_frontline_character"):
		char_a = duo_unit.get_frontline_character()
	if duo_unit.has_method("get_backline_character"):
		char_b = duo_unit.get_backline_character()
	
	if char_a and char_b:
		add_bond_points(char_a, char_b, POINTS_PER_DUO_ACTION)
		# Award to both (bidirectional)
		add_bond_points(char_b, char_a, POINTS_PER_DUO_ACTION)

## Award points when one unit heals another
## @param healer_data: Character who healed
## @param target_data: Character who was healed
func on_unit_healed(healer_data: CharacterData, target_data: CharacterData) -> void:
	if healer_data and target_data and healer_data != target_data:
		add_bond_points(healer_data, target_data, POINTS_PER_HEAL)
		add_bond_points(target_data, healer_data, POINTS_PER_HEAL)

## Award points when attacking enemy that's in both units' ranges
## @param attacker_data: Character who attacked
## @param nearby_ally_data: Nearby ally who also has enemy in range
func on_range_overlap_attack(attacker_data: CharacterData, nearby_ally_data: CharacterData) -> void:
	if attacker_data and nearby_ally_data and attacker_data != nearby_ally_data:
		add_bond_points(attacker_data, nearby_ally_data, POINTS_PER_RANGE_OVERLAP_ATTACK)
		add_bond_points(nearby_ally_data, attacker_data, POINTS_PER_RANGE_OVERLAP_ATTACK)
