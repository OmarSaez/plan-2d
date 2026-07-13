extends Node2D
class_name DrawingLayer

var lines: Array[Dictionary] = [] # Formato: { "points": PackedVector2Array, "length_px": float, "type": String }
var current_line: PackedVector2Array = PackedVector2Array()
var current_length_px: float = 0.0
var current_shape_type: String = "freehand"

var line_width: float = 2.0
var default_font: Font
var offset_scale: float = 1.0

# Eraser variables
var eraser_cursor_pos: Vector2 = Vector2.ZERO
var eraser_radius: float = 20.0
var show_eraser_cursor: bool = false
var eraser_mode: String = "area"

var selected_indices: Array[int] = []
var lasso_polygon: PackedVector2Array = PackedVector2Array()
var is_drawing_lasso: bool = false

signal stroke_updated(bubbles_data: Array)
signal stroke_finished()

func _ready() -> void:
	default_font = ThemeDB.fallback_font
	offset_scale = EventBus.current_project_config.get("canvas_scale", 1.0)
	line_width *= offset_scale
	eraser_radius *= offset_scale
	
	EventBus.unit_changed.connect(func(_u): queue_redraw())
	EventBus.camera_view_changed.connect(func(): queue_redraw())
	EventBus.measures_visibility_changed.connect(func(_v): queue_redraw())

func clear() -> void:
	lines.clear()
	queue_redraw()

func start_shape(type: String) -> void:
	current_shape_type = type
	current_line = PackedVector2Array()
	current_length_px = 0.0

func add_point(point: Vector2) -> void:
	if current_line.size() > 0:
		current_length_px += current_line[-1].distance_to(point)
	
	current_line.append(point)
	var text = EventBus.format_length(current_length_px)
	var offset = Vector2(0, -45 * offset_scale).rotated(deg_to_rad(get_snapped_camera_angle()))
	
	stroke_updated.emit([{"text": text, "pos": point + offset}])
	queue_redraw()

func set_current_line(points: PackedVector2Array) -> void:
	current_line = points
	current_length_px = 0.0
	for i in range(1, points.size()):
		current_length_px += points[i-1].distance_to(points[i])
		
	if points.size() > 0:
		var bubbles_data = []
		if (current_shape_type == "rectangle" or current_shape_type == "perfect") and points.size() == 5:
			var w = points[0].distance_to(points[1])
			var h = points[1].distance_to(points[2])
			
			var top_center = (points[0] + points[1]) / 2.0
			var right_center = (points[1] + points[2]) / 2.0
			var bottom_center = (points[2] + points[3]) / 2.0
			
			# Main bubble (W x H) top
			var offset_up = Vector2(0, -45 * offset_scale).rotated(deg_to_rad(get_snapped_camera_angle()))
			var offset_down = Vector2(0, 25 * offset_scale).rotated(deg_to_rad(get_snapped_camera_angle()))
			var offset_right = Vector2(35 * offset_scale, 0).rotated(deg_to_rad(get_snapped_camera_angle()))
			
			bubbles_data.append({"text": "%s x %s" % [EventBus.format_length(w), EventBus.format_length(h)], "pos": top_center + offset_up})
			
			# Width bubble bottom
			if w >= 0.1:
				bubbles_data.append({"text": EventBus.format_length(w), "pos": bottom_center + offset_down})
			
			# Height bubble right
			if h >= 0.1:
				bubbles_data.append({"text": EventBus.format_length(h), "pos": right_center + offset_right})
		elif current_length_px > 0.1:
			var offset = Vector2(0, -45 * offset_scale).rotated(deg_to_rad(get_snapped_camera_angle()))
			var text = EventBus.format_length(current_length_px)
			bubbles_data.append({"text": text, "pos": current_line[-1] + offset})
			
		stroke_updated.emit(bubbles_data)
	queue_redraw()

func finish_line() -> void:
	if current_line.size() > 1:
		if (current_shape_type == "rectangle" or current_shape_type == "perfect") and current_line.size() == 5:
			# Guardar como 4 trazos independientes
			var default_sides = [1, -1, -1, 1]
			for i in range(4):
				var p1 = current_line[i]
				var p2 = current_line[i+1]
				var dist = p1.distance_to(p2)
				if dist >= 0.1:
					lines.append({
						"points": PackedVector2Array([p1, p2]),
						"length_px": dist,
						"type": "straight",
						"color": EventBus.current_color,
						"label_angle": get_snapped_camera_angle(),
						"label_offset_t": 0.5,
						"label_side": default_sides[i],
						"label_visibility": "default" if EventBus.auto_measure else "hidden"
					})
		else:
			lines.append({
				"points": current_line,
				"length_px": current_length_px,
				"type": current_shape_type,
				"color": EventBus.current_color,
				"label_angle": get_snapped_camera_angle(),
				"label_offset_t": 0.5,
				"label_side": 1,
				"label_visibility": "default" if EventBus.auto_measure else "hidden"
			})
	current_line = PackedVector2Array()
	current_length_px = 0.0
	current_shape_type = "freehand"
	stroke_finished.emit()
	queue_redraw()

