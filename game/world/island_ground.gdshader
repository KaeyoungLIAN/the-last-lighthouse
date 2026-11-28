shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

varying vec2 ground_xz;

float hash21(vec2 p) {
	vec3 h = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float noise2(vec2 p) {
	vec2 cell = floor(p);
	vec2 d = fract(p);
	vec2 t = d * d * (3.0 - 2.0 * d);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.,0.)), t.x),
	           mix(hash21(cell + vec2(0.,1.)), hash21(cell + vec2(1.)), t.x), t.y);
}

void vertex() {
	ground_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = ground_xz;
	float turf = noise2(p * .38);
	float grain = noise2(p * 4.5);
	float edge = UV.x + (turf - .5) * .95 + (grain - .5) * .45;
	float dry = smoothstep(.60, .95, UV.y);
	float tread = (1.0 - smoothstep(1.20, 2.16, edge)) * dry;
	float verge = (1.0 - smoothstep(1.60, 2.90, edge)) * dry;
	vec3 land = COLOR.rgb * (.89 + .18 * turf + .085 * (grain - .5));
	land = mix(land, land * vec3(1.18, 1.03, .86), verge);
	vec3 soil = mix(vec3(.50,.395,.284), vec3(.62,.52,.393), .55 * turf + .45 * grain);
	vec3 ground = mix(land, soil, tread);

	// Flecks set into the dirt form small gravel beds rather than a uniform grain.
	vec2 cell = mat2(vec2(2.7, 1.4), vec2(-1.4, 2.7)) * p;
	vec2 id = floor(cell);
	vec2 pebble = fract(cell) - (.20 + .60 * vec2(hash21(id), hash21(id + 5.1)));
	float variety = hash21(id + 3.7);
	float size = .055 + .105 * variety;
	pebble.x += pebble.y * (variety * 1.7 - .85);
	float radius = max(abs(pebble.x) * .91 + abs(pebble.y) * .52, abs(pebble.y) * 1.52);
	float outline = max(fwidth(cell.x) + fwidth(cell.y), .017);
	float fleck = 1.0 - smoothstep(size - outline, size + outline, radius);
	float bed = smoothstep(.35, .70, turf) * tread * step(.43, hash21(id + 17.1));
	float stone_tint = mix(-.065, .056, hash21(id + 9.3));
	ground += vec3(stone_tint) * fleck * bed * (1.0 - smoothstep(.18, .75, outline));
	ALBEDO = ground;
	ROUGHNESS = .97;
}
