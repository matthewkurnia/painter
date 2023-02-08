extends Viewport


func _enter_tree():
	print(get_parent().rect_size)
	set_canvas_size(get_parent().rect_size)


func set_canvas_size(size: Vector2) -> void:
	self.size = size
