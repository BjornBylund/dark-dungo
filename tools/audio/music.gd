## Recipes for the music, rendered by tools/make_audio.gd to audio/music/<name>.wav,
## all in D minor. A looping track is sequenced over its loop, rendered with
## its last notes' tails, given its reverb, and then the tails are folded back
## onto the start, so the end runs on into the beginning without a seam. The
## stings play once.
extends RefCounted

const Synth := preload("res://tools/audio/synth.gd")
## Mono at 22.05 kHz keeps the files small; the music is low and dark anyway.
const RATE := 22050

## name: [loops, loudness in dB RMS], the loudness reached unless the peaks
## would clip. Audio.TRACKS and Audio.STINGS must name the same.
const TRACKS := {
	&"town": [true, -18.0],
	&"map": [true, -20.0],
	&"combat": [true, -16.5],
	&"boss": [true, -16.0],
	&"victory": [false, -17.0],
	&"defeat": [false, -19.0],
	&"level_up": [false, -20.0],
}

## The town's lute line: [second, note], over chords eight seconds apart.
const TOWN_MELODY := [
	[1.0, 62], [2.0, 65], [3.0, 69], [4.5, 67], [5.0, 65], [6.0, 64], [7.0, 62],
	[9.0, 62], [10.0, 65], [11.0, 70], [12.5, 69], [13.0, 67], [14.0, 65],
	[17.0, 67], [18.0, 70], [19.0, 74], [20.5, 72], [21.0, 70], [22.0, 69],
	[25.0, 69], [26.0, 64], [27.0, 61], [28.5, 64], [29.0, 69],
	[33.0, 74], [34.0, 72], [35.0, 69], [36.5, 70], [37.0, 69], [38.0, 65], [39.0, 62],
	[41.0, 65], [42.0, 69], [43.0, 72], [44.5, 70], [45.0, 69], [46.0, 65],
	[49.0, 67], [50.0, 70], [51.0, 69], [52.5, 67], [53.0, 65], [54.0, 64],
	[57.0, 64], [58.0, 61], [59.0, 57], [60.0, 61], [61.0, 64], [62.5, 62],
]
## Each chord's bass note, the notes held over it, and its riff of eighth notes.
const CHORDS := {
	&"Dm": [38, [57, 62, 65], [50, 50, 53, 50, 52, 50, 48, 50]],
	&"Bb": [34, [58, 62, 65], [46, 46, 50, 46, 48, 46, 45, 46]],
	&"Gm": [43, [58, 62, 67], [43, 43, 46, 43, 45, 43, 41, 43]],
	&"A": [45, [57, 61, 64], [45, 45, 49, 45, 47, 45, 44, 45]],
	&"Eb": [39, [51, 55, 58], []],
	&"C": [36, [48, 52, 55], []],
}
## The boss's riff on D (Phrygian), moved to each chord's bass note.
const BOSS_RIFF := [38, 38, 39, 38, 38, 41, 39, 38]


func render(s: Synth, track: StringName) -> PackedFloat32Array:
	return call("_" + track, s)


# --- Instruments ---

## A bowed note: detuned saws, low-passed, swelling in and fading out over `release` past `seconds`.
func _bow(s: Synth, note: float, seconds: float, attack: float, release: float, cutoff := 1400.0) -> PackedFloat32Array:
	var voice := s.ensemble(s.hz(note), seconds + release, 3, 9.0, Synth.Wave.SAW, 0.004)
	s.lowpass(voice, cutoff, 0.7)
	return s.adsr(voice, attack, 0.0, 1.0, release)


## A short, biting bowed note for the riffs.
func _stab(s: Synth, note: float, bright := 2400.0) -> PackedFloat32Array:
	var voice := s.ensemble(s.hz(note), 0.26, 3, 8.0, Synth.Wave.SAW)
	s.lowpass(voice, [[0.0, bright], [0.2, bright / 3.0]], 0.9)
	return s.adsr(voice, 0.006, 0.08, 0.6, 0.08)


func _harp(s: Synth, note: float, seconds: float) -> PackedFloat32Array:
	return s.lowpass(s.pluck(s.hz(note), seconds, 0.45), 3200.0)


func _sing(s: Synth, note: float, seconds: float, attack: float, release: float, vowel: StringName) -> PackedFloat32Array:
	return s.adsr(s.choir(s.hz(note), seconds + release, vowel), attack, 0.0, 1.0, release)


