## The mood over a screen's picture, under its UI (atmosphere.gdshader): dark
## corners, film grain, and if asked a flicker in the light and lamps that glow
## and gutter. Fills its parent; screens add it just above what they draw
## behind everything.
class_name Atmosphere
extends ColorRect

const SHADER: Shader = preload("res://src/ui/atmosphere.gdshader")
const MAX_LIGHTS := 8


func _init(flicker: float = 0.0) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("flicker", flicker)
	resized.connect(_update_size)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_size()


## Lamps at stage points (x, y, radius in 1920x1080 stage pixels), for a stage
## drawn at `origin` and `scale` in this rect.
func set_lights(lights: Array[Vector3], origin: Vector2 = Vector2.ZERO, scale: float = 1.0) -> void:
	var packed: Array[Vector4] = []
	for light in lights.slice(0, MAX_LIGHTS):
		packed.append(Vector4(origin.x + light.x * scale, origin.y + light.y * scale, light.z * scale, 0.0))
	while packed.size() < MAX_LIGHTS:
		packed.append(Vector4(0, 0, 1, 0))
	material.set_shader_parameter("lights", packed)
	material.set_shader_parameter("light_count", mini(lights.size(), MAX_LIGHTS))


func _update_size() -> void:
	material.set_shader_parameter("size", size)
