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
signal autosave_interval_changed(minutes: int)
signal manual_save_requested()

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
var current_autosave_interval: int = 3
var config_path: String = "user://settings.cfg"

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load(config_path) == OK:
		current_eraser_mode = config.get_value("Settings", "eraser_mode", "stroke")
		current_language = config.get_value("Settings", "language", "en")
		current_unit = config.get_value("Settings", "unit", "mm")
		current_autosave_interval = config.get_value("Settings", "autosave_interval", 3)
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

func format_number_locale(val: float, decimals: int) -> String:
	var s = ("%." + str(decimals) + "f") % val
	var parts = s.split(".")
	var int_part = parts[0]
	var dec_part = ""
	if parts.size() > 1:
		dec_part = parts[1]
	
	var res = ""
	var count = 0
	for i in range(int_part.length() - 1, -1, -1):
		res = int_part[i] + res
		count += 1
		if count == 3 and i > 0 and int_part[i-1] != "-":
			res = "," + res
			count = 0
			
	var final_str = res
	
	if current_language == "es" or current_language == "pt":
		final_str = final_str.replace(",", ".")
		if dec_part != "":
			final_str += "," + dec_part
	else:
		if dec_part != "":
			final_str += "." + dec_part
			
	return final_str

func format_length(length_px: float) -> String:
	var base_val = length_px / PIXELS_PER_UNIT
	var base_u = current_project_config.get("unit", "cm")
	
	var val_in_meters = base_val * get_unit_factor(base_u)
	var final_val = val_in_meters / get_unit_factor(current_unit)
	
	match current_unit:
		"mm": return "%s mm" % format_number_locale(final_val, 1)
		"cm": return "%s cm" % format_number_locale(final_val, 1)
		"m": return "%s m" % format_number_locale(final_val, 2)
		"in": return "%s in" % format_number_locale(final_val, 2)
		_: return "%s" % format_number_locale(final_val, 2)

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
	config.set_value("Settings", "autosave_interval", current_autosave_interval)
	config.save(config_path)

func set_autosave_interval(minutes: int) -> void:
	current_autosave_interval = minutes
	autosave_interval_changed.emit(minutes)
	_save_settings()
signal clear_canvas_requested()

# --- Tool Signals ---
# (Se pueden agregar más señales si las herramientas necesitan notificar algo específico)

# --- Project Management ---
func generate_uuid() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

func get_all_projects() -> Array:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("projects"):
		dir.make_dir("projects")
		
	var projects = []
	dir = DirAccess.open("user://projects")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".res"):
				var data = load_project(file_name.replace(".res", ""))
				if data:
					projects.append(data)
			file_name = dir.get_next()
			
	# Ordenar por timestamp descendente (más reciente primero)
	projects.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
	return projects

func save_project(canvas_state: Dictionary) -> void:
	if not current_project_config.has("id") or current_project_config["id"] == "":
		current_project_config["id"] = generate_uuid()
		
	current_project_config["timestamp"] = Time.get_unix_time_from_system()
	
	var project_data = {
		"config": current_project_config,
		"state": canvas_state,
		"timestamp": current_project_config["timestamp"]
	}
	
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("projects"):
		dir.make_dir("projects")
		
	var path = "user://projects/" + current_project_config["id"] + ".res"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(project_data, true) # full_objects = true
		file.close()

func load_project(id: String) -> Dictionary:
	var path = "user://projects/" + id + ".res"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var data = file.get_var(true)
			file.close()
			if data is Dictionary:
				return data
	return {}

func delete_project(id: String) -> void:
	var path = "user://projects/" + id + ".res"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
