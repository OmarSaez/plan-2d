extends Node2D
class_name CanvasManager

var layers: Array[DrawingLayer] = []
var active_layer_index: int = -1
var paper_rect: ColorRect
var bubbles: Array[Label] = []

func _ready() -> void:
	# Crear la hoja de papel (Tamaño carta 816x1056)
	paper_rect = ColorRect.new()
	paper_rect.color = Color.WHITE
	paper_rect.custom_minimum_size = Vector2(816, 1056)
	paper_rect.size = Vector2(816, 1056)
	
	# Centrar el papel en el mundo (0, 0)
	paper_rect.position = -paper_rect.size / 2.0
	
	paper_rect.clip_contents = true # Evita que los trazos salgan de la hoja
	paper_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	paper_rect.gui_input.connect(_on_paper_gui_input)
	add_child(paper_rect)

	EventBus.clear_canvas_requested.connect(_on_clear_requested)

	add_layer(tr("UI_NEW_LAYER"))
	set_active_layer(0)

func get_unique_layer_name(base_name: String) -> String:
	var new_name = base_name
	var counter = 1
	var name_exists = true
	while name_exists:
		name_exists = false
		for layer in layers:
			if layer.name == new_name:
				name_exists = true
				break
		if name_exists:
			new_name = base_name + " " + str(counter)
			counter += 1
	return new_name

func add_layer(layer_name: String) -> void:
	var unique_name = get_unique_layer_name(layer_name)
	var layer = DrawingLayer.new()
	layer.name = unique_name
	paper_rect.add_child(layer)
	layers.append(layer)
	
	layer.stroke_updated.connect(_on_stroke_updated)
	layer.stroke_finished.connect(_on_stroke_finished)
	
	EventBus.emit_layers_changed(_get_layers_info())

func remove_layer(index: int) -> void:
	if index >= 0 and index < layers.size():
		var layer = layers[index]
		paper_rect.remove_child(layer)
		layer.queue_free()
		layers.remove_at(index)
		
		if layers.size() == 0:
			add_layer(tr("UI_NEW_LAYER"))
			set_active_layer(0)
		else:
			if active_layer_index >= layers.size():
				set_active_layer(layers.size() - 1)
			elif active_layer_index == index:
				set_active_layer(max(0, index - 1))
			else:
				if index < active_layer_index:
					active_layer_index -= 1
				EventBus.emit_active_layer_changed(active_layer_index)
				
		EventBus.emit_layers_changed(_get_layers_info())

func set_active_layer(index: int) -> void:
	if index >= 0 and index < layers.size():
		active_layer_index = index
		EventBus.emit_active_layer_changed(index)

func get_active_layer() -> DrawingLayer:
	if active_layer_index >= 0 and active_layer_index < layers.size():
		return layers[active_layer_index]
	return null

func rename_layer(index: int, new_name: String) -> void:
	if index >= 0 and index < layers.size():
		layers[index].name = new_name
		EventBus.emit_layers_changed(_get_layers_info())

func toggle_layer_visibility(index: int) -> void:
	if index >= 0 and index < layers.size():
		layers[index].visible = !layers[index].visible
		EventBus.emit_layers_changed(_get_layers_info())

func _get_layers_info() -> Array:
	var info = []
	for i in range(layers.size()):
		info.append({
			"name": layers[i].name,
			"visible": layers[i].visible
		})
	return info

func _on_clear_requested() -> void:
	for layer in layers:
		layer.clear()
	update_bubbles([])

func _create_bubble() -> Label:
	var b = Label.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 1.0) # Azul
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.hide()
	add_child(b)
	return b


func update_bubbles(bubbles_data: Array) -> void:
	# Crear más burbujas si hacen falta
	while bubbles.size() < bubbles_data.size():
		bubbles.append(_create_bubble())
	
	for i in range(bubbles.size()):
		if i < bubbles_data.size():
			bubbles[i].visible = true
			bubbles[i].text = bubbles_data[i]["text"]
			bubbles[i].position = paper_rect.position + bubbles_data[i]["pos"]
		else:
			bubbles[i].hide()

func _on_stroke_updated(bubbles_data: Array) -> void:
	update_bubbles(bubbles_data)

func _on_stroke_finished() -> void:
	update_bubbles([])

# El input es ahora relativo a la hoja de papel
func _on_paper_gui_input(event: InputEvent) -> void:
	if get_node_or_null("../../ToolManager"):
		$"../../ToolManager".process_canvas_input(event)
