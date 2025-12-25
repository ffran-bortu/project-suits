"""
FILE: shop_screen.gd
PURPOSE: Provides the shop interface where players can purchase weapons and items using gold.

OVERVIEW:
This screen displays available shop inventory and allows players to browse and purchase items.
It tracks the player's gold and updates the display when purchases are made. Currently implements
the basic UI framework with placeholders for full shop functionality.

FUNCTIONS IN THIS FILE:

1. _ready()
   - What it does: Connects the buy button signal to the purchase handler
   - Uses: Called automatically when the node enters the scene tree
   - Returns: void

2. setup(inventory: Array[Weapon], gold: int)
   - What it does: Initializes the shop with available items and player's current gold amount
   - Uses: Called when opening the shop screen
   - Returns: void

3. refresh()
   - What it does: Updates the gold display and item list to reflect current state
   - Uses: Called after purchases or when shop state changes
   - Returns: void

4. _on_buy_pressed()
   - What it does: Handles purchase logic when player clicks the buy button
   - Uses: Signal callback for buy button press
   - Returns: void

NOTES:
- Depends on Weapon class for item data
- Emits shop_closed signal when shop is exited
- TODO: Implement item list population and purchase logic
- Currently displays gold amount but purchase functionality is incomplete
"""

"""
FILE: shop_screen.gd
PURPOSE: Shop interface for buying/selling weapons and items.
NOTES: Merchant/shop UI.
"""
extends Control
## Shop UI for buying weapons/items

signal shop_closed

@onready var item_list = $Panel/ItemList
@onready var buy_button = $Panel/BuyButton
@onready var gold_label = $Panel/GoldLabel

var shop_inventory: Array[Weapon] = []
var player_gold: int = 1000

func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)

func setup(inventory: Array[Weapon], gold: int) -> void:
	shop_inventory = inventory
	player_gold = gold
	refresh()

func refresh() -> void:
	gold_label.text = "Gold: %d" % player_gold
	# TODO: Populate item list

func _on_buy_pressed() -> void:
	# TODO: Purchase logic
	pass
