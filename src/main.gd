extends Node

@onready var canvas_manager: CanvasManager = $CanvasManager
@onready var tool_manager: ToolManager = $ToolManager

func _ready() -> void:
	# Inicializar el gestor de herramientas pasándole el gestor del canvas
	tool_manager.setup(canvas_manager)
