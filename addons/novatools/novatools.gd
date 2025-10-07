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
	#HOW IS THIS NOT AN EXPOSED FEATURE GODOT `ProgressDialog` IS RIGHT THERE
	var lab := RichTextLabel.new()
	lab.text = message
	lab.bbcode_enabled = true
	lab.custom_minimum_size = min_size

	var wind := PopupPanel.new()
	wind.exclusive = true
	wind.transient = true
	wind.add_child(lab)
	wind.popup_hide.connect(func(): wind.visible = true)
	wind.set_unparent_when_invisible(false)

	if Engine.is_editor_hint():
		EditorInterface.popup_dialog_centered(wind, min_size)
	else:
		Engine.get_main_loop().root.add_child(wind)
		wind.popup_centered(min_size)

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
					  MacOS/Darwin platforms! Commands may not run as expected!")
		new_args = ['-n', 'Terminal.app', command]
		new_args += (['--args'] if args.size() > 0 else [])
		new_args += args
		command = 'open'
	else:
		assert(false, "System terminal not found, cannot run command.")

	print("Running command: %s with args %s"%[command, new_args])

	var pid := OS.create_process(command, new_args, true)

	while OS.is_process_running(pid):
		await Engine.get_main_loop().process_frame

	return OS.get_process_exit_code(pid)

## Launches another instance of the godot editor in the system's default terminal.
static func launch_editor_instance_async(args := [],
										 log_file_path :=  "",
										 stay_open := true
										) -> int:
	if log_file_path != "" and GODOT_LOG_FILE_FLAG not in args:
		args = [GODOT_LOG_FILE_FLAG, log_file_path] + args
	if GODOT_NO_HEADER_FLAG not in args:
		args = [GODOT_NO_HEADER_FLAG] + args
	var ret_code := await launch_external_command_async(OS.get_executable_path(), args, stay_open)
	return OK if ret_code == 0 else FAILED

## Safely initialises a setting in the [EditorSettings] if it is not already made.
## If [param type] is set to [constant Variant.TYPE_NIL],
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


## Launches a python script/file in a separate terminal window asynchronously.
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

## Launches a installed python module on the system in a separate terminal window asynchronously.
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
								headers := PackedStringArray(["User-Agent: NovaTools/1.0 (Godot)"]),
								port:int = -1,
								tls:TLSOptions = null
							   ) -> int:
	print("Downloading: %s%s to %s"%[host, path, to_path])

	var http_client := HTTPClient.new()

	if host.is_empty():
		return ERR_INVALID_PARAMETER

	var err := http_client.connect_to_host(host, port, tls)
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
		err = http_client.poll()
		if err != OK:
			return err
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
		if data.size() > 0:
			err = file.get_error()
			if err != OK:
				return err

		err = http_client.poll()
		if err != OK:
			return err

		await Engine.get_main_loop().process_frame

	http_client.close()
	file.close()

	print("Download complete!")
	return OK

## An absolute version or [method DirAccess.is_link],
## returning [param unsupported_default] when the current platform does not support [method DirAccess.is_link],
## and [code]false[/code] when the base directory could not be opened.
static func is_dir_link_absolute(p:String, unsupported_default := false) -> bool:
	if not OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		return unsupported_default
	p = p.simplify_path()
	var da := DirAccess.open(p.get_base_dir())
	if da == null:
		return false
	return da.is_link(p)

## Decompresses the [code]zip[/code] file located at [param file_path] [param to_path].[br]
## If [param whitelist_starts] is not empty, only file paths that zip relative location
## starts with any of the given strings will be decompressed.
static func decompress_zip_async(file_path:String,
								 to_path:String,
								 whitelist_starts:Array[String] = []
								) -> int:
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
## If [param whitelist_starts] is not empty, only file paths that location relative
## to the [param source_path] starts with nay of the given strings will be compressed.[br]
## If [param include_linked] is true, linked files will also be included in the zip.
## [param compression_level] is the specific compression level to use when compressing.
## Since -1 is a valid ZIP compression level (corelating to the internal library's definition of a default compression level to use, [b]not[/b] to be confused with the default level set in the [ProjectSettings], of which can also include this -1 default value), the value used by this function to indicates the compression level should default to the value in [ProjectSettings] is -2 or lower.
## Note that specifying a individual compression level is only supported in godot v4.5 and up, so this paramiter will raise an error if anything besides the [ProjectSettings] default value is specified to be used (including both by specifying the actual value in project settings or by specifying this to -2 or lower, as noted above).
static func compress_zip_async(source_path:String,
							   to_file:String,
							   whitelist_starts:Array[String] = [],
							   include_linked := true,
							   compression_level:int = -2
							  ) -> int:

	if compression_level <= -2:
		compression_level = ProjectSettings.get_setting("compression/formats/zlib/compression_level")
	var ver_supports_comp_level:bool = not (Engine.get_version_info()["major"] <= 4 and Engine.get_version_info()["minor"] <= 4)
	if not ver_supports_comp_level:
		# We're only allowed to use this level in the first place...
		assert(compression_level == ProjectSettings.get_setting("compression/formats/zlib/compression_level"))

	if not DirAccess.dir_exists_absolute(source_path):
		return ERR_FILE_NOT_FOUND

	var err:int = ensure_absolute_dir_exists(to_file.get_base_dir())
	if err != OK:
		return err

	var files = get_children_files_recursive(source_path)
	files = Array(files).filter(func (p:String): return ((whitelist_starts.is_empty() or whitelist_starts.any(func (start:String): return p.begins_with(start))) and not to_file in p))
	if not include_linked and OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		files = files.filter(is_dir_link_absolute)

	if files.is_empty():
		return OK

	var packer := ZIPPacker.new()
	if ver_supports_comp_level:
		packer.compression_level = compression_level
	err = packer.open(to_file, ZIPPacker.APPEND_CREATE)
	if err == OK:
		for file_path in files:
			assert(file_path.begins_with(source_path))
			var internal_path = file_path.lstrip("/").rstrip("/").substr(source_path.lstrip("/").rstrip("/").length()).lstrip("/").rstrip("/")

			var data := FileAccess.get_file_as_bytes(file_path)
			if data.is_empty():
				err = FileAccess.get_open_error()
				if err != OK and err != ERR_FILE_CANT_OPEN:
					break

			await Engine.get_main_loop().process_frame

			err = packer.start_file(internal_path)
			if err != OK:
				break

			err = packer.write_file(data)
			if err != OK:
				break

			err = packer.close_file()
			if err != OK:
				break

			await Engine.get_main_loop().process_frame

	if err == OK:
		err = packer.close()
	else:
		packer.close() # we should still try to close, but we should maintain the earliest error to return

	return err

