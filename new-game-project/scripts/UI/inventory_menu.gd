class_name InventoryMenu
extends Panel

## Detailed inventory menu for using/equipping items

signal item_selected(item: Resource, action_type: String)
signal menu_closed

# --- UI References ---
var item_list: VBoxContainer
var title_label: Label
var description_label: Label
var current_unit: Unit
var current_buttons: Array[Button] = []

func _ready() -> void:
	_setup_ui()
	hide()
	set_process_input(false)

func _setup_ui() -> void:
	# Create Panel Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.8, 0.8)
	add_theme_stylebox_override("panel", style)
	
	# Layout Container
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT) # Fill panel
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "Inventory"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)
	
	# Item List Container
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	item_list = VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list)
	
	# Description
	description_label = Label.new()
	description_label.text = "Description..."
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.y = 60
	vbox.add_child(description_label)
	
func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(visible)

func show_inventory(unit: Unit) -> void:
	if not unit: return
	current_unit = unit
	
	# Clear old items
	for child in item_list.get_children():
		child.queue_free()
	current_buttons.clear()
	
	# Populate items
	if unit.inventory and unit.inventory.items:
		for item in unit.inventory.items:
			_create_item_button(item)
			
	# Update Title
	title_label.text = "%s's Inventory" % unit.unit_name
	description_label.text = "Select an item to use or equip."
	
	# Configure Panel
	size = Vector2(300, 400) # Ensure good size
	
	# Center on screen
	var vp_size = get_viewport_rect().size
	position = vp_size * 0.5 - size * 0.5
	
	show()
	
	# Focus first button
	if not current_buttons.is_empty():
		current_buttons[0].grab_focus()

func _create_item_button(item: Resource) -> void:
	var btn = Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Format text based on type
	var text = ""
	if item is Weapon:
		text = item.weapon_name
		if current_unit.inventory.equipped_item == item:
			text += " (E)"
	elif item is Consumable:
		text = "%s (%d)" % [item.item_name, item.uses]
	else:
		text = "Unknown Item"
		
	btn.text = text
	
	# Connect signals
	btn.pressed.connect(func(): _on_item_pressed(item))
	btn.focus_entered.connect(func(): _on_item_focused(item))
	
	item_list.add_child(btn)
	current_buttons.append(btn)

func _on_item_pressed(item: Resource) -> void:
	var action = ""
	if item is Consumable:
		if item.can_use_on(current_unit):
			action = "use"
		else:
			# Play error sound
			print("Cannot use this item!")
			return
	elif item is Weapon:
		action = "equip"
		
	if action != "":
		item_selected.emit(item, action)
		hide()

func _on_item_focused(item: Resource) -> void:
	if item.get("description"):
		description_label.text = item.description

func _input(event: InputEvent) -> void:
	if not visible: return
	
	# Cancel
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_X):
		menu_closed.emit()
		hide()
		get_viewport().set_input_as_handled()
		
	# Navigation (handled by Button focus automatically, but we can intercept custom focus here if needed)
