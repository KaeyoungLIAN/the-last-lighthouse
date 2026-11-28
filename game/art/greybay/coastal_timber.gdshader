shader_type spatial;
uniform sampler2D brush : repeat_enable, filter_linear_mipmap_anisotropic;

void fragment() {
	// BrushUV follows the long axis of each timber in the Blender kit.
	vec3 marks = texture(brush, UV * vec2(.64,.79)).rgb;
	float fibre = smoothstep(.48,.78,marks.b);
	float weather = smoothstep(.56,.77,marks.r*.72 + marks.g*.28);
	vec3 timber = COLOR.rgb * (.83 + .21 * marks.r - .23*fibre);
	ALBEDO = mix(timber, timber*.84 + vec3(.085,.095,.078), weather*.65);
	ROUGHNESS = .62 + .23*fibre + .10*weather;
	SPECULAR = .34;
}