## Ensures a given path exists, without throwing errors if the directory already exists.
static func ensure_absolute_dir_exists(path:String) -> int:
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
		dir = from_path.path_join(dir)
		if not only_with_files or not DirAccess.get_files_at(dir).is_empty():
			found.append(dir)
		found.append_array(get_children_dir_recursive(dir, only_with_files))
	return found

## Returns the absolute paths to all files located under the given [param from_path].
static func get_children_files_recursive(from_path:String) -> PackedStringArray:
	var found := PackedStringArray(Array(DirAccess.get_files_at(from_path)).map(func (r:String): return from_path.path_join(r)))
	for dir in DirAccess.get_directories_at(from_path):
		found.append_array(get_children_files_recursive(from_path.path_join(dir)))

	return found

## Generates a [code]version.py[/code] file for this
## specific version of godot to the given [param to_path].
static func generate_version_py(to_path:String) -> int:
	assert(Engine.is_editor_hint())

	var ver_file := FileAccess.open(to_path.path_join("version.py") , FileAccess.WRITE)

	if ver_file == null:
		return FileAccess.get_open_error()

	var err:int = OK

	var is_latest:bool = Engine.get_version_info()["status"] == "dev"

	if err == OK and not ver_file.store_line('website="https://godotengine.org"'):
		err = ver_file.get_error()
	if err == OK and not ver_file.store_line('name="Godot Engine"'):
		err = ver_file.get_error()
	if err == OK and not ver_file.store_line('short_name="godot"'):
		err = ver_file.get_error()
	if err == OK and not ver_file.store_line('module_config=""'):
		err = ver_file.get_error()
	if err == OK and not ver_file.store_line('docs="%s"#Autogenerated"' % ["latest" if is_latest else "stable"]):
		err = ver_file.get_error()
	for key in Engine.get_version_info().keys():
		if err != OK:
			break
		var value = Engine.get_version_info()[key]
		if value is String:
			value = '"' + value + '"'
		if not ver_file.store_line("%s=%s#Autogenerated" % [key, value]):
			err = ver_file.get_error()

	return err

## Copies all files and directories from [param from_path] to [param to_path].
## All paths set in [param ignore_folders] will be skipped when copying.[br]
## The array in [param successfully_copied_buffer] will have all the paths that were created during copying without any errors appended to it.[br]
## NOTE: Depending on the size of data begin moved,
## this function can freeze the editor for some time.
static func copy_recursive(from_path:String,
						   to_path:String,
						   ignore_folders:=PackedStringArray(),
						   max_files:int = -1,
						   delete_on_fail := true,
						   successfully_copied_buffer := PackedStringArray()
						  ) -> int:
	from_path = from_path.rstrip("/")
	to_path = to_path.rstrip("/")
	var try_panic_delete := func():
		if delete_on_fail:
			for f in successfully_copied_buffer:
				#just try all of it
				delete_recursive(f)

	if max_files == 0:
		try_panic_delete.call()
		return ERR_TIMEOUT

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
			try_panic_delete.call()
			return err
		successfully_copied_buffer.append(to_path)

	for file in DirAccess.get_files_at(from_path):
		var err := OK
		if max_files == 0:
			return ERR_TIMEOUT
		file = file.lstrip("/")
		var from_file := (from_path.rstrip("/") + "/" + file).rstrip("/")
		var to_file := (to_path.rstrip("/") + "/" + file).rstrip("/")
		err = DirAccess.copy_absolute(from_file, to_file)
		if max_files > 0:
			max_files -= 1
		if err != OK:
			try_panic_delete.call()
			return err
		else:
			successfully_copied_buffer.append(to_file)

	for dir in DirAccess.get_directories_at(from_path):
		dir = dir.lstrip("/").rstrip("/")
		var from_dir := (from_path.rstrip("/") + "/" + dir).rstrip("/").simplify_path()
		var to_dir := (to_path.rstrip("/") + "/" + dir).rstrip("/").simplify_path()

		if (from_dir != to_dir and
			Array(ignore_folders).all(func (p:String): return not from_path.get_slice("://", 1) in p)
			):
			var err := copy_recursive(from_dir, to_dir, ignore_folders, max_files, delete_on_fail, successfully_copied_buffer)
			if err != OK:
				# no need to panic delete, the recursive call will can do that itself,
				# the successfully_copied_buffer is shared 2 ways after all
				return err
			else:
				successfully_copied_buffer.append(to_dir)
		if max_files > 0:
			max_files = max(0, max_files - DirAccess.get_files_at(from_dir).size())
		ignore_folders.append(to_dir)

	return OK

## Deletes all files and directories from [param path].
## When an error occurs, this function may leave files and folders undeleted.
## The array in [param successfully_removed_buffer] will have all the paths that were removed without any errors appended to it.
## NOTE: Depending on the size of data being moved,
## this function can freeze the editor for some time.
static func delete_recursive(path:String, successfully_removed_buffer := PackedStringArray()) -> int:
	var err:int = FAILED
	if DirAccess.dir_exists_absolute(path):
		# first files then directories,
		# otherwise errors are thrown for non-empty directories being deleted
		for p in DirAccess.get_files_at(path) + DirAccess.get_directories_at(path):
			err = delete_recursive(path.path_join(p), successfully_removed_buffer)
			if err != OK:
				break
		err = DirAccess.remove_absolute(path)
	elif FileAccess.file_exists(path):
		err = DirAccess.remove_absolute(path)
	else:
		err = ERR_FILE_NOT_FOUND

	if err == OK:
		successfully_removed_buffer.append(path)
	return err

## Attempts to recycle a file, falling back to deleting recursively (as moving a directory to the recycling is inherently recursive) it in case that fails for whatever reason (ex. the filesystem does not support it, the OS doesn't support it, etc.)
static func try_recycle_or_delete(path:String) -> int:
	var err := OS.move_to_trash(path)
	if err == OK:
		return err
	return delete_recursive(path)

## Attempts to copy files from [param from] to [param to] recursively; before deleting [param from] recursively.
## When [param undo_partial_copy] is set and an error occurs when copying, all files successfully created from copying will be removed first.
## Otherwise, a error happening during copying will result in any successfully coped files to remain where they were.
static func move_recursive(from:String,
						   to:String,
						   ignore_folders:=PackedStringArray(),
						   max_files:int = -1,
						   delete_on_fail := true,
						   successfully_moved_buffer := PackedStringArray()) -> int:
	var err := copy_recursive(from, to, ignore_folders, max_files, delete_on_fail, successfully_moved_buffer)
	if err == OK:
		err = delete_recursive(from)
		if err != OK:
			#still try to blindly cleanup everything else that was moved first, lets hope that that error was only specific to a single part of the path and doesn't apply to the other stuff moved
			for p in successfully_moved_buffer:
				delete_recursive(from)
	return err

