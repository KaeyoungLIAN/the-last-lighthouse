shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 enamel : source_color = vec4(1.);
uniform float pulse = 0.;
uniform bool filament = false;
uniform float travel = -1.;
varying float elevation;

void vertex() {
	elevation = VERTEX.y;
}

void fragment() {
	if (filament) {
		float h = clamp((elevation-1.53)/1.18,0.,1.);
		float head = 1.-smoothstep(.015,.22,abs(travel-h));
		float tail = .35*(1.-smoothstep(.04,.50,travel-h))*step(h,travel);
		ALBEDO = mix(enamel.rgb,vec3(1.,.83,.46),h*.75+.20);
		ALPHA = max(head,tail)*pulse;
	} else {
		ALBEDO = mix(enamel.rgb,vec3(1.,.82,.47),.48);
		ALPHA = pulse*.82;
	}
}