func cancel_line() -> void:
	current_line = PackedVector2Array()
	current_length_px = 0.0
	current_shape_type = "freehand"
	stroke_finished.emit()
	queue_redraw()

func erase_stroke(point: Vector2) -> bool:
	var erased_something = false
	var threshold = 10.0 * EventBus.current_project_config.get("canvas_scale", 1.0)
	
	for i in range(lines.size() - 1, -1, -1):
		var pts = lines[i]["points"]
		var hit = false
		for j in range(pts.size() - 1):
			var closest = Geometry2D.get_closest_point_to_segment(point, pts[j], pts[j+1])
			if closest.distance_to(point) <= threshold:
				hit = true
				break
		if hit:
			lines.remove_at(i)
			erased_something = true
			
	if erased_something:
		queue_redraw()
	return erased_something

func erase_area(polygon: PackedVector2Array) -> bool:
	var erased_something = false
	var new_lines: Array[Dictionary] = []
	
	for i in range(lines.size()):
		var line_data = lines[i]
		var pts = line_data["points"]
		
		# clip_polyline_with_polygon devuelve las partes FUERA del polígono
		var clipped_parts = Geometry2D.clip_polyline_with_polygon(pts, polygon)
		
		if clipped_parts.size() == 1 and clipped_parts[0].size() == pts.size():
			# Posiblemente idéntico
			var identical = true
			for j in range(pts.size()):
				if clipped_parts[0][j].distance_squared_to(pts[j]) > 0.1:
					identical = false
					break
			if identical:
				new_lines.append(line_data)
				continue
				
		erased_something = true
		
		for part in clipped_parts:
			if part.size() > 1:
				var new_length = 0.0
				for j in range(1, part.size()):
					new_length += part[j-1].distance_to(part[j])
					
				new_lines.append({
					"points": part,
					"length_px": new_length,
					"type": line_data.get("type", "freehand"),
					"color": line_data.get("color", Color.BLACK),
					"label_angle": line_data.get("label_angle", 0.0),
					"label_offset_t": line_data.get("label_offset_t", 0.5),
					"label_side": line_data.get("label_side", 1),
					"show_measure": line_data.get("show_measure", true)
				})
				
	if erased_something:
		lines = new_lines
		queue_redraw()
	return erased_something

func _draw() -> void:
	for i in range(lines.size()):
		var line_data = lines[i]
		var pts: PackedVector2Array = line_data["points"]
		if pts.size() > 1:
			if i in selected_indices:
				draw_polyline(pts, Color(0.15, 0.6, 1.0, 0.85), line_width * 3.0, true)
			draw_polyline(pts, line_data.get("color", Color.BLACK), line_width, true)
			_draw_length_text(line_data)
	
	if current_line.size() > 1:
		draw_polyline(current_line, EventBus.current_color, line_width, true)
		
	if is_drawing_lasso and lasso_polygon.size() > 1:
		draw_polyline(lasso_polygon, Color(0.2, 0.5, 1.0, 0.8), 2.0 * offset_scale, false)
		if lasso_polygon.size() >= 3:
			draw_line(lasso_polygon[-1], lasso_polygon[0], Color(0.2, 0.5, 1.0, 0.4), 2.0 * offset_scale)
			var indices = Geometry2D.triangulate_polygon(lasso_polygon)
			if not indices.is_empty():
				draw_colored_polygon(lasso_polygon, Color(0.2, 0.5, 1.0, 0.1))
		
	if show_eraser_cursor:
		if eraser_mode == "area":
			draw_circle(eraser_cursor_pos, eraser_radius, Color(1, 0.2, 0.2, 0.3))
			draw_arc(eraser_cursor_pos, eraser_radius, 0, TAU, 32, Color(1, 0.2, 0.2, 0.8), 2.0 * EventBus.current_project_config.get("canvas_scale", 1.0))
		elif eraser_mode == "stroke":
			var r = 8.0 * EventBus.current_project_config.get("canvas_scale", 1.0)
			draw_circle(eraser_cursor_pos, r, Color(1, 0.2, 0.2, 0.8))