## Convert a url into a form that is relevant outside this application. For example, all res://, user://, and uid:// urls are converted to their file path forms, and all identifiable file paths without the proper scheme will have the file:// scheme applied to them. This allows for functions like [method OS.shell_open] to compatibly open more types of urls, and ensures that paths are wrapped safely, to avoid potential malicious url collisions
static func normalized_url(url:String, file_relative_base := "") -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	var usr_dir := OS.get_user_data_dir()
	var drive_list:Array = range(DirAccess.get_drive_count()).map(DirAccess.get_drive_name).filter(func (s): return s != "")

	if file_relative_base == "":
		file_relative_base = exe_dir

	#lets manually normalize file paths without the "file://" scheme prefix to help improve the selection of using the browser manually
	var file_mode := url.begins_with("file://")

	if url.begins_with("res://") or url.begins_with("uid://"):
		file_mode = true
		if Engine.is_editor_hint():
			url = ProjectSettings.globalize_path(url)
		elif ResourceLoader.exists(url): #resource paths aren't as simple as being relative to some directory, we need to check with te resource loader
			url = ResourceLoader.load(url, "", ResourceLoader.CACHE_MODE_REUSE).resource_path
			assert (DirAccess.dir_exists_absolute(url) or DirAccess.dir_exists_absolute(url.get_base_dir()))

	if url.begins_with("user://"):
		file_mode = true
		if Engine.is_editor_hint(): #sure, test builds might have access to the ProjectSettings class to, but you make debug builds to debug how it acts on potentially non editor devices...
			url = ProjectSettings.globalize_path(url)
		else:
			url = usr_dir.path_join(url.get_slice("://", 1))

	if url.is_absolute_path() and DirAccess.dir_exists_absolute(url):
		file_mode = true
	elif url.is_relative_path():
		if DirAccess.dir_exists_absolute(usr_dir.path_join(url)):
			url = usr_dir.path_join(url)
			file_mode = true
	#NOTE [b]all[/b] possible urls don't [i]need[/i] to contain "://" exactly to be valid, but valid windows file paths may also contain ":/", so we should only use this to guard against wild collision between valid urls and paths
	elif "://" in url and drive_list.any(func (s): url.begins_with(s)):
		file_mode = true

	if file_mode:
		while "://" in url:
			url = url.get_slice("://", 1)
		url = "file://" + url

	return url

## Take a url, as if it is normalized (using [method normalized_url]) into a file url, return the path from that url.
## OTherwise, return [param default].
## This helps normalize res://, user://, and uid:// paths sensibly while also allowing for safe parsing of file:// urls and paths
static func url_get_file(url:String, default := "") -> String:
	url = normalized_url(url)
	if not "://" in url:
		return default
	var s := url.split(":/", true, 1)
	if s[0] != "file":
		return default
	return s[1]

## Open a url on the system, always converting res://, user:// and uid:// paths into their respective file system paths before then attempting to open any possible valid file paths in the system file browser first, before falling back to the os's choice for program in the case opening it in the file manager fails
static func open_uri_file_fixed(url:String, view_into_folders := false):
	url = normalized_url(url)

	var err := OS.shell_show_in_file_manager(url.get_slice("://", 1), view_into_folders)
	if url.begins_with("file://") and err == OK:
		return err
	return OS.shell_open(url)

## Gets the theme that is closes to the editor's theme, including when this isn't actually the editor. In the case this has no editor theme, it will then attempt to fall back to the project theme before falling back to the default theme.
static func get_most_relevant_editor_theme() -> Theme:
	var theme:Theme = null
	if Engine.is_editor_hint():
		theme = EditorInterface.get_editor_theme()
	if theme == null:
		theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = ThemeDB.get_default_theme()
	return theme

## Check if the [enum Variant.Type] enum value [param type] is some from of "Packed Array". Note that this check uses the string name of the variant type to determine if its a packed array or not, so this may be compatible with other extention that provide more packed array types
static func typeof_is_packed_array(type:int) -> bool:
	var s := type_string(type)
	return (s.begins_with("Packed") and s.ends_with("Array") and s.length() > ("Packed".length() + "Array".length()))

## Check if the [enum Variant.Type] enum value [param type] is some from "Array", either by being [constant Variant.TYPE_ARRAY] or by [method typeof_is_packed_array] returning true.
static func typeof_is_any_array(type:int) -> bool:
	return type == TYPE_ARRAY or typeof_is_packed_array(type)

