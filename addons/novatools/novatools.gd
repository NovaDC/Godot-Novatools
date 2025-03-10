@tool
@icon("./icon.svg")
extends Object
class_name NovaTools

## NovaTools
##
## A collection of common static tool functions used in several plugins,
## not a class that should be instantiated.

## The command line flag used with godot when wanting
## to strip the header message from stdout output.
const GODOT_NO_HEADER_FLAG := "--no-header"
## The command line flag used with godot when wanting
## to specify the location of the log file.
const GODOT_LOG_FILE_FLAG := "--log-file"
## The [EditorSettings] name of the setting for this system's python's executable prefix.
const PYTHON_PREFIX_EDITOR_SETTINGS_PATH := "filesystem/tools/python/python_prefix"
## The default python's executable prefix for this system.
const PYTHON_PREFIX_DEFAULT := "python"
## The flag used with python when launching a installed module in the command line.
const PYTHON_MODULE_FLAG := "-m"
## The name of the godot editor icons theme type.
const EDITOR_ICONS_THEME_TYPE := "EditorIcons"

## A QOL function that popups a file dialog in the editor and runs a given callable
## when a file is confirmed.
static func quick_editor_file_dialog(when_confirmed:Callable,
									 title:String,
									 filters:=PackedStringArray(),
									 start_path:String = "res://",
									 file_mode := EditorFileDialog.FILE_MODE_SAVE_FILE,
									 access := EditorFileDialog.ACCESS_FILESYSTEM
									) -> String:
	var result := ""
	var confirmed := false
	
	var fileselect := EditorFileDialog.new()
	fileselect.visible = false
	fileselect.current_dir = start_path
	fileselect.access = access
	fileselect.dialog_hide_on_ok = true
	fileselect.file_mode = file_mode
	fileselect.title = title
	fileselect.set_filters(filters)
	fileselect.confirmed.connect(func (): await when_confirmed.call(fileselect.current_dir))
	EditorInterface.popup_dialog_centered(fileselect)
	await fileselect.visibility_changed
	fileselect.queue_free()
	
	return result

## Popups a simple popup in front of the editor screen, blocking any editor input,
## with a given bbcode formatted [param message]
## while [code]await[/code]ing for a given [param function] to return.
## This function returns the value that [param function] returns.
static func show_wait_window_while_async(message:String,
										 function:Callable,
										 min_size := Vector2i.ONE * 100
										) -> Variant:
	#HOW IS THIS NOT AN EXPOSED FEATURE GODSOT ProgressDialog IS RIGHT THERE
	var lab := RichTextLabel.new()
	lab.text = message
	lab.bbcode_enabled = true
	lab.custom_minimum_size = min_size
	
	var wind := PopupPanel.new()
	wind.exclusive = true
	wind.transient = true
	wind.add_child(lab)
	wind.popup_hide.connect(func(): wind.visible = true)
	
	EditorInterface.popup_dialog_centered(wind, min_size)
	
	var ret = await function.call()
	
	wind.visible = false
	wind.queue_free()
	
	return ret

## Runs a command in the system's terminal asynchronously,
## waiting for it to finish and returning it's exit code.
static func launch_external_command_async(command:String, args := [], stay_open := true) -> int:
	var new_args:Array = []
	if OS.get_name() == "Windows":
		new_args = ["/k" if stay_open else "/c", command] + args
		command = "cmd.exe"
	elif OS.get_name() == "Linux" or OS.get_name().ends_with("BSD"):
		new_args = ["-hold"] if stay_open else [] + ["-e", command] + args
		command = "xterm"
	elif OS.get_name() == "MacOS" or OS.get_name() == "Darwin":
		push_warning("BE AWARE: This is not properly tested on\
					  MacOS/Darwin platforms! The commands may not run during export!")
		new_args = ['-n', 'Terminal.app', command]
		new_args += (['--args'] if args.size() > 0 else [])
		new_args += args
		command = 'open'
	else:
		assert(false)
	
	print("Running command: %s with args %s"%[command, new_args])
	
	var pid := OS.create_process(command, new_args, true)
	
	while OS.is_process_running(pid):
		await Engine.get_main_loop().process_frame
	
	return OS.get_process_exit_code(pid)

