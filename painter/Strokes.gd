extends Particles2D


func _ready():
	var extents = get_viewport_rect().size / 2
	self.position = extents
	self.process_material.set_shader_param(
		"emission_box_extents",
		Vector3(extents.x, extents.y, 1.0)
	)
