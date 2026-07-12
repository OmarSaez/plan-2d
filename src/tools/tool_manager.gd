extends Node
class_name ToolManager

var current_tool: BaseTool
var canvas_manager: CanvasManager

func setup(_canvas_manager: CanvasManager) -> void:
	canvas_manager = _canvas_manager
	# Iniciar con Lápiz por defecto
	current_tool = PenTool.new(canvas_manager)
	EventBus.tool_selected.connect(_on_tool_selected)
	EventBus.tool_action_cancelled.connect(_on_tool_action_cancelled)

func _on_tool_action_cancelled() -> void:
	if current_tool:
		current_tool.cancel_action()

func _on_tool_selected(tool_id: String) -> void:
	if tool_id == "pen":
		current_tool = PenTool.new(canvas_manager)
	elif tool_id == "ruler":
		current_tool = RulerTool.new(canvas_manager)
	elif tool_id == "rectangle":
		current_tool = RectangleTool.new(canvas_manager)
	elif tool_id == "perfect":
		current_tool = PerfectShapeTool.new(canvas_manager)
	elif tool_id == "label":
		current_tool = LabelTool.new(canvas_manager)
	elif tool_id == "eraser":
		current_tool = EraserTool.new(canvas_manager)

func process_canvas_input(event: InputEvent) -> void:
	if current_tool:
		current_tool.process_input(event)
