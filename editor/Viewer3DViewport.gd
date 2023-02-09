extends Viewport


func _ready():
	self.set_deferred("size", get_parent().rect_size)
