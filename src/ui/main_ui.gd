extends Control

@onready var pen_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid/PenButton
@onready var ruler_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid/RulerButton
@onready var rect_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid/RectangleButton
@onready var perfect_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid/PerfectButton
@onready var label_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid/LabelButton
@onready var eraser_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid/EraserButton

@onready var dim_panel: Control = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper
@onready var dim_vbox: VBoxContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel
@onready var dim_inputs_grid: GridContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/HBoxContainer
@onready var dim_buttons_grid: GridContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/ButtonsHBox
@onready var width_input: LineEdit = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/HBoxContainer/VBoxWidth/WidthInput
@onready var height_input: LineEdit = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/HBoxContainer/VBoxHeight/HeightInput
@onready var label_ancho: Label = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/HBoxContainer/VBoxWidth/Label
@onready var label_alto: Label = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/HBoxContainer/VBoxHeight/Label
@onready var confirm_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/ButtonsHBox/ConfirmButton
@onready var cancel_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/ButtonsHBox/CancelButton

@onready var collapse_btn: SquishyButton = $Sidebar/Margin/VBox/Header/CollapseBtn
@onready var sidebar: PanelContainer = $Sidebar
@onready var content_wrapper: Control = $Sidebar/Margin/VBox/ContentWrapper
@onready var vbox_tools: VBoxContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools
@onready var tools_grid: HFlowContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid
@onready var color_grid: HBoxContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ColorGrid
@onready var label_dibujo: Label = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/LabelDibujo
@onready var undo_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ProyGrid/UndoButton
@onready var redo_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ProyGrid/RedoButton
@onready var eye_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ProyGrid/EyeButton

@onready var settings_widget: PanelContainer = $SettingsWidget
@onready var settings_btn: SquishyButton = $SettingsWidget/Margin/VBox/Header/SettingsBtn
@onready var settings_content: Control = $SettingsWidget/Margin/VBox/Content
@onready var settings_label: Label = $SettingsWidget/Margin/VBox/Header/Label
@onready var lang_option: OptionButton = $SettingsWidget/Margin/VBox/Content/VBoxLang/LangOption
@onready var eraser_option: OptionButton = $SettingsWidget/Margin/VBox/Content/VBoxLang/EraserOption
@onready var unit_option: OptionButton = $SettingsWidget/Margin/VBox/Content/VBoxLang/UnitOption
@onready var vbox_lang: VBoxContainer = $SettingsWidget/Margin/VBox/Content/VBoxLang

var is_collapsed: bool = false
var base_content_height: float = 0.0
var paper_rect: Rect2
var zoom_factor: float = 1.0

var tool_toast_panel: PanelContainer
var tool_toast_label: Label
var tool_toast_tween: Tween
var is_settings_open: bool = false