func _horn(s: Synth, note: float, seconds: float) -> PackedFloat32Array:
	var voice := s.ensemble(s.hz(note), seconds, 2, 8.0, Synth.Wave.SAW)
	s.lowpass(voice, [[0.0, 250.0], [0.1, 1500.0], [seconds, 600.0]], 1.0)
	return s.adsr(voice, 0.03, 0.2, 0.7, minf(0.4, seconds * 0.5))


func _low_drum(s: Synth) -> PackedFloat32Array:
	return s.drive(s.drum(0.8, 95.0, 48.0, 0.35, 500.0), 1.4)


func _mid_drum(s: Synth) -> PackedFloat32Array:
	return s.drum(0.35, 180.0, 125.0, 0.45, 1400.0)


func _rim(s: Synth) -> PackedFloat32Array:
	var click := s.perc(s.bandpass(s.noise(0.04), 3200.0, 2.0), 0.0005, 0.035)
	return s.add(click, s.perc(s.tone(0.04, 820.0), 0.0005, 0.03), 0.0, 0.4)


func _snare(s: Synth) -> PackedFloat32Array:
	var rattle := s.perc(s.bandpass(s.noise(0.25), 1900.0, 0.7), 0.001, 0.2)
	return s.add(rattle, s.perc(s.tone(0.12, [[0.0, 200.0], [0.1, 165.0]]), 0.001, 0.1), 0.0, 0.7)


## Wind through dead trees: noise in a band that wanders with a `period`-second sway.
func _wind(s: Synth, seconds: float, period: float) -> PackedFloat32Array:
	var centers := []
	var levels := []
	for k in int(seconds / 0.5) + 1:
		var t := k * 0.5
		centers.append([t, 550.0 * pow(2.0, 0.9 * sin(TAU * t / period))])
		levels.append([t, 0.6 + 0.4 * sin(TAU * t / period + 1.3)])
	var air := s.bandpass(s.noise(seconds), centers, 2.0)
	return s.fade(s.shape(air, levels), 2.0, 2.0)


## The reverb, then the tails folded onto the start: a seamless loop of
## `length` seconds. Rumble is filtered out before the fold, as a filter
## started on the loop itself would jump where the loop wraps.
func _loop(s: Synth, buf: PackedFloat32Array, length: float, room: float, damp: float, wet: float) -> PackedFloat32Array:
	return s.fold(s.clean(s.reverb(buf, room, damp, wet, 5.0)), length)


## The chord of each bar, from [chord, bars] pairs.
func _bars(plan: Array) -> Array[StringName]:
	var bars: Array[StringName] = []
	for part: Array in plan:
		for i in part[1]:
			bars.append(part[0])
	return bars


## How many bars from `bar` on keep the same chord.
func _held(bars: Array[StringName], bar: int) -> int:
	var count := 1
	while bar + count < bars.size() and bars[bar + count] == bars[bar]:
		count += 1
	return count


# --- Tracks ---

## The hamlet and the title: held strings under a sparse lute, a distant bell. 64 s.
func _town(s: Synth) -> PackedFloat32Array:
	var length := 64.0
	var buf := s.silence(length + 8.0)
	var progression: Array = [
		[38, [50, 57, 65]], [34, [50, 58, 65]], [43, [50, 58, 67]], [45, [49, 57, 64]],
		[38, [50, 57, 65]], [41, [48, 57, 65]], [43, [50, 58, 67]], [45, [52, 57, 61]],
	]
	for i in progression.size():
		var at := i * 8.0
		s.add(buf, _bow(s, progression[i][0], 8.5, 1.5, 2.5, 500.0), at, 0.3)
		for note: int in progression[i][1]:
			s.add(buf, _bow(s, note, 8.5, 2.5, 3.0), at, 0.12)
	for note: Array in TOWN_MELODY:
		s.add(buf, _harp(s, note[1], 3.0), note[0], 0.35)
	s.add(buf, s.lowpass(s.bell(s.hz(50), 6.0, 0.4), 2000.0), 0.0, 0.25)
	s.add(buf, s.lowpass(s.bell(s.hz(45), 6.0, 0.4), 2000.0), 32.0, 0.2)
	return _loop(s, buf, length, 0.85, 0.5, 0.35)


