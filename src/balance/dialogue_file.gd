## A dialogue script (content/dialogue/*.txt) as the balance tool edits it: its
## text, held like a resource's field so edits go through the library's undo
## and save. Not a resource file itself: save writes the text back to `file`.
class_name DialogueFile
extends Resource

## The script's file, res://content/dialogue/<name>.txt.
var file: String
## Whose script it is: the Ancestor or a hero's class name, from the content that names it.
var display_name: String
## Null for the Ancestor's script (CampaignDef.dialogue) and for one no hero names.
var hero: UnitDef
var text: String


static func read(path: String) -> DialogueFile:
	var script := DialogueFile.new()
	script.file = path
	script.text = FileAccess.get_file_as_string(path)
	return script


## Writes the text to the file, and lets the game read it again.
func write() -> Error:
	var out := FileAccess.open(file, FileAccess.WRITE)
	if out == null:
		return FileAccess.get_open_error()
	out.store_string(text)
	out.close()
	Dialogue.forget(file)
	return OK
