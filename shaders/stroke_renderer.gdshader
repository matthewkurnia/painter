shader_type spatial;
render_mode async_visible, blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;

const float stroke_size_bias = 0.5;

uniform vec3 light_position;
uniform vec4 light_color: hint_color;
uniform vec4 shadow_color: hint_color;
uniform float specularity = 10.0;

uniform bool rejection_sampling = true;
uniform sampler2D source;
uniform sampler2D stroke_height_texture;
uniform sampler2D stroke_normal_texture;
uniform sampler2D canvas;
uniform sampler2D depth_motion;
uniform float canvas_roughness;
uniform float screen_width = 1024;
uniform float screen_height = 600;
uniform float smudge_amount = 1.0;
uniform float offset_amount = 0.4;
uniform float distorsion_amount: hint_range(0.0, 0.1) = 0.03;

uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform int particles_anim_h_frames;
uniform int particles_anim_v_frames;
uniform bool particles_anim_loop;
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// value grouping
uniform float highlight_threshold: hint_range(0.0, 1.0) = 0.9;
uniform float highlight_fade_distance: hint_range(0.0, 0.2) = 0.05;
uniform float highlight_lod: hint_range(0.0, 10.0, 0.5) = 2.0;
uniform vec4 highlight_bias: hint_color;
uniform float shadow_threshold: hint_range(0.0, 1.0) = 0.2;
uniform float shadow_fade_distance: hint_range(0.0, 0.2) = 0.05;
uniform float shadow_lod: hint_range(0.0, 10.0, 0.5) = 4.0;
uniform float shadow_cutoff: hint_range(0.0, 1.0) = 0.2;
uniform vec4 shadow_fringe_bias: hint_color;
uniform float shadow_fringe_amount: hint_range(0.0, 1.0) = 0.5;

// kuwahara
uniform int radius = 3;
uniform vec3 offset = vec3(0.0);
uniform sampler2D noise_texture;

// blur
uniform int buffer_width: hint_range(5, 1000, 1) = 7;

const float PI = 3.14159265358979323846;

const vec2 B0 = vec2(0.0, 0.0);
const vec2 B1 = vec2(0.5, 0.0);
const vec2 B2 = vec2(0.5, 1.0);
const vec2 B3 = vec2(1.0, 1.0);

float trig_interpolate(float x, float a, float b) {
	if (x <= a) return 0.0;
	if (x >= b) return 1.0;
	return 0.5 + 0.5 * cos(PI * x / (b - a) + (1.0 - a / (b - a)) * PI);
}

