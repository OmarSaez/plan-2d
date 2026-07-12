extends BaseTool
class_name RectangleTool

var is_drawing: bool = false
var start_point: Vector2 = Vector2.ZERO

func process_input(event: InputEvent) -> void:
	var layer = canvas.get_active_layer()
	if not layer: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			start_point = event.position
			layer.start_shape("rectangle")
			_update_rect(layer, event.position)
		else:
			is_drawing = false
			layer.finish_line()
			
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_drawing:
			_update_rect(layer, event.position)

func _update_rect(layer: DrawingLayer, current_pos: Vector2) -> void:
	var p1 = start_point
	var p2 = Vector2(current_pos.x, start_point.y)
	var p3 = current_pos
	var p4 = Vector2(start_point.x, current_pos.y)
	var p5 = start_point
	layer.set_current_line(PackedVector2Array([p1, p2, p3, p4, p5]))

func cancel_action() -> void:
	if is_drawing:
		is_drawing = false
		var layer = canvas.get_active_layer()
		if layer:
			layer.cancel_line()
