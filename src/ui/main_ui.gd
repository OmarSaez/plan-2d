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
@onready var confirm_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/ButtonsHBox/ConfirmButton
@onready var cancel_btn: SquishyButton = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/DimWrapper/DimensionsPanel/ButtonsHBox/CancelButton

@onready var collapse_btn: SquishyButton = $Sidebar/Margin/VBox/Header/CollapseBtn
@onready var sidebar: PanelContainer = $Sidebar
@onready var content_wrapper: Control = $Sidebar/Margin/VBox/ContentWrapper
@onready var vbox_tools: VBoxContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools
@onready var tools_grid: GridContainer = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/ToolsGrid
@onready var label_dibujo: Label = $Sidebar/Margin/VBox/ContentWrapper/VBoxTools/LabelDibujo

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
	
	_setup_language_options()
	_setup_eraser_options()
	_setup_unit_options()
	
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
	
	tools_grid.columns = 4
	
	# Calcular la altura base dinámicamente en el siguiente frame
	call_deferred("_initialize_heights")

var collapsed_content_h: float = 0.0

func _initialize_heights() -> void:
	base_content_height = vbox_tools.size.y
	content_wrapper.custom_minimum_size.y = base_content_height
	
	collapsed_content_h = label_dibujo.size.y + 16 + tools_grid.size.y
	
	_on_global_tool_selected("pen") # Activar visualmente lápiz

func _on_global_tool_selected(tool_id: String) -> void:
	pen_btn.set_active(tool_id == "pen")
	ruler_btn.set_active(tool_id == "ruler")
	rect_btn.set_active(tool_id == "rectangle")
	perfect_btn.set_active(tool_id == "perfect")
	label_btn.set_active(tool_id == "label")
	eraser_btn.set_active(tool_id == "eraser")
	
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
	var w = float(width_input.text)
	var h = float(height_input.text)
	EventBus.perfect_dimensions_confirmed.emit(w, h)

func _on_dim_cancel() -> void:
	_animate_dim_panel(false)
	EventBus.perfect_dimensions_cancelled.emit()
	EventBus.tool_selected.emit("pen")

func _on_collapse_pressed() -> void:
	is_collapsed = !is_collapsed
	
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	
	if is_collapsed:
		tools_grid.columns = 3
		dim_inputs_grid.columns = 1
		dim_buttons_grid.columns = 1
		
		# Plegar: Reducir altura hasta las herramientas de dibujo
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
		tools_grid.columns = 4
		dim_inputs_grid.columns = 2
		dim_buttons_grid.columns = 2
		
		# Desplegar: Restaurar altura, ancho y rotar la flecha
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
	
	if EventBus.current_unit == "cm":
		unit_option.select(1)
	elif EventBus.current_unit == "m":
		unit_option.select(2)
	elif EventBus.current_unit == "in":
		unit_option.select(3)
	else:
		unit_option.select(0)
		
	unit_option.item_selected.connect(_on_unit_selected)

func _on_unit_selected(index: int) -> void:
	if index == 0:
		EventBus.set_unit("mm")
	elif index == 1:
		EventBus.set_unit("cm")
	elif index == 2:
		EventBus.set_unit("m")
	elif index == 3:
		EventBus.set_unit("in")

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
