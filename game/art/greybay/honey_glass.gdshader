shader_type spatial;

// Opaque painted panes keep the arched windows legible through fog and at night.
varying vec3 pane_position;
varying vec3 pane_normal;

void vertex() {
	pane_position = VERTEX;
	pane_normal = NORMAL;
}

void fragment() {
	float across = dot(pane_position.xz, vec2(pane_normal.z,-pane_normal.x));
	float stripe = fract(pane_position.y*.97 - across*.38);
	float glint = smoothstep(.54,.64,stripe) * (1.0-smoothstep(.68,.83,stripe));
	float high = smoothstep(1.18,2.47,pane_position.y);
	float grazing = pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
	vec3 interior = COLOR.rgb * vec3(.75,.78,.68);
	vec3 sky = vec3(.31,.53,.54);
	vec3 stained = mix(interior, sky, high*.75 + grazing*.18);
	stained += vec3(.14,.17,.16) * glint * (.33 + .62*high);
	float roof_lantern = smoothstep(3.2,4.4,pane_position.y);
	ALBEDO = mix(stained, COLOR.rgb, roof_lantern);
	EMISSION = mix(vec3(.053,.032,.011),vec3(.17,.095,.027),roof_lantern);
	ROUGHNESS = .24;
	SPECULAR = .55;
}
