shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled;

void vertex() {
	// UV.y increases from the rooted base to the tips of leaves and flower stems.
	vec2 base = MODEL_MATRIX[3].xz;
	float breeze = sin(TIME * 1.32 + dot(base, vec2(.35, .21)));
	float gust = sin(TIME * 2.27 + dot(base, vec2(-.18, .43)));
	VERTEX.xz += vec2(.085, .042) * (.7 * breeze + .3 * gust) * UV.y * UV.y;
}

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = .95;
}
