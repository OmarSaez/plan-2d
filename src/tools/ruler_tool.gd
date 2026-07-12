extends BaseTool
class_name RulerTool

var is_drawing: bool = false
var start_point: Vector2 = Vector2.ZERO

func process_input(event: InputEvent) -> void:
	var layer = canvas.get_active_layer()
	if not layer: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_drawing = true
			start_point = event.position
			layer.start_shape("ruler")
			# Crea una línea de 2 puntos: inicio y actual
			layer.set_current_line(PackedVector2Array([start_point, event.position]))
		else:
			is_drawing = false
			layer.finish_line()
			
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_drawing:
			layer.set_current_line(PackedVector2Array([start_point, event.position]))

func cancel_action() -> void:
	if is_drawing:
		is_drawing = false
		var layer = canvas.get_active_layer()
		if layer:
			layer.cancel_line()
