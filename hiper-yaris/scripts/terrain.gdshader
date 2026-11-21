shader_type spatial;
// Kanyon arazisi: eğimli yerlerde katmanlı kaya, düz yerlerde kum/çakıl (triplanar).
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri(sampler2D t, vec3 p, vec3 n, float sc) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy * sc).rgb * w.x + texture(t, p.xz * sc).rgb * w.y + texture(t, p.xy * sc).rgb * w.z;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float slope = 1.0 - wnrm.y;
	vec3 rock = tri(rock_tex, wpos, wnrm, 0.06);
	// Kumtaşı katmanları
	float strata = sin(wpos.y * 0.9 + vnoise(wpos.xz * 0.02) * 6.0) * 0.5 + 0.5;
	vec3 tint = mix(vec3(1.05, 0.72, 0.52), vec3(0.85, 0.5, 0.36), strata);
	rock *= tint * 1.15;
	vec3 sand = texture(sand_tex, wpos.xz * 0.12).rgb * vec3(1.0, 0.86, 0.72);
	vec3 gravel = texture(gravel_tex, wpos.xz * 0.08).rgb * vec3(0.95, 0.8, 0.68);
	float gmix = smoothstep(0.35, 0.65, vnoise(wpos.xz * 0.03));
	vec3 flat_col = mix(sand, gravel, gmix * 0.6);
	float r = smoothstep(0.22, 0.45, slope + (vnoise(wpos.xz * 0.15) - 0.5) * 0.15);
	ALBEDO = mix(flat_col, rock, r);
	vec3 nm = mix(texture(sand_nrm, wpos.xz * 0.12).rgb, tri(rock_nrm, wpos, wnrm, 0.06), r);
	NORMAL_MAP = nm;
	ROUGHNESS = mix(0.95, 0.85, r);
}
