extends Node2D

signal move_command_issued(destination)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		emit_signal("move_command_issued", get_global_mouse_position())
