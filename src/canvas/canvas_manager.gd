extends Node2D
class_name CanvasManager

var layers: Array[DrawingLayer] = []
var active_layer_index: int = -1
var paper_rect: ColorRect
var bubbles: Array[Label] = []

var history_stack: Array[Dictionary] = []
var history_index: int = -1
var is_restoring: bool = false
var auto_save_timer: Timer

func _ready() -> void:
	var p_size: Vector2 = EventBus.current_project_config["paper_size"]
	var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
	var final_size = p_size * c_scale
	
	paper_rect = ColorRect.new()
	paper_rect.color = Color.WHITE
	paper_rect.custom_minimum_size = final_size
	paper_rect.size = final_size
	
	# Centrar el papel en el mundo (0, 0)
	paper_rect.position = -paper_rect.size / 2.0
	
	add_child(paper_rect)
	move_child(paper_rect, 0)
	
	# Ajustar cámara
	var cam = get_viewport().get_camera_2d()
	if cam and cam is CameraController:
		cam.zoom_min = 0.001
		cam.zoom_max = 50.0
		# Zoom para que quepa la hoja (asumiendo pantalla base ~1000px)
		var fit_zoom = 1000.0 / max(final_size.x, final_size.y)
		cam.zoom = Vector2(fit_zoom, fit_zoom)
		cam.update_hud()
	
	paper_rect.clip_contents = true # Evita que los trazos salgan de la hoja
	paper_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	paper_rect.gui_input.connect(_on_paper_gui_input)

	EventBus.clear_canvas_requested.connect(_on_clear_requested)
	EventBus.camera_view_changed.connect(_on_camera_view_changed)
	EventBus.undo_requested.connect(_on_undo_requested)
	EventBus.redo_requested.connect(_on_redo_requested)
	EventBus.manual_save_requested.connect(_on_manual_save_requested)

	var loaded = EventBus.get_meta("loaded_state", {})
	if loaded and loaded.has("layers"):
		restore_state(loaded)
		EventBus.set_meta("loaded_state", {})
	else:
		is_restoring = true
		add_layer(tr("UI_NEW_LAYER"))
		set_active_layer(0)
		is_restoring = false
	save_state()
	
	auto_save_timer = Timer.new()
	auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(auto_save_timer)
	
	EventBus.autosave_interval_changed.connect(_update_auto_save_timer)
	_update_auto_save_timer(EventBus.current_autosave_interval)

func _update_auto_save_timer(minutes: int) -> void:
	if minutes <= 0:
		auto_save_timer.stop()
	else:
		auto_save_timer.wait_time = minutes * 60.0
		auto_save_timer.start()

func _on_auto_save_timeout() -> void:
	EventBus.save_project(get_current_state())

func _on_manual_save_requested() -> void:
	EventBus.save_project(get_current_state())

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
	save_state()

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
		save_state()

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
		save_state()

func toggle_layer_visibility(index: int) -> void:
	if index >= 0 and index < layers.size():
		layers[index].visible = !layers[index].visible
		EventBus.emit_layers_changed(_get_layers_info())
		save_state()

