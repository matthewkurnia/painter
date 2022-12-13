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

float trig_interpolate(float x, float a, float b) {
	if (x <= a) return 0.0;
	if (x >= b) return 1.0;
	return 0.5 + 0.5 * cos(PI * x / (b - a) + (1.0 - a / (b - a)) * PI);
}

float lum(vec3 c) {
	return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
}

vec3 clip_color(vec3 c) {
	vec3 _c = c;
	float l = lum(_c);
	float n = min(_c.r, min(_c.g, _c.b));
	float x = max(_c.r, max(_c.g, _c.b));
	if (n < 0.0) {
		_c.r = l + (((_c.r - l) * l) / (l - n));
		_c.g = l + (((_c.g - l) * l) / (l - n));
		_c.b = l + (((_c.b - l) * l) / (l - n));
	}
	if (x > 1.0) {
		_c.r = l + (((_c.r - l) * (1.0 - l)) / (l - n));
		_c.g = l + (((_c.g - l) * (1.0 - l)) / (l - n));
		_c.b = l + (((_c.b - l) * (1.0 - l)) / (l - n));
	}
	return _c;
}

vec3 set_lum(vec3 c, float l) {
	float d = l - lum(c);
	return clip_color(c + vec3(d));
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
	
	highlight_color = vec4(set_lum(
		textureLod(TEXTURE, UV, shadow_lod).rgb,
		highlight_threshold + highlight_fade_distance
	), 1.0);
	highlight_color = max(textureLod(TEXTURE, UV, highlight_lod), highlight_color);
	
	shadow_color = vec4(set_lum(
		textureLod(TEXTURE, UV, shadow_lod).rgb,
		shadow_threshold - shadow_fade_distance
	), 1.0);
	shadow_color = min(textureLod(TEXTURE, UV, shadow_lod), shadow_color);
	
	original_color = textureLod(TEXTURE, UV, 0.0);
	
	COLOR = mix(original_color, highlight_color, highlight);
	COLOR = mix(COLOR, shadow_color, shadow);
//	COLOR = mix(COLOR, textureLod(TEXTURE, UV, shadow_lod), shadow);
//	COLOR = vec4(set_lum(original_color.rgb, 0.5), 0.5);
}