## The mission map: drones a fifth or a tritone apart, a slow heartbeat, wind,
## and glass tones in the dark. 64 s.
func _map(s: Synth) -> PackedFloat32Array:
	var length := 64.0
	var buf := s.silence(length + 8.0)
	var drones: Array = [[38, 45], [38, 46], [38, 45], [38, 44]]
	for i in drones.size():
		for note: int in drones[i]:
			s.add(buf, _bow(s, note, 17.0, 3.0, 3.0, 320.0), i * 16.0, 0.25)
	for swell: Array in [[4.0, 50], [20.0, 53], [36.0, 52], [52.0, 51]]:
		s.add(buf, _bow(s, swell[1], 8.0, 4.0, 4.0, 700.0), swell[0], 0.14)
	for k in 8:
		var soft := k == 3 or k == 7
		s.add(buf, _low_drum(s), k * 8.0, 0.18 if soft else 0.3)
		s.add(buf, _low_drum(s), k * 8.0 + 0.33, 0.12 if soft else 0.2)
	s.add(buf, _wind(s, length + 2.0, 16.0), 0.0, 0.1)
	for glass: Array in [[6.0, 86], [13.0, 87], [27.0, 81], [38.0, 86], [44.0, 82], [59.0, 80]]:
		s.add(buf, s.bell(s.hz(glass[1]), 5.0, 0.25), glass[0], 0.1)
	return _loop(s, buf, length, 0.9, 0.4, 0.45)


## Fights: war drums, a riff of low strings, horns every four bars, and voices
## for the last eight. 120 BPM, 24 bars, 48 s.
func _combat(s: Synth) -> PackedFloat32Array:
	var bar_length := 2.0
	var step := bar_length / 16.0
	var bars := _bars([[&"Dm", 4], [&"Bb", 4], [&"Gm", 4], [&"A", 4], [&"Dm", 2], [&"Bb", 2], [&"Gm", 2], [&"A", 2]])
	var length := bars.size() * bar_length
	var buf := s.silence(length + 6.0)
	for bar in bars.size():
		var at := bar * bar_length
		var chord: Array = CHORDS[bars[bar]]
		var late := bar >= 16
		for i in 16:
			var t := at + i * step
			if i in [0, 6, 8] or (late and i == 14):
				s.add(buf, _low_drum(s), t, 0.9 if i == 0 else 0.6)
			if i in [4, 12]:
				s.add(buf, _mid_drum(s), t, 0.45)
			if i in [2, 10, 14]:
				s.add(buf, _rim(s), t, 0.2)
			if bar % 4 == 3 and i >= 12:
				s.add(buf, _mid_drum(s), t, 0.35 + 0.05 * (i - 12))
		for k in 8:
			s.add(buf, _stab(s, chord[2][k]), at + k * step * 2.0, 0.26 if k % 2 == 0 else 0.18)
		s.add(buf, _bow(s, chord[0], 1.8, 0.05, 0.3, 380.0), at, 0.35)
		var starts := bar == 0 or bars[bar - 1] != bars[bar]
		if starts:
			var held := _held(bars, bar) * bar_length
			for note: int in chord[1]:
				s.add(buf, _bow(s, note, held, 0.8, 1.2, 1200.0), at, 0.08)
				if late:
					s.add(buf, _sing(s, note, held, 0.5, 1.0, &"a"), at, 0.07)
		if bar % 4 == 0:
			s.add(buf, _horn(s, chord[0] + 12, 0.7), at, 0.22)
			s.add(buf, _horn(s, chord[0] + 19, 0.7), at, 0.16)
	return _loop(s, buf, length, 0.6, 0.5, 0.2)


