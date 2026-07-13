extends Control

var sizes = [
	{"name": "PAPER_LETTER", "size": Vector2(816, 1056)},
	{"name": "PAPER_LEGAL", "size": Vector2(816, 1344)},
	{"name": "A4", "size": Vector2(794, 1123)},
	{"name": "A3", "size": Vector2(1123, 1587)}
]

var units = [
	{"name": "UNIT_MM", "val": "mm"},
	{"name": "UNIT_CM", "val": "cm"},
	{"name": "UNIT_M", "val": "m"},
	{"name": "UNIT_IN", "val": "in"}
]

var scales = [
	{"name": "SCALE_VERY_SMALL", "val": 0.5},
	{"name": "SCALE_SMALL", "val": 1.0},
	{"name": "SCALE_MEDIUM", "val": 4.0},
	{"name": "SCALE_LARGE", "val": 10.0},
	{"name": "SCALE_GIANT", "val": 100.0}
]

var name_input: LineEdit
var size_option: OptionButton
var unit_option: OptionButton
var scale_option: OptionButton
var modal_overlay: ColorRect

var paper_preview: ColorRect
var preview_label: Label
var preview_tween: Tween

var grid_container: GridContainer

var is_delete_mode: bool = false
var selected_for_deletion: Array = []
var btn_trash: Button

var settings_panel: PanelContainer
var settings_vbox: VBoxContainer
var is_settings_open: bool = false
var settings_btn_ref: Button
var settings_label: Label
var settings_content: Control

var lbl_title: Label
var modal_title: Label
var lbl_name: Label
var lbl_size: Label
var lbl_unit: Label
var lbl_scale: Label
var btn_cancel: Button
var btn_create: Button
var preview_title: Label
var lbl_lang: Label
var lbl_eraser: Label
var lbl_save: Label
var opt_lang: OptionButton
var opt_eraser: OptionButton
var opt_save: OptionButton

func _ready() -> void:
	# Fondo general
	var bg = ColorRect.new()
	bg.color = Color("#18191f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	_build_dashboard()
	_build_modal()
	_build_settings_modal()
	
	_update_language()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_language()

func _build_dashboard() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 32)
	margin.add_child(vbox)
	
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	
	lbl_title = Label.new()
	lbl_title.text = tr("UI_MY_PROJECTS")
	lbl_title.add_theme_font_size_override("font_size", 32)
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(lbl_title)
	
	btn_trash = _create_header_button("res://assets/icons/trash-2.svg")
	btn_trash.pressed.connect(_on_trash_pressed)
	header.add_child(btn_trash)
	
	# Espaciador para donde se situará el SettingsPanel flotante
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(48, 48)
	header.add_child(spacer)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	grid_container = GridContainer.new()
	grid_container.columns = 5
	grid_container.add_theme_constant_override("h_separation", 32)
	grid_container.add_theme_constant_override("v_separation", 32)
	scroll.add_child(grid_container)
	
	_populate_projects()

func _populate_projects() -> void:
	if not grid_container:
		return
		
	for c in grid_container.get_children():
		c.queue_free()
		
	var btn_new = _create_card_button("+", tr("UI_NEW_PROJECT"), "")
	btn_new.set_meta("is_new_btn", true)
	btn_new.pressed.connect(_on_new_project_pressed)
	grid_container.add_child(btn_new)
	
	# 2. Proyectos guardados
	var projects = EventBus.get_all_projects()
	for p in projects:
		var cfg = p.get("config", {})
		var p_name = cfg.get("name", "Proyecto")
		var ts = cfg.get("timestamp", 0)
		var p_id = cfg.get("id", "")
		
		var dict = Time.get_datetime_dict_from_unix_time(ts)
		var date_str = "%04d-%02d-%02d %02d:%02d" % [dict["year"], dict["month"], dict["day"], dict["hour"], dict["minute"]]
		
		var btn_proj = _create_card_button("", p_name, date_str, p)
		btn_proj.set_meta("project_id", p_id)
		
		btn_proj.pressed.connect(func():
			if is_delete_mode:
				_toggle_project_selection(btn_proj)
			else:
				_load_and_start_project(p)
		)
		grid_container.add_child(btn_proj)

