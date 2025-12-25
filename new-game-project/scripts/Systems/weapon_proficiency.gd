"""
FILE: weapon_proficiency.gd
PURPOSE: Tracks weapon proficiency ranks (E-S) and experience with rank-up progression.

OVERVIEW:
Resource for managing weapon mastery. Stores proficiencies Dictionary (weapon_type -> {rank, exp}), tracks XP per weapon type,
auto-ranks up on thresholds, provides stat bonuses by rank (S=+5, A=+3, B=+2, C=+1), calculates rank progress percentage.
Supports Fire Emblem-style weapon ranks with colored display. Emits rank_increased signal on level up.

FUNCTIONS: initialize_proficiency, get_rank, get_experience, can_use_weapon, add_experience, _calculate_rank_from_exp,
get_rank_bonus, get_rank_progress, serialize, deserialize, get_all_proficiencies, get_debug_summary, debug_print - 13 total

NOTES: Ranks: E(0 exp) → D(30) → C(80) → B(150) → A(250) → S(400). Rank colors: E=white, D=light blue, C=green, B=yellow, A=orange, S=red.
Signal: rank_increased(weapon_type, new_rank). Proficiency bonuses apply to hit/avoid.
"""


class_name WeaponProficiency
extends Resource

## Weapon proficiency system with rank progression and bonuses

# --- Proficiency Rank Enum ---
enum ProficiencyRank {
	NONE = -1,  # Cannot use
	E = 0,      # Beginner
	D = 1,      # Novice
	C = 2,      # Adequate
	B = 3,      # Skilled
	A = 4,      # Expert
	S = 5       # Master
}

const RANK_NAMES: Dictionary = {
	ProficiencyRank.NONE: "-",
	ProficiencyRank.E: "E",
	ProficiencyRank.D: "D",
	ProficiencyRank.C: "C",
	ProficiencyRank.B: "B",
	ProficiencyRank.A: "A",
	ProficiencyRank.S: "S"
}

const RANK_COLORS: Dictionary = {
	ProficiencyRank.NONE: Color.GRAY,
	ProficiencyRank.E: Color.WHITE,
	ProficiencyRank.D: Color.LIGHT_BLUE,
	ProficiencyRank.C: Color.LIGHT_GREEN,
	ProficiencyRank.B: Color.YELLOW,
	ProficiencyRank.A: Color.ORANGE,
	ProficiencyRank.S: Color.RED
}

# Experience required to rank up
const RANK_THRESHOLDS: Dictionary = {
	ProficiencyRank.E: 0,
	ProficiencyRank.D: 30,
	ProficiencyRank.C: 80,
	ProficiencyRank.B: 150,
	ProficiencyRank.A: 250,
	ProficiencyRank.S: 400
}

# --- Proficiency Data ---
var proficiencies: Dictionary = {}  # PhysicalDamageType -> {rank: int, exp: int}

# --- Signals ---
signal rank_increased(weapon_type: int, new_rank: ProficiencyRank)


## Initialize proficiency for a weapon type
## @param weapon_type: Physical damage type
## @param starting_rank: Initial rank
func initialize_proficiency(weapon_type: int, starting_rank: ProficiencyRank = ProficiencyRank.E) -> void:
	if not proficiencies.has(weapon_type):
		proficiencies[weapon_type] = {
			"rank": starting_rank,
			"exp": RANK_THRESHOLDS.get(starting_rank, 0)
		}


## Get proficiency rank for weapon type
## @param weapon_type: Physical damage type
## @return: ProficiencyRank
func get_rank(weapon_type: int) -> ProficiencyRank:
	if not proficiencies.has(weapon_type):
		return ProficiencyRank.NONE
	return proficiencies[weapon_type].rank


## Get proficiency experience for weapon type
## @param weapon_type: Physical damage type
## @return: Current experience
func get_experience(weapon_type: int) -> int:
	if not proficiencies.has(weapon_type):
		return 0
	return proficiencies[weapon_type].exp