func _ready() -> void:
	pen_btn.tapped.connect(_on_pen_pressed)
	ruler_btn.tapped.connect(_on_ruler_pressed)
	rect_btn.tapped.connect(_on_rect_pressed)
	perfect_btn.tapped.connect(_on_perfect_pressed)
	label_btn.tapped.connect(_on_label_pressed)
	eraser_btn.tapped.connect(_on_eraser_pressed)
	confirm_btn.tapped.connect(_on_dim_confirm)
	cancel_btn.tapped.connect(_on_dim_cancel)
	collapse_btn.tapped.connect(_on_collapse_pressed)
	collapse_btn.pivot_offset = Vector2(16, 16)
	settings_btn.tapped.connect(_on_settings_pressed)
	
	_wrap_button_for_rotation(collapse_btn)
	_wrap_button_for_rotation(settings_btn)
	
	eye_btn.tapped.connect(_on_eye_pressed)
	eye_btn.set_active(true)
	
	undo_btn.tapped.connect(func(): EventBus.undo_requested.emit())
	redo_btn.tapped.connect(func(): EventBus.redo_requested.emit())
	EventBus.history_changed.connect(_on_history_changed)
	_on_history_changed(false, false)
	
	sidebar.custom_minimum_size.x = 248
	sidebar.size.x = 248
	
	dim_vbox.grow_horizontal = Control.GROW_DIRECTION_END
	dim_vbox.grow_vertical = Control.GROW_DIRECTION_END
	dim_vbox.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dim_vbox.offset_left = 0
	dim_vbox.offset_top = 0
	dim_vbox.size.x = 196
	
	dim_panel.custom_minimum_size.y = 0
	dim_panel.hide()
	
	settings_content.custom_minimum_size.y = 0
	settings_content.hide()
	
	EventBus.tool_selected.connect(_on_global_tool_selected)
	EventBus.unit_changed.connect(_on_global_unit_changed)
	
	_setup_language_options()
	_setup_eraser_options()
	_setup_unit_options()
	_setup_autosave_options()
	_setup_color_options()
	_setup_auto_measure_btn()
	_setup_archivo_buttons()
	_setup_tool_toast()
	
	var layer_panel = load("res://src/ui/layer_panel.gd").new()
	layer_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	layer_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer_panel.offset_right = -20
	layer_panel.offset_bottom = -20
	add_child(layer_panel)
	
	vbox_tools.grow_horizontal = Control.GROW_DIRECTION_END
	vbox_tools.grow_vertical = Control.GROW_DIRECTION_END
	vbox_tools.set_anchors_preset(Control.PRESET_TOP_LEFT)
	vbox_tools.offset_left = 0
	vbox_tools.offset_top = 0
	
	tools_grid.custom_minimum_size = Vector2(196, 92)
	tools_grid.size = Vector2(196, 92)
	tools_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	
	# Calcular la altura base dinámicamente en el siguiente frame
	call_deferred("_initialize_heights")

var collapsed_content_h: float = 0.0

func _initialize_heights() -> void:
	base_content_height = vbox_tools.size.y
	content_wrapper.custom_minimum_size.y = base_content_height
	
	collapsed_content_h = tools_grid.size.y + 16
	
	_on_global_tool_selected("pen")

