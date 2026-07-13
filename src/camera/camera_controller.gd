extends Camera2D
class_name CameraController

@onready var info_label: Label = $"../../UILayer/CameraInfo"

var touches: Dictionary = {}

var start_distance: float
var start_angle: float
var start_zoom: Vector2
var start_rot: float
var gesture_world_point: Vector2

var zoom_min: float = 0.1
var zoom_max: float = 5.0

func _ready() -> void:
	ignore_rotation = false
	update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 2:
				_start_gesture()
				get_viewport().set_input_as_handled()
				EventBus.emit_tool_action_cancelled()
		else:
			touches.erase(event.index)
			
	elif event is InputEventScreenDrag:
		if touches.has(event.index):
			touches[event.index] = event.position
			if touches.size() == 2:
				_process_gesture()
				get_viewport().set_input_as_handled()
				
	# PC controls
	elif event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					rotation_degrees -= 5
				else:
					_zoom_at_point(1.1, event.position)
				update_hud()
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					rotation_degrees += 5
				else:
					_zoom_at_point(1.0 / 1.1, event.position)
				update_hud()
				get_viewport().set_input_as_handled()
				
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			position -= event.relative.rotated(rotation) / zoom.x # Paneo
			update_hud()
			get_viewport().set_input_as_handled()

func _start_gesture() -> void:
	var keys = touches.keys()
	var p1 = touches[keys[0]]
	var p2 = touches[keys[1]]
	var midpoint = (p1 + p2) / 2.0
	
	start_distance = p1.distance_to(p2)
	start_angle = p1.angle_to_point(p2)
	start_zoom = zoom
	start_rot = rotation
	
	gesture_world_point = get_canvas_transform().affine_inverse() * midpoint

func _process_gesture() -> void:
	var keys = touches.keys()
	var p1 = touches[keys[0]]
	var p2 = touches[keys[1]]
	var midpoint = (p1 + p2) / 2.0
	
	var current_distance = p1.distance_to(p2)
	var current_angle = p1.angle_to_point(p2)
	
	if start_distance > 0:
		var new_zoom = clamp(start_zoom.x * (current_distance / start_distance), zoom_min, zoom_max)
		zoom = Vector2(new_zoom, new_zoom)
		
	rotation = start_rot - (current_angle - start_angle)
	
	force_update_scroll()
	
	var current_screen_pos = get_canvas_transform() * gesture_world_point
	var diff_screen = midpoint - current_screen_pos
	position -= diff_screen.rotated(rotation) / zoom.x
	
	update_hud()

func _zoom_at_point(factor: float, screen_pos: Vector2) -> void:
	var old_zoom = zoom
	var new_zoom = clamp(zoom.x * factor, zoom_min, zoom_max)
	if old_zoom.x == new_zoom: return
	
	var world_pos = get_canvas_transform().affine_inverse() * screen_pos
	zoom = Vector2(new_zoom, new_zoom)
	
	force_update_scroll()
	
	var new_screen_pos = get_canvas_transform() * world_pos
	var screen_delta = screen_pos - new_screen_pos
	position -= screen_delta.rotated(rotation) / zoom.x

func update_hud() -> void:
	EventBus.camera_view_changed.emit()
	if info_label:
		info_label.text = "Zoom: %d%%  |  Rot: %d°  |  Pos: X %d, Y %d" % [
			int(zoom.x * 100),
			int(rad_to_deg(rotation)) % 360,
			int(position.x),
			int(position.y)
		]