## Launches another instance fo the godot editor in the system's default terminal.
static func launch_editor_instance_async(args := [],
										 log_file_path :=  "",
										 stay_open := true
										) -> Error:
	if log_file_path != "" and GODOT_LOG_FILE_FLAG not in args:
		args = [GODOT_LOG_FILE_FLAG, log_file_path] + args
	if GODOT_NO_HEADER_FLAG not in args:
		args = [GODOT_NO_HEADER_FLAG] + args
	var ret_code := await launch_external_command_async(OS.get_executable_path(), args, stay_open)
	return OK if ret_code == 0 else FAILED

## Safely initialises a setting in the [EditorSettings] if it is not already made.
## If [param type] is set to [constant Variant.Type.TYPE_NIL],
## the type of the setting will be assumed form the [param default] value.
static func try_init_editor_setting_path(path:String,
										 default:Variant = null,
										 type := TYPE_NIL,
										 hint := PROPERTY_HINT_NONE,
										 hint_string := ""
										):
	var editor_settings := EditorInterface.get_editor_settings()
	if not editor_settings.has_setting(path):
		editor_settings.set_setting(path, default)
	
		editor_settings.set_initial_value(path, default, true)
		var prop_info = {
			"name" : path,
			"type" : type if type != TYPE_NIL else typeof(default),
		}
		if hint != PROPERTY_HINT_NONE:
			prop_info["hint"] = hint
			if hint_string != "":
				prop_info["hint_string"] = hint_string
		editor_settings.add_property_info(prop_info)

## Gets the set value form the given editor setting, returning [param default] if it is not set.
static func get_editor_setting_default(path:String, default:Variant = null) -> Variant:
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(path):
		return editor_settings.get_setting(path)
	return default

## Safely removes a given editor setting if it is existant and unchanged from it's default value.
static func remove_unused_editor_setting_path(path:String, default:Variant):
	var editor_settings := EditorInterface.get_editor_settings()
	if editor_settings.has_setting(path) and editor_settings.get(path) == default:
		editor_settings.erase(path)

## Initialises the python prefix editor setting if it is not already initialised.
static func try_init_python_prefix_editor_setting():
	try_init_editor_setting_path(PYTHON_PREFIX_EDITOR_SETTINGS_PATH,
								 PYTHON_PREFIX_DEFAULT,
								 TYPE_STRING,
								 PROPERTY_HINT_GLOBAL_FILE
								)

## Deinitializes the python prefix editor setting if it's unchanged from the default.
static func try_deinit_python_prefix_editor_setting():
	remove_unused_editor_setting_path(PYTHON_PREFIX_EDITOR_SETTINGS_PATH,
									  PYTHON_PREFIX_DEFAULT
									 )


## Launches a python script/file in a seprate terminal window asynchronously.
## Returns the exit code of the script.[br]
## Use [method launch_python_module_async] to run a installed python module on the system.
static func launch_python_file_async(file:String,
									 args := [],
									 python_prefix := "",
									 stay_open := true
									) -> int:
	if python_prefix == "":
		python_prefix = get_editor_setting_default(PYTHON_PREFIX_EDITOR_SETTINGS_PATH,
												   PYTHON_PREFIX_DEFAULT
												  )
	return await launch_external_command_async(python_prefix, [file] + args, stay_open)