func _create_card_button(icon_text: String, title: String, subtitle: String, project_data: Dictionary = {}) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(200, 260)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#2a2b33")
	style_normal.corner_radius_top_left = 16
	style_normal.corner_radius_top_right = 16
	style_normal.corner_radius_bottom_left = 16
	style_normal.corner_radius_bottom_right = 16
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("#3a3c47")
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("focus", style_normal)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)
	
	var icon_container = CenterContainer.new()
	icon_container.custom_minimum_size = Vector2(160, 160)
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_container)
	
	var icon_bg = ColorRect.new()
	icon_bg.custom_minimum_size = Vector2(120, 150)
	icon_bg.color = Color("#e5e7eb") if icon_text == "" else Color("#1e1f26")
	icon_bg.clip_contents = true
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.add_child(icon_bg)
	
	if icon_text == "+":
		var lbl_plus = Label.new()
		lbl_plus.text = "+"
		lbl_plus.add_theme_font_size_override("font_size", 72)
		lbl_plus.add_theme_color_override("font_color", Color.WHITE)
		icon_container.add_child(lbl_plus)
	elif project_data.has("state"):
		icon_bg.color = Color("#1e1f26")
		icon_bg.draw.connect(_on_mini_canvas_draw.bind(icon_bg, project_data))
	
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_title)
	
	if subtitle != "":
		var lbl_sub = Label.new()
		lbl_sub.text = subtitle
		lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_sub.add_theme_font_size_override("font_size", 12)
		lbl_sub.add_theme_color_override("font_color", Color("#a0a4b8"))
		vbox.add_child(lbl_sub)
		
	var select_overlay = ColorRect.new()
	select_overlay.name = "SelectOverlay"
	select_overlay.color = Color(0.1, 0.5, 1.0, 0.3)
	select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_overlay.hide()
	
	var border = ReferenceRect.new()
	border.border_color = Color(0.2, 0.6, 1.0, 1.0)
	border.border_width = 4.0
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_overlay.add_child(border)
	
	var check = TextureRect.new()
	var check_tex = load("res://assets/icons/check.svg")
	if check_tex:
		check.texture = check_tex
		check.modulate = Color(0.2, 0.6, 1.0, 1.0)
		check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		check.position = Vector2(-40, 10)
		check.mouse_filter = Control.MOUSE_FILTER_IGNORE
		select_overlay.add_child(check)
	
	btn.add_child(select_overlay)
	
	return btn

func _on_mini_canvas_draw(rect: ColorRect, p: Dictionary) -> void:
	var state = p.get("state", {})
	var config = p.get("config", {})
	if not state.has("layers"): return
	
	var p_size: Vector2 = config.get("paper_size", Vector2(816, 1056))
	var c_scale: float = config.get("canvas_scale", 1.0)
	var final_size = p_size * c_scale
	
	var available_size = rect.size - Vector2(16, 16)
	var scale_factor = min(available_size.x / final_size.x, available_size.y / final_size.y)
	
	var offset = rect.size / 2.0 - (final_size * scale_factor) / 2.0
	rect.draw_set_transform(offset, 0, Vector2(scale_factor, scale_factor))
	
	rect.draw_rect(Rect2(Vector2.ZERO, final_size), Color.WHITE)
	
	for layer in state["layers"]:
		if not layer.get("visible", true): continue
		for line in layer["lines"]:
			var pts = line.get("points", PackedVector2Array())
			if pts.size() < 2: continue
			var c = line.get("color", Color.BLACK)
			var w = max(line.get("thickness", 2.0), 1.5 / scale_factor)
			rect.draw_polyline(pts, c, w, true)

func _load_and_start_project(project_data: Dictionary) -> void:
	EventBus.current_project_config = project_data.get("config", {})
	EventBus.set_meta("loaded_state", project_data.get("state", {}))
	get_tree().change_scene_to_file("res://src/main.tscn")

