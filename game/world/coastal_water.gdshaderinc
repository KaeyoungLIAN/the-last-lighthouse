// Baked from the same terrain triangles used by the shoreline and tidal paths.
uniform sampler2D seabed : repeat_disable, filter_linear;

float bed_height(vec2 p) {
	vec2 uv = (p + vec2(492.0, 512.0)) / vec2(1152.0, 1024.0);
	return texture(seabed, uv).r * 8.0 - 4.0;
}

float wash_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 part = fract(p);
	part = part * part * (3.0 - 2.0 * part);
	vec4 seed = fract(sin(dot(cell, vec2(21.43, 73.29))
		+ vec4(0.0, 21.43, 73.29, 94.72)) * 4375.83);
	return mix(mix(seed.x, seed.y, part.x), mix(seed.z, seed.w, part.x), part.y);
}

// Analytic slopes keep the reflection coherent across the entire plane.
vec2 wind_slope(vec2 p, float clock, float detail) {
	const vec2 swell = vec2(.39, .92);
	const vec2 chop = vec2(-.71, .70);
	float folds = wash_noise(p * .27 + vec2(-clock * .07, clock * .026));
	float gust = wash_noise(p * .109 - vec2(0.0, clock * .045));
	float bend = folds * 4.2 + sin(dot(p, vec2(.33, -.19)) + clock * .25) * .9;
	vec2 ripple = swell * cos(dot(p, swell) * 1.92 - clock * 1.06 + bend) * .066
		+ chop * cos(dot(p, chop) * 2.28 - clock * 1.34 + folds * 3.5) * .050
		+ swell * cos(dot(p, swell) * 5.81 - clock * 2.6 + bend * 2.0) * .037;
	return ripple * (.26 + gust) * detail;
}
