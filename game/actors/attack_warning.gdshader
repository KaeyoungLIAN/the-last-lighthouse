shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform float charge : hint_range(0.0,1.0) = 0.0;

void fragment() {
	float rim = smoothstep(.94,.975,UV.y);
	float side = (1.0 - smoothstep(.006,.018,min(UV.x,1.0-UV.x))) * smoothstep(.08,.32,UV.y);
	float front = 1.0 - smoothstep(.012,.045,abs(UV.y-charge));
	float ink = max(max(side,rim),front);
	vec3 tone = mix(vec3(.90,.20,.065),vec3(1.0,.83,.48),smoothstep(.72,.98,charge));
	ALBEDO = mix(tone * .48,tone,ink);
	ALPHA = (.15 + .12*step(UV.y,charge) + .65*ink) * smoothstep(.01,.09,UV.y);
}
