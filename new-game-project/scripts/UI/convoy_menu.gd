class_name ConvoyMenu
extends Control

## UI for managing global convoy inventory and trading with units.
##
## Features split view: Unit Items (Left) vs Convoy Items (Right).
## Allows moving items back and forth.

signal menu_closed

# --- UI References ---
# We will create these in _ready structurally for simplicity if scene not loaded,
# effectively "scaffolding" the UI in code to ensure it works even without a .tscn file initially.
var main_container: HBoxContainer
var unit_panel: VBoxContainer
var convoy_panel: VBoxContainer
var unit_list: ItemList
var convoy_list: ItemList
var title_label: Label
var help_label: Label
var close_button: Button

var current_unit: Unit = null
var inventory_manager: InventoryManager = null

func _ready() -> void:
	# Build UI programmatically for robustness
	_setup_ui()
	
	# Find manager
	inventory_manager = get_tree().get_first_node_in_group("inventory_manager")
	if not inventory_manager:
		push_error("ConvoyMenu: InventoryManager not found!")
	
	hide()

func _setup_ui() -> void:
	# Full screen background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Header
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "Convoy"
	title_label.add_theme_font_size_override("font_size", 32)
	header.add_child(title_label)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	close_button = Button.new()
	close_button.text = "Close (Esc)"
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	
	# Main Content (Split View)
	main_container = HBoxContainer.new()
	main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_container.add_theme_constant_override("separation", 20)
	vbox.add_child(main_container)
	
	# Left: Unit Side
	unit_panel = VBoxContainer.new()
	unit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(unit_panel)
	
	var unit_label = Label.new()
	unit_label.text = "Unit Inventory"
	unit_panel.add_child(unit_label)
	
	unit_list = ItemList.new()
	unit_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	unit_list.item_activated.connect(_on_unit_item_activated)
	unit_panel.add_child(unit_list)
	
	# Right: Convoy Side
	convoy_panel = VBoxContainer.new()
	convoy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(convoy_panel)
	
	var convoy_label = Label.new()
	convoy_label.text = "Convoy Inventory"
	convoy_panel.add_child(convoy_label)
	
	convoy_list = ItemList.new()
	convoy_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	convoy_list.item_activated.connect(_on_convoy_item_activated)
	convoy_panel.add_child(convoy_list)
	
	# Footer
	help_label = Label.new()
	help_label.text = "Double click items to transfer."
	vbox.add_child(help_label)

func setup(unit: Unit) -> void:
	current_unit = unit
	if current_unit:
		title_label.text = "Convoy - Managing %s" % current_unit.unit_name
	
	refresh()
	show()
	unit_list.grab_focus()

func refresh() -> void:
	unit_list.clear()
	convoy_list.clear()
	
	if not inventory_manager: return
	
	# Populate Unit List
	if current_unit and current_unit.inventory:
		for item in current_unit.inventory.items:
			var txt = _get_item_name(item)
			if item == current_unit.inventory.equipped_item:
				txt += " (E)"
			unit_list.add_item(txt)
			
	# Populate Convoy List
	for item in inventory_manager.get_convoy_items():
		convoy_list.add_item(_get_item_name(item))

func _get_item_name(item: Resource) -> String:
	if item is Weapon:
		return item.weapon_name
	elif item is Consumable:
		return "%s (%d)" % [item.item_name, item.uses]
	return "Unknown Item"

func _on_unit_item_activated(index: int) -> void:
	if not current_unit or not inventory_manager: return
	
	# Move to convoy
	if inventory_manager.transfer_unit_to_convoy(current_unit, index):
		refresh()
		# Keep focus logic if needed
		if unit_list.item_count > 0:
			var new_idx = min(index, unit_list.item_count - 1)
			unit_list.select(new_idx)
		else:
			convoy_list.grab_focus()

func _on_convoy_item_activated(index: int) -> void:
	if not current_unit or not inventory_manager: return
	
	# Move to unit
	if inventory_manager.transfer_convoy_to_unit(index, current_unit):
		refresh()
		if convoy_list.item_count > 0:
			var new_idx = min(index, convoy_list.item_count - 1)
			convoy_list.select(new_idx)
	else:
		help_label.text = "Unit inventory is full!"

func _on_close_pressed() -> void:
	menu_closed.emit()
	hide()

func _input(event: InputEvent) -> void:
	if not visible: return
	
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
