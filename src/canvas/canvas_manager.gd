extends Node2D
class_name CanvasManager

var papers: Array[ColorRect] = []
var active_paper_index: int = 0
var paper_container: Control
var global_layers: Array[Dictionary] = []
var active_layer_index: int = -1
var bubbles: Array[Label] = []

var history_stack: Array[Dictionary] = []
var history_index: int = -1
var is_restoring: bool = false
var auto_save_timer: Timer

func _ready() -> void:
	var p_size: Vector2 = EventBus.current_project_config["paper_size"]
	var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
	var final_size = p_size * c_scale
	
	paper_container = Control.new()
	add_child(paper_container)
	move_child(paper_container, 0)
	
	_create_paper()
	
	# Ajustar cámara
	var cam = get_viewport().get_camera_2d()
	if cam and cam is CameraController:
		cam.zoom_min = 0.001
		cam.zoom_max = 50.0
		var fit_zoom = 1000.0 / max(final_size.x, final_size.y)
		cam.zoom = Vector2(fit_zoom, fit_zoom)
		cam.update_hud()
	
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

func _create_paper() -> void:
	var p_size: Vector2 = EventBus.current_project_config["paper_size"]
	var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
	var final_size = p_size * c_scale
	
	var paper = ColorRect.new()
	paper.color = Color.WHITE
	paper.custom_minimum_size = final_size
	paper.size = final_size
	
	var y_offset = 0.0
	if papers.size() > 0:
		var last_paper = papers[-1]
		y_offset = last_paper.position.y + last_paper.size.y + 50.0
	else:
		y_offset = -final_size.y / 2.0
		
	paper.position = Vector2(-final_size.x / 2.0, y_offset)
	paper.clip_contents = true
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	paper.gui_input.connect(_on_paper_gui_input.bind(papers.size()))
	
	paper_container.add_child(paper)
	papers.append(paper)
	
	for g_layer in global_layers:
		var layer = DrawingLayer.new()
		layer.name = g_layer.name
		layer.visible = g_layer.visible
		layer.stroke_updated.connect(_on_stroke_updated)
		layer.stroke_finished.connect(_on_stroke_finished)
		paper.add_child(layer)

func add_paper() -> void:
	_create_paper()
	save_state()

func remove_paper() -> void:
	if papers.size() > 1:
		var paper = papers.pop_back()
		paper_container.remove_child(paper)
		paper.queue_free()
		if active_paper_index >= papers.size():
			active_paper_index = papers.size() - 1
		save_state()

func get_unique_layer_name(base_name: String) -> String:
	var new_name = base_name
	var counter = 1
	var name_exists = true
	while name_exists:
		name_exists = false
		for gl in global_layers:
			if gl.name == new_name:
				name_exists = true
				break
		if name_exists:
			new_name = base_name + " " + str(counter)
			counter += 1
	return new_name

func add_layer(layer_name: String) -> void:
	var unique_name = get_unique_layer_name(layer_name)
	global_layers.append({"name": unique_name, "visible": true})
	
	for paper in papers:
		var layer = DrawingLayer.new()
		layer.name = unique_name
		layer.stroke_updated.connect(_on_stroke_updated)
		layer.stroke_finished.connect(_on_stroke_finished)
		paper.add_child(layer)
	
	EventBus.emit_layers_changed(_get_layers_info())
	if not is_restoring: save_state()

func remove_layer(index: int) -> void:
	if index >= 0 and index < global_layers.size():
		global_layers.remove_at(index)
		for paper in papers:
			var layer = paper.get_child(index)
			paper.remove_child(layer)
			layer.queue_free()
		
		if global_layers.size() == 0:
			add_layer(tr("UI_NEW_LAYER"))
			set_active_layer(0)
		else:
			if active_layer_index >= global_layers.size():
				set_active_layer(global_layers.size() - 1)
			elif active_layer_index == index:
				set_active_layer(max(0, index - 1))
			else:
				if index < active_layer_index:
					active_layer_index -= 1
				EventBus.emit_active_layer_changed(active_layer_index)
				
		EventBus.emit_layers_changed(_get_layers_info())
		if not is_restoring: save_state()

func set_active_layer(index: int) -> void:
	if index >= 0 and index < global_layers.size():
		active_layer_index = index
		EventBus.emit_active_layer_changed(index)

func get_active_layer() -> DrawingLayer:
	if active_paper_index >= 0 and active_paper_index < papers.size():
		var paper = papers[active_paper_index]
		if active_layer_index >= 0 and active_layer_index < paper.get_child_count():
			return paper.get_child(active_layer_index) as DrawingLayer
	return null

func rename_layer(index: int, new_name: String) -> void:
	if index >= 0 and index < global_layers.size():
		global_layers[index].name = new_name
		for paper in papers:
			paper.get_child(index).name = new_name
		EventBus.emit_layers_changed(_get_layers_info())
		if not is_restoring: save_state()

func toggle_layer_visibility(index: int) -> void:
	if index >= 0 and index < global_layers.size():
		global_layers[index].visible = !global_layers[index].visible
		for paper in papers:
			paper.get_child(index).visible = global_layers[index].visible
		EventBus.emit_layers_changed(_get_layers_info())
		if not is_restoring: save_state()

