extends BaseTool
class_name PerfectShapeTool

enum State { IDLE, PLACING }
var current_state: State = State.IDLE

var exact_w: float = 0.0
var exact_h: float = 0.0
var last_pos: Vector2 = Vector2.ZERO

func _init(c: CanvasManager) -> void:
	super(c)
	EventBus.perfect_dimensions_confirmed.connect(_on_dimensions_confirmed)
	EventBus.perfect_dimensions_cancelled.connect(_on_dimensions_cancelled)

func _on_dimensions_confirmed(w: float, h: float) -> void:
	exact_w = w
	exact_h = h
	current_state = State.PLACING
	_update_preview(last_pos)

func _on_dimensions_cancelled() -> void:
	current_state = State.IDLE
	var layer = canvas.get_active_layer()
	if layer:
		layer.set_current_line(PackedVector2Array())

func process_input(event: InputEvent) -> void:
	if current_state == State.IDLE:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			last_pos = event.position
		return

	var layer = canvas.get_active_layer()
	if not layer: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Estampar en el lienzo con clic
			_update_preview(event.position)
			layer.finish_line()
			current_state = State.IDLE
			
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		last_pos = event.position
		_update_preview(last_pos)

func _update_preview(center_pos: Vector2) -> void:
	if current_state != State.PLACING: return
	var layer = canvas.get_active_layer()
	if not layer: return
	
	layer.start_shape("rectangle")
	
	# Convertir mm a píxeles
	var w_px = exact_w * layer.pixels_per_mm
	var h_px = exact_h * layer.pixels_per_mm
	
	var p1 = center_pos + Vector2(-w_px/2, -h_px/2)
	var p2 = center_pos + Vector2(w_px/2, -h_px/2)
	var p3 = center_pos + Vector2(w_px/2, h_px/2)
	var p4 = center_pos + Vector2(-w_px/2, h_px/2)
	var p5 = p1
	
	layer.set_current_line(PackedVector2Array([p1, p2, p3, p4, p5]))
