class_name Consumable
extends Resource

## Consumable item resource (Potions, Tonics, Keys, etc.)

# --- Effect Types ---
enum EffectType {
	HEAL,           # Restores HP
	BOOST_STAT,     # Temporary or permanent stat boost
	RESTORE_STATUS, # Cures status effects
	KEY,            # Opens doors/chests
	PROMOTION       # Promotes unit class
}

# --- Basic Info ---
@export_group("Basic Info")
@export var item_name: String = "Vulnerary"
@export var item_id: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

# --- Properties ---
@export_group("Properties")
@export var effect_type: EffectType = EffectType.HEAL
@export_range(1, 99) var uses: int = 3
@export_range(0, 10000) var cost: int = 300
@export var is_droppable: bool = true

# --- Effect Data ---
@export_group("Effect Details")
# For HEAL: impact amount. For BOOST: stat amount.
@export var power: int = 10 
# For BOOST: which stat to boost (using GameTypes.StatType if possible, or string)
@export var stat_type: GameTypes.StatType = GameTypes.StatType.HP
# For BOOST: is it permanent?
@export var is_permanent: bool = false
# For KEY: what tag does it open? (e.g. "door", "chest")
@export var key_tag: String = ""

# --- Usage Validation ---
## Check if item can be used on specific unit
func can_use_on(unit: Node) -> bool:
	if not unit: 
		return false
		
	match effect_type:
		EffectType.HEAL:
			if unit.has_method("get_current_hp") and unit.has_method("get_max_hp"):
				return unit.get_current_hp() < unit.get_max_hp()
			# Fallback for property access
			if "current_health" in unit and "max_health" in unit:
				return unit.current_health < unit.max_health
			return false
			
		EffectType.BOOST_STAT:
			# Always usable unless there's a cap, assuming valid unit
			return true
			
		EffectType.KEY:
			# Keys are contextual, usually checked against terrain, not unit
			return false
			
		_:
			return true

## Get usage summary
func get_debug_summary() -> String:
	return "%s (%d uses): %s" % [item_name, uses, description]
