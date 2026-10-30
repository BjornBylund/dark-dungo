## Recipes for the sound effects, rendered by tools/make_audio.gd to
## audio/sfx/<name>_<n>.wav. Each recipe takes the synth (its random numbers
## seeded by the sound and variant) and the variant's number, from 1, and
## returns the sound. SOUNDS lists each one's variants and peak level.
extends RefCounted

const Synth := preload("res://tools/audio/synth.gd")
const RATE := 44100

## name: [variants, peak level]. Audio.SOUNDS must name the same sounds.
const SOUNDS := {
	# Menus and windows
	&"click": [2, 0.3],
	&"open": [1, 0.45],
	&"deny": [1, 0.4],
	&"page": [1, 0.3],
	&"coins": [2, 0.5],
	# Town
	&"anvil": [1, 0.55],
	&"learn": [1, 0.5],
	&"equip": [1, 0.45],
	&"recruit": [1, 0.65],
	&"relief": [1, 0.5],
	&"embark": [1, 0.8],
	# The mission map
	&"steps": [1, 0.5],
	&"treasure": [1, 0.55],
	&"event": [1, 0.55],
	# Combat
	&"battle_start": [1, 0.85],
	&"swing": [3, 0.55],
	&"shot": [2, 0.55],
	&"cast": [1, 0.45],
	&"miss": [1, 0.4],
	&"hit": [3, 0.85],
	&"crit": [1, 0.95],
	&"block": [1, 0.65],
	&"guard": [1, 0.55],
	&"resist": [1, 0.45],
	&"heal": [1, 0.5],
	&"buff": [1, 0.45],
	&"debuff": [1, 0.5],
	&"stress": [1, 0.5],
	&"stun": [1, 0.55],
	&"bleed": [1, 0.55],
	&"blight": [1, 0.5],
	&"burn": [1, 0.55],
	&"move": [1, 0.35],
	&"deaths_door": [1, 0.75],
	&"deathblow": [1, 0.9],
	&"slain": [2, 0.7],
	&"fallen": [1, 0.65],
	&"meltdown": [1, 0.75],
	&"resolute": [1, 0.7],
	&"chime": [1, 0.5],
}


func render(s: Synth, sound: StringName, variant: int) -> PackedFloat32Array:
	return call("_" + sound, s, variant)


# --- Pieces several sounds share ---

## A small piece of metal struck: inharmonic partials, the high ones short.
func _clink(s: Synth, pitch: float, ring: float) -> PackedFloat32Array:
	var buf := s.silence(ring + 0.02)
	for partial: Array in [[1.0, 1.0], [2.76, 0.5], [5.4, 0.25], [8.93, 0.12]]:
		var f: float = pitch * partial[0]
		if f < s.rate * 0.45:
			s.add(buf, s.perc(s.tone(ring, f), 0.0005, ring / sqrt(partial[0])), 0.0, partial[1])
	return buf


## A blade or arm through the air: noise swept up through a band and down.
func _whoosh(s: Synth, seconds: float, low: float, high: float, peak_at: float) -> PackedFloat32Array:
	var air := s.bandpass(s.noise(seconds), [[0.0, low], [peak_at, high], [seconds, low * 1.4]], 1.3)
	return s.shape(air, [[0.0, 0.0], [peak_at, 1.0], [seconds, 0.0]])


## One footfall on packed earth.
func _footfall(s: Synth, weight: float) -> PackedFloat32Array:
	var thud := s.perc(s.lowpass(s.noise(0.1), 380.0), 0.002, 0.08)
	var grit := s.perc(s.bandpass(s.noise(0.12), s.rng.randf_range(1800.0, 2600.0), 0.8), 0.003, 0.09)
	var body := s.perc(s.tone(0.08, [[0.0, 95.0], [0.08, 60.0]]), 0.002, 0.07)
	return s.layer(0.13, [[thud, 0.0, weight], [grit, 0.0, 0.25], [body, 0.0, 0.6 * weight]])


