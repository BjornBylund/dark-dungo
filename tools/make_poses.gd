## Writes placeholder pose sprites for the combat close-up (see src/ui/poses.gd):
## an attack pose for every hero skill and a hurt pose for every hero and enemy,
## made from each unit's normal sprite. Real art replaces them one file at a
## time. Existing files are kept unless run with --overwrite.
## Run: godot --headless --path . --script res://tools/make_poses.gd [-- --overwrite]
extends SceneTree

## How far the top of the figure leans, as a fraction of its width.
const ATTACK_LEAN := 0.22
const HURT_LEAN := -0.16
const ICON_SIZE := 80


func _initialize() -> void:
	var overwrite := "--overwrite" in OS.get_cmdline_user_args()
	var written := 0
	for dir in ["res://content/heroes", "res://content/enemies"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var unit: UnitDef = load(dir.path_join(file))
			if unit.sprite == null:
				continue
			var base := unit.sprite.get_image()
			if base.is_compressed():
				base.decompress()
			base.convert(Image.FORMAT_RGBA8)
			var folder := "res://art/poses/%s" % unit.id
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			written += _save(_hurt(base), folder.path_join("hurt.png"), overwrite)
			if dir.ends_with("heroes"):
				for skill in unit.skills:
					written += _save(_attack(base, skill), folder.path_join("%s.png" % skill.id), overwrite)
	print("make_poses: wrote %d placeholder poses" % written)
	quit()


## Leaning into the blow, with motion lines behind and the skill's icon on top.
func _attack(base: Image, skill: SkillDef) -> Image:
	var pose := _lean(base, ATTACK_LEAN)
	var width := pose.get_width()
	var height := pose.get_height()
	for i in 5:
		var y := int(height * (0.3 + i * 0.1))
		var length := int(width * (0.25 - absf(i - 2) * 0.05))
		pose.fill_rect(Rect2i(int(width * 0.02), y, length, 4), Color(1, 1, 1, 0.55))
	var icon_texture := UiStyle.skill_icon(skill)
	if icon_texture:
		var icon := icon_texture.get_image()
		if icon.is_compressed():
			icon.decompress()
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(ICON_SIZE, ICON_SIZE)
		pose.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(6, 6))
	return pose


## Recoiling, flushed red, with a burst of impact marks in front.
func _hurt(base: Image) -> Image:
	var pose := _lean(base, HURT_LEAN)
	for y in pose.get_height():
		for x in pose.get_width():
			var pixel := pose.get_pixel(x, y)
			if pixel.a > 0.0:
				pose.set_pixel(x, y, Color(minf(pixel.r * 1.1 + 0.15, 1.0), pixel.g * 0.55, pixel.b * 0.55, pixel.a))
	var width := pose.get_width()
	var height := pose.get_height()
	var center := Vector2i(int(width * 0.82), int(height * 0.35))
	for angle in [-0.6, -0.2, 0.2, 0.6]:
		var direction := Vector2(cos(angle), sin(angle))
		for step in range(18, 60):
			var point := Vector2(center) + direction * step
			pose.fill_rect(Rect2i(Vector2i(point), Vector2i(4, 4)), Color(1, 0.9, 0.8, 0.9))
	return pose


## Shears the figure about its middle: the top slides sideways by half of
## `amount` of the width and the feet the other way, so it leans forward
## (positive) or back without leaving the canvas.
func _lean(base: Image, amount: float) -> Image:
	var width := base.get_width()
	var height := base.get_height()
	var pose := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		var shift := int(amount * width * (0.5 - float(y) / height))
		pose.blit_rect(base, Rect2i(0, y, width, 1), Vector2i(shift, y))
	return pose


func _save(image: Image, path: String, overwrite: bool) -> int:
	if FileAccess.file_exists(path) and not overwrite:
		return 0
	image.save_png(ProjectSettings.globalize_path(path))
	return 1
