shader_type spatial;

// The original Blender meshes carry the paint palette in their vertex colors.
// Local metre coordinates carry the grain around each building, including the tower.
uniform sampler2D brush : repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool is_tower = false;
varying vec3 position_model;
varying vec3 normal_model;

void vertex() {
	position_model = VERTEX;
	normal_model = NORMAL;
}

vec3 brush_on_stone(vec3 p, vec3 weights) {
	return texture(brush, p.zy).rgb * weights.x
		+ texture(brush, p.xz).rgb * weights.y
		+ texture(brush, p.xy).rgb * weights.z;
}

void fragment() {
	vec3 p = position_model;
	vec3 weights = pow(abs(normalize(normal_model)), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), .001);
	vec3 broad = brush_on_stone(p * .24, weights);
	vec3 daub = brush_on_stone(p * .72 + vec3(.61,.32,.21), weights);
	float fleck = daub.g - .5;
	float field = .72 * broad.r + .28 * daub.r;
	vec3 tint = COLOR.rgb;
	// Chipped pigment gathers in connected patches. Distant facets keep their silhouette.
	float chipped = smoothstep(.58,.74,field + fleck * .19);
	float wet_foot = (1.0 - smoothstep(.10, is_tower ? 1.75 : 1.05, p.y + (broad.r-.5)*.80));
	vec3 mineral = tint * (.85 + field*.22 + fleck*.15);
	mineral = mix(mineral, mineral * vec3(.66,.80,.78), wet_foot * (.51 + .42 * field));
	if (is_tower) {
		// Red oxide fades toward the warm limewash underneath; granite retains a cool foot.
		float oxide = smoothstep(.08,.27,tint.r - tint.g);
		mineral = mix(mineral, mix(mineral, vec3(.69,.56,.40), .81), chipped*(.14 + .48*oxide));
	} else {
		float plaster = smoothstep(.30,.53,tint.r) * smoothstep(.19,.39,tint.g) * (1.0-weights.y);
		// A sea-green splash course and a thin hand-ruled line are painted above the plinth.
		float paint = (1.0-smoothstep(.95,.975,p.y + fleck*.045))
			+ (smoothstep(1.006,1.025,p.y) - smoothstep(1.042,1.052,p.y));
		float wear = clamp(paint,0.0,1.0)*plaster*(1.0 - .72*chipped);
		mineral = mix(mineral, mineral * vec3(.30,.52,.50), wear*.85);
		mineral = mix(mineral, mineral*vec3(.77,.79,.72), plaster*chipped*.52);
		// Salt bleaches the exposed upward edge of individual slate pieces.
		float slate = smoothstep(1.9,2.5,p.y) * weights.y;
		mineral += vec3(.050,.055,.048) * slate * chipped;
	}
	ALBEDO = clamp(mineral, vec3(.009), vec3(1.0));
	ROUGHNESS = clamp(.81 + .15 * daub.g - wet_foot * .16 - weights.y*.04,.57,.98);
	SPECULAR = .28;
}
