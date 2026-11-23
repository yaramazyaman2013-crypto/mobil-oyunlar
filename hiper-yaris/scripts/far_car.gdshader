shader_type spatial;
// Uzak araç kopyası: tek yüzey, malzeme renkleri köşe renginde. Boyalı yüzeyler (alfa=0) örnek başına boyanır.
instance uniform vec3 paint = vec3(1.0);
instance uniform float paint_on = 0.0;

void fragment() {
	vec3 c = COLOR.rgb;
	if (paint_on > 0.5) c = mix(paint, c, COLOR.a);
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.35;
	METALLIC = 0.35;
}
