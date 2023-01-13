tool
extends Particles


const POINTS_DATA_PATH := "res://pds/points.csv"
const STROKES_CONFIG_PATH := "res://pds/config.json"

var config := {};


func load_config(path: String) -> void:
	var file = File.new()
	file.open(path, File.READ)
	config = JSON.parse(file.get_as_text()).result
	file.close()


func load_points_as_image(path: String) -> Image:
	assert(config != {}, "Empty config!")
	var image = Image.new()
	image.create(config["amount"], 1, false, Image.FORMAT_RGBAF)
	image.lock()
	var file = File.new()
	file.open(path, File.READ)
	for i in range(config["amount"]):
		var point_str = file.get_csv_line()
		var data_as_color = Color(float(point_str[0]), float(point_str[-1]), 1.0)
		image.set_pixel(i, 0, data_as_color)
		assert(image.get_pixel(i, 0) == data_as_color)
		i += 1
	file.close()
	return image


func strokes_setup():
	load_config(STROKES_CONFIG_PATH)
	var image = load_points_as_image(POINTS_DATA_PATH)
	var image_texture = ImageTexture.new()
	image_texture.create_from_image(image)
	self.process_material.set_shader_param("raw_position_data", image_texture)
	self.amount = config["amount"]
	print("Strokes setup with config: ", config)
	self.process_material.set_shader_param("amount", config["amount"])
	self.process_material.set_shader_param(
		"emission_box_extents",
		Vector3(config["width"] / 2, config["height"] / 2, 1.0)
	)


func _enter_tree():
	if not Engine.editor_hint:
		return
	strokes_setup()


func _ready():
	if Engine.editor_hint:
		return
	strokes_setup()
