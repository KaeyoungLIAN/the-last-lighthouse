shader_type sky;

// R = condensed cloud cover, G = relief on the cloud shoulders, B = high cirrus.
// Both sky hemispheres meet at the same sampled horizon.
uniform sampler2D cloud_study : filter_linear_mipmap, repeat_enable;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform vec4 night_zenith : source_color = vec4(.064, .111, .215, 1.0);
uniform vec4 night_air : source_color = vec4(.235, .312, .396, 1.0);
uniform vec4 day_zenith : source_color = vec4(.185, .495, .684, 1.0);
uniform vec4 day_air : source_color = vec4(.780, .866, .856, 1.0);
uniform vec4 rose_air : source_color = vec4(.875, .574, .470, 1.0);
uniform vec4 twilight_blue : source_color = vec4(.267, .337, .492, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(73.21, 127.19))) * 4375.213);
}

void sky() {
	float altitude = clamp(EYEDIR.y, 0.0, 1.0);
	float elevation = asin(altitude) / (PI * .5);
	float dusk = 1.0 - smoothstep(.0, .51, abs(daylight - .44));
	float night = 1.0 - smoothstep(.025, .36, daylight);
	vec3 source = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(-.62,.67,.41));
	float facing = dot(EYEDIR, source);
	float sunward = smoothstep(-.60, .94, facing);

	// A cool upper vault, a low warm horizon and a narrower belt of sea haze.
	vec3 horizon = mix(night_air.rgb, day_air.rgb, daylight);
	horizon = mix(horizon, rose_air.rgb, dusk * (.62 + .38*sunward));
	vec3 zenith = mix(night_zenith.rgb, day_zenith.rgb, daylight);
	zenith = mix(zenith, twilight_blue.rgb, dusk * .65);
	vec3 sky_air = mix(horizon, zenith, 1.0 - exp(-3.8*altitude));
	sky_air += sky_air * (.055 + .08*dusk) * exp(-30.0*altitude);

	vec2 uv = vec2(SKY_COORDS.x, clamp(elevation, .001, .998));
	float grad_x = fwidth(uv.x);
	// The panorama shares a vertical edge. Isolate its wrap from mip selection.
	float mip = max(0.0, log2(max(min(grad_x, 1.0-grad_x)*2048.0, fwidth(uv.y)*512.0)));
	vec3 sheet = textureLod(cloud_study, uv, mip).rgb;
	float cloud = sheet.r * smoothstep(.008, .057, altitude);
	float relief = clamp(sheet.g / max(.08, sheet.r), 0.0, 1.0);
	float veil = sheet.b * (.14+.03*dusk);
	vec3 light_tint = mix(vec3(.55,.69,.76), vec3(1.,.77,.57), dusk*sunward);
	vec3 color = mix(sky_air, light_tint, veil * (.3+.7*daylight));

	// The setting light catches upper lobes; the broad underside remains cooler.
	vec3 day_shade = mix(vec3(.40,.57,.68), vec3(.48,.37,.50), dusk);
	vec3 day_bright = mix(vec3(.99,.97,.87), vec3(1.,.72,.52), dusk * (.72+.28*sunward));
	vec3 shade = mix(night_zenith.rgb*.88, day_shade, smoothstep(.0,.72,daylight));
	vec3 bright = mix(night_air.rgb*.90, day_bright, smoothstep(.0,.77,daylight));
	vec3 cloud_color = mix(shade, bright, smoothstep(.26,.83,relief));
	cloud_color = mix(horizon, cloud_color, .67 + .32*smoothstep(.02,.36,altitude));

	if (night > .001 && altitude > .015) {
		vec2 atlas = SKY_COORDS * vec2(410.0, 205.0);
		vec2 cell = floor(atlas);
		vec2 center = vec2(hash(cell+7.8), hash(cell+13.6))*.62+.19;
		float size = .036 + .07*hash(cell+11.0);
		float aa = clamp(length(fwidth(atlas))*.4,.012,.13);
		float point = 1.0 - smoothstep(size-aa, size+aa, length(fract(atlas)-center));
		color += vec3(.60,.71,.84) * point * step(.971, hash(cell)) * night * smoothstep(.015,.22,altitude);
	}
	// The disc and the cast shadows share the scene's directional light.
	float disc = smoothstep(.99988,.99995,facing);
	float halo = pow(max(facing,0.0), 38.0);
	color += mix(vec3(.34,.47,.60),vec3(1.,.82,.59),1.0-night) *
			(disc + halo*(.10+.17*dusk)) * (.58+.42*daylight);
	COLOR = mix(color, cloud_color, cloud * (.90+.07*daylight));
}
