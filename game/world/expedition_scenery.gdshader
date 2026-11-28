shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform int terrain_kind=0;
varying vec3 place;
float hash2(vec2 p) {
	vec3 q=fract(vec3(p.xyx)*vec3(.1031,.1030,.0973));
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float noise2(vec2 p) {
	vec2 cell=floor(p),f=fract(p);f=f*f*(3.-2.*f);
	return mix(mix(hash2(cell),hash2(cell+vec2(1,0)),f.x),mix(hash2(cell+vec2(0,1)),hash2(cell+1.),f.x),f.y);
}
void vertex(){place=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
	vec2 cliff=vec2(place.x*.66+place.z*.81,place.y);
	float broad=noise2(cliff*.66),rough=noise2(cliff*2.80);
	float marks=0.;
	if(terrain_kind==0){
		float vein=abs(noise2(cliff*vec2(1.1,.30))-.53);
		marks=.085*(1.-smoothstep(.016,.06,vein))+.05*(broad-.5);
	}else if(terrain_kind==1 || terrain_kind==3){
		float bed=.5+.5*sin(place.y*8.1+cliff.x*.48+2.4*broad);
		marks=.15*(broad-.53)+.10*(rough-.5)-.10*smoothstep(.76,.96,bed)*smoothstep(.25,.85,rough);
	}else if(terrain_kind==2){
		marks=.13*(rough-.5)-.07*smoothstep(.66,.81,broad);
	}else{
		marks=.105*(broad-.5)+.065*(rough-.5);
	}
	ALBEDO=COLOR.rgb*(1.+marks);
	ROUGHNESS=.95;
}
