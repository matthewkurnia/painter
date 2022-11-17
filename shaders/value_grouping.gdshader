shader_type canvas_item;

uniform float highlight_threshold: hint_range(0.0, 1.0) = 0.9;
uniform float highlight_fade_distance: hint_range(0.0, 0.2) = 0.05;
uniform float highlight_lod: hint_range(0.0, 10.0, 0.5) = 2.0;
uniform float shadow_threshold: hint_range(0.0, 1.0) = 0.2;
uniform float shadow_fade_distance: hint_range(0.0, 0.2) = 0.05;
uniform float shadow_lod: hint_range(0.0, 10.0, 0.5) = 4.0;
uniform vec4 shadow_bias: hint_color;

const float PI = 3.14159265358979323846;

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
	
//	COLOR = vec4(vec3(shadow), 1.0);
//	COLOR = vec4(vec3(highlight), 1.0);
	highlight_color = textureLod(TEXTURE, UV, highlight_lod);
	shadow_color = min(textureLod(TEXTURE, UV, shadow_lod), shadow_bias);
	original_color = textureLod(TEXTURE, UV, 0.0);
	
	COLOR = mix(original_color, highlight_color, highlight);
	COLOR = mix(COLOR, shadow_color, shadow);
}