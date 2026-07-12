extends Node

# Señales globales para la comunicación entre UI, Herramientas y Canvas

# --- UI Signals ---
signal tool_selected(tool_id: String)
signal tool_action_cancelled()
signal perfect_dimensions_confirmed(width: float, height: float)
signal perfect_dimensions_cancelled()
signal color_changed(new_color: Color)
signal eraser_mode_changed(mode_id: String)
signal layers_changed(layers_info: Array)
signal active_layer_changed(index: int)
signal camera_view_changed()
signal measures_visibility_changed(visible: bool)
signal undo_requested()
signal redo_requested()
signal history_changed(can_undo: bool, can_redo: bool)

var current_project_config: Dictionary = {
	"name": "Nuevo Proyecto",
	"paper_size": Vector2(816, 1056),
	"unit": "cm",
	"canvas_scale": 1.0
}

const PIXELS_PER_UNIT: float = 100.0

var show_measures: bool = true
var auto_measure: bool = true

func toggle_measures_visibility() -> void:
	show_measures = !show_measures
	measures_visibility_changed.emit(show_measures)

func emit_layers_changed(info: Array) -> void:
	layers_changed.emit(info)

func emit_active_layer_changed(index: int) -> void:
	active_layer_changed.emit(index)

func emit_tool_selected(tool_id: String) -> void:
	tool_selected.emit(tool_id)

func emit_tool_action_cancelled() -> void:
	tool_action_cancelled.emit()

var current_color: Color = Color.BLACK

func set_color(c: Color) -> void:
	current_color = c
	color_changed.emit(c)

var current_eraser_mode: String = "stroke"
var current_language: String = "en"
var current_unit: String = "mm"
var config_path: String = "user://settings.cfg"

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) == OK:
		current_eraser_mode = config.get_value("Settings", "eraser_mode", "stroke")
		current_language = config.get_value("Settings", "language", "en")
		current_unit = config.get_value("Settings", "unit", "mm")
	else:
		# Auto-detect language on first run
		var os_lang = OS.get_locale()
		if os_lang.begins_with("es"): current_language = "es"
		elif os_lang.begins_with("pt"): current_language = "pt"
		else: current_language = "en"
	
	TranslationServer.set_locale(current_language)

func set_language(lang: String) -> void:
	current_language = lang
	TranslationServer.set_locale(lang)
	_save_settings()

func set_eraser_mode(mode: String) -> void:
	current_eraser_mode = mode
	eraser_mode_changed.emit(mode)
	_save_settings()

signal unit_changed(unit: String)

func set_unit(unit: String) -> void:
	current_unit = unit
	unit_changed.emit(unit)
	_save_settings()

func get_unit_factor(u: String) -> float:
	match u:
		"m": return 1.0
		"cm": return 0.01
		"mm": return 0.001
		"in": return 0.0254
		_: return 1.0

func format_length(length_px: float) -> String:
	var base_val = length_px / PIXELS_PER_UNIT
	var base_u = current_project_config.get("unit", "cm")
	
	var val_in_meters = base_val * get_unit_factor(base_u)
	var final_val = val_in_meters / get_unit_factor(current_unit)
	
	match current_unit:
		"mm": return "%.1f mm" % final_val
		"cm": return "%.1f cm" % final_val
		"m": return "%.2f m" % final_val
		"in": return "%.2f in" % final_val
		_: return "%.2f" % final_val

func parse_input_to_px(val: float) -> float:
	var val_in_meters = val * get_unit_factor(current_unit)
	var base_u = current_project_config.get("unit", "cm")
	var val_in_base = val_in_meters / get_unit_factor(base_u)
	
	return val_in_base * PIXELS_PER_UNIT

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "eraser_mode", current_eraser_mode)
	config.set_value("Settings", "language", current_language)
	config.set_value("Settings", "unit", current_unit)
	config.save(config_path)
signal clear_canvas_requested()

# --- Tool Signals ---
# (Se pueden agregar más señales si las herramientas necesitan notificar algo específico)