## A method focused on taking in the many ways enums in godot can be referenced and returning a [Dictionary] that corelates enum's names to the enum's values.
## When using gdscript and referring to constant dictionaries or enums also defined in other non-extension scripts, it's possible to access them like any other constant property in a class (using it like a dictionary as is)
## however, is not consistent between versions or classes that are defined in [Script]s compared to classes defined in the [ClassDB].
## This method attempts to simplify that by allowing for all types of enums to be retrieved in their dictionary form simply by providing the class's name and the enum's name in that class.
## This method will also consistently return enums that can also be inherited from parent classes regardless of if the parent is a [Script] or a [ClassDB] defined class (or both, in the case that is ever possible).
## While [param name_or_object] accepts many different way to refer to a class, the most consistent (and suggested) method is to
## supply the class's name (or the path to the script if the script is an unnamed class) to [param name_or_object] and the enum's name to [param enum_name].
## However, the following are also acceptable way to look up enums:
## [ul]
## If [param name_or_object] is a [Dictionary] that dictionary will be returned verbatim (while still [param enforce_values_of_int], if set). This is the only situation where [param enum_name] is entirely unused, and therefore ignored.
## If [param name_or_object] is a [Object] that's not a [Script], it will reference that object's class and potentially attached [Script] if possible for enums instead.
## If [param name_or_object] is a [Script], that script's will be used for getting finding the enum.
## [/ul]
## Setting [param enforce_values_of_int] will assert that the returned enum must have values of the [int] type. While typically this isn't a concern,
## since [Script]'s enums are only defined as constant dictionaries,
## making it technically possible for typos of names to include dictionaries with non-[int] values.
## While [param enforce_values_of_int] defaults to [code]true[/code], it can be disabled for a menial speed boost when calling this method.
## This methods is indented for use with methods like [make_int_enum_hint_string] or other means handling exported enum values in the inspector.
static func enum_extract_dict(name_or_object:Variant, enum_name := "", enforce_values_of_int := true, enforce_keys_of_stringlike := true) -> Dictionary:
	if typeof(name_or_object) == TYPE_DICTIONARY: #how passing in a gdscript enum type should (hopefully) work
		var typed_dicts_supported:bool = Engine.get_version_info().major >= 4 and Engine.get_version_info().minor >= 4 and name_or_object.is_typed()

		var kt:int = TYPE_NIL
		if typed_dicts_supported and name_or_object.is_typed_key():
			kt = name_or_object.get_typed_key_builtin()
		if enforce_keys_of_stringlike:
			if kt != TYPE_NIL: #If the keys are variant, we should check them manually
				assert(kt in [TYPE_STRING, TYPE_STRING_NAME]) #if they are [Variant typed], which is ok when using both stringnames and strings as keys, since they are technically distinct but equally valid enum name types
			else:
				# humph
				# if you don't enforce the key types
				# then you don't get to use my super cool type fixer
				var key_types:Array = name_or_object.keys().map(typeof)
				var string_key_count := key_types.count(TYPE_STRING)
				var string_name_key_count := key_types.count(TYPE_STRING_NAME)
				assert(string_key_count + string_name_key_count == key_types.size())
				if string_key_count == key_types.size():
					kt = TYPE_STRING
				elif string_name_key_count == key_types.size():
					kt = TYPE_STRING_NAME
				# otherwise, just leave it variant, it's allowable (though perhaps this should change later on)

		var vt:int = TYPE_NIL
		if typed_dicts_supported and name_or_object.is_typed_value():
			vt = name_or_object.get_typed_value_builtin()
		if enforce_values_of_int:
			if vt != TYPE_NIL: #If the values are variant, we should check them manually
				assert(vt == TYPE_INT) #if they are [Variant typed]
			else:
				assert(name_or_object.values().all(func (v): return typeof(v) == TYPE_INT))
				vt = TYPE_INT

		if typed_dicts_supported and (kt != TYPE_NIL or vt != TYPE_NIL):
			name_or_object = Dictionary(name_or_object, kt, "", null, vt, "", null)
			name_or_object.make_read_only()
		elif not name_or_object.is_read_only():
			name_or_object = name_or_object.duplicate(false)
			name_or_object.make_read_only()
		return name_or_object
	elif typeof(name_or_object) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_OBJECT]:
		assert(enum_name != "")

		var ret := {}

		var cls_name:String = ""
		# note that we don't use [get_class_name] here because we want the classdb name specifically
		if typeof(name_or_object) in [TYPE_STRING, TYPE_STRING_NAME]:
			cls_name = str(name_or_object)
		elif name_or_object is Script:
			cls_name = get_class_name(name_or_object)
		else:
			cls_name = name_or_object.get_class()
		if ClassDB.class_exists(cls_name) and ClassDB.class_has_enum(cls_name, enum_name, false):
			var names := ClassDB.class_get_enum_constants(cls_name, enum_name, false)
			for n in names:
				ret[n] = ClassDB.class_get_integer_constant(cls_name, n)

		var script:Script = null
		# note that we don't use [class_name_normalize] or [get_class_name] here because we want the script specifically, or else null
		if typeof(name_or_object) in [TYPE_STRING, TYPE_STRING_NAME]:
			var script_path := script_path_normalize(name_or_object)
			if not script_path.is_empty() and ResourceLoader.exists(script_path, "Script"):
				script = load(script_path)
		elif name_or_object is Script:
			script = name_or_object
		else:
			script = name_or_object.get_script()
		if script != null:
			if not script.get_class().is_empty():
				ret.merge(enum_extract_dict(script.get_class(), enum_name, enforce_values_of_int))
			if script.get_base_script() != null:
				ret.merge(enum_extract_dict(script.get_base_script(), enum_name, enforce_values_of_int))
			var cm := script.get_script_constant_map()
			for cn in cm.keys():
				var c = cm[cn]
				if cn == enum_name and typeof(c) == TYPE_DICTIONARY:
					ret.merge(enum_extract_dict(c, enum_name, enforce_values_of_int))
		return ret

	assert(false)
	# Never reached, but code parsing needs a fallback from an assert for whatever reason
	# note this asserts that they type is correct
	return {}

## Takes a list of enums (in the form of a dictionary with [String] keys, another array (packed or otherwise) of string enum names, or string enum names directly)
## And attempts to merge them all into a single hint_string, intended for use in
## property lists with the hint of [constant PROPERTY_HINT_ENUM_SUGGESTION].
## This will [method assert] that all enum's the names (ignoring the values all together, if even provided)
## has no common names with any other.
static func make_string_suggestion_enum_hint_string(enum_dicts:Array[Variant]) -> String:
	var ns:Array = []
	for v in enum_dicts:
		var ks = null
		match(typeof(v)):
			TYPE_DICTIONARY:
				ks = v.keys()
			TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY:
				ks = v
			TYPE_STRING, TYPE_STRING_NAME:
				ks = [v]
		assert(ks != null)

		for k in ks:
			if k in ns:
				continue
			assert(typeof(k) in [TYPE_STRING, TYPE_STRING_NAME])
			ns.append(k)
	return ",".join(ns)

## Takes a list of enums (in the form of a dictionary of [String] (or [StringName]) keys and [int] values)
## And attempts to merge them all into a single hint_string, intended for use in
## property lists with the hint of [constant PROPERTY_HINT_ENUM].
## This will [method assert] that all enum's the values (but not names)
## has no common values with any other.
## For converting an enum into it's [Dictionary] form consistently, see [method enum_extract_dict].
## Note that this is intended specifically for use with [constant PROPERTY_HINT_ENUM].
## For [constant PROPERTY_HINT_ENUM_SUGGESTION], use [method make_string_suggestion_enum_hint_string].
static func make_int_enum_hint_string(enum_dicts:Array[Dictionary]) -> String:
	var dc := {}
	for d in enum_dicts:
		for k in d.keys():
			assert(typeof(k) in [TYPE_STRING, TYPE_STRING_NAME])
			var v = d[k]
			assert(v not in dc.keys())
			dc[v] = k
	var ret := PackedStringArray()
	for k in dc.keys():
		ret.append(dc[k] + ":" + str(k))
	return ",".join(ret)

