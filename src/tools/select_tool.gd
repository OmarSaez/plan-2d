extends BaseTool
class_name SelectTool

var dragging_index: int = -1
var double_click_timer: float = 0.0
var double_click_threshold: float = 0.25
var last_clicked_index: int = -1
var has_dragged: bool = false
var pending_click_id: int = 0
var last_mouse_pos: Vector2 = Vector2.ZERO
var is_moving: bool = false
var original_state_saved: bool = false

var is_rotating: bool = false
var rotation_center: Vector2 = Vector2.ZERO
var original_points_rot: Array = []

func _init(c: CanvasManager) -> void:
	super._init(c)

func process_input(event: InputEvent) -> void:
	var layer = canvas.get_active_layer()
	if not layer: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				last_mouse_pos = event.position
				
				var clicked_on_selection_bounds = false
				if layer.selected_indices.size() > 0:
					var bounds = _get_selection_bounds(layer)
					bounds = bounds.grow(40.0)
					if bounds.has_point(event.position):
						clicked_on_selection_bounds = true
						
				# Revisar si tocamos una línea (margen 15px) o su etiqueta (margen 40px)
				var idx = layer.get_closest_line_or_label_index(event.position, 40.0, 15.0)
				
				if idx != -1:
					# Lógica de doble clic para rotar etiqueta
					var current_time = Time.get_ticks_msec() / 1000.0
					if idx == last_clicked_index and (current_time - double_click_timer) < double_click_threshold:
						var line = layer.lines[idx]
						
						# Cancelar el tap pendiente
						pending_click_id += 1
						
						var current_angle = line.get("label_angle", 0.0)
						layer.update_line_label_angle(idx, current_angle + 90.0)
						canvas.save_state()
						dragging_index = -1
						last_clicked_index = -1
						return
					
					last_clicked_index = idx
					double_click_timer = current_time
					
					# Programar el ocultamiento diferido para dar tiempo al doble tap
					pending_click_id += 1
					var expected_id = pending_click_id
					canvas.get_tree().create_timer(double_click_threshold).timeout.connect(
						func():
							if pending_click_id == expected_id:
								if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
									return # Es un long press / drag, no un tap, cancelar toggle
									
								var active_layer = canvas.get_active_layer()
								if active_layer and idx >= 0 and idx < active_layer.lines.size():
									var l = active_layer.lines[idx]
									var vis = l.get("label_visibility", "default")
									var is_currently_hidden = (vis == "hidden") or (vis == "default" and not EventBus.show_measures)
									
									var will_hide = not is_currently_hidden
									if will_hide:
										l["label_visibility"] = "hidden"
										l["hidden_at_time"] = Time.get_ticks_msec() / 1000.0
										var t = active_layer.get_tree().create_timer(3.0)
										if t: t.timeout.connect(active_layer.queue_redraw)
									else:
										l["label_visibility"] = "visible"
									
									active_layer.queue_redraw()
									canvas.save_state()
					)
					
					dragging_index = idx
					is_moving = false
					has_dragged = false
					last_mouse_pos = event.position
					original_state_saved = false
					
				elif clicked_on_selection_bounds:
					# Clic dentro del área seleccionada, mover todo
					dragging_index = -2 # Marcador para saber que arrastramos bloque
					is_moving = true
					has_dragged = false
					original_state_saved = false
					
				else:
					# Clic en espacio vacío: empezar lazo
					layer.selected_indices.clear()
					layer.is_drawing_lasso = true
					layer.lasso_polygon.clear()
					layer.lasso_polygon.append(event.position)
					layer.queue_redraw()
					dragging_index = -1
					is_moving = false
					
			else:
				if layer.is_drawing_lasso:
					layer.finish_lasso()
				elif is_moving and has_dragged:
					if not original_state_saved:
						canvas.save_state()
						
				dragging_index = -1
				is_moving = false
				has_dragged = false
				
	elif event is InputEventMouseMotion:
		if layer.is_drawing_lasso:
			if layer.lasso_polygon.size() > 0 and event.position.distance_to(layer.lasso_polygon[-1]) > 10.0:
				layer.lasso_polygon.append(event.position)
				layer.queue_redraw()
				
		elif is_moving and layer.selected_indices.size() > 0:
			var delta = event.position - last_mouse_pos
			last_mouse_pos = event.position
			
			for s_idx in layer.selected_indices:
				var pts: PackedVector2Array = layer.lines[s_idx]["points"]
				for i in range(pts.size()):
					pts[i] += delta
				layer.lines[s_idx]["points"] = pts
				
			has_dragged = true
			layer.queue_redraw()
			
		elif dragging_index >= 0:
			if not has_dragged and event.position.distance_to(last_mouse_pos) < 5.0:
				return # Esperar un poco antes de considerar drag
				
			var pts: PackedVector2Array = layer.lines[dragging_index]["points"]
			var type = layer.lines[dragging_index].get("type", "freehand")
			
			if (type == "straight" or pts.size() == 2) and pts.size() >= 2:
				if not has_dragged:
					pending_click_id += 1 # Cancelar el tap si empezamos a arrastrar antes de que expire
				has_dragged = true
				
				var p1 = pts[0]
				var p2 = pts[-1]
				var dir = (p2 - p1).normalized()
				var proj_dist = (event.position - p1).dot(dir)
				var t = clamp(proj_dist / p1.distance_to(p2), 0.0, 1.0)
				
				var normal = Vector2(-dir.y, dir.x)
				if normal.y > 0 or (normal.y == 0 and normal.x > 0):
					normal = -normal
					
				var to_mouse = event.position - (p1 + dir * proj_dist)
				var side = 1 if normal.dot(to_mouse) > 0 else -1
				
				layer.update_line_label(dragging_index, t, side)