func reorder_layer(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= layers.size() or to_index < 0 or to_index >= layers.size() or from_index == to_index:
		return
		
	var layer = layers[from_index]
	layers.remove_at(from_index)
	layers.insert(to_index, layer)
	
	paper_rect.move_child(layer, to_index)
	
	if active_layer_index == from_index:
		active_layer_index = to_index
	elif active_layer_index > from_index and active_layer_index <= to_index:
		active_layer_index -= 1
	elif active_layer_index < from_index and active_layer_index >= to_index:
		active_layer_index += 1
		
	EventBus.emit_active_layer_changed(active_layer_index)
	EventBus.emit_layers_changed(_get_layers_info())
	save_state()

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
	save_state()

func _on_camera_view_changed() -> void:
	var cam_rot = 0.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam_rot = cam.rotation
	var snapped_cam_rot = snapped(cam_rot, PI/2.0)
	var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
	for b in bubbles:
		if b.visible:
			b.reset_size()
			b.pivot_offset = b.size / 2.0
			b.rotation = snapped_cam_rot
			b.scale = Vector2(c_scale, c_scale)

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
	var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
	b.scale = Vector2(c_scale, c_scale)
	add_child(b)
	return b

func update_bubbles(bubbles_data: Array) -> void:
	var cam_rot = 0.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam_rot = cam.rotation
	var snapped_cam_rot = snapped(cam_rot, PI/2.0)
	
	# Crear más burbujas si hacen falta
	while bubbles.size() < bubbles_data.size():
		bubbles.append(_create_bubble())
	
	for i in range(bubbles.size()):
		if i < bubbles_data.size():
			var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
			bubbles[i].visible = true
			bubbles[i].text = bubbles_data[i]["text"]
			bubbles[i].reset_size()
			bubbles[i].pivot_offset = bubbles[i].size / 2.0
			bubbles[i].scale = Vector2(c_scale, c_scale)
			# El pivot está en el centro, así que scale no mueve el centro.
			# Posicionamos la esquina superior izquierda normal: pos - size/2
			bubbles[i].position = paper_rect.position + bubbles_data[i]["pos"] - bubbles[i].size / 2.0
			bubbles[i].rotation = snapped_cam_rot
		else:
			bubbles[i].hide()

func _on_stroke_updated(bubbles_data: Array) -> void:
	update_bubbles(bubbles_data)

func _on_stroke_finished() -> void:
	update_bubbles([])
	save_state()

# El input es ahora relativo a la hoja de papel
func _on_paper_gui_input(event: InputEvent) -> void:
	if get_node_or_null("../../ToolManager"):
		$"../../ToolManager".process_canvas_input(event)

func get_current_state() -> Dictionary:
	var state_layers = []
	for layer in layers:
		var cloned_lines = []
		for line_data in layer.lines:
			cloned_lines.append(line_data.duplicate(true))
			
		state_layers.append({
			"name": layer.name,
			"visible": layer.visible,
			"lines": cloned_lines
		})
		
	return {
		"active_layer_index": active_layer_index,
		"layers": state_layers
	}

func export_for_print() -> void:
	var vp = SubViewport.new()
	vp.size = paper_rect.size
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	add_child(vp)
	
	remove_child(paper_rect)
	vp.add_child(paper_rect)
	paper_rect.position = Vector2.ZERO
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = vp.get_texture().get_image()
	
	vp.remove_child(paper_rect)
	add_child(paper_rect)
	move_child(paper_rect, 0)
	paper_rect.position = -paper_rect.size / 2.0
	vp.queue_free()
	
	var path = "user://print_temp.png"
	img.save_png(path)
	
	if OS.get_name() == "Android":
		if Engine.has_singleton("PrintPlugin"):
			var plugin = Engine.get_singleton("PrintPlugin")
			plugin.printImage(ProjectSettings.globalize_path(path))
		else:
			print("PrintPlugin not found!")
	else:
		print("Impresión solo disponible en Android. Imagen guardada en: ", ProjectSettings.globalize_path(path))

func restore_state(state: Dictionary) -> void:
	is_restoring = true
	
	for layer in layers:
		paper_rect.remove_child(layer)
		layer.queue_free()
	layers.clear()
	
	for layer_state in state["layers"]:
		var layer = DrawingLayer.new()
		layer.name = layer_state["name"]
		layer.visible = layer_state["visible"]
		
		# Enforce typed array assignment safely
		for ld in layer_state["lines"]:
			layer.lines.append(ld)
		paper_rect.add_child(layer)
		layers.append(layer)
		
		layer.stroke_updated.connect(_on_stroke_updated)
		layer.stroke_finished.connect(_on_stroke_finished)
		
	active_layer_index = state["active_layer_index"]
	
	EventBus.emit_layers_changed(_get_layers_info())
	EventBus.emit_active_layer_changed(active_layer_index)
	
	for layer in layers:
		layer.queue_redraw()
		
	is_restoring = false

func save_state() -> void:
	if is_restoring: return
	
	var state = get_current_state()
	
	if history_index < history_stack.size() - 1:
		history_stack = history_stack.slice(0, history_index + 1)
		
	history_stack.append(state)
	
	if history_stack.size() > 15:
		history_stack.pop_front()
		
	history_index = history_stack.size() - 1
	_emit_history_changed()

func _emit_history_changed() -> void:
	var can_undo = history_index > 0
	var can_redo = history_index < history_stack.size() - 1
	EventBus.history_changed.emit(can_undo, can_redo)

func _on_undo_requested() -> void:
	if history_index > 0:
		history_index -= 1
		restore_state(history_stack[history_index])
		_emit_history_changed()

func _on_redo_requested() -> void:
	if history_index < history_stack.size() - 1:
		history_index += 1
		restore_state(history_stack[history_index])
		_emit_history_changed()
