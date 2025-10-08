@tool
@icon("./icon.svg")
class_name TreeWatcherSingleton
extends Node

## TreeWatcherSingleton
##
## A node intended to be used as a (autoloaded [Node]) singleton. Used to monitor certain
## changes in the [SceneTree] which the [SceneTree] currently doesn't currently provide a simple
## interface to do.[br]
## Currently provides signals connected to the changing of [Scene]s, and to the
## [member SceneTree.paused] state of the tree (independent of the [member Node.process_mode] of any
## given [Node]). This singleton may be deprecated in the future if godot decides to provide similar
## [Signal]s or methods that provide the same, scene-agnostic functionally.

## Emits when the tree is paused.
signal tree_paused()
## Emits when the tree is unpaused.
signal tree_resumed()
## Emits when the tree is pause state is changed.
signal tree_pause_change(paused:bool)

## Emitted when a new scene is loaded into the tree. [param old_scene_root] is the old top level
## [Node] of the scene.
signal tree_scene_unloaded(old_scene_root:Node)
## Emitted when a new scene is loaded into the tree. [param scene_root] is the top level
## [Node] of the scene.
signal tree_scene_loaded(scene_root:Node)

var _pause_eye:PauseEye = null
var _latest_scene_root:Node = null

func _enter_tree():
	_on_node_add(self)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	_pause_eye = PauseEye.new()
	add_child(_pause_eye)
	_pause_eye.paused.connect(tree_paused.emit)
	_pause_eye.paused.connect(tree_pause_change.emit.bind(true))
	_pause_eye.unpaused.connect(tree_resumed.emit)
	_pause_eye.unpaused.connect(tree_pause_change.emit.bind(false))

	var tree := get_tree()
	if tree != null:
		if not tree.node_added.is_connected(_on_node_add):
			tree.node_added.connect(_on_node_add)
		if not tree.node_removed.is_connected(_on_node_free):
			tree.node_removed.connect(_on_node_free)

	_on_node_add(self)

func _exit_tree() -> void:
	_on_node_free(self)

func _on_node_add(_node:Node):
	var tree := get_tree()
	if tree == null:
		return
	if _latest_scene_root != tree.current_scene:
		tree_scene_loaded.emit(tree.current_scene)
		_latest_scene_root = tree.current_scene

func _on_node_free(node:Node):
	var tree := get_tree()
	if tree == null:
		return
	if (tree.current_scene == null and _latest_scene_root != null) or node == _latest_scene_root:
		tree_scene_unloaded.emit(_latest_scene_root)
		_latest_scene_root = tree.current_scene