func _setup_archivo_buttons() -> void:
	var archivo_lbl = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/LabelArchivo
	var archivo_old_grid = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ArchivoGrid
	
	if archivo_old_grid:
		archivo_old_grid.hide()
		archivo_old_grid.queue_free()
		var archivo_wrapper = MarginContainer.new()
		var v_idx = archivo_lbl.get_index()
		$Sidebar/Margin/VBox/ContentWrapper/VBoxTools.add_child(archivo_wrapper)
		$Sidebar/Margin/VBox/ContentWrapper/VBoxTools.move_child(archivo_wrapper, v_idx + 1)
		
		# Capa 1: Cuadrícula original
		var archivo_vbox = VBoxContainer.new()
		archivo_vbox.add_theme_constant_override("separation", 8)
		archivo_wrapper.add_child(archivo_vbox)
		
		# Capa 2: Panel de confirmación (oculto por defecto)
		var confirm_panel = PanelContainer.new()
		confirm_panel.hide()
		
		var sb_confirm = StyleBoxFlat.new()
		sb_confirm.bg_color = Color(0.18, 0.20, 0.24)
		sb_confirm.corner_radius_top_left = 12
		sb_confirm.corner_radius_top_right = 12
		sb_confirm.corner_radius_bottom_left = 12
		sb_confirm.corner_radius_bottom_right = 12
		confirm_panel.add_theme_stylebox_override("panel", sb_confirm)
		archivo_wrapper.add_child(confirm_panel)
		
		var confirm_vbox = VBoxContainer.new()
		confirm_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		confirm_vbox.add_theme_constant_override("separation", 12)
		confirm_panel.add_child(confirm_vbox)
		
		var lbl_q = Label.new()
		lbl_q.text = "UI_CONFIRM_HOME"
		lbl_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_q.add_theme_font_size_override("font_size", 12)
		confirm_vbox.add_child(lbl_q)
		
		var hbox_btns = HBoxContainer.new()
		hbox_btns.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox_btns.add_theme_constant_override("separation", 12)
		confirm_vbox.add_child(hbox_btns)
		
		var btn_cancel = Button.new()
		btn_cancel.text = "UI_CANCEL"
		var sb_c = StyleBoxFlat.new()
		sb_c.bg_color = Color("#3f3f46")
		sb_c.corner_radius_top_left = 8
		sb_c.corner_radius_top_right = 8
		sb_c.corner_radius_bottom_left = 8
		sb_c.corner_radius_bottom_right = 8
		sb_c.content_margin_left = 12
		sb_c.content_margin_right = 12
		sb_c.content_margin_top = 4
		sb_c.content_margin_bottom = 4
		btn_cancel.add_theme_stylebox_override("normal", sb_c)
		btn_cancel.add_theme_stylebox_override("hover", sb_c.duplicate())
		hbox_btns.add_child(btn_cancel)
		
		var btn_accept = Button.new()
		btn_accept.text = "UI_ACCEPT"
		var sb_a = StyleBoxFlat.new()
		sb_a.bg_color = Color("#10b981") # Verde
		sb_a.corner_radius_top_left = 8
		sb_a.corner_radius_top_right = 8
		sb_a.corner_radius_bottom_left = 8
		sb_a.corner_radius_bottom_right = 8
		sb_a.content_margin_left = 12
		sb_a.content_margin_right = 12
		sb_a.content_margin_top = 4
		sb_a.content_margin_bottom = 4
		btn_accept.add_theme_stylebox_override("normal", sb_a)
		btn_accept.add_theme_stylebox_override("hover", sb_a.duplicate())
		hbox_btns.add_child(btn_accept)
		
		var row1 = HBoxContainer.new()
		row1.add_theme_constant_override("separation", 12)
		archivo_vbox.add_child(row1)
		
		var row2 = HBoxContainer.new()
		row2.add_theme_constant_override("separation", 12)
		archivo_vbox.add_child(row2)
		
		var btn_save = _create_action_button("res://assets/icons/save.svg")
		btn_save.pressed.connect(func():
			EventBus.manual_save_requested.emit()
			_animate_save_button(btn_save)
		)
		row1.add_child(btn_save)
		
		var btn_home = _create_action_button("res://assets/icons/home.svg")
		btn_home.pressed.connect(func():
			_animate_home_confirm(btn_home, archivo_vbox, confirm_panel, btn_cancel, btn_accept)
		)
		row1.add_child(btn_home)
		
		var btn_page_plus = _create_action_button("res://assets/icons/file-plus.svg")
		row1.add_child(btn_page_plus)
		
		var btn_page_minus = _create_action_button("res://assets/icons/file-minus.svg")
		row1.add_child(btn_page_minus)
		
		var btn_img = _create_action_button("res://assets/icons/image.svg")
		row2.add_child(btn_img)
		
		var btn_pdf = _create_action_button("res://assets/icons/file-text.svg")
		row2.add_child(btn_pdf)
		
		var btn_print = _create_action_button("res://assets/icons/printer.svg")
		btn_print.pressed.connect(func():
			var canvas = get_tree().current_scene.get_node("Workspace/CanvasManager")
			if canvas:
				canvas.export_for_print()
		)
		row2.add_child(btn_print)

func _create_action_button(icon_path: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(40, 40)
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
	
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.25, 0.28, 0.35)
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	
	return btn

