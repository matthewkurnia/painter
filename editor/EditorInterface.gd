extends Panel


enum {
	UNDO_STROKE,
	REDO_STROKE,
	USE_PENCIL,
	USE_ERASER,
	USE_SQUARE_SHAPE,
	USE_CIRCLE_SHAPE,
	SET_STROKE_SIZE,
	SET_STROKE_COLOR
}


const BrushType := preload("res://editor/Canvas.gd").BrushType


export var canvas_path: NodePath


onready var panel := self
onready var undo_button := $HBoxContainer/UndoContainer/Button
onready var redo_button := $HBoxContainer/RedoContainer/Button
onready var pencil_button := $HBoxContainer/PencilContainer/Button
onready var eraser_button := $HBoxContainer/EraserContainer/Button
onready var square_button := $HBoxContainer/SquareShapeContainer/Button
onready var circle_button := $HBoxContainer/CircleShapeContainer/Button
onready var brush_size_box := $HBoxContainer/BrushSizeContainer/SpinBox
onready var color_picker := $HBoxContainer/ColorPickerContainer/ColorPickerButton

onready var canvas = get_node_or_null(canvas_path)


func _ready():
	undo_button.connect("pressed", self, "on_ui_action", [UNDO_STROKE])
	redo_button.connect("pressed", self, "on_ui_action", [REDO_STROKE])
	pencil_button.connect("pressed", self, "on_ui_action", [USE_PENCIL])
	eraser_button.connect("pressed", self, "on_ui_action", [USE_ERASER])
	square_button.connect("pressed", self, "on_ui_action", [USE_SQUARE_SHAPE])
	circle_button.connect("pressed", self, "on_ui_action", [USE_CIRCLE_SHAPE])
	brush_size_box.connect("value_changed", self, "brush_size_changed")
	color_picker.connect("color_changed", self, "color_changed")
	
	self.mouse_filter = MOUSE_FILTER_STOP
	
	if !canvas:
		return
	canvas.brush_color = color_picker.color
	canvas.brush_type = BrushType.CIRCLE
	canvas.brush_size = brush_size_box.value


func on_ui_action(action):
	if !canvas:
		return
	match action:
		UNDO_STROKE:
			canvas.undo()
			print("undo!")
		REDO_STROKE:
			canvas.redo()
			print("redo!")
		USE_PENCIL:
			color_changed(color_picker.color)
			print("using pencil!")
		USE_ERASER:
			color_changed(Color.white)
			print("using eraser!")
		USE_SQUARE_SHAPE:
			canvas.brush_type = BrushType.SQUARE
			print("using square brush!")
		USE_CIRCLE_SHAPE:
			canvas.brush_type = BrushType.CIRCLE
			print("using circle brush!")


func brush_size_changed(size):
	if !canvas:
		return
	canvas.brush_size = size
	print("brush size changed to %d" % size)


func color_changed(color: Color):
	if !canvas:
		return
	canvas.brush_color = color
	print("brush color changed to ", color)
