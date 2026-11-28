shader_type spatial;

uniform float flame : hint_range(0.0, 1.0) = 0.0;
varying vec3 pane_position;

void vertex() {
	pane_position = VERTEX;
}

void fragment() {
	float height = pane_position.y + 0.5;
	// Pressed glass has a stronger reflection along each horizontal rib.
	float ribs = pow(0.5 + 0.5 * cos(height * 37.7), 10.0);
	vec3 cold_glass = mix(vec3(0.10, 0.16, 0.15), vec3(0.36, 0.48, 0.45), height);
	float mantle = 1.0 - smoothstep(0.0, 0.55, abs(height - 0.38));
	ALBEDO = mix(cold_glass + ribs * 0.05, vec3(0.74, 0.39, 0.12), flame);
	EMISSION = flame * mix(vec3(0.9, 0.26, 0.045), vec3(2.8, 1.58, 0.50), mantle + ribs * 0.03);
	ROUGHNESS = 0.28;
	SPECULAR = 0.6;
}
