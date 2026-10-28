## A sortable table for the balance tool, on a Tree: a row per unit,
## encounter or trinket, with its skills or enemies as child rows. Clicking a
## column title sorts by it (child rows keep their order), again flips it.
## Numbers are tinted by how they rank within their group: top-level rows
## among themselves, child rows among all child rows. Green is stronger.
class_name BalanceTable
extends Tree

signal row_selected(resource: Resource)

const STRONG := Color(0.3, 0.8, 0.45)
const WEAK := Color(0.85, 0.3, 0.3)

## Each column: {title, width, tip, better (1: higher is stronger, -1: lower
## is, 0 or missing: no tint), expand}.
var column_defs: Array[Dictionary] = []
## Each row: {resource, cells, children (rows), dim}. `cells` has one entry
## per column: null for blank, or {value (a number or text, for sorting and
## tints), text, tip, left (to align a number's text left), center, flag
## (marked in amber), stale (greyed: out of date)}.
var _rows: Array[Dictionary] = []
var _sort_column := -1
var _sort_descending := true
## Instance ids of rows showing their children.
var _expanded := {}
var _selected: Resource
## The rows' resources in the order shown, to update in place when it holds.
var _shown: Array[Resource] = []
var _filling := false


func _init() -> void:
	hide_root = true
	select_mode = Tree.SELECT_ROW
	column_titles_visible = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	column_title_clicked.connect(_on_title_clicked)
	item_selected.connect(_on_item_selected)
	item_collapsed.connect(func(item: TreeItem) -> void:
		var resource: Resource = item.get_metadata(0)
		if item.collapsed:
			_expanded.erase(resource.get_instance_id())
		else:
			_expanded[resource.get_instance_id()] = true)


func set_column_defs(defs: Array[Dictionary]) -> void:
	column_defs = defs
	columns = defs.size()
	_sort_column = -1
	_shown.clear()
	for i in defs.size():
		set_column_expand(i, defs[i].get("expand", false))
		set_column_custom_minimum_width(i, defs[i].width)
		set_column_clip_content(i, true)
		set_column_title_tooltip_text(i, defs[i].get("tip", ""))
		set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_CENTER)
	_update_titles()


func show_rows(rows: Array[Dictionary]) -> void:
	_rows = rows
	_fill()


func select_resource(resource: Resource) -> void:
	_selected = resource
	var item := _find(get_root(), resource)
	if item:
		_filling = true
		item.select(0)
		_filling = false
		scroll_to_item(item)


func _fill() -> void:
	var sorted := _sorted(_rows)
	var children: Array[Dictionary] = []
	var order: Array[Resource] = []
	for row in sorted:
		order.append(row.resource)
		for child: Dictionary in row.children:
			children.append(child)
			order.append(child.resource)
	var tints := _tints(sorted)
	var child_tints := _tints(children)
	_filling = true
	if order == _shown and get_root():
		var item := get_root().get_first_child()
		for row in sorted:
			_write(item, row, tints)
			var child_item := item.get_first_child()
			for child: Dictionary in row.children:
				_write(child_item, child, child_tints)
				child_item = child_item.get_next()
			item = item.get_next()
	else:
		clear()
		var top := create_item()
		for row in sorted:
			var item := create_item(top)
			_write(item, row, tints)
			for child: Dictionary in row.children:
				_write(create_item(item), child, child_tints)
			item.collapsed = not _expanded.has(row.resource.get_instance_id())
		_shown = order
		var selected := _find(top, _selected)
		if selected:
			selected.select(0)
			scroll_to_item.call_deferred(selected)
	_filling = false


