shader_type spatial;
render_mode cull_disabled, diffuse_lambert;
uniform float gust : hint_range(0.0,1.0) = .18;
void vertex() {
	float phase=dot(MODEL_MATRIX[3].xz,vec2(.17,.23));
	VERTEX.z += UV.x * (.11+.24*gust)*sin(phase+TIME*(2.3+gust*4.1)-UV.x*6.0);
	VERTEX.y += UV.x*(.04+.075*gust)*sin(phase+TIME*2.-UV.x*5.5)+gust*.12*UV.x;
}
void fragment(){
	float stripe=1.-smoothstep(.064,.085,abs(UV.x-.25));
	ALBEDO=mix(vec3(.49,.19,.112),vec3(.72,.58,.32),stripe);
	ROUGHNESS=.93;
}
