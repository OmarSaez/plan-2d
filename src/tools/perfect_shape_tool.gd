extends BaseTool
class_name PerfectShapeTool

func _init(c: CanvasManager) -> void:
	super(c)
	EventBus.perfect_dimensions_confirmed.connect(_on_dimensions_confirmed)
	EventBus.perfect_dimensions_cancelled.connect(_on_dimensions_cancelled)

func _on_dimensions_confirmed(w: float, h: float) -> void:
	var layer = canvas.get_active_layer()
	if not layer: return
	
	# Encontrar el centro de la pantalla en coordenadas locales de la hoja
	var cam = canvas.get_viewport().get_camera_2d()
	var center_pos = Vector2.ZERO
	if cam:
		center_pos = cam.get_screen_center_position()
		center_pos = layer.get_global_transform().affine_inverse() * center_pos
		
	layer.start_shape("perfect")
	
	var p1 = center_pos + Vector2(-w/2, -h/2)
	var p2 = center_pos + Vector2(w/2, -h/2)
	var p3 = center_pos + Vector2(w/2, h/2)
	var p4 = center_pos + Vector2(-w/2, h/2)
	
	layer.set_current_line(PackedVector2Array([p1, p2, p3, p4, p1]))
	layer.finish_line()
	
	# Seleccionar las 4 líneas recién creadas
	layer.selected_indices.clear()
	var total_lines = layer.lines.size()
	if total_lines >= 4:
		for i in range(total_lines - 4, total_lines):
			layer.selected_indices.append(i)
			
	layer.queue_redraw()
	
	# Cambiar automáticamente a la herramienta Selector para que el usuario pueda moverlo
	EventBus.tool_selected.emit("label")

func _on_dimensions_cancelled() -> void:
	pass

func cancel_action() -> void:
	pass

func process_input(event: InputEvent) -> void:
	pass
