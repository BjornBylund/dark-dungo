## One dialogue scene, ready to play: a title, the heroes on stage, and the
## lines in order, each spoken by a cast member or by the Ancestor (null).
## Built by Dialogue; the campaign queues them until the town plays them.
class_name DialogueScene
extends RefCounted

var title := ""
## A sting that opens the scene (Audio.STINGS), like a level gained's; none if empty.
var sting := &""
## The heroes on stage, in the order they first speak.
var cast: Array[UnitDef] = []
## Who says each line: a cast member, or null for the Ancestor.
var speakers: Array[UnitDef] = []
var texts: Array[String] = []


func _init(scene_title: String = "") -> void:
	title = scene_title


func add_line(speaker: UnitDef, text: String) -> void:
	if speaker and speaker not in cast:
		cast.append(speaker)
	speakers.append(speaker)
	texts.append(text)


func is_empty() -> bool:
	return texts.is_empty()


func to_dict() -> Dictionary:
	return {
		title = title,
		sting = String(sting),
		cast = cast.map(func(unit: UnitDef) -> String: return unit.resource_path),
		lines = range(texts.size()).map(func(i: int) -> Array:
			return [speakers[i].resource_path if speakers[i] else "", texts[i]]),
	}


## Lines by a hero whose class has left the cast are dropped; null if none are left.
static func from_dict(data: Dictionary) -> DialogueScene:
	var scene := DialogueScene.new(data.title)
	scene.sting = StringName(data.get("sting", ""))
	for path: String in data.cast:
		if ResourceLoader.exists(path):
			scene.cast.append(load(path))
	for line: Array in data.lines:
		if line[0] == "":
			scene.add_line(null, line[1])
		elif ResourceLoader.exists(line[0]):
			scene.add_line(load(line[0]), line[1])
	return null if scene.is_empty() else scene
