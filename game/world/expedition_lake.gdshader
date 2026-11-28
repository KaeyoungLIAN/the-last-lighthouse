shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
#include "res://world/coastal_water.gdshaderinc"
varying vec3 pond;

void vertex() {
	pond = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = pond.xz;
	vec2 q = (p - vec2(446.0, 13.0)) / vec2(63.0, 50.0);
	if (length(q) > 1.045 + .025 * sin(atan(q.y, q.x) * 5.0)) { discard; }
	float depth = max(0.0, pond.y - bed_height(p));
	float shoal = exp(-depth * .92);
	float detail = 1.0 - smoothstep(25.0, 95.0, length(VERTEX));
	float reeds = wash_noise(p * .27);
	vec3 bank = mix(vec3(.23, .36, .22), vec3(.44, .47, .30), reeds);
	vec3 water = mix(vec3(.105, .27, .26), bank, shoal);
	vec2 slope = wind_slope(p * .82, TIME * .64, detail) * .50;
	NORMAL = normalize((VIEW_MATRIX * vec4(-slope.x, 1.0, -slope.y, 0.0)).xyz);
	float reflectivity = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(water, vec3(.30, .42, .39), .33 * reflectivity);
	ROUGHNESS = .44;
	SPECULAR = .34;
}