func _write(item: TreeItem, row: Dictionary, tints: Array[Dictionary]) -> void:
	item.set_metadata(0, row.resource)
	for i in column_defs.size():
		var cell: Variant = row.cells[i] if i < row.cells.size() else null
		var flagged: bool = cell != null and cell.get("flag", false)
		item.set_text(i, ("⚑ " if flagged else "") + cell.text if cell else "")
		if flagged:
			item.set_custom_color(i, UiStyle.AMBER.darkened(0.4) if cell.get("stale", false) else UiStyle.AMBER)
		elif cell != null and cell.get("stale", false):
			item.set_custom_color(i, UiStyle.TEXT_DIM.darkened(0.3))
		elif i > 0:
			item.clear_custom_color(i)
		var left: bool = i == 0 or (cell != null and (cell.value is String or cell.get("left", false)))
		var alignment := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		item.set_text_alignment(i, HORIZONTAL_ALIGNMENT_CENTER if cell != null and cell.get("center", false) else alignment)
		var tip: String = cell.get("tip", "") if cell else ""
		var tint: Dictionary = tints[i].get(row.resource, {})
		if tint.is_empty():
			item.clear_custom_bg_color(i)
		else:
			item.set_custom_bg_color(i, tint.color)
			tip = (tip + "\n" if tip != "" else "") + tint.rank
		item.set_tooltip_text(i, tip)
	if row.get("dim", false):
		item.set_custom_color(0, UiStyle.TEXT_DIM)
	else:
		item.clear_custom_color(0)


func _find(from: TreeItem, resource: Resource) -> TreeItem:
	if from == null or resource == null:
		return null
	if from.get_metadata(0) == resource:
		return from
	for child in from.get_children():
		var found := _find(child, resource)
		if found:
			return found
	return null


# --- Sorting ---

func _on_title_clicked(column: int, _mouse_button: int) -> void:
	if column == _sort_column:
		_sort_descending = not _sort_descending
	else:
		_sort_column = column
		_sort_descending = column != 0
	_update_titles()
	_fill()


func _update_titles() -> void:
	for i in column_defs.size():
		var arrow := ""
		if i == _sort_column:
			arrow = " ▼" if _sort_descending else " ▲"
		set_column_title(i, column_defs[i].title + arrow)


## Top-level rows in the chosen order; blanks last either way.
func _sorted(rows: Array[Dictionary]) -> Array[Dictionary]:
	var result := rows.duplicate()
	if _sort_column < 0:
		return result
	var column := _sort_column
	var descending := _sort_descending
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var x: Variant = _value(a, column)
		var y: Variant = _value(b, column)
		if x == null or y == null:
			return y == null and x != null
		if x is String or y is String:
			var order := str(x).naturalnocasecmp_to(str(y))
			return order > 0 if descending else order < 0
		return x > y if descending else x < y)
	return result


func _value(row: Dictionary, column: int) -> Variant:
	var cell: Variant = row.cells[column] if column < row.cells.size() else null
	return cell.value if cell else null


# --- Tints ---

## Per column: row resource -> {color, rank}, for numeric columns that tint
## and have at least three different values.
func _tints(rows: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for column in column_defs.size():
		var tints := {}
		result.append(tints)
		var better: int = column_defs[column].get("better", 0)
		if better == 0:
			continue
		var values: Array[float] = []
		for row in rows:
			var value: Variant = _value(row, column)
			if value is float or value is int:
				values.append(float(value))
		var distinct := {}
		for value in values:
			distinct[value] = true
		if distinct.size() < 3:
			continue
		values.sort()
		var last := values.size() - 1
		for row in rows:
			var cell_value: Variant = _value(row, column)
			if not (cell_value is float or cell_value is int):
				continue
			var value := float(cell_value)
			var below := values.bsearch(value, true)
			var ties := values.bsearch(value, false) - below
			var share := (below + (ties - 1) / 2.0) / last
			var strength := share if better > 0 else 1.0 - share
			var color := Color(STRONG, (strength - 0.5) * 0.55) if strength >= 0.5 else Color(WEAK, (0.5 - strength) * 0.45)
			var place := values.size() - values.bsearch(value, false) + 1 if better > 0 else below + 1
			tints[row.resource] = {color = color, rank = "%s of %d" % [_ordinal(place), values.size()]}
	return result


static func _ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
	return "%d%s" % [n, suffix]


func _on_item_selected() -> void:
	if _filling:
		return
	_selected = get_selected().get_metadata(0)
	row_selected.emit(_selected)
