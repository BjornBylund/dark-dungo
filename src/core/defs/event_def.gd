## A scene in an event room: a title, flavour text setting the scene, and the
## choices the party can make.
class_name EventDef
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var text: String
@export var choices: Array[EventChoiceDef] = []
