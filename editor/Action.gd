class_name Action


var _object
var _method_name: String
var _before_args: Array
var _after_args: Array


func _init(object, method_name: String, before_args, after_args):
	_object = object
	_method_name = method_name
	_before_args = before_args
	_after_args = after_args


func do():
	_object.callv(_method_name, _after_args)


func undo():
	_object.callv(_method_name, _before_args)