func reorder_layer(from_index: int, to_index: int) -> void:
	if from_index < 0 or from_index >= global_layers.size() or to_index < 0 or to_index >= global_layers.size() or from_index == to_index:
		return
		
	var g_layer = global_layers[from_index]
	global_layers.remove_at(from_index)
	global_layers.insert(to_index, g_layer)
	
	for paper in papers:
		var layer = paper.get_child(from_index)
		paper.move_child(layer, to_index)
	
	if active_layer_index == from_index:
		active_layer_index = to_index
	elif active_layer_index > from_index and active_layer_index <= to_index:
		active_layer_index -= 1
	elif active_layer_index < from_index and active_layer_index >= to_index:
		active_layer_index += 1
		
	EventBus.emit_active_layer_changed(active_layer_index)
	EventBus.emit_layers_changed(_get_layers_info())
	if not is_restoring: save_state()

func _get_layers_info() -> Array:
	return global_layers.duplicate(true)

func _on_clear_requested() -> void:
	for paper in papers:
		for layer in paper.get_children():
			if layer is DrawingLayer:
				layer.clear()
	update_bubbles([])
	if not is_restoring: save_state()

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
	
	while bubbles.size() < bubbles_data.size():
		bubbles.append(_create_bubble())
		
	var active_paper_pos = Vector2.ZERO
	if active_paper_index >= 0 and active_paper_index < papers.size():
		active_paper_pos = papers[active_paper_index].position
	
	for i in range(bubbles.size()):
		if i < bubbles_data.size():
			var c_scale: float = EventBus.current_project_config.get("canvas_scale", 1.0)
			bubbles[i].visible = true
			bubbles[i].text = bubbles_data[i]["text"]
			bubbles[i].reset_size()
			bubbles[i].pivot_offset = bubbles[i].size / 2.0
			bubbles[i].scale = Vector2(c_scale, c_scale)
			bubbles[i].position = active_paper_pos + bubbles_data[i]["pos"] - bubbles[i].size / 2.0
			bubbles[i].rotation = snapped_cam_rot
		else:
			bubbles[i].hide()

func _on_stroke_updated(bubbles_data: Array) -> void:
	update_bubbles(bubbles_data)

func _on_stroke_finished() -> void:
	update_bubbles([])
	save_state()

func _on_paper_gui_input(event: InputEvent, paper_idx: int) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			active_paper_index = paper_idx
	if get_node_or_null("../../ToolManager"):
		$"../../ToolManager".process_canvas_input(event)

func get_current_state() -> Dictionary:
	var state_papers = []
	for paper in papers:
		var state_layers = []
		for i in range(global_layers.size()):
			var layer = paper.get_child(i)
			var cloned_lines = []
			for line_data in layer.lines:
				cloned_lines.append(line_data.duplicate(true))
			state_layers.append({
				"lines": cloned_lines
			})
		state_papers.append(state_layers)
		
	return {
		"active_layer_index": active_layer_index,
		"active_paper_index": active_paper_index,
		"global_layers": global_layers.duplicate(true),
		"papers": state_papers
	}

func export_for_print() -> void:
	if papers.size() == 0: return
	
	var vp = SubViewport.new()
	var min_y = INF
	var max_y = -INF
	for paper in papers:
		min_y = min(min_y, paper.position.y)
		max_y = max(max_y, paper.position.y + paper.size.y)
		
	var total_size = papers[0].size
	total_size.y = max_y - min_y
	
	vp.size = total_size
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	add_child(vp)
	
	remove_child(paper_container)
	vp.add_child(paper_container)
	
	var old_pos = paper_container.position
	paper_container.position = Vector2(papers[0].size.x / 2.0, -min_y)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = vp.get_texture().get_image()
	
	vp.remove_child(paper_container)
	add_child(paper_container)
	move_child(paper_container, 0)
	paper_container.position = old_pos
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
	
	for paper in papers:
		paper_container.remove_child(paper)
		paper.queue_free()
	papers.clear()
	global_layers.clear()
	
	if state.has("papers"):
		global_layers = state["global_layers"].duplicate(true)
		var state_papers = state["papers"]
		for i in range(state_papers.size()):
			_create_paper()
			var paper = papers[i]
			var state_layers = state_papers[i]
			for j in range(state_layers.size()):
				var layer = paper.get_child(j)
				for ld in state_layers[j]["lines"]:
					layer.lines.append(ld.duplicate(true))
	elif state.has("layers"):
		var layer_states = state["layers"]
		for ls in layer_states:
			global_layers.append({"name": ls["name"], "visible": ls["visible"]})
		
		_create_paper()
		var paper = papers[0]
		for j in range(layer_states.size()):
			var layer = paper.get_child(j)
			for ld in layer_states[j]["lines"]:
				layer.lines.append(ld.duplicate(true))
				
	active_layer_index = state["active_layer_index"]
	if state.has("active_paper_index"):
		active_paper_index = state["active_paper_index"]
	
	EventBus.emit_layers_changed(_get_layers_info())
	EventBus.emit_active_layer_changed(active_layer_index)
	
	for paper in papers:
		for layer in paper.get_children():
			if layer is DrawingLayer:
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
