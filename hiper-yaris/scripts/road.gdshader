shader_type spatial;
// UV.x = yanal metre (-kenar..+kenar), UV.y = pist boyunca metre.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float half_width = 9.0;
uniform float track_length = 1000.0;

float band(float v, float a, float b) {
	float aa = fwidth(v) * 1.5;
	return smoothstep(a - aa, a, v) * (1.0 - smoothstep(b, b + aa, v));
}

void fragment() {
	float x = UV.x;
	float s = UV.y;
	vec2 tuv = vec2(x, s) / 5.0;
	vec3 asphalt = texture(albedo_tex, tuv).rgb * vec3(0.78, 0.76, 0.74);
	// Lastik izleri: şerit ortalarında koyulaşma
	float lane_pos = fract((x + half_width) / 4.5);
	asphalt *= 1.0 - 0.12 * (band(lane_pos, 0.18, 0.32) + band(lane_pos, 0.68, 0.82));
	float rough = texture(rough_tex, tuv).r;
	vec3 col = asphalt;
	float ax = abs(x);
	// Sarı kenar çizgisi
	float edge = band(ax, half_width - 0.65, half_width - 0.4);
	col = mix(col, vec3(0.95, 0.72, 0.1), edge);
	// Beyaz kesikli şerit çizgileri
	float dash = step(fract(s / 14.0), 0.45);
	float lanes = band(x, -4.6, -4.4) + band(x, -0.1, 0.1) + band(x, 4.4, 4.6);
	col = mix(col, vec3(0.92), clamp(lanes * dash, 0.0, 1.0));
	// Başlangıç çizgisi (dama)
	float sm = mod(s, track_length);
	if (sm < 3.0 && ax < half_width - 0.4) {
		float chk = mod(floor(x / 1.0) + floor(sm / 1.0), 2.0);
		col = mix(vec3(0.05), vec3(0.95), chk);
	}
	float paint = clamp(edge + lanes * dash, 0.0, 1.0);
	// Banket: tozlu kum geçişi
	if (ax > half_width) {
		vec3 sand = texture(sand_tex, tuv * 0.6).rgb * vec3(0.95, 0.85, 0.75);
		float t = smoothstep(half_width, half_width + 2.5, ax);
		col = mix(asphalt * 1.1, sand, t);
	}
	ALBEDO = col;
	NORMAL_MAP = texture(normal_tex, tuv).rgb;
	NORMAL_MAP_DEPTH = 1.0 - paint * 0.7;
	ROUGHNESS = mix(rough, 0.55, paint);
	SPECULAR = 0.4;
}
