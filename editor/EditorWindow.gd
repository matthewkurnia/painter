extends Control


export var nested_input_handler_path: NodePath

var handle_input := false

onready var nested_input_handler = get_node_or_null(nested_input_handler_path)


func on_mouse_entered():
	handle_input = true
	print(self.name + " ENTER!")


func on_mouse_exited():
	handle_input = false
	print(self.name + " EXIT!")


func _input(event):
	if handle_input and nested_input_handler:
		nested_input_handler._unhandled_input(event)