func _build_modal() -> void:
	modal_overlay = ColorRect.new()
	modal_overlay.color = Color(0, 0, 0, 0.6)
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.hide()
	add_child(modal_overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.add_child(center)
	
	var panel = PanelContainer.new()
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color("#1e1f26")
	p_style.corner_radius_top_left = 16
	p_style.corner_radius_top_right = 16
	p_style.corner_radius_bottom_left = 16
	p_style.corner_radius_bottom_right = 16
	p_style.content_margin_left = 32
	p_style.content_margin_right = 32
	p_style.content_margin_top = 32
	p_style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", p_style)
	center.add_child(panel)
	
	var hbox_main = HBoxContainer.new()
	hbox_main.add_theme_constant_override("separation", 48)
	panel.add_child(hbox_main)
	
	# --- COLUMNA IZQUIERDA: FORMULARIO ---
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_main.add_child(vbox)
	
	modal_title = Label.new()
	modal_title.text = tr("UI_NEW_PROJECT")
	modal_title.add_theme_font_size_override("font_size", 24)
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(modal_title)
	
	# Nombre
	var group_name = VBoxContainer.new()
	group_name.add_theme_constant_override("separation", 6)
	vbox.add_child(group_name)
	
	lbl_name = Label.new()
	lbl_name.text = tr("UI_PROJECT_NAME")
	group_name.add_child(lbl_name)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = tr("UI_MY_PLAN")
	name_input.custom_minimum_size.x = 300
	group_name.add_child(name_input)
	
	# Tamaño
	var group_size = VBoxContainer.new()
	group_size.add_theme_constant_override("separation", 6)
	vbox.add_child(group_size)
	
	lbl_size = Label.new()
	lbl_size.text = tr("UI_PAPER_SIZE")
	group_size.add_child(lbl_size)
	
	size_option = OptionButton.new()
	for s in sizes:
		size_option.add_item(tr(s["name"]))
	size_option.item_selected.connect(func(idx): _update_preview())
	group_size.add_child(size_option)
	
	# Unidad
	var group_unit = VBoxContainer.new()
	group_unit.add_theme_constant_override("separation", 6)
	vbox.add_child(group_unit)
	
	lbl_unit = Label.new()
	lbl_unit.text = tr("UI_MEASUREMENT_UNIT")
	group_unit.add_child(lbl_unit)
	
	unit_option = OptionButton.new()
	for u in units:
		unit_option.add_item(tr(u["name"]))
	unit_option.select(1) # cm default
	unit_option.item_selected.connect(func(idx): _update_preview())
	group_unit.add_child(unit_option)
	
	# Escala (Capacidad)
	var group_scale = VBoxContainer.new()
	group_scale.add_theme_constant_override("separation", 6)
	vbox.add_child(group_scale)
	
	lbl_scale = Label.new()
	lbl_scale.text = tr("UI_CANVAS_CAPACITY")
	group_scale.add_child(lbl_scale)
	
	scale_option = OptionButton.new()
	for s in scales:
		scale_option.add_item(tr(s["name"]))
	scale_option.select(2) # Mediano default
	scale_option.item_selected.connect(func(idx): _update_preview())
	group_scale.add_child(scale_option)
	
	# Botones
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)
	
	btn_cancel = Button.new()
	btn_cancel.text = tr("UI_CANCEL")
	btn_cancel.custom_minimum_size = Vector2(120, 40)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	hbox.add_child(btn_cancel)
	
	btn_create = Button.new()
	btn_create.text = tr("UI_CREATE")
	btn_create.custom_minimum_size = Vector2(120, 40)
	
	var create_style = StyleBoxFlat.new()
	create_style.bg_color = Color("#3b82f6")
	create_style.corner_radius_top_left = 8
	create_style.corner_radius_top_right = 8
	create_style.corner_radius_bottom_left = 8
	create_style.corner_radius_bottom_right = 8
	btn_create.add_theme_stylebox_override("normal", create_style)
	btn_create.add_theme_stylebox_override("hover", create_style)
	btn_create.add_theme_stylebox_override("pressed", create_style)
	btn_create.add_theme_stylebox_override("focus", create_style)
	
	btn_create.pressed.connect(_on_create_pressed)
	hbox.add_child(btn_create)

	# --- COLUMNA DERECHA: VISTA PREVIA ---
	var preview_vbox = VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 16)
	preview_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_main.add_child(preview_vbox)
	
	preview_title = Label.new()
	preview_title.text = tr("UI_CAPACITY_PREVIEW")
	preview_title.add_theme_color_override("font_color", Color("#a0a4b8"))
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_vbox.add_child(preview_title)
	
	var paper_preview_container = CenterContainer.new()
	paper_preview_container.custom_minimum_size = Vector2(250, 250)
	preview_vbox.add_child(paper_preview_container)
	
	paper_preview = ColorRect.new()
	paper_preview.color = Color.WHITE
	paper_preview_container.add_child(paper_preview)
	
	preview_label = Label.new()
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_color_override("font_color", Color("#a0a4b8"))
	preview_vbox.add_child(preview_label)

