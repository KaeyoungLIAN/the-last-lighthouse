shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
#include "res://world/coastal_water.gdshaderinc"

uniform bool inside_mirror_room = false;
varying vec3 sea;

void vertex() {
	sea = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = sea.xz;
	if (inside_mirror_room && distance(p, vec2(0.0, 130.0)) < 16.8) { discard; }
	float depth = max(0.0, sea.y - bed_height(p));
	float near_detail = 1.0 - smoothstep(24.0, 115.0, length(VERTEX));
	float broad = wash_noise(p * .11);
	float flecks = wash_noise(p * 1.85 + vec2(TIME * .07, -TIME * .12));
	float shoal = exp(-depth * .75);
	vec3 bottom = mix(vec3(.17, .405, .355), vec3(.39, .53, .386), broad);
	vec3 body = mix(vec3(.064, .235, .270), bottom, shoal);
	// Sparse sunlight ribbons on the bottom disappear as the water deepens.
	float strands = abs(sin(dot(p, vec2(1.8, .81)) + 2.7 * sin(p.y * 1.84 + TIME * .57)
		+ 3.4 * flecks - TIME * .77));
	body += vec3(.042, .069, .040) * (1.0 - smoothstep(.06, .30, strands)) * shoal * near_detail;
	vec2 slope = wind_slope(p, TIME, near_detail);
	NORMAL = normalize((VIEW_MATRIX * vec4(-slope.x, 1.0, -slope.y, 0.0)).xyz);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);
	body = mix(body, vec3(.24, .39, .405), rim * .42);

	// Depth contours follow the actual water level. The swash rolls shoreward,
	// thins to broken lace, and leaves small flecks behind.
	float swash = .5 + .5 * sin(TIME * 1.17 + broad * 5.0);
	float distance_to_crest = abs(depth - .16 - swash * .20 - (flecks - .5) * .18);
	float lip = 1.0 - smoothstep(.018, .068 + fwidth(depth) * .5, distance_to_crest);
	float soft_edge = 1.0 - smoothstep(.045, .21, depth + (flecks - .5) * .16);
	float foam = clamp(lip * smoothstep(.16, .60, flecks) + soft_edge * .48, 0.0, 1.0) * near_detail;
	ALBEDO = mix(body, vec3(.73, .82, .75), foam * .84);
	ROUGHNESS = mix(.46, .78, foam);
	SPECULAR = mix(.33, .18, foam);
}
