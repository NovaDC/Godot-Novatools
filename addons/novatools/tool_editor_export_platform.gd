@tool
class_name ToolEditorExportPlatform
extends EditorExportPlatformExtension

## ToolEditorExportPlatform
##
## A base class extending [class EditorExportPlatformExtension] used for making
## tool export platforms (export platforms that call tools instead of exporting the project).

## The newline seporator used in config error messages.
const ERR_MESSAGE_NEWLINE := "\n"

func _has_valid_project_configuration(preset: EditorExportPreset):
	return true

func _has_valid_export_configuration(preset: EditorExportPreset, debug: bool):
	var preset_ok := true
	if preset.is_runnable():
		add_config_error(self._get_name().capitalize() + " cannot be runnable.")
		preset_ok = false
	if preset.get_export_filter() != EditorExportPreset.ExportFilter.EXPORT_ALL_RESOURCES:
		add_config_error("Must include all files.")
		preset_ok = false
	if preset.get_encrypt_pck() or preset.get_encrypt_directory():
		add_config_error("Cannot be encrypted.")
		preset_ok = false
	if preset.get_script_export_mode() != EditorExportPreset.ScriptExportMode.MODE_SCRIPT_TEXT:
		add_config_error("Cannot export tokenised scripts.")
		preset_ok = false
	if not preset.get_patches().is_empty():
		add_config_error("Cannot apply patches.")
		preset_ok = false
	if debug:
		add_config_error(_get_name().capitalize() + " cannot be debugged.")
		preset_ok = false
	return preset_ok

func _can_export(preset: EditorExportPreset, debug: bool):
	return (_has_valid_export_configuration(preset, debug) 
			and _has_valid_project_configuration(preset)
		   )
	
func _is_executable(path:String):
	return false

func _get_binary_extensions(preset: EditorExportPreset):
	return PackedStringArray()

# DO NOT OVERRIDE THIS METHOD WHEN EXTENDING
func _export_project(preset: EditorExportPreset,
					 debug: bool,
					 path: String,
					 flags:EditorExportPlatform.DebugFlags
					):
	if not _can_export(preset, debug):
		return ERR_INVALID_PARAMETER
	
	var err := await _export_hook(preset, path)
	if err != OK:
		return err
	
	return OK

func _get_os_name():
	return "NA"

func _get_platform_features():
	return PackedStringArray([_get_name().strip_edges().to_lower().replace(" ", "")])

func _get_preset_features(preset: EditorExportPreset):
	if (preset.get_or_env("post_processing_commands", "") is Array and
	   	preset.get_or_env("post_processing_commands", "").size() > 0
	   ):
		return PackedStringArray(["postprocessed"])
	return PackedStringArray()

func _get_export_options():
	return []

## Adds a single line to the config error. Like [method set_config_error],
## this should only be called in [method _can_export],
## [method _has_valid_export_configuration], or [method _has_valid_project_configuration].
func add_config_error(error:String):
	set_config_error(get_config_error() + ERR_MESSAGE_NEWLINE + error.strip_edges())

## A abstract method.[br]
## Must be overridden when extengin this class.
func _export_hook(preset: EditorExportPreset, path: String) -> Error:
	assert(false, "ABSTRACT METHOD NOT OVERRIDDEN")
	return ERR_CANT_RESOLVE

## Removes a single line to the config error. Like [method  set_config_error],
## this should only be called in [method  _can_export],
## [method  _has_valid_export_configuration], or [method  _has_valid_project_configuration].
func remove_config_error(error:String):
	var filtered_errs := Array(error.split(ERR_MESSAGE_NEWLINE))
	filtered_errs = filtered_errs.filter(func(e:String) : return e.strip_edges() != error)
	var errs = ERR_MESSAGE_NEWLINE.join(filtered_errs)
	errs += ERR_MESSAGE_NEWLINE + error.strip_edges()
	set_config_error(errs)

## Calls this export tool manually.
func manual_export_async(path:String, preset:EditorExportPreset) -> Error:
	return await _export_project(preset, false, path, 0)
