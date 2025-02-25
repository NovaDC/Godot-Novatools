@tool
extends EditorPlugin
class_name NovatoolsEditorPlugin

## The name of this plugin.
const PLUGIN_NAME := "novatools"

func _get_plugin_name() -> String:
	return PLUGIN_NAME

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/novatools/icon.svg")

## The name of the [TreeWatcherSingleton] to ass as a autoload.
const TREE_WATCHER_SINGLETON_NAME := "TreeWatcher"

func _enter_tree() -> void:
	if get_editor_interface().is_plugin_enabled(PLUGIN_NAME):
		_enable_plugin()

func _enable_plugin() -> void:
	add_autoload_singleton(TREE_WATCHER_SINGLETON_NAME, "res://addons/novatools/tree_watcher.gd")

func _disable_plugin() -> void:
	if not Engine.has_singleton(TREE_WATCHER_SINGLETON_NAME):
		remove_autoload_singleton(TREE_WATCHER_SINGLETON_NAME)
