extends RefCounted
class_name BaseTool

var canvas: CanvasManager

func _init(_canvas: CanvasManager) -> void:
	canvas = _canvas

func process_input(event: InputEvent) -> void:
	pass
