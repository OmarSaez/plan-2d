extends PanelContainer
class_name LayerPanel

var list_vbox: VBoxContainer
var title_label: Label
var layer_to_delete: int = -1
var is_collapsed: bool = false
var content_vbox: VBoxContainer
var confirm_dialog_vbox: VBoxContainer
var confirm_dialog_separator: HSeparator
var collapse_btn: Button
var add_btn: Button
var add_btn_wrapper: Control

var confirm_wrapper: Control
var content_wrapper: Control
var layer_scroll: ScrollContainer

var eye_icon = preload("res://assets/icons/eye.svg")
var eye_off_icon = preload("res://assets/icons/eye-off.svg")
var edit_icon = preload("res://assets/icons/edit-2.svg")
var trash_icon = preload("res://assets/icons/trash-2.svg")
var plus_icon = preload("res://assets/icons/plus.svg")
var chevron_up = preload("res://assets/icons/chevron-up.svg")
var chevron_down = preload("res://assets/icons/chevron-down.svg")

func _ready() -> void:
	custom_minimum_size = Vector2(300, 60)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.16)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.18, 0.20, 0.24)
	add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	margin.add_child(main_vbox)
	
	confirm_wrapper = Control.new()
	confirm_wrapper.clip_contents = true
	confirm_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_wrapper.custom_minimum_size.y = 0
	main_vbox.add_child(confirm_wrapper)
	
	content_wrapper = Control.new()
	content_wrapper.clip_contents = true
	content_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_wrapper.custom_minimum_size.y = 0
	main_vbox.add_child(content_wrapper)
	
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	main_vbox.add_child(header)
	
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	header.add_child(title_label)
	
	add_btn_wrapper = Control.new()
	add_btn_wrapper.clip_contents = true
	add_btn_wrapper.custom_minimum_size.x = 30
	header.add_child(add_btn_wrapper)
	
	add_btn = _create_icon_btn(plus_icon, 30)
	add_btn.pressed.connect(func():
		var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
		if canvas: canvas.add_layer(tr("UI_NEW_LAYER"))
	)
	add_btn_wrapper.add_child(add_btn)
	
	var collapse_wrapper = Control.new()
	collapse_wrapper.custom_minimum_size = Vector2(30, 30)
	header.add_child(collapse_wrapper)
	
	collapse_btn = _create_icon_btn(chevron_down, 30)
	collapse_btn.pivot_offset = Vector2(15, 15)
	collapse_btn.pressed.connect(_on_collapse_pressed)
	collapse_wrapper.add_child(collapse_btn)
	
	content_vbox = VBoxContainer.new()
	content_vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	content_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	content_wrapper.add_child(content_vbox)
	
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 8
	content_vbox.add_child(top_spacer)
	
	layer_scroll = ScrollContainer.new()
	layer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layer_scroll.custom_minimum_size.y = 0
	content_vbox.add_child(layer_scroll)
	
	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layer_scroll.add_child(list_vbox)
	
	var hs = HSeparator.new()
	hs.add_theme_constant_override("separation", 12)
	content_vbox.add_child(hs)
	
	_build_confirm_dialog()
	
	EventBus.layers_changed.connect(_on_layers_changed)
	EventBus.active_layer_changed.connect(_on_active_layer_changed)

	call_deferred("_load_initial_layers")

func _load_initial_layers() -> void:
	var canvas = get_tree().current_scene.get_node_or_null("Workspace/CanvasManager")
	if canvas:
		_on_layers_changed(canvas._get_layers_info())

func _create_icon_btn(icon: Texture2D, size: int = 24) -> Button:
	var btn = Button.new()
	btn.icon = icon
	btn.custom_minimum_size = Vector2(size, size)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.expand_icon = true
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.24)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h = sb.duplicate()
	sb_h.bg_color = Color(0.25, 0.28, 0.33)
	btn.add_theme_stylebox_override("hover", sb_h)
	return btn

func _build_confirm_dialog() -> void:
	confirm_dialog_vbox = VBoxContainer.new()
	confirm_dialog_vbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	confirm_dialog_vbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
	confirm_wrapper.add_child(confirm_dialog_vbox)
	
	var lbl = Label.new()
	lbl.text = "¿Eliminar capa y sus trazos?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	confirm_dialog_vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	confirm_dialog_vbox.add_child(hbox)
	
	var btn_sb = StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.18, 0.20, 0.24)
	btn_sb.corner_radius_top_left = 16
	btn_sb.corner_radius_top_right = 16
	btn_sb.corner_radius_bottom_left = 16
	btn_sb.corner_radius_bottom_right = 16
	btn_sb.content_margin_left = 16
	btn_sb.content_margin_right = 16
	btn_sb.content_margin_top = 8
	btn_sb.content_margin_bottom = 8
	
	var btn_sb_hover = btn_sb.duplicate()
	btn_sb_hover.bg_color = Color(0.25, 0.28, 0.33)
	
	var btn_yes = Button.new()
	btn_yes.text = "Eliminar"
	btn_yes.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_yes.add_theme_stylebox_override("normal", btn_sb)
	btn_yes.add_theme_stylebox_override("hover", btn_sb_hover)
	btn_yes.pressed.connect(func():
		var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
		if canvas: canvas.remove_layer(layer_to_delete)
		hide_confirm_delete()
	)
	hbox.add_child(btn_yes)
	
	var btn_no = Button.new()
	btn_no.text = "Cancelar"
	btn_no.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	btn_no.add_theme_stylebox_override("normal", btn_sb)
	btn_no.add_theme_stylebox_override("hover", btn_sb_hover)
	btn_no.pressed.connect(func(): hide_confirm_delete())
	hbox.add_child(btn_no)

	var hs2 = HSeparator.new()
	hs2.add_theme_constant_override("separation", 12)
	confirm_dialog_vbox.add_child(hs2)

