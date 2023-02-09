extends Spatial


const CAMERA_SCROLL_STRIDE := 1.0

onready var mesh_container = $MeshContainer
onready var mesh_rotation = $MeshContainer/MeshRotation
onready var camera = $Camera

var pressed := false
var sensitivity := 0.01


func _unhandled_input(event):
	if event.is_action_pressed("pan") and not event.is_echo():
		pressed = true
	if event.is_action_released("pan") and not event.is_echo():
		pressed = false
	if pressed and event is InputEventMouseMotion:
		mesh_container.rotation.x += event.relative.y * sensitivity
		mesh_rotation.rotation.y += event.relative.x * sensitivity
	
	if event.is_action_released("scroll_up"):
		camera.translation.z -= CAMERA_SCROLL_STRIDE
	elif event.is_action_released("scroll_down"):
		camera.translation.z += CAMERA_SCROLL_STRIDE

