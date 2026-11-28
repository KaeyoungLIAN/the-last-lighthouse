shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

// A lengthwise section through the shaft always faces the viewer. Its silhouette
// and far end both fade to zero, even against a clear night sky.
varying float along;
varying float across;

void vertex() {
	vec3 origin = MODELVIEW_MATRIX[3].xyz;
	vec3 axis = normalize(MODELVIEW_MATRIX[0].xyz);
	vec3 side = cross(axis, normalize(origin));
	side /= max(length(side), .0001);
	along = clamp(VERTEX.x / 34.0, 0.0, 1.0);
	float width = mix(.57, 5.5, along);
	across = VERTEX.y * width / 5.5;
	VERTEX = origin + axis * (34.0 * along) + side * across;
}

void fragment() {
	float edge = 1.0 - smoothstep(.0, 1.0, abs(across) / mix(.57, 5.5, along));
	float travel = (1.0 - smoothstep(.05, 1.0, along)) * smoothstep(.0, .034, along);
	float haze = .95 + .05 * sin(along * 27.0 + across * 2.1 - TIME * .35);
	ALBEDO = mix(vec3(1.0, .67, .31), vec3(.90, .80, .57), along);
	ALPHA = edge * travel * haze * .38;
}