func _animate_save_button(btn: Button) -> void:
	if btn.get_meta("is_animating", false): return
	btn.set_meta("is_animating", true)
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var original_icon = load("res://assets/icons/save.svg")
	var check_icon = load("res://assets/icons/check.svg")
	var original_style = btn.get_theme_stylebox("normal").duplicate()
	
	var success_style = original_style.duplicate()
	success_style.bg_color = Color("#34c759") # Verde vibrante
	
	btn.add_theme_stylebox_override("normal", success_style)
	btn.add_theme_stylebox_override("hover", success_style)
	btn.icon = check_icon
	
	var tw = create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	btn.pivot_offset = btn.size / 2.0
	tw.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		var fade_tw = create_tween()
		btn.icon = original_icon
		btn.add_theme_stylebox_override("normal", original_style)
		var sb_hover = original_style.duplicate()
		sb_hover.bg_color = Color(0.25, 0.28, 0.35)
		btn.add_theme_stylebox_override("hover", sb_hover)
		
		btn.set_meta("is_animating", false)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
	)

func _animate_home_confirm(btn_home: Button, archivo_vbox: Control, confirm_panel: Control, btn_cancel: Button, btn_accept: Button) -> void:
	if btn_home.get_meta("is_animating", false): return
	btn_home.set_meta("is_animating", true)
	
	var tw_fade = create_tween()
	tw_fade.tween_property(archivo_vbox, "modulate:a", 0.0, 0.15)
	tw_fade.tween_callback(func(): archivo_vbox.hide())
	
	var clone = Panel.new()
	var sb = btn_home.get_theme_stylebox("normal").duplicate()
	clone.add_theme_stylebox_override("panel", sb)
	
	clone.top_level = true
	clone.global_position = btn_home.global_position
	clone.size = btn_home.size
	archivo_vbox.get_parent().add_child(clone)
	
	archivo_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_panel.custom_minimum_size = archivo_vbox.size
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tw.tween_property(clone, "global_position", archivo_vbox.global_position, 0.4)
	tw.tween_property(clone, "size", archivo_vbox.size, 0.4)
	
	tw.chain().tween_callback(func():
		confirm_panel.show()
		clone.queue_free()
	)
	
	for c in btn_cancel.pressed.get_connections():
		btn_cancel.pressed.disconnect(c.callable)
	for c in btn_accept.pressed.get_connections():
		btn_accept.pressed.disconnect(c.callable)
		
	btn_cancel.pressed.connect(func():
		_cancel_home_confirm(btn_home, archivo_vbox, confirm_panel)
	)
	
	btn_accept.pressed.connect(func():
		EventBus.manual_save_requested.emit()
		get_tree().change_scene_to_file("res://src/ui/project_selector.tscn")
	)

func _cancel_home_confirm(btn_home: Button, archivo_vbox: Control, confirm_panel: Control) -> void:
	confirm_panel.hide()
	
	var clone = Panel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.24)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	clone.add_theme_stylebox_override("panel", sb)
	
	clone.top_level = true
	clone.global_position = archivo_vbox.global_position
	clone.size = archivo_vbox.size
	archivo_vbox.get_parent().add_child(clone)
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	
	tw.tween_property(clone, "global_position", btn_home.global_position, 0.4)
	tw.tween_property(clone, "size", btn_home.size, 0.4)
	
	tw.chain().tween_callback(func():
		clone.queue_free()
		archivo_vbox.show()
		var tw2 = create_tween()
		tw2.tween_property(archivo_vbox, "modulate:a", 1.0, 0.15)
		btn_home.set_meta("is_animating", false)
	)

func _wrap_button_for_rotation(btn: Button) -> void:
	var parent = btn.get_parent()
	var wrapper = Control.new()
	wrapper.custom_minimum_size = btn.custom_minimum_size
	var idx = btn.get_index()
	parent.remove_child(btn)
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	wrapper.add_child(btn)
	btn.position = Vector2.ZERO