vec2 bezier_interpolate(vec2 q0, vec2 q1, vec2 q2, vec2 q3, float t) {
	q0 = mix(q0, q1, t);
	q1 = mix(q1, q2, t);
	q2 = mix(q2, q3, t);
	q0 = mix(q0, q1, t);
	q1 = mix(q1, q2, t);
	q0 = mix(q0, q1, t);
	return q0;
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

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	mat4 mat_world = mat4(normalize(CAMERA_MATRIX[0])*length(WORLD_MATRIX[0]),normalize(CAMERA_MATRIX[1])*length(WORLD_MATRIX[0]),normalize(CAMERA_MATRIX[2])*length(WORLD_MATRIX[2]),WORLD_MATRIX[3]);
	mat_world = mat_world * mat4( vec4(cos(INSTANCE_CUSTOM.x),-sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0),vec4(0.0, 0.0, 1.0, 0.0),vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = INV_CAMERA_MATRIX * mat_world;
	float h_frames = float(particles_anim_h_frames);
	float v_frames = float(particles_anim_v_frames);
	float particle_total_frames = float(particles_anim_h_frames * particles_anim_v_frames);
	float particle_frame = floor(INSTANCE_CUSTOM.z * float(particle_total_frames));
	if (!particles_anim_loop) {
		particle_frame = clamp(particle_frame, 0.0, particle_total_frames - 1.0);
	} else {
		particle_frame = mod(particle_frame, particle_total_frames);
	}	UV /= vec2(h_frames, v_frames);
	UV += vec2(mod(particle_frame, h_frames) / h_frames, floor((particle_frame + 0.5) / h_frames) / v_frames);
}

float grainify(float x, float a) {
	x -= 0.5;
	a -= 0.5;
	return max(min(canvas_roughness * (x + a) + 0.5, 1.0), 0.0);
}

vec4 kuwahara(vec2 pixel_size, vec2 uv) {
	float n = float((radius + 1) * (radius + 1));
	vec3 m0 = offset; vec3 m1 = offset; vec3 m2 = offset; vec3 m3 = offset;
	vec3 s0 = offset; vec3 s1 = offset; vec3 s2 = offset; vec3 s3 = offset;
	vec3 c;
	
	for (int j = -radius; j <= 0; ++j) {
		for (int i = -radius; i <= 0; ++i) {
			c = texture(source, uv + vec2(float(i),float(j)) * pixel_size).rgb;
			m0 += c;
			s0 += c * c;
		}
	}
	
	for (int j = -radius; j <= 0; ++j)  {
	for (int i = 0; i <= radius; ++i)  {
		c = texture(source, uv + vec2(float(i),float(j)) * pixel_size).rgb;
			m1 += c;
			s1 += c * c;
		}
	}
	
	for (int j = 0; j <= radius; ++j)  {
		for (int i = 0; i <= radius; ++i)  {
			c = texture(source, uv + vec2(float(i),float(j)) * pixel_size).rgb;
			m2 += c;
			s2 += c * c;
		}
	}
	
	for (int j = 0; j <= radius; ++j)  {
		for (int i = -radius; i <= 0; ++i)  {
			c = texture(source, uv + vec2(float(i),float(j)) * pixel_size).rgb;
			m3 += c;
			s3 += c * c;
		}
	}
	
	vec4 color;
	
	float min_sigma2 = 1e+2;
	m0 /= n;
	s0 = abs(s0 / n - m0 * m0);

	float sigma2 = s0.r + s0.g + s0.b;
	if (sigma2 < min_sigma2) {
		min_sigma2 = sigma2;
		color = vec4(m0, 1.0);
	}
	
	m1 /= n;
	s1 = abs(s1 / n - m1 * m1);
	
	sigma2 = s1.r + s1.g + s1.b;
	if (sigma2 < min_sigma2) {
		min_sigma2 = sigma2;
		color = vec4(m1, 1.0);
	}
	
	m2 /= n;
	s2 = abs(s2 / n - m2 * m2);
	
	sigma2 = s2.r + s2.g + s2.b;
	if (sigma2 < min_sigma2) {
		min_sigma2 = sigma2;
		color = vec4(m2, 1.0);
	}
	
	m3 /= n;
	s3 = abs(s3 / n - m3 * m3);
	
	sigma2 = s3.r + s3.g + s3.b;
	if (sigma2 < min_sigma2) {
		min_sigma2 = sigma2;
		color = vec4(m3, 1.0);
	}
	
	return mix(color, textureLod(source, uv, 2), texture(canvas, uv).r);
}

void fragment() {
	
//	generated start
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	albedo_tex *= COLOR;
	
	vec2 normalized_position = COLOR.xy;
	float angle = COLOR.z;
	float scale = COLOR.w;
	mat2 rotation;
	rotation[0] = vec2(cos(angle), -sin(angle));
	rotation[1] = vec2(sin(angle), cos(angle));
	
	vec4 height_color = texture(stroke_height_texture, UV);
	float height = height_color.x;
	float alpha = height_color.a;
	
	float ratio = screen_height / screen_width;
	
	vec2 uv_with_offset = SCREEN_UV + rotation * vec2(0.0, (height - 0.5) * distorsion_amount);
	vec2 uv_with_more_offset = SCREEN_UV + rotation * vec2(0.0, (height - 0.5) * distorsion_amount * 5.0);
	
	vec3 kuwa_color = kuwahara(vec2(1.0/screen_width, 1.0/screen_height), uv_with_offset).rgb;
	
	vec4 raw_color = texture(source, uv_with_offset);
	float raw_value = lum(raw_color.rgb);
	float shadow = 1.0 - trig_interpolate(
		raw_value,
		shadow_threshold - shadow_fade_distance,
		shadow_threshold + shadow_fade_distance
	);
	
	float f_buffer_width = float(buffer_width);
	vec2 pixelated_uv = floor(uv_with_more_offset * f_buffer_width * vec2(1.0, ratio)) / (f_buffer_width * vec2(1.0, ratio));
	vec3 blurred_color = mix(
		mix(
			texture(source, pixelated_uv),
			texture(source, pixelated_uv + vec2(sign(SCREEN_UV.x - pixelated_uv.x) / f_buffer_width, 0)),
			bezier_interpolate(B0, B1, B2, B3, abs(SCREEN_UV.x - pixelated_uv.x) * f_buffer_width).y
		),
		mix(
			texture(source, pixelated_uv + vec2(0.0, sign(SCREEN_UV.y - pixelated_uv.y) / (f_buffer_width * ratio))),
			texture(source, pixelated_uv + vec2(sign(SCREEN_UV.x - pixelated_uv.x) / f_buffer_width, sign(SCREEN_UV.y - pixelated_uv.y) / (f_buffer_width * ratio))),
			bezier_interpolate(B0, B1, B2, B3, abs(SCREEN_UV.x - pixelated_uv.x) * f_buffer_width).y
		),
		bezier_interpolate(B0, B1, B2, B3, (SCREEN_UV.y - pixelated_uv.y) * f_buffer_width * ratio).y
	).rgb;
	float blurred_value = lum(blurred_color);
	blurred_color = mix(blurred_color, shadow_fringe_bias.rgb, shadow_fringe_amount);
//	blurred_color = set_lum(blurred_color, min(blurred_value, shadow_threshold - shadow_fade_distance));
	blurred_color = set_lum(blurred_color, max(raw_value, shadow_cutoff));
	
	bool stroke_overlaps_light = true;
	vec3 stroke_color;
	vec3 upper_color = texture(
		source,
		normalized_position + rotation * vec2(0.0, 0.5 * stroke_size_bias) * vec2(ratio, 1.0) * scale
	).rgb;
	vec3 lower_color = texture(
		source,
		normalized_position + rotation * vec2(0.0, -0.5 * stroke_size_bias) * vec2(ratio, 1.0) * scale
	).rgb;
	vec3 core_color = texture(source, normalized_position).rgb;
	if (UV.y <= 0.5) {
		stroke_color = mix(upper_color, core_color, UV.y * 2.0);
	} else {
		stroke_color = mix(core_color, lower_color, (UV.y - 0.5) * 2.0);
	}
	stroke_color = mix(stroke_color, core_color, (1.0 - smudge_amount) * height);
	if (rejection_sampling) {
		float upper_value = lum(upper_color);
		bool upper_is_shadow = shadow_threshold > trig_interpolate(
			upper_value,
			shadow_threshold - shadow_fade_distance,
			shadow_threshold + shadow_fade_distance
		);
		float lower_value = lum(lower_color);
		bool lower_is_shadow = shadow_threshold > trig_interpolate(
			lower_value,
			shadow_threshold - shadow_fade_distance,
			shadow_threshold + shadow_fade_distance
		);
		float core_value = lum(core_color);
		bool core_is_shadow = shadow_threshold > trig_interpolate(
			core_value,
			shadow_threshold - shadow_fade_distance,
			shadow_threshold + shadow_fade_distance
		);
		stroke_overlaps_light = !upper_is_shadow || !lower_is_shadow || !core_is_shadow;
//		use_multi_sampling =
//			(!upper_is_shadow && !lower_is_shadow && !core_is_shadow) ||
//			(upper_is_shadow && lower_is_shadow && core_is_shadow);
//		if (upper_is_shadow) stroke_color = upper_color;
//		else if (core_is_shadow) stroke_color = core_color;
//		else if (lower_is_shadow) stroke_color = lower_color;
//		if (!use_multi_sampling) stroke_color = vec3(0.0);
	}
	
//	ALBEDO = texture(source, pixelated_uv).rgb;
//	ALBEDO = blurred_color;
	
	if (stroke_overlaps_light && rejection_sampling) {
		ALBEDO = mix(kuwa_color, blurred_color, shadow);
	} else {
		ALBEDO = mix(kuwa_color, mix(stroke_color, blurred_color, 0.5), shadow);
	}
//	if (use_multi_sampling) {
//		ALBEDO = vec3(0.0);
//	}
//	ALBEDO = kuwa_color;
	
	vec3 light = normalize(light_position - vec3(SCREEN_UV - vec2(0.5), 0.0));
	vec3 camera = normalize(vec3(vec2(0.5) - SCREEN_UV, 1.0));
	vec3 normal = normalize(texture(stroke_normal_texture, UV).rgb * 2.0 - vec3(1.0));
	normal = vec3(rotation * normal.xy, normal.z);
	vec3 r = reflect(-light, normal);
	ALBEDO = ALBEDO * mix(vec3(1.0), shadow_color.rgb, dot(normal, light));
	ALBEDO = ALBEDO + max(mix(vec3(0.0), light_color.rgb, pow(dot(r, camera), specularity)), vec3(0.0));
	
	ALPHA = grainify(
		texture(canvas, SCREEN_UV).x,
		texture(stroke_height_texture, UV).a
	);
	ALPHA = texture(stroke_height_texture, UV).a;
}