func _update_preview() -> void:
	if not is_instance_valid(paper_preview): return
	
	var s_idx = size_option.get_selected_id()
	var u_idx = unit_option.get_selected_id()
	var scale_idx = scale_option.get_selected_id()
	
	if s_idx < 0 or u_idx < 0 or scale_idx < 0: return
	
	var paper_dim = sizes[s_idx]["size"]
	var unit_val = units[u_idx]["val"]
	var scale_val = scales[scale_idx]["val"]
	
	# Calcular dimensiones relativas para el dibujo del rectangulito
	var max_preview_size = 200.0
	var aspect = paper_dim.x / paper_dim.y
	var target_size = Vector2()
	if aspect > 1.0:
		target_size = Vector2(max_preview_size, max_preview_size / aspect)
	else:
		target_size = Vector2(max_preview_size * aspect, max_preview_size)
		
	if preview_tween and preview_tween.is_valid():
		preview_tween.kill()
		
	preview_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	preview_tween.tween_property(paper_preview, "custom_minimum_size", target_size, 0.5)
		
	# Calcular capacidad real
	var width_units = (paper_dim.x * scale_val) / 100.0
	var height_units = (paper_dim.y * scale_val) / 100.0
	
	var w_str = EventBus.format_number_locale(width_units, 2)
	var h_str = EventBus.format_number_locale(height_units, 2)
	
	preview_label.text = tr("UI_MAX_SIZE_PREVIEW") % [w_str, tr(unit_val.to_upper()), h_str, tr(unit_val.to_upper())]

func _on_new_project_pressed() -> void:
	name_input.text = ""
	size_option.select(0)
	unit_option.select(1) # cm default
	scale_option.select(2) # Mediano default
	_update_preview()
	modal_overlay.show()

func _on_cancel_pressed() -> void:
	modal_overlay.hide()

func _on_create_pressed() -> void:
	var pname = name_input.text.strip_edges()
	if pname == "":
		pname = tr("UI_NEW_PROJECT")
		
	var s_idx = size_option.get_selected_id()
	var u_idx = unit_option.get_selected_id()
	var scale_idx = scale_option.get_selected_id()
	
	var new_cfg = {
		"id": "", # Se asignará uno al guardar
		"name": pname,
		"paper_size": sizes[s_idx]["size"],
		"unit": units[u_idx]["val"],
		"canvas_scale": scales[scale_idx]["val"]
	}
	
	EventBus.current_project_config = new_cfg
	# Eliminar metadata de carga para empezar en limpio
	if EventBus.has_meta("loaded_state"):
		EventBus.remove_meta("loaded_state")
		
	get_tree().change_scene_to_file("res://src/main.tscn")

func _create_header_button(icon_path: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	var tex = load(icon_path)
	if tex:
		btn.icon = tex
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.24)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.25, 0.27, 0.32)
	btn.add_theme_stylebox_override("hover", sb_hover)
	var sb_pressed = sb.duplicate()
	sb_pressed.bg_color = Color(0.15, 0.17, 0.20)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	return btn