func _on_global_tool_selected(tool_id: String) -> void:
	pen_btn.set_active(tool_id == "pen")
	ruler_btn.set_active(tool_id == "ruler")
	rect_btn.set_active(tool_id == "rectangle")
	perfect_btn.set_active(tool_id == "perfect")
	label_btn.set_active(tool_id == "label")
	eraser_btn.set_active(tool_id == "eraser")
	
	var tool_names = {
		"pen": "UI_TOOL_PEN",
		"ruler": "UI_TOOL_RULER",
		"rectangle": "UI_TOOL_RECTANGLE",
		"perfect": "UI_TOOL_PERFECT",
		"label": "UI_TOOL_LABEL",
		"eraser": "UI_TOOL_ERASER"
	}
	var t_key = tool_names.get(tool_id, "")
	if t_key != "":
		show_tool_toast(tr(t_key))
	
	if tool_id != "perfect":
		_animate_dim_panel(false)

func _on_pen_pressed() -> void:
	EventBus.tool_selected.emit("pen")

func _on_ruler_pressed() -> void:
	EventBus.tool_selected.emit("ruler")

func _on_rect_pressed() -> void:
	EventBus.tool_selected.emit("rectangle")

func _on_perfect_pressed() -> void:
	EventBus.tool_selected.emit("perfect")
	_animate_dim_panel(true)

func _on_label_pressed() -> void:
	EventBus.tool_selected.emit("label")

func _on_eraser_pressed() -> void:
	EventBus.tool_selected.emit("eraser")

func _setup_tool_toast() -> void:
	tool_toast_panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.95, 0.95, 0.95, 0.9)
	sb.corner_radius_top_left = 20
	sb.corner_radius_top_right = 20
	sb.corner_radius_bottom_left = 20
	sb.corner_radius_bottom_right = 20
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	tool_toast_panel.add_theme_stylebox_override("panel", sb)
	
	tool_toast_label = Label.new()
	tool_toast_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	tool_toast_label.add_theme_font_size_override("font_size", 16)
	tool_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	tool_toast_panel.add_child(tool_toast_label)
	
	tool_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	tool_toast_panel.position.y -= 100 # Un poco arriba del centro
	
	tool_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	tool_toast_panel.modulate.a = 0
	add_child(tool_toast_panel)

func show_tool_toast(text: String) -> void:
	if not tool_toast_panel: return
	tool_toast_label.text = text
	
	move_child(tool_toast_panel, get_child_count() - 1)
	
	if tool_toast_tween:
		tool_toast_tween.kill()
		
	tool_toast_tween = create_tween()
	tool_toast_tween.tween_property(tool_toast_panel, "modulate:a", 1.0, 0.15)
	tool_toast_tween.tween_interval(1.0)
	tool_toast_tween.tween_property(tool_toast_panel, "modulate:a", 0.0, 0.3)

func _animate_dim_panel(show: bool) -> void:
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	
	var dim_h = 0
	if show:
		if is_collapsed:
			dim_inputs_grid.columns = 1
			dim_buttons_grid.columns = 1
			dim_h = 230
		else:
			dim_inputs_grid.columns = 2
			dim_buttons_grid.columns = 2
			dim_h = 120
	
	var base_h = collapsed_content_h if is_collapsed else base_content_height
	var side_base_h = 96 + base_h
	
	if show:
		dim_panel.show()
		tw.tween_property(dim_panel, "custom_minimum_size:y", dim_h, 0.3)
		tw.tween_property(content_wrapper, "custom_minimum_size:y", base_h + dim_h + 16, 0.3)
		tw.tween_property(sidebar, "size:y", side_base_h + dim_h + 16, 0.3)
	else:
		tw.tween_property(dim_panel, "custom_minimum_size:y", 0, 0.3)
		tw.tween_property(content_wrapper, "custom_minimum_size:y", base_h, 0.3)
		tw.tween_property(sidebar, "size:y", side_base_h, 0.3)
		tw.chain().tween_callback(func(): dim_panel.hide())

