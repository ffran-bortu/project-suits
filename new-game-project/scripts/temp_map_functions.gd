func _on_view_map_pressed() -> void:
	update_help_text("Viewing map. Press X to return.")
	_enter_map_view_mode()


## Enter map view mode
func _enter_map_view_mode() -> void:
	# Hide all prep screen UI
	for child in get_children():
		if child is Control:
			child.visible = false
	
	# Allow clicks to pass through to see map
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Show simple "Press X to Return" HUD
	var hud = PanelContainer.new()
	hud.name = "MapViewHUD"
	hud.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_top = -60
	hud.offset_left = 20
	hud.offset_right = -20
	hud.offset_bottom = -20
	
	var label = Label.new()
	label.text = "Map View - Press X to Return"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(label)
	
	add_child(hud)
	DebugLog.log("PrepScreen: Entered map view mode", "cyan")


## Exit map view mode
func _exit_map_view_mode() -> void:
	# Remove HUD
	var hud = get_node_or_null("MapViewHUD")
	if hud:
		hud.queue_free()
	
	# Restore UI visibility
	for child in get_children():
		if child is Control and child.name != "MapViewHUD":
			child.visible = true
	
	# Restore input  
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	update_help_text("Choose an option to prepare for battle.")


func _on_equip_skills_pressed() -> void:
