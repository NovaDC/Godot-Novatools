@tool
class_name PauseEye
extends Node

## PauseEye
##
## A simple [Node] with signals to monitor for the [SceneTree] for pausing and resuming behaviours.
## [br]Not specifically intended for use outside of a [TreeWatcherSingleton].[br]
## Can still be used independently if you wish to not require that a
## [TreeWatcherSingleton] be enabled at the time of use.[br][br]
## Due to how godot manages pausing [Node]s, this node must exist as a separate entity,
## as a [Node] will only be aware of the tree being paused if it's [member Node.process_mode]
## is set to [const Node.PROCESS_MODE_PAUSABLE], and since [const Node.PROCESS_MODE_PAUSABLE]
## [Node]s can only process themselves when the tree is not [member SceneTree.paused],
## the [TreeWatcherSingleton] would not be able to function when the tree is
## [member SceneTree.paused] (and this would therefore also lead to the breaking of some of it's
## other functions, as these must run even when the [SceneTree] is not [member SceneTree.paused]).

## Emitted when the tree is paused.
signal paused()
## Emitted when the tree is unpaused.
signal unpaused()

func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _notification(what:int):
	match(what):
		NOTIFICATION_PAUSED:
			paused.emit()
		NOTIFICATION_UNPAUSED:
			unpaused.emit()