## An enum made specifically for use with the [method get_debug_info] function.
## Note that the values are specifically started [b]after[/b] the [constant Performance.MONITOR_MAX]
## value, to allow for values for this enum to be used along side values form the [enum Performance.Monitor] enum
## without further ambiguity.
## Also note that values in this enum start [b]after[/b] [constant Performance.MONITOR_MAX] and not at
## [constant Performance.MONITOR_MAX], in case this max value
## ends up used for some purpose beyond simply signifying the maximum value
## (a choice sometimes made in other godot engine functions).
enum DebugInfoTypes{
	RUN_IS_DEBUG = Performance.MONITOR_MAX + 1,
	RUN_IS_TEMPLATE,
	RUN_IS_EDITOR,
	RUN_IS_EDITOR_EMBEDDED,
	RUN_IS_VERBOSE,
	RUN_IS_USER_FS_PERSISTENT,
	RUN_SCRIPT_LANGUAGE_NAMES,
	RUN_SINGLETON_NAMES,
	RUN_IS_FOCUSED,
	RUN_WINDOW_MODE,
	RUN_USER_DIRECTORY,
	RUN_EXE_DIRECTORY,
	RUN_MAIN_LOOP_TYPE,
	RUN_LOW_PROCESSOR_MODE,
	RUN_LOW_PROCESSOR_MODE_SLEEP_SEC,

	PROJECT_NAME,
	PROJECT_VERSION,
	PROJECT_DESCRIPTION,
	PROJECT_AUTO_ACCEPT_QUIT,
	PROJECT_QUIT_ON_GO_BACK,
	PROJECT_MAIN_SCENE,
	PROJECT_MAIN_LOOP_TYPE,

	OS_NAME,
	OS_DISTRIBUTION_NAME_OR_NAME,
	OS_NAME_WITH_DISTRIBUTION,
	OS_MODEL_NAME,
	OS_PROCESSOR_NAME,
	OS_DEVICE_UUID,
	OS_VERSION_NUMBER,
	OS_VERSION_ALIAS_OR_NUMBER,
	OS_BROWSER_OS,
	OS_GRANTED_PERMISSIONS,
	OS_ARCHITECTURE_NAME,
	OS_CPU_COUNT,
	OS_WINDOW_SERVER_NAME,

	MAIN_THREAD_ID,
	MAIN_PROCESS_ID,

	LOCALE_LANG,
	LOCALE_SCRIPT,
	LOCALE_COUNTRY,
	LOCALE_VARIANT,
	LOCALE_EXTRAS,

	TRANSLATION_SERVER_LOCALE,
	TRANSLATION_SERVER_EDITOR_LOCALE_OR_LOCALE,
	TRANSLATION_SERVER_LOCALE_NAME,
	TRANSLATION_SERVER_EDITOR_LOCALE_OR_LOCALE_NAME,

	TEXT_SERVER_NAME,
	TEXT_SERVER_SUPPORT_DATA_INFO,
	TEXT_SERVER_FEATURES,
	TEXT_SERVER_FEATURE_SIMPLE_LAYOUT,
	TEXT_SERVER_FEATURE_BIDI_LAYOUT,
	TEXT_SERVER_FEATURE_VERTICAL_LAYOUT,
	TEXT_SERVER_FEATURE_SHAPING,
	TEXT_SERVER_FEATURE_KASHIDA_JUSTIFICATION,
	TEXT_SERVER_FEATURE_BREAK_ITERATORS,
	TEXT_SERVER_FEATURE_FONT_BITMAP,
	TEXT_SERVER_FEATURE_FONT_DYNAMIC,
	TEXT_SERVER_FEATURE_FONT_MSDF,
	TEXT_SERVER_FEATURE_FONT_SYSTEM,
	TEXT_SERVER_FEATURE_FONT_VARIABLE,
	TEXT_SERVER_FEATURE_CONTEXT_SENSITIVE_CASE_CONVERSION,
	TEXT_SERVER_FEATURE_USE_SUPPORT_DATA,
	TEXT_SERVER_FEATURE_UNICODE_IDENTIFIERS,
	TEXT_SERVER_FEATURE_UNICODE_SECURITY,

	VIDEO_BACKEND_NAME,
	VIDEO_BACKEND_METHOD,
	VIDEO_ADAPTER_NAME,
	VIDEO_ADAPTER_VERSION,
	VIDEO_ADAPTER_TYPE,
	VIDEO_ADAPTER_VENDOR,
	VIDEO_FEATURES_S3TC,
	VIDEO_FEATURES_ETC,
	VIDEO_FEATURES_ETC2,
	VIDEO_MAX_FPS,

	AUDIO_DRIVER_NAME,
	AUDIO_BUS_COUNT,
	AUDIO_SPEAKER_MODE,
	AUDIO_PLAYBACK_SCALE,
	AUDIO_INPUT_SAMPLE_RATE,
	AUDIO_OUTPUT_SAMPLE_RATE,
	AUDIO_INPUT_DEVICE_NAME,
	AUDIO_OUTPUT_DEVICE_NAME,

	CAMERA_IS_MONITORING_FEEDS,
	CAMERA_FEED_COUNT,

	PHYSICS_MAX_STEP_PER_FRAME,
	PHYSICS_JITTER_FIX,
	PHYSICS_TIME_SCALE,

	INPUT_TOUCH_FROM_MOUSE,
	INPUT_MOUSE_FROM_TOUCH,
	INPUT_USE_ACCUMULATED_INPUT,
	INPUT_IS_ANYTHING_PRESSED,
	INPUT_MOUSE_BUTTON_MASK,
	INPUT_MOUSE_SCREEN_POSITION,
	INPUT_CONNECTED_JOYPAD_INDEXES,
	INPUT_CONNECTED_JOYPAD_GUIDS,
	INPUT_CONNECTED_JOYPAD_NAMES,
	INPUT_CONNECTED_JOYPAD_NAME_MAPPING,
	INPUT_CONNECTED_JOYPAD_KNOWN_MAPPING,
	INPUT_CONNECTED_JOYPADS_COUNT,
	INPUT_ACCELEROMETER,
	INPUT_GRAVITY,
	INPUT_GYROSCOPE,
	INPUT_MAGNETOMETER,

	XR_INTERFACE_COUNT,
	XR_INTERFACE_NAMES,

	ENGINE_VERSION,
	ENGINE_VERSION_MAJOR,
	ENGINE_VERSION_MINOR,
	ENGINE_VERSION_PATCH,
	ENGINE_VERSION_HEX,
	ENGINE_VERSION_STATUS,
	ENGINE_VERSION_BUILD,
	ENGINE_VERSION_TIMESTAMP,
	ENGINE_AUTHOR_INFO,
	ENGINE_COPYRIGHT_INFO,
	ENGINE_DONOR_INFO,
	ENGINE_LICENCE_INFO,

	DEBUG_INFO_TYPES_MAX,
}

## Determines if the given [param enum_value] is a value compatible
## originating from [enum Performance.Monitor].
## This is used internally in [method get_debug_info], and only implements a
## rough approximation of the possible values in [enum Performance.Monitor]
## (it uses [constant Performance.MONITOR_MAX] instead of finding all possible enum values).
static func is_performance_monitor_id(enum_value:int) -> bool:
	return enum_value <= Performance.MONITOR_MAX

