extends Node2D
class_name DrawingLayer

var lines: Array[Dictionary] = [] # Formato: { "points": PackedVector2Array, "length_mm": float, "type": String }
var current_line: PackedVector2Array = PackedVector2Array()
var current_length_mm: float = 0.0
var current_shape_type: String = "freehand"

var line_width: float = 2.0
var pixels_per_mm: float = 1.0 
var default_font: Font

# Eraser variables
var eraser_cursor_pos: Vector2 = Vector2.ZERO
var eraser_radius: float = 20.0
var show_eraser_cursor: bool = false
var eraser_mode: String = "area"

signal stroke_updated(bubbles_data: Array)
signal stroke_finished()

func _ready() -> void:
	default_font = ThemeDB.fallback_font
	EventBus.unit_changed.connect(func(_u): queue_redraw())
	EventBus.camera_view_changed.connect(func(): queue_redraw())
	EventBus.measures_visibility_changed.connect(func(_v): queue_redraw())

func clear() -> void:
	lines.clear()
	queue_redraw()

func start_shape(type: String) -> void:
	current_shape_type = type
	current_line = PackedVector2Array()
	current_length_mm = 0.0

func add_point(point: Vector2) -> void:
	if current_line.size() > 0:
		var distance_px = current_line[-1].distance_to(point)
		current_length_mm += distance_px / pixels_per_mm
	
	current_line.append(point)
	var text = EventBus.format_length(current_length_mm)
	var offset = Vector2(0, -45).rotated(deg_to_rad(get_snapped_camera_angle()))
	
	if EventBus.auto_measure and EventBus.show_measures:
		stroke_updated.emit([{"text": text, "pos": point + offset}])
	else:
		stroke_updated.emit([])
		
	queue_redraw()

func set_current_line(points: PackedVector2Array) -> void:
	current_line = points
	current_length_mm = 0.0
	for i in range(1, points.size()):
		current_length_mm += points[i-1].distance_to(points[i]) / pixels_per_mm
		
	if points.size() > 0:
		var bubbles_data = []
		if (current_shape_type == "rectangle" or current_shape_type == "perfect") and points.size() == 5:
			var w = points[0].distance_to(points[1]) / pixels_per_mm
			var h = points[1].distance_to(points[2]) / pixels_per_mm
			
			var top_center = (points[0] + points[1]) / 2.0
			var right_center = (points[1] + points[2]) / 2.0
			var bottom_center = (points[2] + points[3]) / 2.0
			
			# Main bubble (W x H) top
			var offset_up = Vector2(0, -45).rotated(deg_to_rad(get_snapped_camera_angle()))
			var offset_down = Vector2(0, 25).rotated(deg_to_rad(get_snapped_camera_angle()))
			var offset_right = Vector2(35, 0).rotated(deg_to_rad(get_snapped_camera_angle()))
			
			bubbles_data.append({"text": "%s x %s" % [EventBus.format_length(w), EventBus.format_length(h)], "pos": top_center + offset_up})
			
			# Width bubble bottom
			if w >= 0.1:
				bubbles_data.append({"text": EventBus.format_length(w), "pos": bottom_center + offset_down})
			
			# Height bubble right
			if h >= 0.1:
				bubbles_data.append({"text": EventBus.format_length(h), "pos": right_center + offset_right})
		elif current_length_mm > 0.1:
			var offset = Vector2(0, -45).rotated(deg_to_rad(get_snapped_camera_angle()))
			var text = EventBus.format_length(current_length_mm)
			bubbles_data.append({"text": text, "pos": current_line[-1] + offset})
			
		if EventBus.auto_measure and EventBus.show_measures:
			stroke_updated.emit(bubbles_data)
		else:
			stroke_updated.emit([])
	queue_redraw()

func finish_line() -> void:
	if current_line.size() > 1:
		if (current_shape_type == "rectangle" or current_shape_type == "perfect") and current_line.size() == 5:
			# Guardar como 4 trazos independientes
			var default_sides = [1, -1, -1, 1]
			for i in range(4):
				var p1 = current_line[i]
				var p2 = current_line[i+1]
				var dist = p1.distance_to(p2) / pixels_per_mm
				if dist >= 0.1:
					lines.append({
						"points": PackedVector2Array([p1, p2]),
						"length_mm": dist,
						"type": "straight",
						"color": EventBus.current_color,
						"label_angle": get_snapped_camera_angle(),
						"label_offset_t": 0.5,
						"label_side": default_sides[i],
						"show_measure": EventBus.auto_measure
					})
		else:
			lines.append({
				"points": current_line,
				"length_mm": current_length_mm,
				"type": current_shape_type,
				"color": EventBus.current_color,
				"label_angle": get_snapped_camera_angle(),
				"label_offset_t": 0.5,
				"label_side": 1,
				"show_measure": EventBus.auto_measure
			})
	current_line = PackedVector2Array()
	current_length_mm = 0.0
	current_shape_type = "freehand"
	stroke_finished.emit()
	queue_redraw()

