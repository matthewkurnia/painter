extends ViewportContainer


signal scale_updated(scale)

var prev_mouse_position: Vector2
var curr_mouse_position: Vector2
var scale := 1.0
var scale_factor := 1.2


func _init():
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE
	._init();


func _process(delta):
	prev_mouse_position = curr_mouse_position
	curr_mouse_position = get_global_mouse_position()
	var mouse_displacement := curr_mouse_position - prev_mouse_position
	if Input.is_action_pressed("pan"):
		self.rect_position += mouse_displacement
	
	if Input.is_action_just_released("scroll_up"):
		apply_scale(scale_factor)
	elif Input.is_action_just_released("scroll_down"):
		apply_scale(1/scale_factor)


func apply_scale(multiplier: float) -> void:
	var displacement := (curr_mouse_position - self.rect_position) * (1 - multiplier)
	self.rect_position += displacement
	scale *= multiplier
	self.rect_scale = scale * Vector2.ONE
	emit_signal("scale_updated", scale)
