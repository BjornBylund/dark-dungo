## Autoload: the music and the sound effects. One looping track plays at a
## time and crossfades into the next; a sting (a fight won or lost, a level
## gained) plays once over it while it dips. Sound effects play from a pool of
## players, each time a random one of the sound's variants at a slightly
## different pitch, and every button clicks. The Master, Music and Effects
## volumes are kept in user://settings.cfg. The files in audio/ are rendered
## from code by tools/make_audio.gd.
extends Node

const SETTINGS_PATH := "user://settings.cfg"
const SFX_FOLDER := "res://audio/sfx"
const MUSIC_FOLDER := "res://audio/music"
const MUSIC_BUS := &"Music"
const EFFECTS_BUS := &"Effects"
const BUSES: Array[StringName] = [&"Master", MUSIC_BUS, EFFECTS_BUS]
const DEFAULT_VOLUMES := {&"Master": 0.8, &"Music": 0.7, &"Effects": 0.85}
## Every sound effect; each is one or more files, <name>_<n>.wav.
const SOUNDS: Array[StringName] = [
	&"click", &"open", &"deny", &"page", &"coins",
	&"anvil", &"learn", &"equip", &"recruit", &"relief", &"embark",
	&"steps", &"treasure", &"event",
	&"battle_start", &"swing", &"shot", &"cast", &"miss", &"hit", &"crit", &"block", &"guard", &"resist",
	&"heal", &"buff", &"debuff", &"stress", &"stun", &"bleed", &"blight", &"burn", &"move",
	&"deaths_door", &"deathblow", &"slain", &"fallen", &"meltdown", &"resolute", &"chime",
]
## The looping tracks, and the stings that play once.
const TRACKS: Array[StringName] = [&"town", &"map", &"combat", &"boss"]
const STINGS: Array[StringName] = [&"victory", &"defeat", &"level_up"]
## Seconds a change of track takes.
const CROSSFADE := 1.5
## How far the music dips under a dialogue scene or a sting.
const DUCK_DB := -10.0
const SILENT_DB := -60.0
const VOICES := 16
## The same sound again this soon, in milliseconds, is skipped: several tokens landing at once sound once.
const REPEAT_MS := 50
## Buttons inside a node in this group don't click (the balance tool).
const QUIET_GROUP := &"quiet_buttons"

var _sounds: Dictionary[StringName, Array] = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_played: Dictionary[StringName, int] = {}
## Two players, so one track can fade out as the next fades in.
var _music: Array[AudioStreamPlayer] = []
var _playing := 0
var _track := &""
var _sting: AudioStreamPlayer
var _ducked := false
var _fades: Dictionary[AudioStreamPlayer, Tween] = {}
var _volumes: Dictionary[StringName, float] = {}
## Where the volumes are kept; tests point it elsewhere.
var settings_path := SETTINGS_PATH
## Browsers hold audio back until the first click or key; the track then starts again.
var _unlocked := not OS.has_feature("web")


