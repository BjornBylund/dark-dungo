## The content the balance tool edits: every hero, enemy, encounter and
## trinket file, and the campaign and regions that list them. Every change
## goes through here so it can be undone, and marks the file it belongs to
## (its root) as unsaved until save() writes it.
class_name BalanceLibrary
extends RefCounted

## After any change, undo or redo. `from_history` is true for undo and redo,
## when forms showing the roots must rebuild.
signal edited(roots: Array[Resource], from_history: bool)

enum Kind { HERO, ENEMY, ENCOUNTER, TRINKET, OTHER }

const CAMPAIGN_PATH := "res://content/campaign.tres"
const SANDBOX_PATH := "res://content/sandbox.tres"
const TARGETS_PATH := "res://content/balance_targets.tres"
## Edits of the same field this close together undo as one step (typing,
## dragging). UndoRedo merges only within 0.8 s.
const MERGE_SECONDS := 0.8

## Where each kind's files live, and where new ones are saved.
var folders: Dictionary[Kind, String] = {
	Kind.HERO: "res://content/heroes",
	Kind.ENEMY: "res://content/enemies",
	Kind.ENCOUNTER: "res://content/encounters",
	Kind.TRINKET: "res://content/trinkets",
}
var campaign: CampaignDef
var sandbox: SandboxDef
## The tool's presets and targets.
var targets: BalanceTargets
var heroes: Array[UnitDef] = []
var enemies: Array[UnitDef] = []
var encounters: Array[EncounterDef] = []
var trinkets: Array[TrinketDef] = []
var history := UndoRedo.new()
var _relay := Relay.new()

## Per history entry, by its index: {serial, roots}. Every change gets a new
## serial, a merged one too. A root is unsaved while the newest applied entry
## touching it isn't the one it was saved at.
var _entries: Array[Dictionary] = []
var _next_serial := 1
## The state with no history applied: as loaded, or as discard() left it.
var _base_serial := 0
## Root -> the serial of the entry it was saved at (0 for as loaded).
var _saved_at: Dictionary[Resource, int] = {}
## Instance ids of resources that have a file: their ids are locked.
var _on_disk := {}
var _last_field := ""
var _last_edit_time := 0.0


## What the history calls back. UndoRedo holds a strong reference to any
## RefCounted whose method it calls, which would keep the library alive for
## good, so it calls this plain Object instead.
class Relay extends Object:
	var library: WeakRef

	func announce(touched: Array[Resource]) -> void:
		var owner: BalanceLibrary = library.get_ref()
		if owner:
			owner._announce(touched)

	func insert(list: Array, at: int, item: Resource) -> void:
		list.insert(at, item)

	func erase(list: Array, item: Resource) -> void:
		list.erase(item)


func _init() -> void:
	_relay.library = weakref(self)
	campaign = load(CAMPAIGN_PATH)
	sandbox = load(SANDBOX_PATH)
	targets = load(TARGETS_PATH)
	heroes.assign(_load_all(folders[Kind.HERO]))
	enemies.assign(_load_all(folders[Kind.ENEMY]))
	encounters.assign(_load_all(folders[Kind.ENCOUNTER]))
	trinkets.assign(_load_all(folders[Kind.TRINKET]))
	for root in roots():
		_remember_on_disk(root)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		history.free()
		_relay.free()


