extends MeshInstance


var camera_previous_position := Vector3()
var camera_previous_rotation := Quat()


func _process(delta):
	var material := get_surface_material(0)
	var camera := get_parent()
	assert(camera is Camera)
	
	var linear_velocity = camera.global_transform.origin - camera_previous_position
	
	var camera_rotation_current = Quat(camera.global_transform.basis)
	var camera_rotation_difference = camera_rotation_current - camera_previous_rotation
	var camera_rotation_conjugate = conjugate(camera_rotation_current)
	var angular_velocity = (camera_rotation_difference * 2.0) * camera_rotation_conjugate
	angular_velocity = Vector3(angular_velocity.x, angular_velocity.y, angular_velocity.z)
	
	material.set_shader_param("linear_velocity", linear_velocity)
	material.set_shader_param("angular_velocity", angular_velocity)
	
	camera_previous_position = camera.global_transform.origin
	camera_previous_rotation = Quat(camera.global_transform.basis)


func conjugate(quat: Quat) -> Quat:
	return Quat(-quat.x, -quat.y, -quat.z, quat.w)
