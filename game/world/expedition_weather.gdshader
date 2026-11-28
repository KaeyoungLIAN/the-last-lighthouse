shader_type canvas_item;
render_mode unshaded;
uniform int biome = 0;
uniform float strength : hint_range(0.0,1.0) = 0.0;
uniform float severity : hint_range(0.0,1.0) = 0.0;
uniform float exposure : hint_range(0.0,1.0) = 0.0;
uniform float cold : hint_range(0.0,1.0) = 0.0;
uniform float wash : hint_range(0.0,1.0) = 0.0;
uniform float clock = 0.0;

float rand_cell(vec2 p){
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float noise_field(vec2 p){
	vec2 a=floor(p),t=fract(p);
	t=t*t*(3.0-2.0*t);
	return mix(mix(rand_cell(a),rand_cell(a+vec2(1,0)),t.x),
		mix(rand_cell(a+vec2(0,1)),rand_cell(a+vec2(1,1)),t.x),t.y);
}
void fragment(){
	vec2 uv=UV;
	float edge=smoothstep(.36,1.0,length((uv-.5)*1.65));
	float cloud=noise_field(vec2(uv.x*4.5-clock*.11,uv.y*5.3+.32*sin(uv.x*4.)));
	float bank=smoothstep(.01,.89,cloud);
	vec3 ink=vec3(.91,.96,.95);
	float alpha=0.0;
	if(biome==1){
		ink=vec3(.85,.92,.95);
		alpha=strength*(.035+edge*.14+bank*severity*.31);
	} else if(biome==2){
		ink=vec3(.44,.70,.73);
		alpha=strength*(edge*.14+bank*.035);
	} else if(biome==3){
		ink=vec3(.53,.35,.39);
		alpha=strength*(.013+edge*.12+bank*severity*.06);
	} else if(biome==4){
		ink=vec3(.86,.70,.48);
		float streak=noise_field(vec2(uv.x*4.0-clock*.93,uv.y*27.+uv.x*3.));
		alpha=strength*(.035+.11*edge+severity*.23*streak);
	} else if(biome==5){
		ink=vec3(.73,.85,.82);
		alpha=strength*(.08+.10*edge+severity*bank*.42);
	} else if(biome==6){
		ink=vec3(.41,.60,.43);
		alpha=strength*(edge*.09+bank*severity*.028);
	}
	float stress=exposure*edge*(.20+.13*bank);
	float water=wash*(.28+.58*noise_field(vec2(uv.x*6.+uv.y*12.,uv.y*17.+clock*1.1)));
	vec3 frost=mix(vec3(.86,.50,.31),vec3(.85,.93,.97),cold);
	ink=mix(ink,frost,stress/max(.02,alpha+stress));
	ink=mix(ink,vec3(.57,.80,.80),water/max(.02,alpha+stress+water));
	COLOR=vec4(ink,min(.85,alpha+stress+water));
}
