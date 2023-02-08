shader_type particles;

uniform bool debug = false;
uniform int amount;
uniform float scale = 1.0;
uniform float scale_random_amount;
uniform float respawn_threshold: hint_range(0.0, 1.0, 0.1) = 0.3;
uniform vec3 emission_box_extents;
uniform sampler2D color_ramp;
uniform sampler2D source;
uniform sampler2D depth_motion;
uniform sampler2D raw_position_data;
uniform sampler2D strokes_output;

const float PI = 3.14159;

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

void vertex() {
	// CUSTOM.x === angle of particle
	// CUSTOM.y === current_transparency
	// CUSTOM.z === target_transparency
	// COLOR.r === normalized_position.x
	// COLOR.g === normalized_position.y
	// COLOR.b === angle (in radians)
	// COLOR.a === scale
	
	uint alt_seed = hash(uint(INDEX) + RANDOM_SEED);
	
	vec2 normalized_position = texelFetch(raw_position_data, ivec2(INDEX, 0), 0).xy;
	
	// initializes the stroke
	if (CUSTOM.x == 0.0) {
		CUSTOM.x = rand_from_seed(alt_seed) * 2.0 * PI;
		if (texture(strokes_output, normalized_position).a < 0.5) {
			CUSTOM.y = 1.0;
		} else {
			CUSTOM.y = 0.0;
		}
	}
	
	CUSTOM.y = 1.0;

//	vec2 position = normalized_position * 2.0 * emission_box_extents.xy - emission_box_extents.xy;
	vec2 position = (normalized_position - 0.5 * vec2(1)) * vec2(emission_box_extents.x / emission_box_extents.y, 1);
	
	vec4 current_strokes_output = texture(strokes_output, normalized_position);
	vec4 current_frame_color = texture(source, normalized_position);
	
	float depth = texture(depth_motion, normalized_position).z;
	
	
	COLOR = vec4(
		normalized_position.x,
		normalized_position.y,
		CUSTOM.x,
		scale
	);
	
//	if (distance(current_strokes_output, current_frame_color) > respawn_threshold) {
//		// respawn
//		CUSTOM.y = 1.0;
//	} else {
//		CUSTOM.y = 0.0;
//	}
	
	// set the transform
	TRANSFORM[0].xyz = vec3(cos(CUSTOM.x), -sin(CUSTOM.x), 0.0);
	TRANSFORM[1].xyz = vec3(sin(CUSTOM.x), cos(CUSTOM.x), 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
//	TRANSFORM[3] = vec4(position, -pow(depth, 20.0), 0.0);
//	TRANSFORM[3] = vec4(position, -float(INDEX) / 100.0, 0.0);
	if (CUSTOM.y > 0.5) {
		TRANSFORM[3] = vec4(position, -pow(depth, 20.0) - float(INDEX) * 0.005, 0.0);
//		TRANSFORM[3] = vec4(position, -float(INDEX) / 100.0, 0.0);
	} else {
		TRANSFORM[3] = vec4(vec2(-10000), 0, 0);
	}
//	TRANSFORM[3] = vec4(vec2(0), -10.0+float(INDEX)/10.0, 0.0);
//	TRANSFORM[3].xyz = vec3(float(INDEX)) * 0.1;
	float base_scale = scale;
	TRANSFORM[0].xyz *= base_scale;
	TRANSFORM[1].xyz *= base_scale;
	TRANSFORM[2].xyz *= base_scale;
}