func cancel_action() -> void:
	var layer = canvas.get_active_layer()
	if layer:
		layer.selected_indices.clear()
		layer.is_drawing_lasso = false
		layer.lasso_polygon.clear()
		layer.queue_redraw()
	is_rotating = false
	original_points_rot.clear()

func _get_selection_bounds(layer) -> Rect2:
	if layer.selected_indices.size() == 0:
		return Rect2()
	
	var first = true
	var min_p = Vector2()
	var max_p = Vector2()
	
	for s_idx in layer.selected_indices:
		var pts = layer.lines[s_idx]["points"]
		for p in pts:
			if first:
				min_p = p
				max_p = p
				first = false
			else:
				min_p.x = min(min_p.x, p.x)
				min_p.y = min(min_p.y, p.y)
				max_p.x = max(max_p.x, p.x)
				max_p.y = max(max_p.y, p.y)
				
	return Rect2(min_p, max_p - min_p)

func on_rotation_start(world_pos: Vector2) -> bool:
	var layer = canvas.get_active_layer()
	if not layer or layer.selected_indices.size() == 0:
		return false
		
	var bounds = _get_selection_bounds(layer)
	bounds = bounds.grow(40.0)
	
	var local_pos = layer.get_global_transform().affine_inverse() * world_pos
	
	if bounds.has_point(local_pos):
		is_rotating = true
		rotation_center = bounds.get_center()
		original_points_rot.clear()
		
		for s_idx in layer.selected_indices:
			original_points_rot.append(layer.lines[s_idx]["points"].duplicate())
			
		return true
	return false

func on_rotation_process(angle_delta: float) -> void:
	if not is_rotating: return
	
	var layer = canvas.get_active_layer()
	if not layer: return
	
	for i in range(layer.selected_indices.size()):
		var s_idx = layer.selected_indices[i]
		var orig_pts: PackedVector2Array = original_points_rot[i]
		var new_pts: PackedVector2Array = PackedVector2Array()
		
		for p in orig_pts:
			new_pts.append(rotation_center + (p - rotation_center).rotated(angle_delta))
			
		layer.lines[s_idx]["points"] = new_pts
		
	layer.queue_redraw()

func on_rotation_end() -> void:
	if is_rotating:
		canvas.save_state()
		is_rotating = false
		original_points_rot.clear()

func on_rotation_discrete(world_pos: Vector2, angle_delta: float) -> bool:
	var layer = canvas.get_active_layer()
	if not layer or layer.selected_indices.size() == 0:
		return false
		
	var bounds = _get_selection_bounds(layer)
	bounds = bounds.grow(40.0)
	
	var local_pos = layer.get_global_transform().affine_inverse() * world_pos
	
	if bounds.has_point(local_pos):
		var center = bounds.get_center()
		
		for s_idx in layer.selected_indices:
			var pts: PackedVector2Array = layer.lines[s_idx]["points"]
			for i in range(pts.size()):
				pts[i] = center + (pts[i] - center).rotated(angle_delta)
			layer.lines[s_idx]["points"] = pts
			
		layer.queue_redraw()
		canvas.save_state()
		return true
		
	return false
