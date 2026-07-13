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

func _ready() -> void:
	# Fondo general
	var bg = ColorRect.new()
	bg.color = Color("#18191f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	_build_dashboard()
	_build_modal()

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
	
	var title = Label.new()
	title.text = "Mis Proyectos"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
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
	for c in grid_container.get_children():
		c.queue_free()
		
	# 1. Nueva Hoja (+)
	var btn_new = _create_card_button("+", tr("UI_NEW_PROJECT"), "")
	btn_new.pressed.connect(_on_new_project_pressed)
	grid_container.add_child(btn_new)
	
	# 2. Proyectos guardados
	var projects = EventBus.get_all_projects()
	for p in projects:
		var cfg = p.get("config", {})
		var p_name = cfg.get("name", "Proyecto")
		var ts = cfg.get("timestamp", 0)
		
		var dict = Time.get_datetime_dict_from_unix_time(ts)
		var date_str = "%04d-%02d-%02d %02d:%02d" % [dict["year"], dict["month"], dict["day"], dict["hour"], dict["minute"]]
		
		var btn_proj = _create_card_button("", p_name, date_str, p)
		btn_proj.pressed.connect(func(): _load_and_start_project(p))
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
	
	var title = Label.new()
	title.text = tr("UI_NEW_PROJECT")
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Nombre
	var group_name = VBoxContainer.new()
	group_name.add_theme_constant_override("separation", 6)
	vbox.add_child(group_name)
	
	var lbl_name = Label.new()
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
	
	var lbl_size = Label.new()
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
	
	var lbl_unit = Label.new()
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
	
	var lbl_scale = Label.new()
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
	
	var btn_cancel = Button.new()
	btn_cancel.text = tr("UI_CANCEL")
	btn_cancel.custom_minimum_size = Vector2(120, 40)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	hbox.add_child(btn_cancel)
	
	var btn_create = Button.new()
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
	
	var preview_title = Label.new()
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