func _on_dim_confirm() -> void:
	var w = EventBus.parse_input_to_px(float(width_input.text))
	var h = EventBus.parse_input_to_px(float(height_input.text))
	EventBus.perfect_dimensions_confirmed.emit(w, h)

func _on_dim_cancel() -> void:
	_animate_dim_panel(false)
	EventBus.perfect_dimensions_cancelled.emit()
	EventBus.tool_selected.emit("pen")

func _on_eye_pressed() -> void:
	EventBus.toggle_measures_visibility()
	eye_btn.set_active(EventBus.show_measures)

func _on_history_changed(can_undo: bool, can_redo: bool) -> void:
	undo_btn.disabled = !can_undo
	if can_undo:
		undo_btn.modulate = Color.WHITE
		undo_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		undo_btn.modulate = Color(1, 1, 1, 0.25)
		undo_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	redo_btn.disabled = !can_redo
	if can_redo:
		redo_btn.modulate = Color.WHITE
		redo_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		redo_btn.modulate = Color(1, 1, 1, 0.25)
		redo_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_collapse_pressed() -> void:
	is_collapsed = !is_collapsed
	
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	
	if is_collapsed:
		auto_measure_btn.hide()
		tools_grid.custom_minimum_size.x = 144
		tools_grid.size.x = 144
		dim_inputs_grid.columns = 1
		dim_buttons_grid.columns = 1
		
		var target_h = collapsed_content_h
		var dim_h = 0
		if dim_panel.visible:
			dim_h = 230
			target_h += dim_h + 16
			
		tw.tween_property(dim_vbox, "size:x", 152, 0.4)
		tw.tween_property(dim_panel, "custom_minimum_size:y", dim_h, 0.4)
		tw.tween_property(content_wrapper, "custom_minimum_size:y", target_h, 0.4)
		tw.tween_property(sidebar, "custom_minimum_size:x", 200, 0.4)
		tw.tween_property(sidebar, "size", Vector2(200, 96 + target_h), 0.4)
		tw.tween_property(collapse_btn, "rotation_degrees", 180, 0.4)
	else:
		auto_measure_btn.show()
		tools_grid.custom_minimum_size.x = 196
		tools_grid.size.x = 196
		dim_inputs_grid.columns = 2
		dim_buttons_grid.columns = 2
		
		var target_h = base_content_height
		var dim_h = 0
		if dim_panel.visible:
			dim_h = 120
			target_h += dim_h + 16
		
		tw.tween_property(dim_vbox, "size:x", 196, 0.4)
		tw.tween_property(dim_panel, "custom_minimum_size:y", dim_h, 0.4)
		tw.tween_property(content_wrapper, "custom_minimum_size:y", target_h, 0.4)
		tw.tween_property(sidebar, "custom_minimum_size:x", 248, 0.4)
		tw.tween_property(sidebar, "size", Vector2(248, 96 + target_h), 0.4)
		tw.tween_property(collapse_btn, "rotation_degrees", 0, 0.4)

func _setup_language_options() -> void:
	lang_option.add_item("English", 0)
	lang_option.add_item("Español", 1)
	lang_option.add_item("Português", 2)
	
	if EventBus.current_language == "es":
		lang_option.select(1)
	elif EventBus.current_language == "pt":
		lang_option.select(2)
	else:
		lang_option.select(0)
		
	lang_option.item_selected.connect(_on_language_selected)

func _on_language_selected(index: int) -> void:
	if index == 0:
		EventBus.set_language("en")
	elif index == 1:
		EventBus.set_language("es")
	elif index == 2:
		EventBus.set_language("pt")

func _setup_eraser_options() -> void:
	eraser_option.add_item("MODE_AREA", 0)
	eraser_option.add_item("MODE_STROKE", 1)
	
	if EventBus.current_eraser_mode == "stroke":
		eraser_option.select(1)
	else:
		eraser_option.select(0)
		
	eraser_option.item_selected.connect(_on_eraser_mode_selected)

