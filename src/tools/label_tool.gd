extends BaseTool
class_name LabelTool

var dragging_index: int = -1
var double_click_timer: float = 0.0
var double_click_threshold: float = 0.3
var last_clicked_index: int = -1

func _init(c: CanvasManager) -> void:
	super._init(c)

func process_input(event: InputEvent) -> void:
	var layer = canvas.get_active_layer()
	if not layer: return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var idx = layer.get_closest_label_index(event.position, 40.0)
				if idx != -1:
					var current_time = Time.get_ticks_msec() / 1000.0
					if idx == last_clicked_index and (current_time - double_click_timer) < double_click_threshold:
						var line = layer.lines[idx]
						var current_angle = line.get("label_angle", 0.0)
						layer.update_line_label_angle(idx, current_angle + 90.0)
						dragging_index = -1
						last_clicked_index = -1 # Reset for next click
					else:
						dragging_index = idx
						last_clicked_index = idx
						double_click_timer = current_time
			else:
				dragging_index = -1
				
	elif event is InputEventMouseMotion:
		if dragging_index != -1:
			var line = layer.lines[dragging_index]
			var pts: PackedVector2Array = line["points"]
			var type = line.get("type", "freehand")
			
			if (type == "straight" or pts.size() == 2) and pts.size() >= 2:
				var p1 = pts[0]
				var p2 = pts[-1]
				var dir = (p2 - p1).normalized()
				var length = p1.distance_to(p2)
				
				var v = event.position - p1
				var dot = v.dot(dir)
				var t = clamp(dot / length, 0.0, 1.0)
				
				var normal = Vector2(-dir.y, dir.x)
				if normal.y > 0 or (normal.y == 0 and normal.x > 0):
					normal = -normal
					
				var normal_dist = v.dot(normal)
				var side = 1 if normal_dist > 0 else -1
				
				layer.update_line_label(dragging_index, t, side)