func _on_trash_pressed() -> void:
	if not is_delete_mode:
		is_delete_mode = true
		selected_for_deletion.clear()
		var sb = btn_trash.get_theme_stylebox("normal").duplicate()
		sb.bg_color = Color("#ef4444")
		btn_trash.add_theme_stylebox_override("normal", sb)
		_update_jiggle_mode()
	else:
		if selected_for_deletion.size() > 0:
			_show_delete_confirm()
		else:
			_exit_delete_mode()

func _exit_delete_mode() -> void:
	is_delete_mode = false
	selected_for_deletion.clear()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.24)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	btn_trash.add_theme_stylebox_override("normal", sb)
	_update_jiggle_mode()

func _update_jiggle_mode() -> void:
	for c in grid_container.get_children():
		var is_new_btn = c.get_meta("is_new_btn", false)
		if is_new_btn:
			continue
			
		if is_delete_mode:
			c.pivot_offset = c.size / 2.0
			var tw = create_tween().set_loops()
			tw.tween_property(c, "rotation_degrees", 2.0, 0.1)
			tw.tween_property(c, "rotation_degrees", -2.0, 0.1)
			c.set_meta("jiggle_tween", tw)
			_update_selection_visuals(c)
		else:
			var tw = c.get_meta("jiggle_tween")
			if tw:
				tw.kill()
				c.set_meta("jiggle_tween", null)
			c.rotation_degrees = 0
			var overlay = c.get_node_or_null("SelectOverlay")
			if overlay:
				overlay.hide()

func _toggle_project_selection(btn: Button) -> void:
	var pid = btn.get_meta("project_id", "")
	if pid == "": return
	
	if selected_for_deletion.has(pid):
		selected_for_deletion.erase(pid)
	else:
		selected_for_deletion.append(pid)
		
	_update_selection_visuals(btn)

func _update_selection_visuals(btn: Button) -> void:
	var pid = btn.get_meta("project_id", "")
	var overlay = btn.get_node_or_null("SelectOverlay")
	if overlay:
		if selected_for_deletion.has(pid):
			overlay.show()
		else:
			overlay.hide()

var delete_confirm_panel: PanelContainer

func _show_delete_confirm() -> void:
	if delete_confirm_panel != null:
		delete_confirm_panel.queue_free()
		
	delete_confirm_panel = PanelContainer.new()
	delete_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)
	delete_confirm_panel.add_theme_stylebox_override("panel", bg)
	add_child(delete_confirm_panel)
	
	var center = CenterContainer.new()
	delete_confirm_panel.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "¿Eliminar " + str(selected_for_deletion.size()) + " proyectos seleccionados?"
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.custom_minimum_size = Vector2(120, 48)
	btn_cancel.pressed.connect(func():
		delete_confirm_panel.queue_free()
		_exit_delete_mode()
	)
	hbox.add_child(btn_cancel)
	
	var btn_accept = Button.new()
	btn_accept.text = "Eliminar"
	btn_accept.custom_minimum_size = Vector2(120, 48)
	var sb_acc = StyleBoxFlat.new()
	sb_acc.bg_color = Color("#ef4444")
	btn_accept.add_theme_stylebox_override("normal", sb_acc)
	btn_accept.pressed.connect(func():
		for pid in selected_for_deletion:
			EventBus.delete_project(pid)
		delete_confirm_panel.queue_free()
		_exit_delete_mode()
		_populate_projects()
	)
	hbox.add_child(btn_accept)

func _on_settings_pressed() -> void:
	is_settings_open = !is_settings_open
	
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_settings_open:
		settings_label.show()
		settings_content.show()
		
		tw.tween_property(settings_content, "custom_minimum_size:y", settings_vbox.size.y, 0.4)
		tw.tween_property(settings_panel, "custom_minimum_size:x", 250, 0.4)
		tw.tween_property(settings_btn_ref, "rotation_degrees", 90, 0.4)
	else:
		settings_label.hide() # Ocultar inmediatamente para evitar superposición
		tw.tween_property(settings_content, "custom_minimum_size:y", 0, 0.4)
		tw.tween_property(settings_panel, "custom_minimum_size:x", 0, 0.4)
		tw.tween_property(settings_btn_ref, "rotation_degrees", 0, 0.4)
		tw.chain().tween_callback(func():
			settings_content.hide()
		)