## A function intended for use in debug logging and displays;
## it first checks if the [param name_or_id] is the name of a custom [Performance]
## monitor, or if its the integer index of a [enum Performance.Monitor], and if found,
## returns that performance monitor value.
## Otherwise, it will then expect the [param name_or_id] to be
## a integer value corelating to [enum DebugInfoTypes].
## If nothing else applies, then [param default] is returned
## Note how the [enum DebugInfoTypes] enum is made specifically to avoid
## any common values with the [enum Performance.Monitor] enum,
## so you are safe to use either enum's value as an id without further specification.
static func get_debug_info(name_or_id:Variant, default:Variant = null) -> Variant:
	if typeof(name_or_id) in [TYPE_STRING_NAME, TYPE_STRING]:
		if Performance.has_custom_monitor(name_or_id):
			return Performance.get_custom_monitor(name_or_id)
	elif typeof(name_or_id) == TYPE_INT:
		match(name_or_id):
			var mon when is_performance_monitor_id(mon):
				return Performance.get_monitor(mon)

			DebugInfoTypes.RUN_IS_DEBUG:
				return OS.is_debug_build()
			DebugInfoTypes.RUN_IS_TEMPLATE:
				return OS.has_feature("template")
			DebugInfoTypes.RUN_IS_EDITOR:
				return Engine.is_editor_hint()
			DebugInfoTypes.RUN_IS_EDITOR_EMBEDDED:
				return Engine.is_embedded_in_editor()
			DebugInfoTypes.RUN_IS_VERBOSE:
				return OS.is_stdout_verbose()
			DebugInfoTypes.RUN_IS_USER_FS_PERSISTENT:
				return OS.is_userfs_persistent()
			DebugInfoTypes.RUN_SCRIPT_LANGUAGE_NAMES:
				return PackedStringArray(range(Engine.get_script_language_count()).map(func (si): return Engine.get_script_language(si).get_class()))
			DebugInfoTypes.RUN_SINGLETON_NAMES:
				return Engine.get_singleton_list()
			DebugInfoTypes.RUN_IS_FOCUSED:
				return Engine.get_main_loop().root.has_focus()
			DebugInfoTypes.RUN_WINDOW_MODE:
				return Engine.get_main_loop().root.mode
			DebugInfoTypes.RUN_USER_DIRECTORY:
				return OS.get_user_data_dir()
			DebugInfoTypes.RUN_EXE_DIRECTORY:
				return OS.get_executable_path().get_base_dir()
			DebugInfoTypes.RUN_MAIN_LOOP_TYPE:
				return Engine.get_main_loop().get_class()
			DebugInfoTypes.RUN_LOW_PROCESSOR_MODE:
				return OS.low_processor_usage_mode
			DebugInfoTypes.RUN_LOW_PROCESSOR_MODE_SLEEP_SEC:
				return OS.low_processor_usage_mode_sleep_usec / 1000000.0

			DebugInfoTypes.PROJECT_NAME:
				return ProjectSettings.get_setting("application/config/name", "")
			DebugInfoTypes.PROJECT_VERSION:
				return ProjectSettings.get_setting("application/config/version", "")
			DebugInfoTypes.PROJECT_DESCRIPTION:
				return ProjectSettings.get_setting("application/config/description", "")
			DebugInfoTypes.PROJECT_AUTO_ACCEPT_QUIT:
				return ProjectSettings.get_setting("application/config/auto_accept_quit", null)
			DebugInfoTypes.PROJECT_QUIT_ON_GO_BACK:
				return ProjectSettings.get_setting("application/config/quit_on_go_back", null)
			DebugInfoTypes.PROJECT_MAIN_SCENE:
				return ProjectSettings.get_setting("application/run/main_scene", "")
			DebugInfoTypes.PROJECT_MAIN_LOOP_TYPE:
				return ProjectSettings.get_setting("application/run/main_loop_type", "")

			DebugInfoTypes.OS_NAME:
				return OS.get_name()
			DebugInfoTypes.OS_DISTRIBUTION_NAME_OR_NAME:
				return OS.get_distribution_name() if OS.get_distribution_name() != "" else OS.get_name()
			DebugInfoTypes.OS_NAME_WITH_DISTRIBUTION:
				return ("%s (%s)" % [OS.get_name(), OS.get_distribution_name()]) if (OS.get_distribution_name() != "" and OS.get_distribution_name() != OS.get_name()) else OS.get_name()
			DebugInfoTypes.OS_MODEL_NAME:
				return OS.get_model_name()
			DebugInfoTypes.OS_PROCESSOR_NAME:
				return OS.get_processor_name()
			DebugInfoTypes.OS_DEVICE_UUID:
				return OS.get_unique_id()
			DebugInfoTypes.OS_VERSION_NUMBER:
				return OS.get_version()
			DebugInfoTypes.OS_VERSION_ALIAS_OR_NUMBER:
				return OS.get_version_alias()
			DebugInfoTypes.OS_BROWSER_OS:
				for feat in ["web_android", "web_ios", "web_macos", "web_windows", "web_linuxbsd", "web"]:
					if OS.has_feature(feat):
						return feat
				return null
			DebugInfoTypes.OS_GRANTED_PERMISSIONS:
				return OS.get_granted_permissions()
			DebugInfoTypes.OS_ARCHITECTURE_NAME:
				return OS.get_processor_name()
			DebugInfoTypes.OS_CPU_COUNT:
				return OS.get_processor_count()
			DebugInfoTypes.OS_WINDOW_SERVER_NAME:
				return DisplayServer.get_name()

			DebugInfoTypes.LOCALE_LANG:
				return OS.get_locale_language()
			DebugInfoTypes.LOCALE_SCRIPT:
				return OS.get_locale().get_slice("_", 1)
			DebugInfoTypes.LOCALE_COUNTRY:
				return OS.get_locale().get_slice("_", 2)
			DebugInfoTypes.LOCALE_VARIANT:
				return OS.get_locale().get_slice("_", 3).get_slice("@", 0)
			DebugInfoTypes.LOCALE_EXTRAS:
				return OS.get_locale().get_slice("_", 3).get_slice("@", 1).split(";")

			DebugInfoTypes.TRANSLATION_SERVER_LOCALE:
				return TranslationServer.get_locale()
			DebugInfoTypes.TRANSLATION_SERVER_EDITOR_LOCALE_OR_LOCALE:
				return TranslationServer.get_tool_locale()
			DebugInfoTypes.TRANSLATION_SERVER_LOCALE_NAME:
				return TranslationServer.get_locale_name(TranslationServer.get_locale())
			DebugInfoTypes.TRANSLATION_SERVER_EDITOR_LOCALE_OR_LOCALE_NAME:
				return TranslationServer.get_locale_name(TranslationServer.get_tool_locale())

			DebugInfoTypes.TEXT_SERVER_NAME:
				return TextServerManager.get_primary_interface().get_name()
			DebugInfoTypes.TEXT_SERVER_SUPPORT_DATA_INFO:
				return TextServerManager.get_primary_interface().get_support_data_info()
			DebugInfoTypes.TEXT_SERVER_FEATURES:
				return TextServerManager.get_primary_interface().get_features()
			DebugInfoTypes.TEXT_SERVER_FEATURE_SIMPLE_LAYOUT:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_SIMPLE_LAYOUT)
			DebugInfoTypes.TEXT_SERVER_FEATURE_BIDI_LAYOUT:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_BIDI_LAYOUT)
			DebugInfoTypes.TEXT_SERVER_FEATURE_VERTICAL_LAYOUT:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_VERTICAL_LAYOUT)
			DebugInfoTypes.TEXT_SERVER_FEATURE_SHAPING:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_SHAPING)
			DebugInfoTypes.TEXT_SERVER_FEATURE_KASHIDA_JUSTIFICATION:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_KASHIDA_JUSTIFICATION)
			DebugInfoTypes.TEXT_SERVER_FEATURE_BREAK_ITERATORS:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_BREAK_ITERATORS)
			DebugInfoTypes.TEXT_SERVER_FEATURE_FONT_BITMAP:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_FONT_BITMAP)
			DebugInfoTypes.TEXT_SERVER_FEATURE_FONT_DYNAMIC:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_FONT_DYNAMIC)
			DebugInfoTypes.TEXT_SERVER_FEATURE_FONT_MSDF:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_FONT_MSDF)
			DebugInfoTypes.TEXT_SERVER_FEATURE_FONT_SYSTEM:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_FONT_SYSTEM)
			DebugInfoTypes.TEXT_SERVER_FEATURE_FONT_VARIABLE:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_FONT_VARIABLE)
			DebugInfoTypes.TEXT_SERVER_FEATURE_CONTEXT_SENSITIVE_CASE_CONVERSION:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_CONTEXT_SENSITIVE_CASE_CONVERSION)
			DebugInfoTypes.TEXT_SERVER_FEATURE_USE_SUPPORT_DATA:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_USE_SUPPORT_DATA)
			DebugInfoTypes.TEXT_SERVER_FEATURE_UNICODE_IDENTIFIERS:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_UNICODE_IDENTIFIERS)
			DebugInfoTypes.TEXT_SERVER_FEATURE_UNICODE_SECURITY:
				return TextServerManager.get_primary_interface().has_feature(TextServer.FEATURE_UNICODE_SECURITY)

			DebugInfoTypes.MAIN_THREAD_ID:
				return OS.get_main_thread_id()
			DebugInfoTypes.MAIN_PROCESS_ID:
				return OS.get_process_id()

			DebugInfoTypes.VIDEO_BACKEND_NAME:
				return RenderingServer.get_current_rendering_driver_name()
			DebugInfoTypes.VIDEO_BACKEND_METHOD:
				return RenderingServer.get_current_rendering_method()
			DebugInfoTypes.VIDEO_ADAPTER_NAME:
				return RenderingServer.get_video_adapter_name()
			DebugInfoTypes.VIDEO_ADAPTER_VERSION:
				return RenderingServer.get_video_adapter_api_version()
			DebugInfoTypes.VIDEO_ADAPTER_TYPE:
				if RenderingServer.get_rendering_device() == null:
					return null
				return RenderingServer.get_rendering_device().get_device_type()
			DebugInfoTypes.VIDEO_ADAPTER_VENDOR:
				return RenderingServer.get_video_adapter_vendor()
			DebugInfoTypes.VIDEO_MAX_FPS:
				return Engine.max_fps
			DebugInfoTypes.VIDEO_FEATURES_S3TC:
				return RenderingServer.has_os_feature("s3tc")
			DebugInfoTypes.VIDEO_FEATURES_ETC:
				return RenderingServer.has_os_feature("etc")
			DebugInfoTypes.VIDEO_FEATURES_ETC2:
				return RenderingServer.has_os_feature("etc2")

			DebugInfoTypes.AUDIO_INPUT_DEVICE_NAME:
				return AudioServer.input_device
			DebugInfoTypes.AUDIO_OUTPUT_DEVICE_NAME:
				return AudioServer.output_device
			DebugInfoTypes.AUDIO_PLAYBACK_SCALE:
				return AudioServer.playback_speed_scale
			DebugInfoTypes.AUDIO_BUS_COUNT:
				return AudioServer.bus_count
			DebugInfoTypes.AUDIO_DRIVER_NAME:
				return AudioServer.get_driver_name()
			DebugInfoTypes.AUDIO_INPUT_SAMPLE_RATE:
				return AudioServer.get_input_mix_rate()
			DebugInfoTypes.AUDIO_OUTPUT_SAMPLE_RATE:
				return AudioServer.get_mix_rate()
			DebugInfoTypes.AUDIO_SPEAKER_MODE:
				return AudioServer.get_speaker_mode()

			DebugInfoTypes.CAMERA_IS_MONITORING_FEEDS:
				return CameraServer.monitoring_feeds
			DebugInfoTypes.CAMERA_FEED_COUNT:
				return CameraServer.get_feed_count()

			DebugInfoTypes.PHYSICS_MAX_STEP_PER_FRAME:
				return Engine.physics_ticks_per_second
			DebugInfoTypes.PHYSICS_JITTER_FIX:
				return Engine.physics_jitter_fix
			DebugInfoTypes.PHYSICS_TIME_SCALE:
				return Engine.time_scale

			DebugInfoTypes.INPUT_TOUCH_FROM_MOUSE:
				return Input.is_emulating_touch_from_mouse()
			DebugInfoTypes.INPUT_MOUSE_FROM_TOUCH:
				return Input.is_emulating_mouse_from_touch()
			DebugInfoTypes.INPUT_USE_ACCUMULATED_INPUT:
				return Input.use_accumulated_input
			DebugInfoTypes.INPUT_IS_ANYTHING_PRESSED:
				return Input.is_anything_pressed()
			DebugInfoTypes.INPUT_MOUSE_BUTTON_MASK:
				return Input.get_mouse_button_mask()
			DebugInfoTypes.INPUT_MOUSE_SCREEN_POSITION:
				return DisplayServer.mouse_get_position()
			DebugInfoTypes.INPUT_CONNECTED_JOYPAD_INDEXES:
				return Input.get_connected_joypads()
			DebugInfoTypes.INPUT_CONNECTED_JOYPAD_GUIDS:
				return Input.get_connected_joypads().map(Input.get_joy_guid)
			DebugInfoTypes.INPUT_CONNECTED_JOYPAD_NAMES:
				return Input.get_connected_joypads().map(Input.get_joy_name)
			DebugInfoTypes.INPUT_CONNECTED_JOYPAD_NAME_MAPPING:
				var result = {}
				for i in Input.get_connected_joypads():
					result[i] = Input.get_joy_name(i)
				return result
			DebugInfoTypes.INPUT_CONNECTED_JOYPAD_KNOWN_MAPPING:
				var result = {}
				for i in Input.get_connected_joypads():
					result[i] = Input.is_joy_known(i)
				return result
			DebugInfoTypes.INPUT_CONNECTED_JOYPADS_COUNT:
				return Input.get_connected_joypads().size()
			DebugInfoTypes.INPUT_ACCELEROMETER:
				return Input.get_accelerometer()
			DebugInfoTypes.INPUT_GRAVITY:
				return Input.get_gravity()
			DebugInfoTypes.INPUT_GYROSCOPE:
				return Input.get_gyroscope()
			DebugInfoTypes.INPUT_MAGNETOMETER:
				return Input.get_magnetometer()

			DebugInfoTypes.XR_INTERFACE_COUNT:
				return XRServer.get_interface_count()
			DebugInfoTypes.XR_INTERFACE_NAMES:
				return range(XRServer.get_interface_count()).map(func (i): return XRServer.get_interface(i).get_name())

			DebugInfoTypes.ENGINE_VERSION:
				return Engine.get_version_info()
			DebugInfoTypes.ENGINE_VERSION_MAJOR:
				return Engine.get_version_info().get("major", 0)
			DebugInfoTypes.ENGINE_VERSION_MINOR:
				return Engine.get_version_info().get("minor", 0)
			DebugInfoTypes.ENGINE_VERSION_PATCH:
				return Engine.get_version_info().get("patch", 0)
			DebugInfoTypes.ENGINE_VERSION_HEX:
				return Engine.get_version_info().get("hex", 0)
			DebugInfoTypes.ENGINE_VERSION_STATUS:
				return Engine.get_version_info().get("status", "")
			DebugInfoTypes.ENGINE_VERSION_BUILD:
				return Engine.get_version_info().get("build", "")
			DebugInfoTypes.ENGINE_VERSION_TIMESTAMP:
				return Engine.get_version_info().get("timestamp", 0)
			DebugInfoTypes.ENGINE_AUTHOR_INFO:
				return Engine.get_author_info()
			DebugInfoTypes.ENGINE_COPYRIGHT_INFO:
				return Engine.get_copyright_info()
			DebugInfoTypes.ENGINE_DONOR_INFO:
				return Engine.get_donor_info()
			DebugInfoTypes.ENGINE_LICENCE_INFO:
				return Engine.get_license_info()

	return default

