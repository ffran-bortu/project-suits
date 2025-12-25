class_name GameTypes
extends Object

## Central repository for game-wide enums and types to prevent duplication

enum StatType {
	HP,
	STR,
	MAG,
	SKILL,
	SPD,
	LUCK,
	DEF,
	RES,
	MOV,
	CON # Constitution/Build
}

## Helper to convert string to StatType
static func string_to_stat_type(stat_name: String) -> StatType:
	match stat_name.to_lower():
		"hp", "max_health", "max_hp": return StatType.HP
		"str", "strength": return StatType.STR
		"mag", "magic": return StatType.MAG
		"skl", "skill", "dex": return StatType.SKILL
		"spd", "speed": return StatType.SPD
		"lok", "luck", "lck": return StatType.LUCK
		"def", "defense": return StatType.DEF
		"res", "resistance": return StatType.RES
		"mov", "movement": return StatType.MOV
		"con", "build": return StatType.CON
		_: 
			push_warning("GameTypes: Invalid stat type '%s', defaulting to HP" % stat_name)
			return StatType.HP