## Check if can use weapon type
## @param weapon_type: Physical damage type
## @param required_rank: Minimum rank required
## @return: true if proficient enough
func can_use_weapon(weapon_type: int, required_rank: ProficiencyRank = ProficiencyRank.E) -> bool:
	var current_rank := get_rank(weapon_type)
	if current_rank == ProficiencyRank.NONE:
		return false
	return current_rank >= required_rank


## Add proficiency experience
## @param weapon_type: Physical damage type
## @param amount: Experience to add
## @return: true if ranked up
func add_experience(weapon_type: int, amount: int) -> bool:
	if not proficiencies.has(weapon_type):
		initialize_proficiency(weapon_type)
	
	var data: Dictionary = proficiencies[weapon_type]
	var old_rank: ProficiencyRank = data.rank
	
	data.exp += amount
	
	# Check for rank up
	var new_rank := _calculate_rank_from_exp(data.exp)
	if new_rank > old_rank and new_rank <= ProficiencyRank.S:
		data.rank = new_rank
		rank_increased.emit(weapon_type, new_rank)
		return true
	
	data.rank = new_rank
	return false


## Calculate rank from experience
## @param exp: Total experience
## @return: Corresponding rank
func _calculate_rank_from_exp(exp: int) -> ProficiencyRank:
	if exp >= RANK_THRESHOLDS[ProficiencyRank.S]:
		return ProficiencyRank.S
	elif exp >= RANK_THRESHOLDS[ProficiencyRank.A]:
		return ProficiencyRank.A
	elif exp >= RANK_THRESHOLDS[ProficiencyRank.B]:
		return ProficiencyRank.B
	elif exp >= RANK_THRESHOLDS[ProficiencyRank.C]:
		return ProficiencyRank.C
	elif exp >= RANK_THRESHOLDS[ProficiencyRank.D]:
		return ProficiencyRank.D
	else:
		return ProficiencyRank.E


## Get stat bonus from proficiency rank
## @param rank: Proficiency rank
## @return: Hit/Avoid bonus
func get_rank_bonus(rank: ProficiencyRank) -> int:
	match rank:
		ProficiencyRank.S: return 5
		ProficiencyRank.A: return 3
		ProficiencyRank.B: return 2
		ProficiencyRank.C: return 1
		_: return 0


## Get progress to next rank
## @param weapon_type: Physical damage type
## @return: Progress from 0.0 to 1.0
func get_rank_progress(weapon_type: int) -> float:
	if not proficiencies.has(weapon_type):
		return 0.0
	
	var data: Dictionary = proficiencies[weapon_type]
	var current_rank: ProficiencyRank = data.rank
	
	if current_rank == ProficiencyRank.S:
		return 1.0
	
	var current_threshold: int = RANK_THRESHOLDS[current_rank]
	var next_threshold: int = RANK_THRESHOLDS[current_rank + 1]
	var progress := float(data.exp - current_threshold) / float(next_threshold - current_threshold)
	
	return clamp(progress, 0.0, 1.0)


## Serialize for save/load
## @return: Dictionary
func serialize() -> Dictionary:
	return {
		"proficiencies": proficiencies.duplicate(true)
	}


## Deserialize from save data
## @param data: Save data
## @return: true if successful
func deserialize(data: Dictionary) -> bool:
	if not data:
		return false
	
	proficiencies = data.get("proficiencies", {})
	return true


## Get all proficiencies
## @return: Dictionary of all proficiencies
func get_all_proficiencies() -> Dictionary:
	return proficiencies.duplicate(true)


## Get debug summary
## @return: String summary
func get_debug_summary() -> String:
	var summary := "=== Weapon Proficiencies ===\n"
	
	if proficiencies.is_empty():
		summary += "No proficiencies\n"
		return summary
	
	for weapon_type in proficiencies:
		var data: Dictionary = proficiencies[weapon_type]
		var rank_name: String = RANK_NAMES.get(data.rank, "?")
		var progress := get_rank_progress(weapon_type) * 100
		
		summary += "%s: Rank %s (%d exp, %.0f%% to next)\n" % [
			Weapon.PHYSICAL_TYPE_NAMES.get(weapon_type, "Unknown"),
			rank_name,
			data.exp,
			progress
		]
	
	return summary


## Debug print
func debug_print() -> void:
	print(get_debug_summary())
