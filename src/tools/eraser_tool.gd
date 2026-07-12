extends BaseTool
class_name EraserTool

var is_dragging: bool = false
var mode: String = "stroke" # area | stroke

func _init(c: CanvasManager) -> void:
	super._init(c)
	mode = EventBus.current_eraser_mode
	EventBus.eraser_mode_changed.connect(_update_mode)

func _update_mode(new_mode: String) -> void:
	mode = new_mode
	if canvas and canvas.get_active_layer():
		canvas.get_active_layer().eraser_mode = mode
		canvas.get_active_layer().queue_redraw()

func activate() -> void:
	if canvas and canvas.get_active_layer():
		canvas.get_active_layer().show_eraser_cursor = true
		canvas.get_active_layer().eraser_mode = mode
		# Setear la pos inicial por si el mouse ya está dentro
		canvas.get_active_layer().eraser_cursor_pos = canvas.get_local_mouse_position()
		canvas.get_active_layer().queue_redraw()

func deactivate() -> void:
	is_dragging = false
	if canvas and canvas.get_active_layer():
		canvas.get_active_layer().show_eraser_cursor = false
		canvas.get_active_layer().queue_redraw()


func process_input(event: InputEvent) -> void:
	var l = canvas.get_active_layer()
	
	if event is InputEventMouseMotion:
		l.eraser_cursor_pos = event.position
		l.queue_redraw()
		
		if is_dragging:
			_perform_erase(event.position)
			
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				_perform_erase(event.position)
			else:
				is_dragging = false

func _perform_erase(pos: Vector2) -> void:
	var l = canvas.get_active_layer()
	if mode == "stroke":
		l.erase_stroke(pos)
	elif mode == "area":
		var poly = _create_circle_polygon(pos, l.eraser_radius)
		l.erase_area(poly)

func _create_circle_polygon(center: Vector2, radius: float, segments: int = 16) -> PackedVector2Array:
	var poly = PackedVector2Array()
	var step = TAU / segments
	for i in range(segments):
		var angle = i * step
		poly.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return poly
