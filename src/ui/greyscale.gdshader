// Draws a canvas item in greyscale, scaled by `brightness` (unusable skills, portraits).
shader_type canvas_item;

uniform float brightness = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114)) * brightness;
	COLOR = vec4(vec3(grey), color.a);
}
