## Pose sprites for the combat close-up: a unit's attack pose for each skill and
## its hurt pose when hit. They live by convention in the unit's own art folder,
## next to its normal sprite:
##   art/characters/<class>/<skill id>.png   and   art/characters/<class>/hurt.png
## so art can be dropped in one file at a time; tools/make_poses.gd writes
## placeholders. A missing pose means the unit's normal sprite.
class_name Poses
extends RefCounted

## One folder per unit, named after its class: sprite.png (its UnitDef sprite),
## hurt.png and the attack poses.
const ROOT := "res://art/characters"

static var _cache := {}


## The unit's art folder: wherever its sprite is. Empty for a unit without one.
static func folder(unit: UnitDef) -> String:
	return unit.sprite.resource_path.get_base_dir() if unit.sprite else ""


static func attack(unit: UnitDef, skill: SkillDef) -> Texture2D:
	return _load(unit, "%s.png" % skill.id)


static func hurt(unit: UnitDef) -> Texture2D:
	return _load(unit, "hurt.png")


static func _load(unit: UnitDef, file: String) -> Texture2D:
	if unit.sprite == null:
		return null
	var path := folder(unit).path_join(file)
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
