shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
instance uniform float phase=0.;
float hash2(vec2 c){return fract(sin(dot(c,vec2(27.19,35.11)))*4327.75);}
float cloud(vec2 q){
	vec2 c=floor(q),f=fract(q);f=f*f*(3.-2.*f);
	return mix(mix(hash2(c),hash2(c+vec2(1,0)),f.x),mix(hash2(c+vec2(0,1)),hash2(c+1.),f.x),f.y);
}
void vertex(){
	mat4 billboard=mat4(normalize(INV_VIEW_MATRIX[0]),vec4(0.,1.,0.,0.),normalize(INV_VIEW_MATRIX[2]),MODEL_MATRIX[3]);
	MODELVIEW_MATRIX=VIEW_MATRIX*billboard;
}
void fragment(){
	float y=1.-UV.y;
	float t=TIME*.28+phase*10.;
	float n=cloud(vec2(UV.x*3.,y*3.4-t));
	float center=.43+.14*y+.12*sin(y*7.1-t*1.8)*y+.09*(n-.5);
	float r=abs(UV.x-center)/(.08+.37*y);
	float blend=(1.-smoothstep(.08,1.,r))*(1.-smoothstep(.38,.98,y))*smoothstep(.0,.16,y);
	ALBEDO=mix(vec3(.51,.48,.43),vec3(.76,.77,.73),n);
	ALPHA=blend*.34*smoothstep(.13,.77,n+.18*cloud(vec2(UV.x*9.,y*11.-1.65*t)));
}