func _build_settings_modal() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 20
	add_child(canvas_layer)
	
	settings_panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.24)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	settings_panel.add_theme_stylebox_override("panel", sb)
	settings_panel.clip_contents = true
	
	settings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	settings_panel.anchor_left = 1.0
	settings_panel.anchor_right = 1.0
	settings_panel.anchor_bottom = 0.0
	settings_panel.anchor_top = 0.0
	settings_panel.offset_top = 64
	settings_panel.offset_right = -64
	settings_panel.offset_left = -112
	settings_panel.offset_bottom = 112
	
	canvas_layer.add_child(settings_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	settings_panel.add_child(margin)
	
	var vbox_main = VBoxContainer.new()
	vbox_main.add_theme_constant_override("separation", 16)
	margin.add_child(vbox_main)
	
	var header = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	vbox_main.add_child(header)
	
	settings_label = Label.new()
	settings_label.text = tr("UI_SETTINGS")
	settings_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	settings_label.add_theme_font_size_override("font_size", 12)
	settings_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_label.hide()
	header.add_child(settings_label)
	
	settings_btn_ref = Button.new()
	settings_btn_ref.custom_minimum_size = Vector2(24, 24)
	settings_btn_ref.icon = load("res://assets/icons/settings.svg")
	settings_btn_ref.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn_sb = StyleBoxEmpty.new()
	settings_btn_ref.add_theme_stylebox_override("normal", btn_sb)
	settings_btn_ref.add_theme_stylebox_override("hover", btn_sb)
	settings_btn_ref.add_theme_stylebox_override("pressed", btn_sb)
	settings_btn_ref.add_theme_stylebox_override("focus", btn_sb)
	settings_btn_ref.pivot_offset = Vector2(12, 12)
	settings_btn_ref.pressed.connect(_on_settings_pressed)
	header.add_child(settings_btn_ref)
	
	settings_content = Control.new()
	settings_content.clip_contents = true
	settings_content.hide()
	vbox_main.add_child(settings_content)
	
	settings_vbox = VBoxContainer.new()
	settings_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_vbox.add_theme_constant_override("separation", 12)
	settings_content.add_child(settings_vbox)
	
	# Idioma
	lbl_lang = Label.new()
	lbl_lang.text = tr("UI_LANGUAGE")
	lbl_lang.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	lbl_lang.add_theme_font_size_override("font_size", 10)
	settings_vbox.add_child(lbl_lang)
	opt_lang = OptionButton.new()
	opt_lang.add_item("English", 0)
	opt_lang.add_item("Español", 1)
	opt_lang.add_item("Português", 2)
	if EventBus.current_language == "en": opt_lang.select(0)
	elif EventBus.current_language == "es": opt_lang.select(1)
	elif EventBus.current_language == "pt": opt_lang.select(2)
	opt_lang.item_selected.connect(func(idx):
		if idx == 0: EventBus.set_language("en")
		elif idx == 1: EventBus.set_language("es")
		elif idx == 2: EventBus.set_language("pt")
	)
	_style_dropdown(opt_lang)
	settings_vbox.add_child(opt_lang)
	
	# Borrador
	lbl_eraser = Label.new()
	lbl_eraser.text = tr("UI_ERASER_MODE")
	lbl_eraser.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	lbl_eraser.add_theme_font_size_override("font_size", 10)
	settings_vbox.add_child(lbl_eraser)
	opt_eraser = OptionButton.new()
	opt_eraser.add_item(tr("MODE_AREA"), 0)
	opt_eraser.add_item(tr("MODE_STROKE"), 1)
	if EventBus.current_eraser_mode == "stroke": opt_eraser.select(1)
	else: opt_eraser.select(0)
	opt_eraser.item_selected.connect(func(idx):
		if idx == 0: EventBus.set_eraser_mode("pixel")
		else: EventBus.set_eraser_mode("stroke")
	)
	_style_dropdown(opt_eraser)
	settings_vbox.add_child(opt_eraser)
	
	# Auto-guardado
	lbl_save = Label.new()
	lbl_save.text = tr("UI_AUTOSAVE")
	lbl_save.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	lbl_save.add_theme_font_size_override("font_size", 10)
	settings_vbox.add_child(lbl_save)
	opt_save = OptionButton.new()
	opt_save.add_item(tr("AUTOSAVE_OFF"), 0)
	opt_save.add_item(tr("AUTOSAVE_3M"), 1)
	opt_save.add_item(tr("AUTOSAVE_5M"), 2)
	opt_save.add_item(tr("AUTOSAVE_10M"), 3)
	opt_save.add_item(tr("AUTOSAVE_20M"), 4)
	if EventBus.current_autosave_interval == 0: opt_save.select(0)
	elif EventBus.current_autosave_interval == 3: opt_save.select(1)
	elif EventBus.current_autosave_interval == 5: opt_save.select(2)
	elif EventBus.current_autosave_interval == 10: opt_save.select(3)
	elif EventBus.current_autosave_interval == 20: opt_save.select(4)
	opt_save.item_selected.connect(func(idx):
		if idx == 0: EventBus.set_autosave_interval(0)
		elif idx == 1: EventBus.set_autosave_interval(3)
		elif idx == 2: EventBus.set_autosave_interval(5)
		elif idx == 3: EventBus.set_autosave_interval(10)
		elif idx == 4: EventBus.set_autosave_interval(20)
	)
	_style_dropdown(opt_save)
	settings_vbox.add_child(opt_save)

func _style_dropdown(opt: OptionButton) -> void:
	opt.custom_minimum_size.y = 48
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color("#111114")
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	opt.add_theme_stylebox_override("normal", sb)
	opt.add_theme_stylebox_override("hover", sb)
	opt.add_theme_stylebox_override("pressed", sb)
	opt.add_theme_stylebox_override("focus", sb)

func _update_language() -> void:
	if lbl_title: lbl_title.text = tr("UI_MY_PROJECTS")
	
	if modal_title: modal_title.text = tr("UI_NEW_PROJECT")
	if lbl_name: lbl_name.text = tr("UI_PROJECT_NAME")
	if name_input: name_input.placeholder_text = tr("UI_MY_PLAN")
	if lbl_size: lbl_size.text = tr("UI_PAPER_SIZE")
	if lbl_unit: lbl_unit.text = tr("UI_MEASUREMENT_UNIT")
	if lbl_scale: lbl_scale.text = tr("UI_CANVAS_CAPACITY")
	if preview_title: preview_title.text = tr("UI_CAPACITY_PREVIEW")
	if btn_cancel: btn_cancel.text = tr("UI_CANCEL")
	if btn_create: btn_create.text = tr("UI_CREATE")
	_update_preview()
	
	if settings_label: settings_label.text = tr("UI_SETTINGS")
	if lbl_lang: lbl_lang.text = tr("UI_LANGUAGE")
	if lbl_eraser: lbl_eraser.text = tr("UI_ERASER_MODE")
	if opt_eraser:
		opt_eraser.set_item_text(0, tr("MODE_AREA"))
		opt_eraser.set_item_text(1, tr("MODE_STROKE"))
	if lbl_save: lbl_save.text = tr("UI_AUTOSAVE")
	if opt_save:
		opt_save.set_item_text(0, tr("AUTOSAVE_OFF"))
		opt_save.set_item_text(1, tr("AUTOSAVE_3M"))
		opt_save.set_item_text(2, tr("AUTOSAVE_5M"))
		opt_save.set_item_text(3, tr("AUTOSAVE_10M"))
		opt_save.set_item_text(4, tr("AUTOSAVE_20M"))
	
	if size_option:
		for i in sizes.size(): size_option.set_item_text(i, tr(sizes[i]["name"]))
	if unit_option:
		for i in units.size(): unit_option.set_item_text(i, tr(units[i]["name"]))
	if scale_option:
		for i in scales.size(): scale_option.set_item_text(i, tr(scales[i]["name"]))
	
	_populate_projects()