## A soft sine note with its octave, for chimes that glow rather than strike.
func _glow(s: Synth, note: float, seconds: float) -> PackedFloat32Array:
	var pitch := s.hz(note)
	var buf := s.add(s.tone(seconds, pitch), s.tone(seconds, pitch * 2.0), 0.0, 0.3)
	return s.perc(buf, 0.02, seconds)


func _brass(s: Synth, note: float, seconds: float) -> PackedFloat32Array:
	var buf := s.ensemble(s.hz(note), seconds, 2, 8.0, Synth.Wave.SAW)
	s.lowpass(buf, [[0.0, 250.0], [0.1, 1500.0], [seconds, 600.0]], 1.0)
	return s.adsr(buf, 0.03, 0.2, 0.7, minf(0.4, seconds * 0.5))


# --- Menus and windows ---

## A wooden tick.
func _click(s: Synth, variant: int) -> PackedFloat32Array:
	var pitch := 1700.0 if variant == 1 else 1450.0
	var tick := s.perc(s.bandpass(s.noise(0.05), pitch, 4.0), 0.0005, 0.03)
	var body := s.perc(s.tone(0.05, [[0.0, pitch * 0.5], [0.05, pitch * 0.42]], Synth.Wave.TRIANGLE), 0.0005, 0.035)
	return s.layer(0.06, [[tick, 0.0, 1.0], [body, 0.0, 0.5]])


## Cloth and paper thrown open.
func _open(s: Synth, _variant: int) -> PackedFloat32Array:
	var air := s.lowpass(s.noise(0.4), [[0.0, 400.0], [0.12, 2200.0], [0.4, 600.0]], 0.9)
	s.shape(air, [[0.0, 0.0], [0.08, 1.0], [0.4, 0.0]])
	var thud := s.perc(s.tone(0.25, [[0.0, 140.0], [0.25, 80.0]]), 0.003, 0.2)
	return s.layer(0.42, [[air, 0.0, 0.7], [thud, 0.02, 0.6]])


## Two dull knocks: no.
func _deny(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.3)
	for knock: Array in [[0.0, 1.0], [0.12, 0.8]]:
		var wood := s.perc(s.lowpass(s.noise(0.08), 900.0), 0.001, 0.07)
		var body := s.perc(s.tone(0.1, [[0.0, 190.0], [0.1, 150.0]]), 0.001, 0.08)
		s.add(buf, s.layer(0.1, [[wood, 0.0, 0.6], [body, 0.0, 1.0]]), knock[0], knock[1])
	return buf


## A page turned.
func _page(s: Synth, _variant: int) -> PackedFloat32Array:
	var paper := s.highpass(s.noise(0.3), [[0.0, 1500.0], [0.3, 4000.0]])
	s.shape(paper, [[0.0, 0.0], [0.07, 1.0], [0.12, 0.4], [0.18, 0.7], [0.3, 0.0]])
	return s.lowpass(paper, 7000.0)


## A few coins dropped on a table.
func _coins(s: Synth, variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.75)
	for i in 4 + variant * 2:
		var at := 0.0 if i == 0 else s.rng.randf_range(0.02, 0.34)
		s.add(buf, _clink(s, s.rng.randf_range(2600.0, 4300.0), s.rng.randf_range(0.15, 0.3)), at,
				s.rng.randf_range(0.5, 1.0))
	return buf


# --- Town ---

## A hammer on an anvil, ringing.
func _anvil(s: Synth, _variant: int) -> PackedFloat32Array:
	var ring := s.silence(1.3)
	for partial: Array in [[1.0, 1.0, 1.0], [2.43, 0.6, 0.7], [3.87, 0.45, 0.5], [5.61, 0.3, 0.35], [7.12, 0.2, 0.25]]:
		var f: float = 620.0 * partial[0] * s.rng.randf_range(0.998, 1.002)
		s.add(ring, s.perc(s.tone(1.3, f), 0.0005, 1.2 * partial[2]), 0.0, partial[1])
	var strike := s.perc(s.bandpass(s.noise(0.05), 3000.0, 1.2), 0.0003, 0.04)
	var thud := s.perc(s.tone(0.15, [[0.0, 160.0], [0.15, 90.0]]), 0.001, 0.12)
	var buf := s.layer(1.3, [[ring, 0.0, 0.5], [strike, 0.0, 1.0], [thud, 0.0, 0.7]])
	return s.reverb(buf, 0.5, 0.5, 0.15, 0.6)


