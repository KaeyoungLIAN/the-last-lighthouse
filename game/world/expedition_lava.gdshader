shader_type spatial;
render_mode cull_disabled, unshaded;
varying vec2 p;
float h(vec2 c) { return fract(sin(dot(c,vec2(127.13,311.71)))*43758.54); }
float noise2(vec2 x) {
	vec2 i=floor(x),f=fract(x);
	f=f*f*(3.-2.*f);
	return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+1.),f.x),f.y);
}
void vertex() {p=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment() {
	float bank=abs(UV.x-.5)*2.;
	float slow=TIME*.095;
	vec2 warp=p*vec2(.54,.72)+vec2(noise2(p*.31+slow),noise2(p*.24-slow));
	float fissure=abs(noise2(warp+vec2(0.,slow))-.49);
	float broken=1.-smoothstep(.019,.14,fissure);
	float skin=noise2(p*1.75);
	float core=(1.-smoothstep(.46,.94,bank+.20*(skin-.5)))*(.35+.65*broken);
	vec3 stone=mix(vec3(.18,.14,.15),vec3(.28,.19,.16),skin);
	vec3 amber=mix(vec3(.68,.24,.10),vec3(1.,.66,.25),broken*smoothstep(.2,.75,core));
	ALBEDO=mix(stone,amber,core);
	if (bank>.88+.115*noise2(p*1.14)) {discard;}
}