## Fetches an editor icon form the most relevant editor theme.
static func get_editor_icon_named(name:String, manual_size := -Vector2i.ONE) -> Texture2D:
	var theme = get_most_relevant_editor_theme()

	if theme == null || theme.has_icon(name, EDITOR_ICONS_THEME_TYPE):
		return null

	var texture := theme.get_icon(name, EDITOR_ICONS_THEME_TYPE)
	var original_size := texture.get_image().get_size()
	if manual_size.x < 0:
		manual_size.x = original_size.x
	if manual_size.y < 0:
		manual_size.y = original_size.y

	if manual_size != original_size:
		texture = texture.duplicate()
		texture.set_size_override(manual_size)

	return texture

## Attempts to call a method on the editor's version control system, as exposed as virtual methods
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

## Checks if any file are changed as according to the vcs, always returning [code]false[/code]
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
## it's path will be returned.[br]
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
## of the same script simultaneously.
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
	# and we have not control over order,
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
## NOTE: This overrides any existing paths set for [member Control.focus_neighbor_right].
static func focus_chain_right(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrapi(i+1, 0, controls.size())
		controls[i].focus_neighbor_right = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_left]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_left] will be cleared.[br]
## NOTE: This overrides any existing paths set for [member Control.focus_neighbor_left].
static func focus_chain_left(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrapi(i+1, 0, controls.size())
		controls[i].focus_neighbor_left = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_top]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_top] will be cleared.[br]
