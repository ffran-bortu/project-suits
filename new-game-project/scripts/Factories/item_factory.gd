class_name ItemFactory
extends Object

## Factory for creating Consumable items

static func create_vulnerary() -> Consumable:
	var item = Consumable.new()
	item.item_name = "Vulnerary"
	item.item_id = "vulnerary"
	item.description = "Restores 10 HP."
	item.effect_type = Consumable.EffectType.HEAL
	item.power = 10
	item.uses = 3
	item.cost = 300
	item.icon = null # TODO: Load icon from assets
	return item

static func create_elixir() -> Consumable:
	var item = Consumable.new()
	item.item_name = "Elixir"
	item.item_id = "elixir"
	item.description = "Fully restores HP."
	item.effect_type = Consumable.EffectType.HEAL
	item.power = 999
	item.uses = 1
	item.cost = 1000
	return item

static func create_chest_key() -> Consumable:
	var item = Consumable.new()
	item.item_name = "Chest Key"
	item.item_id = "chest_key"
	item.description = "Opens chests."
	item.effect_type = Consumable.EffectType.KEY
	item.key_tag = "chest"
	item.uses = 1
	item.cost = 300
	return item

static func create_door_key() -> Consumable:
	var item = Consumable.new()
	item.item_name = "Door Key"
	item.item_id = "door_key"
	item.description = "Opens doors."
	item.effect_type = Consumable.EffectType.KEY
	item.key_tag = "door"
	item.uses = 1
	item.cost = 300
	return item

static func create_item_from_name(name: String) -> Consumable:
	match name.to_lower():
		"vulnerary": return create_vulnerary()
		"elixir": return create_elixir()
		"chest key": return create_chest_key()
		"door key": return create_door_key()
		_:
			push_warning("ItemFactory: Unknown item name '%s'" % name)
			return null