func _load_all(folder: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var files := Array(DirAccess.get_files_at(folder))
	files.sort()
	for file: String in files:
		if file.ends_with(".tres"):
			result.append(load(folder.path_join(file)))
	return result


## Everything that can be edited and saved: the content files, the campaign
## and its regions, and the tool's targets.
func roots() -> Array[Resource]:
	var result: Array[Resource] = []
	result.append_array(heroes)
	result.append_array(enemies)
	result.append_array(encounters)
	result.append_array(trinkets)
	result.append(campaign)
	result.append_array(campaign.regions)
	result.append(targets)
	return result


func list_of(kind: Kind) -> Array:
	match kind:
		Kind.HERO:
			return heroes
		Kind.ENEMY:
			return enemies
		Kind.ENCOUNTER:
			return encounters
		Kind.TRINKET:
			return trinkets
	return []


func kind_of(root: Resource) -> Kind:
	if root is UnitDef:
		return Kind.HERO if root in heroes else Kind.ENEMY if root in enemies else Kind.OTHER
	if root is EncounterDef and root in encounters:
		return Kind.ENCOUNTER
	if root is TrinketDef and root in trinkets:
		return Kind.TRINKET
	return Kind.OTHER


# --- Editing ---

## Sets `object`'s property, part of `root`'s file, as one undoable step.
## Repeated edits of the same field in quick succession merge into one.
func set_value(root: Resource, object: Object, property: StringName, value: Variant) -> void:
	var old: Variant = object.get(property)
	if typeof(old) == typeof(value) and old == value:
		return
	var field := "%d:%s" % [object.get_instance_id(), property]
	var now := Time.get_ticks_msec() / 1000.0
	var merge := field == _last_field and now - _last_edit_time < MERGE_SECONDS
	_last_field = field
	_last_edit_time = now
	_commit("Set %s" % property, [root], func() -> void:
		history.add_do_property(object, property, value)
		history.add_undo_property(object, property, old), merge)


## Runs `steps` (which add do and undo operations to `history`) as one undoable action touching `touched`.
func _commit(action: String, touched: Array[Resource], steps: Callable, merge: bool = false) -> void:
	var count_before := history.get_history_count()
	var current_before := history.get_current_action()
	history.create_action(action, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE)
	steps.call()
	history.add_do_method(_relay.announce.bind(touched))
	history.add_undo_method(_relay.announce.bind(touched))
	history.commit_action()
	var index := history.get_current_action()
	if history.get_history_count() == count_before and index == current_before:
		# Merged into the last entry: it's still a new state, saved or simulated by nothing yet.
		_entries[index].serial = _next_serial
		for root in touched:
			if root not in _entries[index].roots:
				_entries[index].roots.append(root)
	else:
		_entries.resize(index)
		_entries.append({serial = _next_serial, roots = touched.duplicate()})
	_next_serial += 1


func _announce(touched: Array[Resource]) -> void:
	edited.emit(touched, not history.is_committing_action())


## Names the content's current state: it changes with every edit, and undoing
## back to a state gives its name back, so results can tell whether they fit.
func state() -> int:
	var index := history.get_current_action()
	return _entries[index].serial if index >= 0 else _base_serial


func undo() -> void:
	_last_field = ""
	history.undo()


func redo() -> void:
	_last_field = ""
	history.redo()


func is_unsaved(root: Resource) -> bool:
	return _applied_serial(root) != _saved_at.get(root, 0)


func unsaved() -> Array[Resource]:
	var result: Array[Resource] = []
	result.assign(roots().filter(func(root: Resource) -> bool: return is_unsaved(root)))
	return result


## The serial of the newest applied entry that touched `root`, or 0.
func _applied_serial(root: Resource) -> int:
	for index in range(history.get_current_action(), -1, -1):
		if root in _entries[index].roots:
			return _entries[index].serial
	return 0


## Whether the resource came from (or was saved to) a file, so saves may refer to its id.
func is_locked(resource: Resource) -> bool:
	return _on_disk.has(resource.get_instance_id())


func _remember_on_disk(root: Resource) -> void:
	_on_disk[root.get_instance_id()] = true
	for skill: SkillDef in root.get(&"skills") if root is UnitDef else []:
		_on_disk[skill.get_instance_id()] = true


# --- New content ---

## A copy of `root` with its own skills, effects, bonuses and triggers (art
## and listed units are shared), a new id and name, added after it. Unsaved
## until save(), which picks its file name.
func duplicate_root(root: Resource) -> Resource:
	var kind := kind_of(root)
	var copy := root.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
	copy.resource_path = ""
	if &"id" in copy:
		var taken := list_of(kind).map(func(each: Resource) -> StringName: return each.get(&"id"))
		var base := String(root.get(&"id")) + "_copy"
		var id := base
		var n := 2
		while StringName(id) in taken:
			id = "%s%d" % [base, n]
			n += 1
		copy.set(&"id", StringName(id))
	copy.set(&"display_name", "%s (copy)" % root.get(&"display_name"))
	var list := list_of(kind)
	var at := list.find(root) + 1
	var touched: Array[Resource] = [copy]
	_last_field = ""
	_commit("Duplicate", touched, func() -> void:
		history.add_do_method(_relay.insert.bind(list, at, copy))
		history.add_undo_method(_relay.erase.bind(list, copy)))
	return copy


# --- Listing in the campaign ---

## Where the game can use `root`: [{label, holder, property, on}]. `holder`'s
## `property` is an array that lists it, or a single slot (a region's boss).
## Turning on a hero's Starting Heroes takes it off Recruits and back.
func listings(root: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match kind_of(root):
		Kind.HERO:
			result.append(_listing("Starting Heroes", campaign, &"starting_heroes", root))
			result.append(_listing("Recruits", campaign, &"recruits", root))
		Kind.ENCOUNTER:
			for region in campaign.regions:
				for pair: Array in [["fights", &"encounters"], ["elites", &"elites"], ["finales", &"finales"],
						["boss", &"boss"]]:
					result.append(_listing("%s %s" % [region.display_name, pair[0]], region, pair[1], root))
		Kind.TRINKET:
			result.append(_listing("Trinket list", campaign, &"trinkets", root))
	return result


func _listing(label: String, holder: Resource, property: StringName, root: Resource) -> Dictionary:
	var value: Variant = holder.get(property)
	var on: bool = root in value if value is Array else value == root
	return {label = label, holder = holder, property = property, on = on}


## Lists or unlists `root` as `listing` (from listings()) says, as one undoable step.
func set_listed(root: Resource, listing: Dictionary, on: bool) -> void:
	var changes: Array[Array] = [[listing.holder, listing.property, _with(listing.holder.get(listing.property), root, on)]]
	if on and kind_of(root) == Kind.HERO:
		var other := &"recruits" if listing.property == &"starting_heroes" else &"starting_heroes"
		changes.append([campaign, other, _with(campaign.get(other), root, false)])
	var touched: Array[Resource] = [listing.holder]
	_last_field = ""
	_commit("List", touched, func() -> void:
		for change in changes:
			history.add_do_property(change[0], change[1], change[2])
			history.add_undo_property(change[0], change[1], change[0].get(change[1])))


## `value` with `root` in it or not: a copied array, or a single slot.
func _with(value: Variant, root: Resource, on: bool) -> Variant:
	if not value is Array:
		return root if on else (null if value == root else value)
	var copy: Array = value.duplicate()
	if on and root not in copy:
		copy.append(root)
	elif not on:
		copy.erase(root)
	return copy


## "The Graveyard boss", "The Burrows fights", "Sandbox wave": where an encounter is used.
func roles_of(encounter: EncounterDef) -> Array[String]:
	var result: Array[String] = []
	for listing in listings(encounter):
		if listing.on:
			result.append(listing.label)
	if encounter in sandbox.waves:
		result.append("Sandbox wave")
	return result


## The kinds of room a region uses an encounter for: &"fights", &"elites", &"finales", &"boss".
func role_keys(encounter: EncounterDef) -> Array[StringName]:
	var result: Array[StringName] = []
	for region in campaign.regions:
		for key: StringName in BalanceTarget.ROLE_KEYS:
			var property := &"encounters" if key == &"fights" else key
			var value: Variant = region.get(property)
			if (encounter in value if value is Array else value == encounter) and key not in result:
				result.append(key)
	return result


## The encounters an enemy stands in.
func encounters_with(enemy: UnitDef) -> Array[EncounterDef]:
	var result: Array[EncounterDef] = []
	for encounter in encounters:
		if enemy in encounter.enemies:
			result.append(encounter)
	return result


# --- Saving ---

## Writes every unsaved root to its file. New ones get a file named after their
## id (or name) in their kind's folder before anything is written, so files
## that refer to them, new ones included, link to that file.
func save() -> Error:
	var pending := unsaved()
	for root in pending:
		if root.resource_path == "":
			root.resource_path = _new_path(root)
	for root in pending:
		var error := ResourceSaver.save(root, root.resource_path)
		if error != OK:
			return error
		_saved_at[root] = _applied_serial(root)
		_remember_on_disk(root)
	return OK


func _new_path(root: Resource) -> String:
	var label: String = String(root.get(&"id")) if &"id" in root else root.get(&"display_name")
	var name := RegEx.create_from_string("[^a-z0-9]+").sub(label.to_lower(), "_", true).strip_edges().trim_prefix("_") \
			.trim_suffix("_")
	var folder := folders[kind_of(root)]
	var path := folder.path_join(name + ".tres")
	var n := 2
	while ResourceLoader.exists(path):
		path = folder.path_join("%s_%d.tres" % [name, n])
		n += 1
	return path


## Puts every unsaved root back as its file has it, and drops unsaved new ones.
func discard() -> void:
	for root in unsaved():
		if root.resource_path == "":
			list_of(kind_of(root)).erase(root)
		else:
			ResourceLoader.load(root.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	history.clear_history()
	_entries.clear()
	_saved_at.clear()
	_last_field = ""
	_base_serial = _next_serial
	_next_serial += 1
