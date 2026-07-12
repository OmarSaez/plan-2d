extends BaseTool
class_name PenTool

var is_drawing: bool = false

func process_input(event: InputEvent) -> void:
	var layer = canvas.get_active_layer()
	if not layer: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			layer.start_shape("freehand")
			layer.add_point(event.position)
		else:
			is_drawing = false
			layer.finish_line()
			
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_drawing:
			layer.add_point(event.position)