func _on_eraser_mode_selected(index: int) -> void:
	if index == 0:
		EventBus.set_eraser_mode("area")
	elif index == 1:
		EventBus.set_eraser_mode("stroke")

func _setup_unit_options() -> void:
	unit_option.add_item("UNIT_MM", 0)
	unit_option.add_item("UNIT_CM", 1)
	unit_option.add_item("UNIT_M", 2)
	unit_option.add_item("UNIT_IN", 3)
	
	var conf_unit = EventBus.current_project_config.get("unit", "cm")
	EventBus.current_unit = conf_unit
	
	if EventBus.current_unit == "cm":
		unit_option.select(1)
	elif EventBus.current_unit == "m":
		unit_option.select(2)
	elif EventBus.current_unit == "in":
		unit_option.select(3)
	else:
		unit_option.select(0)
		
	unit_option.item_selected.connect(_on_unit_selected)
	_on_global_unit_changed(EventBus.current_unit)

func _on_global_unit_changed(unit: String) -> void:
	label_ancho.text = "ANCHO (%s)" % unit
	label_alto.text = "ALTO (%s)" % unit

var auto_measure_btn: Button

func _setup_auto_measure_btn() -> void:
	auto_measure_btn = Button.new()
	auto_measure_btn.custom_minimum_size = Vector2(92, 40)
	auto_measure_btn.text = "UI_MEASUREMENTS"
	auto_measure_btn.add_theme_font_size_override("font_size", 12)
	
	_update_auto_measure_btn_style()
	
	auto_measure_btn.pressed.connect(func():
		EventBus.auto_measure = !EventBus.auto_measure
		_update_auto_measure_btn_style()
	)
	
	tools_grid.add_child(auto_measure_btn)

func _update_auto_measure_btn_style() -> void:
	var sb = StyleBoxFlat.new()
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	
	if EventBus.auto_measure:
		sb.bg_color = Color(0.25, 0.28, 0.35)
		auto_measure_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		sb.bg_color = Color(0.15, 0.17, 0.22)
		auto_measure_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		
	auto_measure_btn.add_theme_stylebox_override("normal", sb)
	auto_measure_btn.add_theme_stylebox_override("hover", sb)
	auto_measure_btn.add_theme_stylebox_override("pressed", sb)
	auto_measure_btn.add_theme_stylebox_override("focus", sb)

func _on_unit_selected(index: int) -> void:
	if index == 0:
		EventBus.set_unit("mm")
	elif index == 1:
		EventBus.set_unit("cm")
	elif index == 2:
		EventBus.set_unit("m")
	elif index == 3:
		EventBus.set_unit("in")

var autosave_option: OptionButton

func _setup_autosave_options() -> void:
	var lbl = Label.new()
	lbl.text = "UI_AUTOSAVE"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox_lang.add_child(lbl)
	
	autosave_option = OptionButton.new()
	autosave_option.add_item("AUTOSAVE_OFF", 0)
	autosave_option.add_item("AUTOSAVE_3M", 3)
	autosave_option.add_item("AUTOSAVE_5M", 5)
	autosave_option.add_item("AUTOSAVE_10M", 10)
	autosave_option.add_item("AUTOSAVE_20M", 20)
	
	var intervals = [0, 3, 5, 10, 20]
	var current_idx = intervals.find(EventBus.current_autosave_interval)
	if current_idx >= 0:
		autosave_option.select(current_idx)
	else:
		autosave_option.select(1)
		
	autosave_option.item_selected.connect(_on_autosave_selected)
	vbox_lang.add_child(autosave_option)

func _on_autosave_selected(index: int) -> void:
	var intervals = [0, 3, 5, 10, 20]
	if index >= 0 and index < intervals.size():
		EventBus.set_autosave_interval(intervals[index])

var color_buttons: Array[Button] = []
var active_color_btn: Button = null
var hidden_color_popup: PopupPanel
var color_picker: ColorPicker