## Launches a installed python module on the system in a seprate terminal window asynchronously.
## Returns the exit code of the module.[br]
## Use [method launch_python_file_async] to run a python script/file instead.
static func launch_python_module_async(module_name:String,
									   args := [],
									   python_prefix := "",
									   stay_open := true
									  ) -> int:
	if python_prefix == "":
		python_prefix = get_editor_setting_default(PYTHON_PREFIX_EDITOR_SETTINGS_PATH,
												   PYTHON_PREFIX_DEFAULT
												  )
	return await launch_external_command_async(python_prefix,
											   [PYTHON_MODULE_FLAG, module_name] + args,
											   stay_open
											  )

## Downloads a file located at a specific http [param host]'s [param path]
## [param to_path] located on this system.[br]
## When set, the headers of the request will be set to [param headers].[br]
## When set to a non-negative value, the port of the request will be set to [param port].
## When set to a negative value, the port will be determined from the [param host]'s scheme
## (the "[code]http[/code]" or "[code]https[/code]" prefix).[br]
## NOTE: Depending on the size of data begin downloaded,
## this function can freeze the editor for some time if it is used in a blocking way.
## It is highly suggested to use a means of allowing for the editor to pause while downloading,
## such as by using [method show_wait_window_while_async].
static func download_http_async(to_path:String,
								host:String,
								path := "/",
								headers := PackedStringArray(["User-Agent: Godotcgen/1.0 (Godot)"]),
								port:int = -1
							   ) -> Error:
	print("Downloading: %s%s to %s"%[host, path, to_path])
	
	var http_client := HTTPClient.new()

	if host.is_empty():
		return ERR_INVALID_PARAMETER

	var err := http_client.connect_to_host(host, port)
	if err != OK:
		return err

	while http_client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		http_client.poll()
		await Engine.get_main_loop().process_frame

	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		return ERR_CONNECTION_ERROR

	err = http_client.request(HTTPClient.METHOD_GET, path, headers)
	if err != OK:
		return err

	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await Engine.get_main_loop().process_frame

	if not http_client.get_status() in [HTTPClient.STATUS_BODY, HTTPClient.STATUS_CONNECTED]:
		return ERR_CONNECTION_ERROR

	if not http_client.has_response():
		return ERR_CONNECTION_ERROR

	if not http_client.is_response_chunked() and http_client.get_response_body_length() < 0:
		return ERR_CONNECTION_ERROR

	var file := FileAccess.open(to_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	while http_client.get_status() == HTTPClient.STATUS_BODY:
		var data := http_client.read_response_body_chunk()
		
		file.store_buffer(data)
		
		err = http_client.poll()
		if err != OK:
			return err
		
		await Engine.get_main_loop().process_frame

	http_client.close()
	file.close()
	
	print("Download complete!")
	return OK

## Decompresses the [code]zip[/code] file located at [param file_path] [param to_path].[br]
## If [param whitelist_starts] is not empty, only file paths that zip relitive location
## starts with any of the given strings will be decompressed.
static func decompress_zip_async(file_path:String,
								 to_path:String,
								 whitelist_starts:Array[String] = []
								) -> Error:
	print("Decompressing %s to %s" % [file_path, to_path])
	
	var reader := ZIPReader.new()
	var err := reader.open(file_path)
	if err != OK:
		return err
	
	for internal_path in reader.get_files():
		if (not whitelist_starts.is_empty() and
			not whitelist_starts.any(func (start:String): return internal_path.begins_with(start))):
			continue
		
		if internal_path.ends_with("/"):
			err = DirAccess.make_dir_recursive_absolute((to_path.rstrip("/") + "/" + internal_path))
			if err != OK:
				return err
		else:
			var file := FileAccess.open(to_path.rstrip("/") + "/" + internal_path, FileAccess.WRITE)
			if file == null:
				return FileAccess.get_open_error()
			file.store_buffer(reader.read_file(internal_path))
			file.close()
		
		await Engine.get_main_loop().process_frame
	
	err = reader.close()
	if err != OK:
		return err
	
	print("Decompress successful!")
	
	return OK

## Compresses the files located at [param source_path] to a [code]zip[/code] file located
## at [param to_file].[br]
## If [param whitelist_starts] is not empty, only file paths that location relitive
## to the [param source_path] starts with nay of the given strings will be compressed.
static func compress_zip_async(source_path:String,
							   to_file:String,
							   whitelist_starts:Array[String] = []
							  ) -> Error:
	var packer := ZIPPacker.new()
	var err := packer.open(to_file, ZIPPacker.APPEND_CREATE)
	if err != OK:
		return err
	
	for file_path in get_children_files_recursive(source_path):
		if (not whitelist_starts.is_empty() and
			not whitelist_starts.any(func (start:String): return file_path.begins_with(start))
		   ):
			continue
		
		assert(file_path.begins_with(source_path))
		var internal_path = file_path.substr(file_path.length()).lstrip("/").rstrip("/")
		
		var data := FileAccess.get_file_as_bytes(file_path)
		if data.is_empty():
			return FileAccess.get_open_error()
		
		await Engine.get_main_loop().process_frame
		
		err = packer.start_file(internal_path)
		if err != OK:
			return err
		
		err = packer.write_file(data)
		if err != OK:
			return err
		
		err = packer.close_file()
		if err != OK:
			return err
		
		await Engine.get_main_loop().process_frame
	
	err = packer.close()
	if err != OK:
		return err
	
	return OK

## Ensures a given path exists, without throwing errors if the directory already exists.
static func ensure_absolute_dir_exists(path:String) -> Error:
	if not DirAccess.dir_exists_absolute(path):
		return DirAccess.make_dir_recursive_absolute(path)
	return OK

## Returns the absolute paths to all directories located under the given [param from_path].[br]
## When [param only_with_files] is true, only directories that contain any files will be returned.
## NOTE: this will not count any directories contained in that directory as a file.
## Though those child directories will still be searched to find any further
## grandchildren directories that may have files regardless of weather
## or not they also contained files.
static func get_children_dir_recursive(from_path:String,
									   only_with_files := false
									  ) -> PackedStringArray:
	from_path = ProjectSettings.globalize_path(from_path)
	var found := PackedStringArray()
	for dir in DirAccess.get_directories_at(from_path):
		dir = from_path + "/" + dir
		if not only_with_files or not DirAccess.get_files_at(dir).is_empty():
			found.append(dir)
		found.append_array(get_children_dir_recursive(dir, only_with_files))
	return found

## Returns the absolute paths to all files located under the given [param from_path].
static func get_children_files_recursive(from_path:String) -> PackedStringArray:
	var found := DirAccess.get_files_at(from_path)
	for dir in DirAccess.get_directories_at(from_path):
		found.append_array(get_children_files_recursive(from_path + "/" + dir))
	return found

## Generates a [code]version.py[/code] file for this
## specific version of godot to the given [param to_path].
static func generate_version_py(to_path:String) -> Error:
	assert(Engine.is_editor_hint())
	
	var ver_file := FileAccess.open(to_path.rstrip("/") + "/" + "version.py", FileAccess.WRITE)
	
	if ver_file == null:
		return FileAccess.get_open_error()
	
	var is_latest:bool = Engine.get_version_info()["status"] == "dev"
	
	ver_file.store_line('website="https://godotengine.org"')
	ver_file.store_line('name="Godot Engine"')
	ver_file.store_line('short_name="godot"')
	ver_file.store_line('module_config=""')
	ver_file.store_line('docs="%s"#Autogenerated"' % ["latest" if is_latest else "stable"])
	for key in Engine.get_version_info().keys():
		var value = Engine.get_version_info()[key]
		if value is String:
			value = '"' + value + '"'
		ver_file.store_line("%s=%s#Autogenerated" % [key, value])
	
	ver_file.close()

	return OK

## Coppies all files and directories from [param from_path] to [param to_path].
## All paths set in [param ignore_folders] will be skipped when copying.[br]
## NOTE: Depending on the size of data begin moved,
## this function can freeze the editor for some time.
static func copy_recursive(from_path:String,
						   to_path:String,
						   ignore_folders:=PackedStringArray()
						  ) -> Error:
	from_path = from_path.rstrip("/")
	to_path = to_path.rstrip("/")
	
	if from_path.begins_with("res:") or from_path.begins_with("user:"):
		if from_path in ["res:", "user:"]:
			from_path += "//"
		from_path = ProjectSettings.globalize_path(from_path)
	
	if to_path.begins_with("res:") or to_path.begins_with("user:"):
		if to_path in ["res:", "user:"]:
			to_path += "//"
		to_path = ProjectSettings.globalize_path(to_path)
	
	if to_path in ignore_folders:
		return OK
	
	ignore_folders = ignore_folders.duplicate()
	ignore_folders.append(to_path.rstrip("/"))
	
	if not DirAccess.dir_exists_absolute(to_path):
		var err := DirAccess.make_dir_recursive_absolute(to_path)
		if err != OK:
			return err
	
	for file in DirAccess.get_files_at(from_path):
		file = file.lstrip("/")
		var from_file := (from_path.rstrip("/") + "/" + file).rstrip("/")
		var to_file := (to_path.rstrip("/") + "/" + file).rstrip("/")
		var err := DirAccess.copy_absolute(from_file, to_file)
		if err != OK:
			return err
	
	for dir in DirAccess.get_directories_at(from_path):
		dir = dir.lstrip("/").rstrip("/")
		var from_dir := (from_path.rstrip("/") + "/" + dir).rstrip("/")
		var to_dir := (to_path.rstrip("/") + "/" + dir).rstrip("/")
		
		if (from_dir != to_dir and
			Array(ignore_folders).all(func (p:String): return not from_dir.begins_with(p))
		   ):
			var err := copy_recursive(from_dir, to_dir, ignore_folders)
			if err != OK:
				return err
		ignore_folders.append(to_dir)

	return OK

## Fetches a icon form the editor's theme
static func get_editor_icon_named(name:String, manual_size:=Vector2i.ONE) -> Texture2D:
	assert(Engine.is_editor_hint())
	
	var theme := EditorInterface.get_editor_theme()
	if theme == null:
		theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = ThemeDB.get_default_theme()
	assert(theme != null)
	
	assert(theme.has_icon(name, EDITOR_ICONS_THEME_TYPE))
	
	var texture := theme.get_icon(name, EDITOR_ICONS_THEME_TYPE)
	
	if manual_size != texture.get_image().get_size():
		texture = texture.duplicate()
		texture.set_size_override(manual_size)
	
	return texture

## Attempts to call a method on the editor's version controll system, as exposed as virtual methods
## in [EditorVCSInterface].[br]
## This expects for the editor VCS interface to be initialised already.
static func callv_vcs_method(name:StringName, args:Array = []) -> Variant:
	var singleton_name:String = ProjectSettings.get_setting("editor/version_control/plugin_name")
	assert(Engine.has_singleton(singleton_name))
	var singleton := Engine.get_singleton(singleton_name)
	if not singleton.has_method(name) and singleton.has_method("_" + name):
		name = "_" + name
	return singleton.callv(name, args)

## Guesses weather or not the VCS interface has been enabled in the editor.
static func vcs_active() -> bool:
	return (ProjectSettings.get_setting("editor/version_control/autoload_on_startup") and
			Engine.has_singleton(ProjectSettings.get_setting("editor/version_control/plugin_name"))
		   )

## Trys to call the method on the editor's interface if it's most likely active, otherwise returning
## the [param default]. Note this will still assert that the vsc class has the method
## with the name if it is active.
static func try_callv_vcs_method(name:StringName,
								 args:Array = [],
								 default:Variant = null
								) -> Variant:
	if vcs_active():
		return callv_vcs_method(name, args)
	return default

## Checks if any file are chenaged as according to the vcs, always returning [code]false[/code]
## if the vcs is not enabled.
static func vcs_is_something_changed() -> bool:
	return vcs_active() and callv_vcs_method("get_modified_files_data", []).size() > 0

## Gets a dict containing information on a given [param path_or_name] of a script.[br]
## This may return a empty dict if no or more than one script is found where
## [param path_or_name] is the path or name of the script.[br]
## The returned [Dictionary]'s format will always match that of
## [method ProjectSettings.get_global_class_list],
## unless the returned [Dictionary] is empty.
static func get_global_script_info(path_or_name) -> Dictionary:
	if path_or_name is StringName:
		path_or_name = String(path_or_name)
	var filter := func(d): return (d["class"] == path_or_name or d["path"] == path_or_name)
	var found := ProjectSettings.get_global_class_list().filter(filter)
	if found.size() == 1: #non ambiguous
		return found[0]
	return {}

## Gets the class name of the given [param path_name_or_script].[br]
## If [param path_name_or_script] is a [Script],
## it will always return the [method Script.get_global_name].
## If [param path_name_or_script] is a [String], it will be treated as a
## potential class name or math to a script.
## It will return [param path_name_or_script] unchanged if [param path_name_or_script]
## is a name of a class in the [ClassDB], or the name of a global script if a [b]single[/b] script
## with that name or path can be found.[br]
static func class_name_normalize(path_name_or_script) -> String:
	if path_name_or_script is Script:
		return path_name_or_script.get_global_name()
	if ClassDB.class_exists(path_name_or_script):
		return path_name_or_script
	return get_global_script_info(path_name_or_script).get("class", "")

## Gets the path to a given [param path_name_or_script].[br]
## If [param path_name_or_script] is a [Script],
## it will always return [member Script.resource_path], even if it's empty.[br]
## Otherwise, [param path_name_or_script] will be treated as a
## potential name or path to a script and if a [b]single[/b] [Script] is found,
## it's path will be returened.[br]
static func script_path_normalize(path_name_or_script) -> String:
	if path_name_or_script is Script:
		return path_name_or_script.resource_path
	return get_global_script_info(path_name_or_script).get("path", "")

## Returns the name of base class of the [param path_name_or_script].
## If none are found, return [param default].
static func get_class_base(path_name_or_script) -> String:
	if path_name_or_script is Script:
		return path_name_or_script.get_instance_base_type()
	if ClassDB.class_exists(path_name_or_script):
		return ClassDB.get_parent_class(path_name_or_script)
	return get_global_script_info(path_name_or_script).get("base", "")

## Returns the icon for the given [param path_or_name] of a class.[br]
## NOTE: This currently cannot retrieve the icons of builtin classes.
static func get_class_icon_path(path_or_name:String) -> String:
	#no way to get builtin icons for scripts, huh...
	return get_global_script_info(path_or_name).get("icon", "")

## Instantiate the given [param path_name_script_or_scene]
## (resource path, class name, script object, or packed scene object).
## If [param path_name_script_or_scene] is the name of a class in the
## [ClassDB], that will always take precedent.[br]
## Will default to returning [code]null[/code] when things can't be found.
static func instantiate_this(path_name_script_or_scene) -> Object:
	if path_name_script_or_scene is String or path_name_script_or_scene is StringName:
		if (ClassDB.class_exists(path_name_script_or_scene) and
			ClassDB.is_class_enabled(path_name_script_or_scene) and
			ClassDB.can_instantiate(path_name_script_or_scene)
		   ):
			return ClassDB.instantiate(path_name_script_or_scene)
		
		var script_path = script_path_normalize(path_name_script_or_scene)
		if not script_path.is_empty() and ResourceLoader.exists(script_path, "Script"):
			var loaded := load(script_path)
			if loaded != null and loaded.can_instantiate():
				path_name_script_or_scene = loaded
		elif ResourceLoader.exists(path_name_script_or_scene, "PackedScene"):
			var loaded := load(path_name_script_or_scene)
			if loaded != null and loaded.can_instantiate():
				path_name_script_or_scene = loaded
	
	if path_name_script_or_scene is Script:
		return path_name_script_or_scene.new()
	
	if path_name_script_or_scene is PackedScene:
		return path_name_script_or_scene.instantiate()

	return null

## Get the classes that inherit the [param name_or_path]
## of a class, including classes defined in currently loaded [Scripts].[br]
## This list will not include the base [param name_or_path].[br]
## This function allows for either (or both) [param include_script_paths]
## or [param include_script_class_names].
## If both are included, this lis may contain the class name and the path
## of the same script simutaniously.
static func get_classes_inheriting(name_or_path:String,
								   include_script_paths := false,
								   include_script_class_names := true
								  ) -> PackedStringArray:
	assert(include_script_class_names or include_script_paths,
		   "You have to include at least one of the names or paths..."
		  )
	var path := script_path_normalize(name_or_path)
	var name := class_name_normalize(name_or_path)
	var found := ClassDB.get_inheriters_from_class(name_or_path)
	found.append(path)
	found.append(name)
	var added:int = found.size()
	# We need to do this recursively,
	# and we have not controll over order,
	# so monitor the amount of things found and stop once no more can be added
	while added > 0:
		added = 0
		for d in ProjectSettings.get_global_class_list():
			if d["base"] in found:
				if (include_script_paths and
					d.has("path") and
					d["path"] not in found
					and not d.get("path", "").is_empty()
				   ):
					found.append(d["path"])
					added += 1
				if (include_script_class_names and
					d.has("class") and
					d["class"] not in found and
					not d.get("class", "").is_empty()
				   ):
					found.append(d["class"])
					added += 1
	while found.find(name) > -1:
		found.remove_at(found.find(name))
	while found.find(path) > -1:
		found.remove_at(found.find(path))
	return found

## Gets the class name or path of the object,
## giving priority to the class names of any attached scripts
static func get_class_name(object:Object) -> String:
	var script:Script= object.get_script()
	if script != null:
		var script_name := script.get_global_name()
		if not script_name.is_empty():
			return script_name
	return object.get_class()

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_right]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_right] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_neighbor_right].
static func focus_chain_right(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrap(i+1, 0, controls.size())
		controls[i].focus_neighbor_right = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_left]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_left] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_neighbor_left].
