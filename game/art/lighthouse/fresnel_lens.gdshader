shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform bool burning = false;
varying vec3 glass_point;

void vertex() {
	glass_point = VERTEX;
}

void fragment() {
	// The profile is stepped in the mesh. Every polished facet catches a different strip of light.
	float height = clamp((glass_point.y - 2.22) / .91, 0., 1.);
	float rib = fract((glass_point.y - 2.22) / .103);
	float lip = smoothstep(.0, .24, rib) * (1. - smoothstep(.33, .72, rib));
	float rim = pow(1. - max(0., dot(normalize(NORMAL), normalize(VIEW))), 2.);
	float angle = atan(glass_point.x, glass_point.z);
	float reflection = pow(.5 + .5 * cos(angle * 2. - .78), 12.);
	float core = exp(-5.6 * abs(height - .50)) * (.45 + .55 * reflection);
	vec3 edge = burning ? vec3(.39,.20,.058) : vec3(.055,.18,.19);
	vec3 glass = burning ? vec3(.89,.65,.25) : vec3(.35,.59,.55);
	ALBEDO = mix(edge, glass, .29 + .49 * lip + .18 * rim);
	ROUGHNESS = mix(.25, .12, lip);
	SPECULAR = .76;
	METALLIC = .10;
	EMISSION = burning ? vec3(1.,.73,.31) * (.19 + .59 * lip + 1.1 * core)
		: vec3(.18,.32,.29) * (.10 * rim + .12 * lip);
}