## NOTE: This overrides any existing paths set for [member Control.focus_neighbor_top].
static func focus_chain_top(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrapi(i+1, 0, controls.size())
		controls[i].focus_neighbor_top = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_neighbor_bottom]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_neighbor_bottom] will be cleared.[br]
## NOTE: This overrides any existing paths set for [member Control.focus_neighbor_bottom].
static func focus_chain_bottom(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrapi(i+1, 0, controls.size())
		controls[i].focus_neighbor_bottom = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s, setting their [member Control.focus_next]
## to the [Control] next to them in [param controls].[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## first [Control] in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_next] will be cleared.[br]
## NOTE: This overrides any existing paths set for [member Control.focus_next].
static func focus_chain_next(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrapi(i+1, 0, controls.size())
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
## NOTE: This overrides any existing paths set for [member Control.focus_previous].
static func focus_chain_previous(controls:Array[Control], loop:= false, unique_paths_allowed := false):
	var range_max := controls.size()
	if not loop:
		range_max -= 1
	for i in range(range_max):
		var next_i := wrapi(i+1, 0, controls.size())
		controls[i].focus_previous = controls[i].get_path_to(controls[next_i], unique_paths_allowed)

## Takes a [Array] of [Control]s and sets their [member Control.focus_previous]
## .[br]
## If [param loop], the last [Control] in [param controls] will also link to the
## First item in [param controls].[br]
## Similar to [method Node.get_path_to], [param unique_paths_allowed] will allow for unique
## paths as well, if the route is shorter.[br]
## NOTE: in there is no node path that can be made from one [Control] to the next, that
## [member Control.focus_previous] will be cleared.[br]
## NOTE: This overrides any existing paths set for [member Control.focus_previous].
static func focus_chain_all(controls:Array[Control], loop := false, unique_paths_allowed := false):
	focus_chain_bottom(controls, loop, unique_paths_allowed)
	focus_chain_right(controls, loop, unique_paths_allowed)
	focus_chain_next(controls, loop, unique_paths_allowed)
	var rev := controls.duplicate()
	rev.reverse()
	focus_chain_top(rev, loop, unique_paths_allowed)
	focus_chain_left(rev, loop, unique_paths_allowed)
	focus_chain_previous(rev, loop, unique_paths_allowed)
