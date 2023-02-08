class_name BoundedUndoRedo


var history := BoundedHistory.new()


func _init():
	pass


func undo() -> bool:
	if not history.can_move_backward():
		return false
	var undo_action = history.move_backward()
	undo_action.undo()
	return true


func redo() -> bool:
	if not history.can_move_forward():
		return false
	var redo_action = history.move_forward()
	redo_action.do()
	return true


func commit_action(action: Action) -> void:
	history.push(action)
#	action.do()
