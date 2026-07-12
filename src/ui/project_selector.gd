extends Control

var sizes = [
	{"name": "Carta (Letter)", "size": Vector2(816, 1056)},
	{"name": "Oficio (Legal)", "size": Vector2(816, 1344)},
	{"name": "A4", "size": Vector2(794, 1123)},
	{"name": "A3", "size": Vector2(1123, 1587)}
]

var units = [
	{"name": "Milímetros (mm)", "val": "mm"},
	{"name": "Centímetros (cm)", "val": "cm"},
	{"name": "Metros (m)", "val": "m"},
	{"name": "Pulgadas (in)", "val": "in"}
]

var scales = [
	{"name": "Muy Pequeño", "val": 0.5},
	{"name": "Pequeño", "val": 1.0},
	{"name": "Mediano", "val": 4.0},
	{"name": "Grande", "val": 10.0},
	{"name": "Gigante", "val": 100.0}
]

var name_input: LineEdit
var size_option: OptionButton
var unit_option: OptionButton
var scale_option: OptionButton
var modal_overlay: ColorRect

var paper_preview: ColorRect
var preview_label: Label

func _ready() -> void:
	# Fondo general
	var bg = ColorRect.new()
	bg.color = Color("#18191f")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Contenedor para centrar el botón de nuevo proyecto
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	# Botón de nuevo proyecto (Hoja con +)
	var btn_new = Button.new()
	btn_new.custom_minimum_size = Vector2(160, 220)
	var plus_icon = load("res://assets/icons/plus.svg")
	if plus_icon:
		btn_new.icon = plus_icon
		btn_new.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn_new.expand_icon = true
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#2a2b33")
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_top_right = 8
	style_normal.corner_radius_bottom_left = 8
	style_normal.corner_radius_bottom_right = 8
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color("#32343d")
	
	btn_new.add_theme_stylebox_override("normal", style_normal)
	btn_new.add_theme_stylebox_override("hover", style_hover)
	btn_new.add_theme_stylebox_override("pressed", style_normal)
	btn_new.add_theme_stylebox_override("focus", style_normal)
	
	btn_new.pressed.connect(_on_new_project_pressed)
	center.add_child(btn_new)
	
	_build_modal()

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
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_main.add_child(vbox)
	
	var title = Label.new()
	title.text = "Nuevo Proyecto"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Nombre
	var lbl_name = Label.new()
	lbl_name.text = "Nombre del proyecto"
	vbox.add_child(lbl_name)
	
	name_input = LineEdit.new()
	name_input.placeholder_text = "Mi Plano"
	name_input.custom_minimum_size.x = 300
	vbox.add_child(name_input)
	
	# Tamaño
	var lbl_size = Label.new()
	lbl_size.text = "Tamaño de Hoja"
	vbox.add_child(lbl_size)
	
	size_option = OptionButton.new()
	for s in sizes:
		size_option.add_item(s["name"])
	size_option.item_selected.connect(func(idx): _update_preview())
	vbox.add_child(size_option)
	
	# Unidad
	var lbl_unit = Label.new()
	lbl_unit.text = "Unidad de Medida"
	vbox.add_child(lbl_unit)
	
	unit_option = OptionButton.new()
	for u in units:
		unit_option.add_item(u["name"])
	unit_option.select(1) # cm default
	unit_option.item_selected.connect(func(idx): _update_preview())
	vbox.add_child(unit_option)
	
	# Escala (Capacidad)
	var lbl_scale = Label.new()
	lbl_scale.text = "Capacidad del Lienzo (Espacio)"
	vbox.add_child(lbl_scale)
	
	scale_option = OptionButton.new()
	for s in scales:
		scale_option.add_item(s["name"])
	scale_option.select(2) # Mediano default
	scale_option.item_selected.connect(func(idx): _update_preview())
	vbox.add_child(scale_option)
	
	# Botones
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancelar"
	btn_cancel.custom_minimum_size = Vector2(120, 40)
	btn_cancel.pressed.connect(_on_cancel_pressed)
	hbox.add_child(btn_cancel)
	
	var btn_create = Button.new()
	btn_create.text = "Crear"
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
	preview_title.text = "Vista Previa de Capacidad"
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
	if aspect > 1.0:
		paper_preview.custom_minimum_size = Vector2(max_preview_size, max_preview_size / aspect)
	else:
		paper_preview.custom_minimum_size = Vector2(max_preview_size * aspect, max_preview_size)
		
	# Calcular capacidad real
	var width_units = (paper_dim.x * scale_val) / 100.0
	var height_units = (paper_dim.y * scale_val) / 100.0
	
	preview_label.text = "Ancho máximo: %.2f %s\nAlto máximo: %.2f %s" % [width_units, unit_val, height_units, unit_val]

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
		pname = "Nuevo Proyecto"
		
	var s_idx = size_option.get_selected_id()
	var u_idx = unit_option.get_selected_id()
	var scale_idx = scale_option.get_selected_id()
	
	EventBus.current_project_config = {
		"name": pname,
		"paper_size": sizes[s_idx]["size"],
		"unit": units[u_idx]["val"],
		"canvas_scale": scales[scale_idx]["val"]
	}
	
	get_tree().change_scene_to_file("res://src/main.tscn")