func cancel_line() -> void:
	current_line = PackedVector2Array()
	current_length_mm = 0.0
	current_shape_type = "freehand"
	stroke_finished.emit()
	queue_redraw()

func erase_stroke(point: Vector2) -> bool:
	var erased_something = false
	var threshold = 10.0
	
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
					new_length += part[j-1].distance_to(part[j]) / pixels_per_mm
					
				new_lines.append({
					"points": part,
					"length_mm": new_length,
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
	for line_data in lines:
		var pts: PackedVector2Array = line_data["points"]
		if pts.size() > 1:
			draw_polyline(pts, line_data.get("color", Color.BLACK), line_width, true)
			_draw_length_text(line_data)
	
	if current_line.size() > 1:
		draw_polyline(current_line, EventBus.current_color, line_width, true)
		
	if show_eraser_cursor:
		if eraser_mode == "area":
			draw_circle(eraser_cursor_pos, eraser_radius, Color(1, 0.2, 0.2, 0.3))
			draw_arc(eraser_cursor_pos, eraser_radius, 0, TAU, 32, Color(1, 0.2, 0.2, 0.8), 2.0)
		elif eraser_mode == "stroke":
			draw_circle(eraser_cursor_pos, 8.0, Color(1, 0.2, 0.2, 0.8))

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
		
		var text = EventBus.format_length(line_data.get("length_mm", 0.0))
		var text_size = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14) if default_font else Vector2(60, 14)
		var angle_deg = line_data.get("label_angle", 0.0)
		var is_vertical_text = (int(angle_deg) % 180 != 0)
		
		var effective_width = text_size.y if is_vertical_text else text_size.x
		var effective_height = text_size.x if is_vertical_text else text_size.y
		
		var offset = Vector2.ZERO
		if abs(normal.x) > abs(normal.y):
			# Línea vertical -> Normal horizontal
			offset = normal * (effective_width / 2.0 + 8.0)
		else:
			# Línea horizontal -> Normal vertical
			offset = normal * (effective_height / 2.0 + 8.0)
			
		return center + offset # Este es el centro geométrico absoluto
	else:
		var float_idx = (pts.size() - 1) * t
		var idx0 = floor(float_idx)
		var idx1 = ceil(float_idx)
		var pos = pts[int(idx0)]
		if idx0 != idx1:
			var rem = float_idx - idx0
			pos = pos.lerp(pts[int(idx1)], rem)
			
		return pos + Vector2(0, -15 * side) # Desplazamiento simple para a pulso

func _draw_length_text(line_data: Dictionary) -> void:
	if not EventBus.show_measures: return
	if not line_data.get("show_measure", true): return
	if line_data["points"].size() < 2 or default_font == null: return
	
	var type = line_data.get("type", "freehand")
	if (type == "rectangle" or type == "perfect") and line_data["points"].size() == 5:
		return # Ya no soportamos renderizar rectángulos consolidados
		
	var geometric_center = get_label_position(line_data)
	var text = EventBus.format_length(line_data["length_mm"])
	var angle_deg = line_data.get("label_angle", 0.0)
	
	var text_size = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14) if default_font else Vector2(60, 14)
	
	var draw_pos = geometric_center
	
	if angle_deg != 0.0:
		draw_set_transform(geometric_center, deg_to_rad(angle_deg), Vector2.ONE)
		draw_pos = Vector2.ZERO # El origen ahora es el centro geométrico
	
	# Mover desde el centro geométrico hasta el baseline para dibujado left-aligned
	draw_pos += Vector2(-text_size.x / 2.0, text_size.y * 0.35)
	
	draw_string_outline(default_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 2, Color.WHITE)
	draw_string(default_font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	
	if angle_deg != 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_closest_label_index(pos: Vector2, threshold: float = 30.0) -> int:
	var closest_idx = -1
	var min_dist = threshold
	
	for i in range(lines.size()):
		var rect_center = get_label_position(lines[i]) # Ahora es el centro geométrico real
		var dist = rect_center.distance_to(pos)
		if dist < min_dist:
			min_dist = dist
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

func get_snapped_camera_angle() -> float:
	var cam_rot = 0.0
	var cam = get_viewport().get_camera_2d()
	if cam:
		cam_rot = cam.rotation
	return rad_to_deg(snapped(cam_rot, PI/2.0))