func _setup_color_options() -> void:
	var colors = [
		Color.BLACK,
		Color("#FF4B4B"),
		Color("#20C96F"),
		Color("#3B82F6")
	]
	
	for c in colors:
		var btn = _create_color_button(c)
		color_buttons.append(btn)
		color_grid.add_child(btn)
		btn.pressed.connect(func(): _on_color_selected(btn, c))
		
	var custom_btn = Button.new()
	custom_btn.custom_minimum_size = Vector2(30, 30)
	custom_btn.icon = load("res://assets/icons/palette.svg")
	custom_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_btn.expand_icon = true
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.20, 0.24)
	sb.corner_radius_top_left = 15
	sb.corner_radius_top_right = 15
	sb.corner_radius_bottom_left = 15
	sb.corner_radius_bottom_right = 15
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0)
	
	custom_btn.add_theme_stylebox_override("normal", sb)
	custom_btn.add_theme_stylebox_override("hover", sb)
	custom_btn.add_theme_stylebox_override("pressed", sb)
	custom_btn.add_theme_stylebox_override("focus", sb)
	
	color_buttons.append(custom_btn)
	color_grid.add_child(custom_btn)
	
	hidden_color_popup = PopupPanel.new()
	var popup_style = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.13, 0.16)
	popup_style.corner_radius_top_left = 12
	popup_style.corner_radius_top_right = 12
	popup_style.corner_radius_bottom_left = 12
	popup_style.corner_radius_bottom_right = 12
	hidden_color_popup.add_theme_stylebox_override("panel", popup_style)
	
	color_picker = ColorPicker.new()
	hidden_color_popup.add_child(color_picker)
	add_child(hidden_color_popup)
	
	custom_btn.pressed.connect(func():
		hidden_color_popup.popup_centered()
	)
	
	color_picker.color_changed.connect(func(c):
		sb.bg_color = c
		custom_btn.icon = null
		_on_color_selected(custom_btn, c)
	)
	
	_on_color_selected(color_buttons[0], colors[0])

func _create_color_button(c: Color) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(30, 30)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = c
	sb.corner_radius_top_left = 15
	sb.corner_radius_top_right = 15
	sb.corner_radius_bottom_left = 15
	sb.corner_radius_bottom_right = 15
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0, 0, 0, 0)
	
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	return btn

func _on_color_selected(btn: Button, c: Color) -> void:
	if active_color_btn:
		var old_sb = active_color_btn.get_theme_stylebox("normal")
		old_sb.border_color = Color(0, 0, 0, 0)
		old_sb.shadow_color = Color(0, 0, 0, 0)
		old_sb.shadow_size = 0
		
	active_color_btn = btn
	var new_sb = active_color_btn.get_theme_stylebox("normal")
	new_sb.border_color = Color(1.0, 1.0, 1.0, 0.9)
	new_sb.shadow_color = Color(1.0, 1.0, 1.0, 0.4)
	new_sb.shadow_size = 4
	
	EventBus.set_color(c)

func _on_settings_pressed() -> void:
	is_settings_open = !is_settings_open
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	
	if is_settings_open:
		settings_label.show()
		settings_content.show()
		tw.tween_property(settings_content, "custom_minimum_size:y", vbox_lang.size.y, 0.4)
		tw.tween_property(settings_widget, "custom_minimum_size:x", 200, 0.4)
		tw.tween_property(settings_btn, "rotation_degrees", 90, 0.4)
	else:
		tw.tween_property(settings_content, "custom_minimum_size:y", 0, 0.4)
		tw.tween_property(settings_widget, "custom_minimum_size:x", 0, 0.4)
		tw.tween_property(settings_btn, "rotation_degrees", 0, 0.4)
		tw.chain().tween_callback(func(): 
			settings_content.hide()
			settings_label.hide()
		)
