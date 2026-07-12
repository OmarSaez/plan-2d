extends Button
class_name SquishyButton

signal tapped()

var is_active_tool: bool = false
var glow_style: StyleBoxFlat
var normal_style: StyleBoxFlat

var hold_time: float = 0.0
var is_pressing: bool = false
var tooltip_shown: bool = false
var tooltip_label: Label
var custom_tip: String = ""

func _ready() -> void:
	# Guardar tooltip y quitar el nativo para evitar duplicados
	custom_tip = tooltip_text
	tooltip_text = ""
	
	# Configurar el pivote al centro para escalar correctamente
	pivot_offset = size / 2.0
	resized.connect(_on_resized)
	
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_setup_styles()
	_setup_tooltip_label()

func _setup_styles() -> void:
	# Estilo normal (gris)
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#2a2b33")
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.corner_radius_bottom_left = 12
	
	# Estilo activo (azul glow)
	glow_style = StyleBoxFlat.new()
	glow_style.bg_color = Color("#3b82f6")
	glow_style.corner_radius_top_left = 12
	glow_style.corner_radius_top_right = 12
	glow_style.corner_radius_bottom_right = 12
	glow_style.corner_radius_bottom_left = 12
	glow_style.shadow_color = Color("#3b82f644")
	glow_style.shadow_size = 12
	
	_apply_styles()

func _setup_tooltip_label() -> void:
	tooltip_label = Label.new()
	tooltip_label.hide()
	tooltip_label.top_level = true # Para que flote sobre todo y no se corte
	tooltip_label.add_theme_font_size_override("font_size", 12)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	tooltip_label.add_theme_stylebox_override("normal", style)
	
	add_child(tooltip_label)

func _process(delta: float) -> void:
	if is_pressing:
		hold_time += delta
		if hold_time >= 0.6 and not tooltip_shown and custom_tip != "":
			_show_tooltip()

func _show_tooltip() -> void:
	tooltip_shown = true
	tooltip_label.text = tr(custom_tip)
	tooltip_label.show()
	# Centrar arriba del botón
	tooltip_label.position = global_position + Vector2(size.x / 2.0 - tooltip_label.size.x / 2.0, -tooltip_label.size.y - 8)

func _hide_tooltip() -> void:
	tooltip_shown = false
	if tooltip_label:
		tooltip_label.hide()

func _on_resized() -> void:
	pivot_offset = size / 2.0

func _on_button_down() -> void:
	is_pressing = true
	hold_time = 0.0
	_squish(Vector2(0.85, 0.85))

func _on_button_up() -> void:
	is_pressing = false
	_hide_tooltip()
	_squish(Vector2.ONE)
	
	# Tap corto = Seleccionar
	if hold_time < 0.6 and is_hovered():
		tapped.emit()
	
	hold_time = 0.0

func _squish(target: Vector2) -> void:
	var tw = create_tween()
	tw.tween_property(self, "scale", target, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_mouse_entered() -> void:
	if not is_active_tool:
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color(1.3, 1.3, 1.3), 0.15)

func _on_mouse_exited() -> void:
	is_pressing = false
	_hide_tooltip()
	if not is_active_tool:
		var tw = create_tween()
		tw.tween_property(self, "modulate", Color.WHITE, 0.15)

func set_active(active: bool) -> void:
	is_active_tool = active
	_apply_styles()

func _apply_styles() -> void:
	if is_active_tool:
		add_theme_stylebox_override("normal", glow_style)
		add_theme_stylebox_override("hover", glow_style)
		add_theme_stylebox_override("pressed", glow_style)
		modulate = Color.WHITE
	else:
		add_theme_stylebox_override("normal", normal_style)
		add_theme_stylebox_override("hover", normal_style)
		add_theme_stylebox_override("pressed", normal_style)
