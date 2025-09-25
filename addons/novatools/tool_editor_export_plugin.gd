@tool
@icon("res://addons/editor_export_command/icon.svg")
class_name ToolEditorExportPlugin
extends EditorExportPlugin

## ToolEditorExportPlugin
##
## A abstract base class for running tools during exporting of projects.[br]

var _is_exporting := false
var _current_export_features := PackedStringArray()
var _current_export_is_debug := false
var _current_export_path := ""
var _current_export_flags := 0

## INTENDED TO BE VIRTUAL[br]
## Called when the pre export tools should be run.
## Used as a replacement for [method _export_begin].[br]
## [param features], [param is_debug], [param path] and [param flags] all corlate to the paramiters
## given to [method _export_begin].
func _export_begin_tool(features:PackedStringArray, is_debug:bool, path:String, flags:int):
	assert(false)

## INTENDED TO BE VIRTUAL[br]
## Called when the post export tools should be run.
## Used as a replacement for [method _export_end].[br]
## [param features], [param is_debug], [param path] and [param flags] all corlate to the paramiters
## given to [method _export_begin].
func _export_end_tool(features:PackedStringArray, is_debug:bool, path:String, flags:int):
	assert(false)


## Used to check if a project is currently being exported.
func is_exporting() -> bool:
	return _is_exporting

## Intended to be a sealed method.
func _export_begin(features:PackedStringArray, is_debug:bool, path:String, flags:int):
	_is_exporting = true

	_current_export_features = features
	_current_export_is_debug = is_debug
	_current_export_path = path
	_current_export_flags = flags
	_export_begin_tool(_current_export_features,
					   _current_export_is_debug,
					   _current_export_path,
					   _current_export_flags)

# Intended to be a sealed method.
func _export_end():
	_export_end_tool(_current_export_features,
					 _current_export_is_debug,
					 _current_export_path,
					 _current_export_flags)
	_is_exporting = false
