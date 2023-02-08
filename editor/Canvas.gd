extends Sprite


const MAX_DISTANCE := 3.0
const MAX_BUFFER_SIZE := 64
const USE_CUSTOM_HISTORY := true

enum BrushType { SQUARE, CIRCLE }

var curr_mouse_position: Vector2
var prev_mouse_position: Vector2
var brush_buffer := []
var image := Image.new()
var image_texture := ImageTexture.new()
var undo_redo := UndoRedo.new()
var prev_image := Image.new()
var bounded_undo_redo := BoundedUndoRedo.new()
var history := BoundedHistory.new()

var canvas_scale := 1.0

var brush_color := Color.black

var brush_type = BrushType.CIRCLE

var brush_size := 1

var cursor_wet := false


func _ready():
	var size := get_viewport().size
	image.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	image.fill(Color.white)
	image_texture.create_from_image(image, Texture.FLAG_REPEAT)
	self.texture = image_texture
	self.offset = 0.5 * size
	prev_image = image


func _draw():
	for location in brush_buffer:
		match brush_type:
			BrushType.CIRCLE:
				draw_circle(location, brush_size, brush_color)
			BrushType.SQUARE:
				var extents := Vector2.ONE * brush_size
				draw_rect(Rect2(location - extents, 2 * extents), brush_color)


func _unhandled_input(event):
	prev_mouse_position = curr_mouse_position
	curr_mouse_position = get_global_mouse_position() / canvas_scale
	var distance := prev_mouse_position.distance_to(curr_mouse_position)
	var displacement := curr_mouse_position - prev_mouse_position
	
	# A stroke is put down when:
	# - The user clicks for the first time, or
	# - The user is clicking and the mouse has moved
	
	if event.is_action_pressed("paint") and not event.is_echo():
		prev_image = image_texture.get_data()
		add_brush(curr_mouse_position)
		update()
		cursor_wet = true;
	elif cursor_wet and distance > 0:
		var n := int(distance / MAX_DISTANCE)
		if n > 0:
			var stride := 1 / float(n) * displacement
			for i in range(1, n + 1):
				add_brush(prev_mouse_position + stride * i)
		add_brush(curr_mouse_position)
		update()
		# In order to keep the draw calls small, we update
		# the image when the buffer size exceeds a constant
		if brush_buffer.size() > MAX_BUFFER_SIZE:
			update_image()
	
	if event.is_action_released("paint"):
		update_image(true)
		cursor_wet = false
	
	if event.is_action_pressed("redo") and not event.is_echo():
		redo()
	elif event.is_action_pressed("undo") and not event.is_echo():
		undo()


func undo():
	print("<<<")
	if USE_CUSTOM_HISTORY:
		bounded_undo_redo.undo()
	else:
		undo_redo.undo()


func redo():
	print(">>>")
	if USE_CUSTOM_HISTORY:
		bounded_undo_redo.redo()
	else:
		undo_redo.redo()


func add_brush(location: Vector2):
	brush_buffer.append(location)


func update_image(commit_to_history = false) -> void:
	# Update the image being shown by sprite
	yield(VisualServer, "frame_post_draw")
	var drawn_image := get_viewport().get_texture().get_data()
	drawn_image.flip_y()
	image_texture.set_data(drawn_image)
	
	# Clear the brush buffer, then update
	brush_buffer.clear()
	update()
	
	# If we are at the end of an action, commit to history
	if commit_to_history:
		commit_to_history()


func commit_to_history() -> void:
	var undo_image = prev_image.duplicate()
	var redo_image = image_texture.get_data().duplicate()
	
	if USE_CUSTOM_HISTORY:
		var action := Action.new(
			image_texture,
			"set_data",
			[undo_image],
			[redo_image]
		)
		bounded_undo_redo.commit_action(action)
		return
	
	undo_redo.create_action("Paint")
	undo_redo.add_do_method(
		image_texture,
		"set_data",
		image_texture.get_data()
	)
	undo_redo.add_undo_method(
		image_texture,
		"set_data",
		prev_image
	)
	undo_redo.commit_action()


func canvas_scale_updated(s: float) -> void:
	canvas_scale = s
