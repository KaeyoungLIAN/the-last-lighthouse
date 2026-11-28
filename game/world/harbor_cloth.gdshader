shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
void vertex() {
	float wind = sin(TIME*2.5 + VERTEX.x*.76) + .28*sin(TIME*5.1+VERTEX.z*.8);
	VERTEX.xz += vec2(.06,.15)*wind*UV.y;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = .96;
}