func show_confirm_delete(index: int) -> void:
	layer_to_delete = index
	call_deferred("_update_panel_height")

func hide_confirm_delete() -> void:
	layer_to_delete = -1
	call_deferred("_update_panel_height")

func _on_collapse_pressed() -> void:
	is_collapsed = !is_collapsed
	
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	
	if is_collapsed:
		var target_w = title_label.get_minimum_size().x + 100 # Márgenes + separaciones + botones + bordes
		tw.tween_property(add_btn, "modulate:a", 0.0, 0.15)
		tw.tween_property(add_btn_wrapper, "custom_minimum_size:x", 0, 0.3)
		tw.tween_property(self, "custom_minimum_size:x", target_w, 0.3)
		tw.tween_property(content_wrapper, "custom_minimum_size:y", 0, 0.3)
		tw.tween_property(confirm_wrapper, "custom_minimum_size:y", 0, 0.3)
		tw.tween_property(layer_scroll, "custom_minimum_size:y", 0, 0.3)
		tw.tween_property(collapse_btn, "rotation_degrees", -180, 0.3)
	else:
		tw.tween_property(add_btn_wrapper, "custom_minimum_size:x", 30, 0.3)
		tw.tween_property(self, "custom_minimum_size:x", 300, 0.3)
		tw.tween_property(collapse_btn, "rotation_degrees", 0, 0.3)
		tw.chain().tween_property(add_btn, "modulate:a", 1.0, 0.15)
		call_deferred("_update_panel_height")

func _update_panel_height() -> void:
	if is_collapsed: return
	
	await get_tree().process_frame
	
	var list_h = list_vbox.get_minimum_size().y
	var clamped_list_h = clamp(list_h, 0, 350)
	
	var content_h = 0
	if list_h > 0:
		content_h = clamped_list_h + 20 # 12 (separador inferior) + 8 (espaciador superior)
	
	var confirm_h = 0
	if layer_to_delete >= 0:
		confirm_h = confirm_dialog_vbox.get_minimum_size().y
		
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	
	tw.tween_property(layer_scroll, "custom_minimum_size:y", clamped_list_h, 0.3)
	tw.tween_property(content_wrapper, "custom_minimum_size:y", content_h, 0.3)
	tw.tween_property(confirm_wrapper, "custom_minimum_size:y", confirm_h, 0.3)

func _on_layers_changed(layers_info: Array) -> void:
	for c in list_vbox.get_children():
		c.queue_free()
	
	var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
	if not canvas: return
	
	for i in range(layers_info.size()):
		var info = layers_info[i]
		var item = _create_layer_item(i, info, canvas.active_layer_index == i)
		list_vbox.add_child(item)
		
	call_deferred("_update_panel_height")

func _on_active_layer_changed(index: int) -> void:
	var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
	if canvas:
		_on_layers_changed(canvas._get_layers_info())

func _create_layer_item(index: int, info: Dictionary, is_active: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.bg_color = Color(0.2, 0.3, 0.6, 0.3) if is_active else Color(0.15, 0.16, 0.18, 1.0)
	if is_active:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.3, 0.5, 1.0)
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.2, 0.22, 0.26)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
			if canvas: canvas.set_active_layer(index)
	)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var eye_btn = _create_icon_btn(eye_icon if info.visible else eye_off_icon, 24)
	eye_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	eye_btn.pressed.connect(func():
		var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
		if canvas: canvas.toggle_layer_visibility(index)
	)
	hbox.add_child(eye_btn)
	
	var lbl = Label.new()
	lbl.text = info.name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)
	
	var line_edit = LineEdit.new()
	line_edit.text = info.name
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.hide()
	hbox.add_child(line_edit)
	
	line_edit.text_submitted.connect(func(new_text):
		var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
		if canvas: canvas.rename_layer(index, new_text)
	)
	
	var edit_btn = _create_icon_btn(edit_icon, 24)
	edit_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	edit_btn.pressed.connect(func():
		lbl.hide()
		line_edit.show()
		line_edit.grab_focus()
	)
	hbox.add_child(edit_btn)
	
	var del_btn = _create_icon_btn(trash_icon, 24)
	del_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	del_btn.pressed.connect(func():
		show_confirm_delete(index)
	)
	hbox.add_child(del_btn)
	
	if is_active:
		title_label.text = info.name.to_upper()
	
	return panel