func get_label_position(line_data: Dictionary) -> Vector2:
	var pts: PackedVector2Array = line_data["points"]
	var type = line_data.get("type", "freehand")
	var t = line_data.get("label_offset_t", 0.5)
	var side = line_data.get("label_side", 1)
	
	if pts.size() < 2: return Vector2.ZERO
	
	if type == "straight" or pts.size() == 2:
		var p1 = pts[0]
		var p2 = pts[-1]
		var center = p1.lerp(p2, t)
		
		var dir = (p2 - p1).normalized()
		var normal = Vector2(-dir.y, dir.x)
		if normal.y > 0 or (normal.y == 0 and normal.x > 0):
			normal = -normal
			
		normal *= side
		
		var text = EventBus.format_length(line_data.get("length_px", 0.0))
		var text_size = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14) if default_font else Vector2(60, 14)
		text_size *= offset_scale # Escalar para el espacio de mundo
		var angle_deg = line_data.get("label_angle", 0.0)
		var is_vertical_text = (int(angle_deg) % 180 != 0)
		
		var effective_width = text_size.y if is_vertical_text else text_size.x
		var effective_height = text_size.x if is_vertical_text else text_size.y
		
		var offset = Vector2.ZERO
		if abs(normal.x) > abs(normal.y):
			# Línea vertical -> Normal horizontal
			offset = normal * (effective_width / 2.0 + 8.0 * offset_scale)
		else:
			# Línea horizontal -> Normal vertical
			offset = normal * (effective_height / 2.0 + 8.0 * offset_scale)
			
		return center + offset # Este es el centro geométrico absoluto
	else:
		var float_idx = (pts.size() - 1) * t
		var idx0 = floor(float_idx)
		var idx1 = ceil(float_idx)
		var pos = pts[int(idx0)]
		if idx0 != idx1:
			var rem = float_idx - idx0
			pos = pos.lerp(pts[int(idx1)], rem)
			
		return pos + Vector2(0, -15 * side * offset_scale) # Desplazamiento simple para a pulso

func _draw_length_text(line_data: Dictionary) -> void:
	var vis = line_data.get("label_visibility", "default")
	var is_hidden = (vis == "hidden") or (vis == "default" and not EventBus.show_measures)
	
	if is_hidden: return
	if line_data["points"].size() < 2 or default_font == null: return
	
	var type = line_data.get("type", "freehand")
	if (type == "rectangle" or type == "perfect") and line_data["points"].size() == 5:
		return # Ya no soportamos renderizar rectángulos consolidados
		
	var geometric_center = get_label_position(line_data)
	var text = EventBus.format_length(line_data.get("length_px", 0.0))
	var angle_deg = line_data.get("label_angle", 0.0)
	
	var text_size = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14) if default_font else Vector2(60, 14)
	
	draw_set_transform(geometric_center, deg_to_rad(angle_deg), Vector2(offset_scale, offset_scale))
	
	# Mover desde el centro geométrico hasta el baseline para dibujado left-aligned
	var draw_pos = Vector2(-text_size.x / 2.0, text_size.y * 0.35)
	
	draw_string_outline(default_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 2, Color.WHITE)
	draw_string(default_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_closest_line_or_label_index(pos: Vector2, label_threshold: float = 40.0, line_threshold: float = 15.0) -> int:
	var closest_idx = -1
	var label_min_dist = label_threshold * offset_scale
	var line_min_dist = line_threshold * offset_scale
	var current_best_dist = INF
	
	for i in range(lines.size()):
		var line_data = lines[i]
		
		var allow_label_hitbox = true
		var vis = line_data.get("label_visibility", "default")
		var is_hidden = (vis == "hidden") or (vis == "default" and not EventBus.show_measures)
		
		if is_hidden:
			var hidden_time = line_data.get("hidden_at_time", 0.0)
			if (Time.get_ticks_msec() / 1000.0) - hidden_time >= 3.0:
				allow_label_hitbox = false
		
		if allow_label_hitbox:
			var rect_center = get_label_position(line_data)
			var dist = rect_center.distance_to(pos)
			if dist < label_min_dist and dist < current_best_dist:
				current_best_dist = dist
				closest_idx = i
				continue
				
		var pts: PackedVector2Array = line_data["points"]
		for j in range(pts.size() - 1):
			var closest = Geometry2D.get_closest_point_to_segment(pos, pts[j], pts[j+1])
			var d = closest.distance_to(pos)
			if d < line_min_dist and d < current_best_dist:
				current_best_dist = d
				closest_idx = i
				
	return closest_idx

func update_line_label(index: int, offset_t: float, side: int) -> void:
	if index >= 0 and index < lines.size():
		lines[index]["label_offset_t"] = clamp(offset_t, 0.0, 1.0)
		lines[index]["label_side"] = side
		queue_redraw()

func update_line_label_angle(index: int, angle_deg: float) -> void:
	if index >= 0 and index < lines.size():
		lines[index]["label_angle"] = fmod(angle_deg, 360.0)
	queue_redraw()

func finish_lasso() -> void:
	if lasso_polygon.size() < 3:
		lasso_polygon.clear()
		is_drawing_lasso = false
		queue_redraw()
		return
		
	for i in range(lines.size()):
		var pts = lines[i]["points"]
		var all_inside = true
		for p in pts:
			if not Geometry2D.is_point_in_polygon(p, lasso_polygon):
				all_inside = false
				break
		if all_inside:
			if not i in selected_indices:
				selected_indices.append(i)
				
	lasso_polygon.clear()
	is_drawing_lasso = false
	queue_redraw()

func get_snapped_camera_angle() -> float:
	var cam_rot = 0.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam_rot = cam.rotation
	return rad_to_deg(snapped(cam_rot, PI/2.0))