## Built as the autoload is made, before any scene (or test) runs.
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: StringName in [MUSIC_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	_load_volumes()
	for sound in SOUNDS:
		_sounds[sound] = variants(sound)
	for i in VOICES:
		_players.append(_player(EFFECTS_BUS))
	for i in 2:
		_music.append(_player(MUSIC_BUS))
	_sting = _player(MUSIC_BUS)
	_sting.finished.connect(func() -> void: _fade(_music[_playing], _music_level(), 1.0))


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	if _unlocked or not event.is_pressed() or not (event is InputEventMouseButton or event is InputEventKey
			or event is InputEventScreenTouch):
		return
	_unlocked = true
	if _track != &"":
		_music[_playing].play.call_deferred()


## The files of `sound`'s variants, as streams.
static func variants(sound: StringName) -> Array[AudioStream]:
	var found: Array[AudioStream] = []
	while ResourceLoader.exists(_variant_path(sound, found.size() + 1)):
		found.append(load(_variant_path(sound, found.size() + 1)))
	return found


static func _variant_path(sound: StringName, number: int) -> String:
	return "%s/%s_%d.wav" % [SFX_FOLDER, sound, number]


static func track_path(track: StringName) -> String:
	return "%s/%s.wav" % [MUSIC_FOLDER, track]


# --- Sound effects ---

## Plays sound effect `sound`, `volume_db` louder or quieter than it was made.
func play(sound: StringName, volume_db := 0.0) -> void:
	var streams: Array = _sounds.get(sound, [])
	if streams.is_empty():
		push_warning("No sound effect named %s" % sound)
		return
	var now := Time.get_ticks_msec()
	if now - _last_played.get(sound, -REPEAT_MS) < REPEAT_MS:
		return
	_last_played[sound] = now
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = streams.pick_random()
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_click.bind(node))
	elif node is TabBar:
		(node as TabBar).tab_clicked.connect(func(_tab: int) -> void: _click(node))


func _click(node: Node) -> void:
	for quiet in get_tree().get_nodes_in_group(QUIET_GROUP):
		if quiet == node or quiet.is_ancestor_of(node):
			return
	play(&"click")


# --- Music ---

## Crossfades to looping track `track`. Asking for the track already playing changes nothing.
func play_music(track: StringName) -> void:
	if track == _track:
		return
	_track = track
	_fade(_music[_playing], SILENT_DB, CROSSFADE, true)
	_playing = 1 - _playing
	var next := _music[_playing]
	next.stream = load(track_path(track))
	next.volume_db = SILENT_DB
	next.play()
	_fade(next, _music_level(), CROSSFADE)


## Fades the music out over `seconds`; the next play_music starts its track from the beginning.
func stop_music(seconds := CROSSFADE) -> void:
	_track = &""
	_fade(_music[_playing], SILENT_DB, seconds, true)


func current_track() -> StringName:
	return _track


## Plays sting `name` once; the music dips until it ends.
func sting(name: StringName) -> void:
	_sting.stream = load(track_path(name))
	_sting.play()
	_fade(_music[_playing], _music_level(), 0.3)


## Lowers the music, or brings it back, as a dialogue scene starts or ends.
func duck(on: bool) -> void:
	_ducked = on
	_fade(_music[_playing], _music_level(), 0.6)


func _music_level() -> float:
	return DUCK_DB if _ducked or _sting.playing else 0.0


func _fade(player: AudioStreamPlayer, volume_db: float, seconds: float, stop := false) -> void:
	if _fades.has(player) and _fades[player].is_valid():
		_fades[player].kill()
	if not player.playing:
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", volume_db, seconds)
	if stop:
		tween.tween_callback(player.stop)
	_fades[player] = tween


func _player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# --- Volumes ---

## A bus's volume, from 0 (silent) to 1 (as made).
func volume(bus: StringName) -> float:
	return _volumes.get(bus, DEFAULT_VOLUMES[bus])


## Sets and saves a bus's volume. The level is squared on its way to decibels,
## so half way on a slider sounds about half as loud.
func set_volume(bus: StringName, value: float) -> void:
	_volumes[bus] = clampf(value, 0.0, 1.0)
	_apply(bus)
	var config := ConfigFile.new()
	config.load(settings_path)
	for each in BUSES:
		config.set_value("volume", String(each), volume(each))
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save the settings: %s" % error_string(error))


func _load_volumes() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for bus in BUSES:
			_volumes[bus] = clampf(float(config.get_value("volume", String(bus), DEFAULT_VOLUMES[bus])), 0.0, 1.0)
	for bus in BUSES:
		_apply(bus)


func _apply(bus: StringName) -> void:
	var index := AudioServer.get_bus_index(bus)
	var level := volume(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level * level, 0.00001)))
	AudioServer.set_bus_mute(index, level <= 0.0)
