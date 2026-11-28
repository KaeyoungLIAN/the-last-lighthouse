shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float flow : hint_range(0.0,1.0)=0.28;
void fragment(){
	vec2 p=UV*2.0-1.0;
	float rad=length(p);
	float ridge=abs(p.y-.16*sin(p.x*9.0+TIME*.6)-.20*p.x);
	float seam=1.0-smoothstep(.035,.095,ridge);
	float narrow=abs(p.y+.21+.46*p.x+.11*sin(p.x*12.));
	seam=max(seam,1.0-smoothstep(.024,.068,narrow));
	float edge=smoothstep(.60,.92,rad)*(1.-smoothstep(.90,.98,rad));
	float light=(.55+.45*sin(TIME*2.4-p.x*7.))*flow;
	ALBEDO=mix(vec3(.57,.14,.045),vec3(1.,.60,.19),light);
	ALPHA=clamp((seam*.74+edge*.80)*flow*(1.-smoothstep(.88,1.,rad)),0.,.92);
}
