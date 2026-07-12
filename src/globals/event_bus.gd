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

func emit_layers_changed(info: Array) -> void:
	layers_changed.emit(info)

func emit_active_layer_changed(index: int) -> void:
	active_layer_changed.emit(index)

func emit_tool_selected(tool_id: String) -> void:
	tool_selected.emit(tool_id)

func emit_tool_action_cancelled() -> void:
	tool_action_cancelled.emit()

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

func format_length(length_mm: float) -> String:
	match current_unit:
		"cm": return "%.1f cm" % (length_mm / 10.0)
		"m": return "%.2f m" % (length_mm / 1000.0)
		"in": return "%.2f in" % (length_mm / 25.4)
		_: return "%.1f mm" % length_mm

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "eraser_mode", current_eraser_mode)
	config.set_value("Settings", "language", current_language)
	config.set_value("Settings", "unit", current_unit)
	config.save(config_path)
signal clear_canvas_requested()

# --- Tool Signals ---
# (Se pueden agregar más señales si las herramientas necesitan notificar algo específico)
