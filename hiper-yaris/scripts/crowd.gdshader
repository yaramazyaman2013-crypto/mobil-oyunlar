shader_type spatial;
// Tribün seyirci sırası: her kişi kendi ritminde zıplar ("cheer" yarış başı/bitişte artar)
render_mode cull_disabled, depth_prepass_alpha;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float cheer = 0.25;
uniform float people = 24.0;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	float pid = floor(UV.x * people) + floor(UV2.x) * 97.0;
	float r = hash(pid);
	float speed = 5.0 + r * 4.0;
	float jump = max(0.0, sin(TIME * speed + r * 6.283)) * (0.06 + 0.1 * cheer) * step(0.35 - cheer * 0.3, r);
	vec4 c = texture(tex, vec2(UV.x, UV.y + jump));
	if (UV.y + jump > 1.0) c.a = 0.0;
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb * (0.85 + 0.15 * hash(pid + 7.0));
	ROUGHNESS = 0.9;
}
