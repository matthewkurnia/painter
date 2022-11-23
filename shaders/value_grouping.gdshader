shader_type canvas_item;

uniform float highlight_threshold: hint_range(0.0, 1.0) = 0.9;
uniform float highlight_fade_distance: hint_range(0.0, 0.2) = 0.05;
uniform float highlight_lod: hint_range(0.0, 10.0, 0.5) = 2.0;
uniform vec4 highlight_bias: hint_color;
uniform float shadow_threshold: hint_range(0.0, 1.0) = 0.2;
uniform float shadow_fade_distance: hint_range(0.0, 0.2) = 0.05;
uniform float shadow_lod: hint_range(0.0, 10.0, 0.5) = 4.0;
uniform vec4 shadow_bias: hint_color;

const float PI = 3.14159265358979323846;
const float X_ABS = 1.0;
const float Y_ABS = 1.0;
const float Z_ABS = 1.0;

const mat3 mat_rgb_to_xyz = mat3(
	vec3(0.412453, 0.212671, 0.019334),
	vec3(0.357580, 0.715160, 0.119193),
	vec3(0.180423, 0.072169, 0.950227)
);

const mat3 mat_xyz_to_rgb = mat3(
	vec3(3.240479, -0.969256, 0.055648),
	vec3(-1.537150, 1.875992, -0.204043),
	vec3(-0.498535, 0.041556, 1.057311)
);

vec3 rgb_to_xyz(vec3 input) {
	return mat_rgb_to_xyz * input;
}

vec3 xyz_to_rgb(vec3 input) {
	return mat_xyz_to_rgb * input;
}

float f(float t) {
	if (t > 0.008856) return pow(t, 0.333333);
	return 7.787 * t + 0.137931;
}

vec3 xyz_to_cielab(vec3 input) {
	float xn = input.x / X_ABS;
	float yn = input.y / Y_ABS;
	float zn = input.z / Z_ABS;
	float l = 903.3 * yn;
	if (yn > 0.008856) l = 116.0 * pow(yn, 0.333333) - 16.0;
	return vec3(l, 500.0 * (f(xn) - f(yn)), 200.0 * (f(yn) - f(zn)));
}

vec3 cielab_to_xyz(vec3 input) {
	float l = input.x;
	float a = input.y;
	float b = input.z;
	float p = (l + 16.0) / 116.0;
	return vec3(
		X_ABS * pow(p + a / 500.0, 3.0),
		Y_ABS * pow(p, 3.0),
		Z_ABS * pow(p - b / 200.0, 3.0)
	);
}

float trig_interpolate(float x, float a, float b) {
	if (x <= a) return 0.0;
	if (x >= b) return 1.0;
	return 0.5 + 0.5 * cos(PI * x / (b - a) + (1.0 - a / (b - a)) * PI);
}

void fragment() {
	vec4 raw_color;
	float raw_value;
	float highlight; float shadow; float midtone;
	vec4 highlight_color; vec4 shadow_color; vec4 original_color;
	
	raw_color = texture(TEXTURE, UV);
	
	raw_value = 0.3 * raw_color.r + 0.59 * raw_color.g + 0.11 * raw_color.b;
	
	highlight = trig_interpolate(
		raw_value,
		highlight_threshold - highlight_fade_distance,
		highlight_threshold + highlight_fade_distance
	);
	
	shadow = 1.0 - trig_interpolate(
		raw_value,
		shadow_threshold - shadow_fade_distance,
		shadow_threshold + shadow_fade_distance
	);
	
	float highligh_lightness = xyz_to_cielab(rgb_to_xyz(vec3(highlight_threshold + highlight_fade_distance))).x;
	vec3 highlight_color_temp = xyz_to_cielab(rgb_to_xyz(textureLod(TEXTURE, UV, highlight_lod).rgb));
	highlight_color = vec4(
		mix(
			xyz_to_rgb(cielab_to_xyz(vec3(highligh_lightness, highlight_color_temp.y, highlight_color_temp.z))),
			highlight_bias.rgb,
			highlight_bias.a
		),
		1.0
	);
	highlight_color = max(textureLod(TEXTURE, UV, highlight_lod), highlight_color);
	
	float shadow_lightness = xyz_to_cielab(rgb_to_xyz(vec3(shadow_threshold - shadow_fade_distance))).x;
	vec3 shadow_color_temp = xyz_to_cielab(rgb_to_xyz(textureLod(TEXTURE, UV, shadow_lod).rgb));
	shadow_color = vec4(
		mix(
			xyz_to_rgb(cielab_to_xyz(vec3(shadow_lightness, shadow_color_temp.y, shadow_color_temp.z))),
			shadow_bias.rgb,
			shadow_bias.a
		),
		1.0
	);
	shadow_color = min(textureLod(TEXTURE, UV, shadow_lod), shadow_color);
	
	original_color = textureLod(TEXTURE, UV, 0.0);
	
	COLOR = mix(original_color, highlight_color, highlight);
	COLOR = mix(COLOR, shadow_color, shadow);
}