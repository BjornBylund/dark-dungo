// Turns what is drawn behind a rect to greyscale, darkened by `brightness`,
// fading out towards an oval edge (a closed region's landmark on the map).
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float brightness = 0.4;

void fragment() {
	vec3 behind = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(behind, vec3(0.299, 0.587, 0.114)) * brightness;
	float edge = smoothstep(1.0, 0.65, length((UV - 0.5) * 2.0));
	COLOR = vec4(vec3(grey), edge);
}
