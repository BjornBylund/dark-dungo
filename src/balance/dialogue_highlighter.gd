## Colours a dialogue script in the balance tool's editor: "== section" lines
## in gold, "? conditions" in blue, comments dim, each speaker in their colour
## (red if no one by that name), and placeholders green, or red if unknown.
class_name DialogueHighlighter
extends SyntaxHighlighter

const HEADER := Color("e3c27a")
const CONDITION := Color("8fb4e8")
const COMMENT := Color("7a7268")
const PLACEHOLDER := Color("8fd18a")
const WRONG := Color("ff6a5a")

## Class name -> colour, the Ancestor's included.
var speakers := {}
var _mark := RegEx.create_from_string("\\{(\\w*)\\}")


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text := get_text_edit().get_line(line)
	var start := text.length() - text.strip_edges(true, false).length()
	var body := text.strip_edges()
	if body == "":
		return {}
	if body.begins_with("#"):
		return {start: {color = COMMENT}}
	if body.begins_with("=="):
		return {start: {color = HEADER}}
	if body.begins_with("?"):
		return {start: {color = CONDITION}}
	var colon := text.find(":")
	if colon < 0:
		return {start: {color = WRONG}}
	var speaker := text.left(colon).strip_edges()
	var colours := {start: {color = speakers.get(speaker, WRONG)}, colon + 1: {color = UiStyle.TEXT}}
	for mark in _mark.search_all(text, colon):
		var known := Dialogue.PLACEHOLDERS.has(mark.get_string(1))
		colours[mark.get_start()] = {color = PLACEHOLDER if known else WRONG}
		colours[mark.get_end()] = {color = UiStyle.TEXT}
	return colours
