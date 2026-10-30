// The mood over a screen's picture, under its UI: lamps that glow and gutter,
// and dark corners that breathe with a flicker.
shader_type canvas_item;

// The rect's size in pixels, for lamp positions.
uniform vec2 size = vec2(1920.0, 1080.0);
uniform float vignette = 0.8;
uniform float flicker = 0.0;
uniform vec4 lamp_color : source_color = vec4(1.0, 0.62, 0.25, 1.0);
// Each lamp: x, y and radius in pixels of the rect.
uniform vec4 lights[8];
uniform int light_count = 0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 pixel = UV * size;
	float lamp = 0.0;
	for (int i = 0; i < light_count; i++) {
		float distance_out = length(pixel - lights[i].xy) / lights[i].z;
		float beat = 0.7 + 0.3 * noise(vec2(TIME * 7.0, float(i) * 13.0));
		lamp = max(lamp, (1.0 - smoothstep(0.0, 1.0, distance_out)) * beat * 0.4);
	}
	float shimmer = 1.0 + flicker * (noise(vec2(TIME * 9.0, 0.0)) - 0.5);
	float vig = clamp(smoothstep(0.55, 1.4, length((UV - 0.5) * 2.0)) * vignette * shimmer, 0.0, 1.0);
	// Layered as if painted in turn: lamps, then dark corners.
	float keep = (1.0 - lamp) * (1.0 - vig);
	vec3 painted = lamp_color.rgb * lamp * (1.0 - vig);
	float alpha = 1.0 - keep;
	COLOR = vec4(alpha > 0.0 ? painted / alpha : vec3(0.0), alpha);
}
