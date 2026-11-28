shader_type spatial;
render_mode unshaded;

varying float height;
void vertex() {
	height = VERTEX.y;
}

void fragment() {
	// Each annulus concentrates the light along a slightly different face.
	float ring = fract((height - 13.54) / .112);
	float band = smoothstep(.05, .34, ring) * (1.0 - smoothstep(.44, .96, ring));
	float center = max(0.0, 1.0 - abs(height - 14.25) / .86);
	float facet = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	ALBEDO = mix(vec3(.88,.45,.12), vec3(1.0,.90,.65), band * .84 + facet * .12);
	ALBEDO += vec3(.22,.20,.11) * center * center;
}