static func focus_chain_left(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrap(i+1, 0, controls.size())
		controls[i].focus_neighbor_left = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_top]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_top] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_neighbor_top].
static func focus_chain_top(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrap(i+1, 0, controls.size())
		controls[i].focus_neighbor_top = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_bottom]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_bottom] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_neighbor_bottom].
static func focus_chain_bottom(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrap(i+1, 0, controls.size())
		controls[i].focus_neighbor_bottom = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_next]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_next] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_next].
static func focus_chain_next(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrap(i+1, 0, controls.size())
		controls[i].focus_next = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_bottom],
## [member Control.focus_neighbor_top], [member Control.focus_neighbor_left],
## [member Control.focus_neighbor_right], [member Control.focus_next],
## and [member Control.focus_previous] to the [Control] beside them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_previous] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_previous].
static func focus_chain_previous(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrap(i+1, 0, controls.size())
		controls[i].focus_previous = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s and sets their [member Control.focus_previous]
## .[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## First item in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_previous] will be cleared.[br]
## NOTE: This overides any existing paths set for [member Control.focus_previous].
static func focus_chain_all(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	focus_chain_bottom(controls, loop, unique_paths_allowed)
	focus_chain_right(controls, loop, unique_paths_allowed)
	focus_chain_next(controls, loop, unique_paths_allowed)
	var rev := controls.duplicate()
	rev.reverse()
	focus_chain_top(rev, loop, unique_paths_allowed)
	focus_chain_left(rev, loop, unique_paths_allowed)
	focus_chain_previous(rev, loop, unique_paths_allowed)