## Boss fights: a Phrygian riff, drums on every beat, a choir, a tolling bell,
## and tritone horns. 140 BPM, 28 bars, 48 s.
func _boss(s: Synth) -> PackedFloat32Array:
	var bar_length := 4.0 * 60.0 / 140.0
	var step := bar_length / 16.0
	var bars := _bars([[&"Dm", 2], [&"Eb", 2], [&"Dm", 2], [&"C", 2], [&"Bb", 2], [&"Eb", 2], [&"Gm", 2], [&"A", 2],
			[&"Dm", 2], [&"Eb", 2], [&"Dm", 2], [&"Eb", 2], [&"Bb", 2], [&"A", 2]])
	var length := bars.size() * bar_length
	var buf := s.silence(length + 6.0)
	for bar in bars.size():
		var at := bar * bar_length
		var chord: Array = CHORDS[bars[bar]]
		var shift: int = (chord[0] - 38 + 6) % 12 - 6
		for i in 16:
			var t := at + i * step
			if i % 4 == 0:
				s.add(buf, _low_drum(s), t, [0.75, 0.55, 0.65, 0.55][int(i / 4.0)])
			elif i == 14:
				s.add(buf, _low_drum(s), t, 0.45)
			if i == 4 or i == 12:
				s.add(buf, _snare(s), t, 0.5)
			if i % 2 == 1:
				s.add(buf, _rim(s), t, 0.12 if i % 4 == 3 else 0.08)
			if bar % 4 == 3 and i in [8, 10, 12, 13, 14, 15]:
				s.add(buf, _mid_drum(s), t, 0.4)
		for k in 8:
			s.add(buf, s.drive(_stab(s, BOSS_RIFF[k] + shift, 1600.0), 1.5), at + k * step * 2.0, 0.3 if k % 2 == 0 else 0.22)
		if bar == 0 or bars[bar - 1] != bars[bar]:
			var held := _held(bars, bar) * bar_length
			for note: int in chord[1]:
				s.add(buf, _sing(s, note, held, 0.4, 0.8, &"a"), at, 0.08)
				s.add(buf, _bow(s, note, held, 0.6, 0.8, 1000.0), at, 0.06)
		if bar % 4 == 0:
			s.add(buf, s.bell(s.hz(50), 4.0, 0.5), at, 0.22)
		if bar == 0 or bar == 16:
			s.add(buf, _horn(s, 50, 0.8), at, 0.22)
			s.add(buf, _horn(s, 56, 0.8), at, 0.2)
	return _loop(s, buf, length, 0.7, 0.5, 0.22)


# --- Stings ---

## A fight won: two drums, a horn call up to D, a major chord and a bell.
func _victory(s: Synth) -> PackedFloat32Array:
	var buf := s.silence(4.5)
	s.add(buf, _low_drum(s), 0.0, 0.8)
	s.add(buf, _low_drum(s), 0.25, 0.6)
	s.add(buf, _horn(s, 57, 0.22), 0.0, 0.3)
	s.add(buf, _horn(s, 62, 2.2), 0.25, 0.35)
	for note: int in [50, 54, 57]:
		s.add(buf, _bow(s, note, 2.0, 0.15, 1.2, 1600.0), 0.25, 0.15)
	s.add(buf, s.bell(s.hz(74), 2.5, 0.5), 0.25, 0.2)
	return s.fade(s.reverb(buf, 0.75, 0.5, 0.3, 2.0), 0.0, 0.5)


## A fight lost: a low bell, strings falling to A, low voices.
func _defeat(s: Synth) -> PackedFloat32Array:
	var buf := s.silence(6.0)
	s.add(buf, s.bell(s.hz(38), 5.0, 0.5), 0.0, 0.5)
	for line: Array in [[0.3, 62, 1.2], [1.5, 60, 1.2], [2.7, 58, 1.2], [3.9, 57, 1.8]]:
		s.add(buf, _bow(s, line[1], line[2], 0.3, 0.8, 1000.0), line[0], 0.25)
	for note: int in [50, 53, 57]:
		s.add(buf, _sing(s, note, 4.5, 1.0, 1.2, &"u"), 0.3, 0.1)
	return s.fade(s.reverb(buf, 0.85, 0.5, 0.4, 2.5), 0.0, 1.0)


## A level gained: a bright arpeggio up to D and a bell.
func _level_up(s: Synth) -> PackedFloat32Array:
	var buf := s.silence(3.0)
	for i in 4:
		s.add(buf, s.pluck(s.hz([62, 66, 69, 74][i]), 1.8, 0.7), i * 0.1, 0.4)
		s.add(buf, s.bell(s.hz([74, 78, 81, 86][i]), 1.2, 0.4), i * 0.1, 0.12)
	s.add(buf, s.bell(s.hz(86), 2.0, 0.6), 0.45, 0.3)
	var sparkle := s.shape(s.highpass(s.noise(1.0), 5000.0), [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]])
	s.add(buf, sparkle, 0.4, 0.05)
	return s.fade(s.reverb(buf, 0.75, 0.4, 0.35, 1.5), 0.0, 0.5)