## A page, then a rising chime: something learned.
func _learn(s: Synth, variant: int) -> PackedFloat32Array:
	var buf := s.add(s.silence(1.3), _page(s, variant), 0.0, 0.6)
	for i in 3:
		s.add(buf, s.bell(s.hz([69, 74, 78][i]), 1.1, 0.5), 0.06 + i * 0.1, 0.45)
	return s.reverb(buf, 0.7, 0.4, 0.3, 1.0)


## A buckle fastened.
func _equip(s: Synth, _variant: int) -> PackedFloat32Array:
	var leather := s.perc(s.bandpass(s.noise(0.15), 320.0, 1.0), 0.01, 0.12)
	var snap := s.perc(s.bandpass(s.noise(0.04), 2600.0, 2.0), 0.0005, 0.03)
	return s.layer(0.4, [[leather, 0.0, 0.5], [snap, 0.08, 0.8], [_clink(s, 1900.0, 0.18), 0.09, 0.5]])


## A bell tolls over a warm chord: someone new arrives.
func _recruit(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.add(s.silence(2.6), s.bell(s.hz(57), 2.6, 0.5), 0.0, 0.7)
	for note: int in [50, 54, 57]:
		var voice := s.lowpass(s.ensemble(s.hz(note), 2.2, 3, 9.0), 1200.0)
		s.add(buf, s.adsr(voice, 0.5, 0.0, 1.0, 1.2), 0.15, 0.12)
	return s.reverb(buf, 0.8, 0.5, 0.3, 1.5)


## A harp's falling-open chord: the weight lifts.
func _relief(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(1.8)
	for i in 4:
		s.add(buf, s.lowpass(s.pluck(s.hz([62, 69, 74, 78][i]), 1.6, 0.4), 3000.0), i * 0.09, 0.5)
	return s.reverb(buf, 0.75, 0.4, 0.3, 1.2)


## A war drum and a low horn: the party sets out.
func _embark(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.add(s.silence(2.2), s.drive(s.drum(1.2, 90.0, 48.0, 0.4, 500.0), 1.5), 0.0, 1.0)
	s.add(buf, _brass(s, 45, 0.4), 0.05, 0.35)
	s.add(buf, _brass(s, 50, 1.3), 0.45, 0.4)
	return s.reverb(buf, 0.7, 0.5, 0.25, 1.2)


# --- The mission map ---

## Three steps along a path.
func _steps(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.5)
	for i in 3:
		s.add(buf, _footfall(s, s.rng.randf_range(0.7, 1.0)), i * 0.15 + s.rng.randf_range(-0.01, 0.01), 1.0)
	return buf


## A chest's hinge creaks, then coins.
func _treasure(s: Synth, variant: int) -> PackedFloat32Array:
	var creak := s.tone(0.5, [[0.0, 135.0], [0.5, 95.0]], Synth.Wave.SAW)
	s.tremolo(creak, 31.0, 0.7)
	s.bandpass(creak, [[0.0, 700.0], [0.5, 1100.0]], 1.5)
	s.shape(creak, [[0.0, 0.0], [0.08, 1.0], [0.4, 0.8], [0.5, 0.0]])
	var buf := s.add(s.silence(1.3), creak, 0.0, 0.5)
	return s.add(buf, _coins(s, variant), 0.42, 0.9)


## Glass tones a semitone apart over a low swell: something strange here.
func _event(s: Synth, _variant: int) -> PackedFloat32Array:
	var swell := s.lowpass(s.ensemble(s.hz(38), 1.8, 3, 12.0), 300.0)
	s.shape(swell, [[0.0, 0.0], [0.6, 1.0], [1.8, 0.0]])
	var buf := s.add(s.silence(1.8), swell, 0.0, 0.6)
	s.add(buf, s.bell(s.hz(86), 1.6, 0.3), 0.0, 0.3)
	s.add(buf, s.bell(s.hz(87), 1.5, 0.3), 0.3, 0.25)
	return s.reverb(buf, 0.85, 0.4, 0.4, 1.5)


# --- Combat ---

## A great drum, a second answering it, a brass stab and a hiss of cymbal: battle.
func _battle_start(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.add(s.silence(2.0), s.drive(s.drum(1.5, 80.0, 40.0, 0.5, 600.0), 1.6), 0.0, 1.0)
	s.add(buf, s.drum(0.6, 130.0, 90.0, 0.4, 900.0), 0.25, 0.6)
	var cymbal := s.shape(s.highpass(s.noise(1.6), 5000.0), [[0.0, 0.0], [0.05, 1.0], [1.6, 0.0]])
	s.add(buf, cymbal, 0.25, 0.12)
	s.add(buf, _brass(s, 38, 0.7), 0.0, 0.3)
	s.add(buf, _brass(s, 45, 0.7), 0.0, 0.25)
	return s.reverb(buf, 0.6, 0.5, 0.25, 1.0)


func _swing(s: Synth, variant: int) -> PackedFloat32Array:
	var peak_at: float = [0.1, 0.085, 0.12][variant - 1]
	return s.lowpass(_whoosh(s, 0.32, 500.0, [2400.0, 2900.0, 2000.0][variant - 1], peak_at), 6000.0)


## A throw or a shot: a flick, then a quick rush of air.
func _shot(s: Synth, variant: int) -> PackedFloat32Array:
	var snap := s.perc(s.highpass(s.noise(0.02), 2500.0), 0.0002, 0.015)
	var flick := s.tone(0.05, [[0.0, 2200.0 - variant * 300.0], [0.04, 700.0]], Synth.Wave.TRIANGLE)
	s.perc(flick, 0.0005, 0.04)
	return s.layer(0.32, [[snap, 0.0, 0.7], [flick, 0.0, 0.5], [_whoosh(s, 0.24, 900.0, 3600.0, 0.07), 0.02, 1.0]])


## A shimmer rising: a skill that isn't an attack.
func _cast(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.6)
	for note: int in [76, 81, 83, 88]:
		var glide := s.tone(0.55, [[0.0, s.hz(note - 12)], [0.5, s.hz(note)]])
		s.add(buf, s.shape(glide, [[0.0, 0.0], [0.15, 1.0], [0.55, 0.0]]), 0.0, 0.2)
	var sparkle := s.shape(s.highpass(s.noise(0.5), 6000.0), [[0.0, 0.0], [0.25, 1.0], [0.5, 0.0]])
	s.add(buf, sparkle, 0.05, 0.08)
	return s.reverb(buf, 0.6, 0.4, 0.3, 0.6)


func _miss(s: Synth, _variant: int) -> PackedFloat32Array:
	return _whoosh(s, 0.22, 1200.0, 4000.0, 0.06)


## A blow landing: a low thump, a smack and a crunch.
func _hit(s: Synth, variant: int) -> PackedFloat32Array:
	var thump := s.perc(s.tone(0.25, [[0.0, 140.0 - variant * 10.0], [0.12, 55.0]]), 0.001, 0.18)
	var smack := s.perc(s.lowpass(s.noise(0.12), [[0.0, 3000.0], [0.12, 600.0]]), 0.0005, 0.08)
	var crunch := s.perc(s.bandpass(s.noise(0.1), 750.0 + variant * 150.0, 1.5), 0.001, 0.09)
	var buf := s.layer(0.3, [[thump, 0.0, 1.0], [smack, 0.0, 0.7], [crunch, 0.005, 0.5]])
	return s.drive(buf, 2.0)


## A heavier blow: a boom under the hit, a crack and a ring.
func _crit(s: Synth, variant: int) -> PackedFloat32Array:
	var boom := s.perc(s.tone(0.6, [[0.0, 90.0], [0.25, 35.0]]), 0.001, 0.5)
	var crack := s.perc(s.highpass(s.noise(0.08), 3000.0), 0.0003, 0.05)
	var buf := s.layer(0.8, [[_hit(s, variant), 0.0, 0.9], [boom, 0.0, 0.8], [crack, 0.0, 0.5],
			[_clink(s, 1500.0, 0.5), 0.0, 0.2]])
	return s.reverb(s.drive(buf, 2.5), 0.5, 0.5, 0.2, 0.5)


## A blow on armour or a shield: a clang.
func _block(s: Synth, _variant: int) -> PackedFloat32Array:
	var ring := s.silence(0.55)
	for partial: Array in [[1.0, 1.0], [1.58, 0.7], [2.31, 0.5], [3.12, 0.35], [4.2, 0.2]]:
		s.add(ring, s.perc(s.tone(0.55, 1180.0 * partial[0]), 0.0005, 0.45 / sqrt(partial[0])), 0.0, partial[1])
	var strike := s.perc(s.bandpass(s.noise(0.04), 4000.0, 1.0), 0.0003, 0.03)
	var thud := s.perc(s.tone(0.12, [[0.0, 200.0], [0.12, 120.0]]), 0.001, 0.1)
	var buf := s.layer(0.55, [[ring, 0.0, 0.45], [strike, 0.0, 0.8], [thud, 0.0, 0.6]])
	return s.reverb(buf, 0.4, 0.5, 0.15, 0.4)


## A shield raised: a wooden thunk.
func _guard(s: Synth, _variant: int) -> PackedFloat32Array:
	var body := s.perc(s.tone(0.2, [[0.0, 210.0], [0.2, 150.0]]), 0.001, 0.15)
	var wood := s.perc(s.lowpass(s.noise(0.08), 1200.0), 0.0005, 0.06)
	return s.layer(0.4, [[body, 0.0, 1.0], [wood, 0.0, 0.6], [_clink(s, 2400.0, 0.1), 0.01, 0.2]])


## Something shrugged off: a dull knock.
func _resist(s: Synth, _variant: int) -> PackedFloat32Array:
	var body := s.perc(s.tone(0.18, [[0.0, 320.0], [0.18, 260.0]], Synth.Wave.TRIANGLE), 0.001, 0.12)
	var tap := s.perc(s.bandpass(s.noise(0.05), 1500.0, 2.0), 0.0005, 0.05)
	return s.layer(0.3, [[body, 0.0, 1.0], [tap, 0.0, 0.5]])


## A warm chime rising.
func _heal(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(1.3)
	for i in 3:
		s.add(buf, _glow(s, [74, 81, 86][i], 1.1), i * 0.07, 0.5)
	return s.reverb(buf, 0.7, 0.4, 0.35, 0.8)


## Two tones gliding up a fifth.
func _buff(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.7)
	for note: int in [62, 69]:
		var glide := s.tone(0.6, [[0.0, s.hz(note)], [0.25, s.hz(note + 7)]], Synth.Wave.TRIANGLE)
		s.add(buf, s.shape(glide, [[0.0, 0.0], [0.04, 1.0], [0.6, 0.0]]), 0.0, 0.5)
	s.lowpass(buf, 4000.0)
	return s.reverb(buf, 0.6, 0.4, 0.25, 0.6)


## A dark glide down, with a tritone under it.
func _debuff(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.8)
	for interval: float in [1.0, 1.414]:
		var glide := s.tone(0.7, [[0.0, 330.0 * interval], [0.5, 190.0 * interval]], Synth.Wave.SAW)
		s.add(buf, s.shape(s.lowpass(glide, 900.0), [[0.0, 0.0], [0.04, 1.0], [0.7, 0.0]]), 0.0,
				0.6 if interval == 1.0 else 0.35)
	return s.reverb(buf, 0.6, 0.5, 0.25, 0.6)


## A whisper and two tones grinding a semitone apart.
func _stress(s: Synth, _variant: int) -> PackedFloat32Array:
	var whisper := s.bandpass(s.noise(0.9), [[0.0, 1800.0], [0.4, 900.0], [0.9, 2600.0]], 3.0)
	s.shape(whisper, [[0.0, 0.0], [0.15, 1.0], [0.5, 0.6], [0.9, 0.0]])
	var buf := s.add(s.silence(0.95), whisper, 0.0, 0.8)
	for note: int in [75, 76]:
		var voice := s.tremolo(s.tone(0.9, s.hz(note)), 9.0, 0.6)
		s.add(buf, s.shape(voice, [[0.0, 0.0], [0.2, 1.0], [0.9, 0.0]]), 0.0, 0.2)
	return s.reverb(buf, 0.6, 0.4, 0.3, 0.6)


## A knock on the head, and ringing.
func _stun(s: Synth, _variant: int) -> PackedFloat32Array:
	var bonk := s.perc(s.tone(0.15, [[0.0, 400.0], [0.15, 200.0]], Synth.Wave.TRIANGLE), 0.001, 0.1)
	var ring := s.add(s.tone(0.8, 1800.0), s.tone(0.8, 2710.0), 0.0, 0.6)
	s.perc(s.tremolo(ring, 14.0, 0.7), 0.002, 0.8)
	var buf := s.layer(0.85, [[bonk, 0.0, 1.0], [ring, 0.02, 0.3]])
	return s.reverb(buf, 0.5, 0.4, 0.2, 0.4)


## A wet splash and drips.
func _bleed(s: Synth, _variant: int) -> PackedFloat32Array:
	var splash := s.perc(s.lowpass(s.noise(0.3), [[0.0, 2500.0], [0.3, 500.0]]), 0.002, 0.25)
	var buf := s.add(s.silence(0.45), splash, 0.0, 0.8)
	for at: float in [0.05, 0.17]:
		s.add(buf, s.perc(s.tone(0.08, [[0.0, 1400.0], [0.05, 500.0]]), 0.001, 0.07), at, 0.4)
	return buf


## Bubbles and a hiss.
func _blight(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(0.65)
	for i in 6:
		var pitch := s.rng.randf_range(300.0, 700.0)
		var bubble := s.perc(s.tone(0.06, [[0.0, pitch], [0.05, pitch * 1.6]]), 0.002, 0.05)
		s.add(buf, bubble, s.rng.randf_range(0.0, 0.5), s.rng.randf_range(0.3, 0.6))
	var hiss := s.shape(s.highpass(s.noise(0.6), 3000.0), [[0.0, 0.0], [0.2, 1.0], [0.6, 0.0]])
	s.add(buf, hiss, 0.0, 0.12)
	var gurgle := s.tremolo(s.lowpass(s.brown(0.6), 300.0), 12.0, 0.8)
	return s.add(buf, s.fade(gurgle, 0.05, 0.3), 0.0, 0.5)


## A rush of flame and crackles.
func _burn(s: Synth, _variant: int) -> PackedFloat32Array:
	var flame := s.lowpass(s.noise(0.6), [[0.0, 500.0], [0.15, 2500.0], [0.6, 900.0]])
	s.shape(flame, [[0.0, 0.0], [0.12, 1.0], [0.6, 0.0]])
	var buf := s.add(s.silence(0.65), flame, 0.0, 0.8)
	for i in 10:
		var crackle := s.perc(s.highpass(s.noise(0.006), 2000.0), 0.0002, 0.005)
		s.add(buf, crackle, s.rng.randf_range(0.02, 0.55), s.rng.randf_range(0.3, 0.8))
	return s.drive(buf, 1.5)


## Two soft steps and a rustle: shuffling places.
func _move(s: Synth, _variant: int) -> PackedFloat32Array:
	var rustle := s.shape(s.bandpass(s.noise(0.35), 1200.0, 0.7), [[0.0, 0.0], [0.15, 1.0], [0.35, 0.0]])
	return s.layer(0.4, [[_footfall(s, 0.7), 0.0, 0.8], [_footfall(s, 0.6), 0.16, 0.7], [rustle, 0.0, 0.25]])


## A heartbeat, twice, over a low swell.
func _deaths_door(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(1.5)
	for beat: Array in [[0.0, 1.0], [0.22, 0.7], [0.9, 0.7], [1.12, 0.5]]:
		s.add(buf, s.perc(s.tone(0.2, [[0.0, 70.0], [0.15, 45.0]]), 0.005, 0.15), beat[0], beat[1])
	var swell := s.lowpass(s.ensemble(s.hz(38), 1.4, 3, 12.0), 250.0)
	s.add(buf, s.shape(swell, [[0.0, 0.0], [0.05, 1.0], [1.4, 0.0]]), 0.0, 0.5)
	return s.reverb(s.drive(buf, 1.4), 0.7, 0.5, 0.25, 0.8)


## A great low bell and a boom: the blow that kills.
func _deathblow(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.add(s.silence(3.0), s.bell(s.hz(38), 3.0, 0.7), 0.0, 0.8)
	s.add(buf, s.drive(s.drum(1.0, 70.0, 35.0, 0.3, 300.0), 1.5), 0.0, 0.7)
	return s.reverb(buf, 0.85, 0.5, 0.35, 1.5)


## Something heavy collapsing, and rubble.
func _slain(s: Synth, variant: int) -> PackedFloat32Array:
	var thud := s.perc(s.tone(0.3, [[0.0, 120.0 - variant * 10.0], [0.2, 50.0]]), 0.002, 0.25)
	var body := s.perc(s.lowpass(s.noise(0.4), 600.0), 0.002, 0.35)
	var buf := s.layer(0.85, [[thud, 0.0, 1.0], [body, 0.0, 0.6]])
	for i in 5 + variant:
		var stone := s.perc(s.lowpass(s.noise(0.06), 1500.0), 0.001, 0.05)
		s.add(buf, stone, s.rng.randf_range(0.05, 0.5), s.rng.randf_range(0.3, 0.6))
	return s.drive(buf, 1.6)


## Low voices falling: a hero is gone.
func _fallen(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(2.6)
	for chord: Array in [[0.0, [50, 53, 57]], [1.1, [46, 49, 53]]]:
		for note: int in chord[1]:
			var voice := s.choir(s.hz(note), 1.5, &"u")
			s.add(buf, s.adsr(voice, 0.3, 0.0, 1.0, 0.6), chord[0], 0.25)
	return s.reverb(buf, 0.85, 0.5, 0.4, 1.5)


## Grinding saws and a rising roar: a mind breaks.
func _meltdown(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(1.8)
	for note: int in [50, 51, 56]:
		var voice := s.tremolo(s.ensemble(s.hz(note), 1.6, 3, 20.0), 7.0, 0.5)
		s.lowpass(voice, [[0.0, 300.0], [0.6, 2500.0], [1.6, 800.0]], 1.2)
		s.add(buf, s.shape(voice, [[0.0, 0.0], [0.5, 1.0], [1.6, 0.0]]), 0.0, 0.3)
	var roar := s.shape(s.highpass(s.noise(1.6), 1000.0), [[0.0, 0.0], [0.6, 1.0], [1.6, 0.0]])
	s.add(buf, roar, 0.0, 0.15)
	return s.reverb(s.drive(buf, 3.0), 0.6, 0.5, 0.25, 0.8)


## Voices on a bright major chord, and a bell: courage found.
func _resolute(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.silence(1.8)
	for note: int in [62, 66, 69]:
		var voice := s.choir(s.hz(note), 1.6, &"a")
		s.add(buf, s.shape(voice, [[0.0, 0.0], [0.25, 1.0], [1.6, 0.0]]), 0.0, 0.25)
	var low := s.lowpass(s.ensemble(s.hz(50), 1.6, 3, 9.0), 900.0)
	s.add(buf, s.shape(low, [[0.0, 0.0], [0.25, 1.0], [1.6, 0.0]]), 0.0, 0.2)
	s.add(buf, s.bell(s.hz(86), 1.5, 0.5), 0.0, 0.3)
	return s.reverb(buf, 0.75, 0.4, 0.35, 1.0)


## A holy chime: ground made sacred.
func _chime(s: Synth, _variant: int) -> PackedFloat32Array:
	var buf := s.add(s.silence(1.6), s.bell(s.hz(86), 1.5, 0.5), 0.0, 1.0)
	s.add(buf, s.bell(s.hz(93), 1.2, 0.5), 0.05, 0.5)
	return s.reverb(buf, 0.7, 0.4, 0.3, 0.8)
