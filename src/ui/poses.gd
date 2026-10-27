## Pose sprites for the combat close-up: a unit's attack pose for each skill and
## its hurt pose when hit. They live by convention at
##   art/poses/<unit id>/<skill id>.png   and   art/poses/<unit id>/hurt.png
## so art can be dropped in one file at a time; tools/make_poses.gd writes
## placeholders. A missing pose means the unit's normal sprite.
class_name Poses
extends RefCounted

const ROOT := "res://art/poses"

static var _cache := {}


static func attack(unit: UnitDef, skill: SkillDef) -> Texture2D:
	return _load("%s/%s/%s.png" % [ROOT, unit.id, skill.id])


static func hurt(unit: UnitDef) -> Texture2D:
	return _load("%s/%s/hurt.png" % [ROOT, unit.id])


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
