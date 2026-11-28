shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// A continuous survey writes four province weights to CUSTOM0 and the last two to UV2.
uniform int province = -1;
// R = short grasses, G = rolled gravel and mud, B = fractured stone.
uniform sampler2D ground_pigments : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D harbor_flagstones : repeat_enable, filter_linear_mipmap_anisotropic;
varying vec2 ground;
varying float upward;
varying vec2 slope_direction;
varying vec4 western;
varying vec2 eastern;
float hash21(vec2 q) {
	vec3 h = fract(vec3(q.xyx) * vec3(.1031,.1030,.0973));
	h += dot(h,h.yzx+33.33);
	return fract((h.x+h.y)*h.z);
}
float wash(vec2 q) {
	vec2 cell=floor(q), d=fract(q);
	d=d*d*(3.-2.*d);
	return mix(mix(hash21(cell),hash21(cell+vec2(1.,0.)),d.x),
		mix(hash21(cell+vec2(0.,1.)),hash21(cell+1.),d.x),d.y);
}
float path_span(vec2 p, vec2 start, vec2 end) {
	vec2 span = end - start;
	return length(p-start-span*clamp(dot(p-start,span)/dot(span,span),0.0,1.0));
}

// Old flagstones survive on the quay street, the library forecourt and the cape landing.
float paved_distance(vec2 p) {
	float d = path_span(p, vec2(-38.,36.4),vec2(-40.,31.));
	d = min(d,path_span(p,vec2(-40.,31.),vec2(-36.,22.))+.13);
	d = min(d,path_span(p,vec2(-40.,31.),vec2(-29.,29.))+.08);
	d = min(d,path_span(p,vec2(-29.,29.),vec2(-29.6,23.15))-.26);
	d = min(d,path_span(p,vec2(35.1,28.8),vec2(40.9,32.))+.24);
	return min(d,path_span(p,vec2(40.9,32.),vec2(41.,30.45))-.18);
}
void vertex() {
	ground=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;
	upward = NORMAL.y;
	slope_direction = NORMAL.xz;
	western=CUSTOM0;
	eastern=UV2;
	// Single-province terrain meshes also work during standalone survey previews.
	if (province >= 0) {
		western=vec4(float(province==0),float(province==1),float(province==2),float(province==3));
		eastern=vec2(float(province==4),float(province==5));
	}
}
void fragment() {
	vec2 p=ground;
	float local=wash(p*.36), area=wash(p*.072), grit=wash(p*2.05);
	float near_detail=1.-smoothstep(.04,.48,max(fwidth(p).x,fwidth(p).y));
	float home=clamp(1.-dot(western,vec4(1.))-dot(eastern,vec2(1.)),0.,1.);
	float edge=UV.x+.77*(local-.5)+.30*(grit-.5);
	float trail=(1.-smoothstep(.82,2.55,edge))*smoothstep(.32,1.,UV.y);
	vec3 soil=COLOR.rgb*(.88+.14*local+.10*area);
	vec3 ink=western.r*vec3(.47,.54,.53)+western.g*vec3(.39,.38,.29)+western.b*vec3(.24,.21,.21)
		+western.a*vec3(.58,.43,.31)+eastern.x*vec3(.40,.41,.30)+eastern.y*vec3(.32,.30,.20)+home*vec3(.57,.48,.32);
	if (western.r>.001) {
		// Short wind-carved ledges over blue, occasionally exposed bedding.
		float run=p.y*2.4+p.x*.82+2.5*wash(p*.42)+.9*area;
		float lip=smoothstep(.68,.98,sin(run))*smoothstep(.36,.78,local);
		float schist=smoothstep(.68,.84,wash(p*vec2(.28,.82)))*smoothstep(.45,.74,area);
		soil=mix(soil,soil*(1.+.09*lip)-vec3(.055,.036,.012)*schist,western.r);
	}
	if (western.g>.001) {
		float channel=abs(wash(vec2(p.x*.11+p.y*.08,p.y*.30))-.48);
		float wet=(1.-smoothstep(.016,.095,channel))*smoothstep(.32,.70,area);
		float ripple=sin(p.y*6.0+p.x*1.4+2.8*local+.42*sin(p.x*.9));
		soil=mix(soil,soil*(.95+.065*smoothstep(-.36,.85,ripple)*near_detail)
			*mix(vec3(1.),vec3(.72,.81,.78),wet),western.g);
	}
	if (western.b>.001) {
		vec2 warp=p+vec2(local,grit*.16)*1.5;
		float scar=min(abs(wash(warp*.48)-.52),abs(wash(warp*vec2(.20,.73))-.44));
		float seam=(1.-smoothstep(.008,.045,scar))*near_detail;
		float cinder=smoothstep(.57,.80,area)*smoothstep(.46,.77,grit);
		soil=mix(soil,soil*(1.-.16*seam)+vec3(.048,.016,.003)*cinder,western.b);
	}
	if (western.a>.001) {
		// Parallel slipface ripples break up in dry gravel fans in the hollows.
		float wind=dot(p,vec2(1.42,4.31))+1.9*sin(.24*p.x)+2.1*local;
		float lip=pow(.5+.5*sin(wind),3.);
		float reg=smoothstep(.55,.80,area)*smoothstep(.47,.76,grit);
		soil=mix(soil,soil*(.96+.068*lip*near_detail-.115*reg),western.a);
	}
	if (eastern.x>.001) {
		float bank=(1.-smoothstep(.7,3.4,UV.y))*smoothstep(.31,.76,grit);
		soil=mix(soil,soil*mix(vec3(1.),vec3(.73,.86,.79),bank),eastern.x);
	}
	if (eastern.y>.001) {
		float moss=smoothstep(.49,.77,area+.20*(local-.5));
		float needles=smoothstep(.55,.76,wash(p*vec2(1.2,4.1)))*near_detail;
		soil=mix(soil,soil*mix(vec3(.83,.85,.77),vec3(1.,1.06,.92),moss)+vec3(.030,.014,.004)*needles,eastern.y);
	}
	ink *= .82+.18*local+.14*grit;
	vec3 country_tread=mix(soil*vec3(.83,.82,.78),ink,.24-.12*western.r+.36*(eastern.x+eastern.y));
	vec3 base = mix(soil,mix(country_tread,ink,home),trail*(.83-.24*western.a));
	// Two brush scales keep marks legible beside the character without a grid at distance.
	vec2 curl = vec2(area, local)*.075;
	vec3 marks = texture(ground_pigments, p*.167+curl).rgb - vec3(.5);
	mat2 rotation = mat2(vec2(.8,.6),vec2(-.6,.8));
	marks = .75*marks + .25*(texture(ground_pigments, rotation*p*.095-curl).rgb-.5);
	float grassy_home = home*smoothstep(-.01,.025,COLOR.g-COLOR.r);
	float meadow = clamp(grassy_home+eastern.x+eastern.y+.34*western.g,0.,1.);
	float turf = meadow * smoothstep(.58,.89,upward) * smoothstep(.76,2.2,UV.y);
	float rock = max(max(western.b,western.r),1.-smoothstep(.57,.87,upward));
	// On steep cuts the chips follow the cliff face and keep their painted proportions.
	if (upward < .87) {
		vec2 face_weight = abs(slope_direction);
		float yz = texture(ground_pigments, vec2(p.y, UV.y)*.167+curl).b;
		float xy = texture(ground_pigments, vec2(p.x, UV.y)*.167+curl).b;
		float cliff = mix(xy,yz,face_weight.x / max(.001,face_weight.x+face_weight.y));
		float exposure = 1.-smoothstep(.46,.87,upward);
		marks.b = mix(marks.b,cliff-.5,exposure);
		vec3 bedrock = mix(vec3(.26,.266,.237),vec3(.42,.40,.32),local);
		base = mix(base,bedrock, .70*exposure*(home+eastern.x+eastern.y)*(1.-trail));
	}
	float grass_pigment = marks.r*turf*(1.-trail);
	float dirt_pigment = marks.g*(1.-rock)*(1.-turf*(1.-trail));
	float stone_pigment = marks.b*rock*(1.-.65*trail);
	base *= 1. + grass_pigment*.86 + dirt_pigment*.92 + stone_pigment*.72;
	base += vec3(.075,.063,.003)*max(grass_pigment,0.) + vec3(.08,.07,.046)*max(dirt_pigment,0.);
	if (p.x > -44. && p.x < 45. && p.y > 18. && p.y < 40.) {
		float distance_to_paving = paved_distance(p);
		float margin = distance_to_paving+(local-.5)*.57+(grit-.5)*.29;
		float shoulder = (1.-smoothstep(1.48,2.05,margin))*smoothstep(.15,.82,upward);
		if (shoulder>.001) {
			vec2 uv = mat2(vec2(.94,.34),vec2(-.34,.94))*p/vec2(4.9,3.65);
			vec3 stone = texture(harbor_flagstones,uv+.009*vec2(local,grit)).rgb;
			float paving = 1.-smoothstep(.86,1.49,margin+(stone.g-.5)*.46);
			vec3 gravel = mix(base,vec3(.325,.308,.240),.48)*(1.+.98*marks.g);
			vec3 slab = mix(vec3(.355,.371,.345),vec3(.515,.490,.410),stone.g);
			slab *= .87+.22*stone.b+.075*area;
			base = mix(base,mix(gravel,slab,stone.r*paving),shoulder);
		}
	}
	ALBEDO=base;
	ROUGHNESS=mix(.87,.96,turf);
}
