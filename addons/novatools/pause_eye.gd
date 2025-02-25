@tool
extends Node
class_name PauseEye

## PauseEye
## 
## A simple [Node] with signals to moniter for the [ScebeTree] for pausing and resuming behaviours.
## [br]Not specifically intended for use outside of a [TreeWatcherSingleton].

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
