## The building blocks of the game's synthesized sounds and music, for
## tools/make_audio.gd: oscillators, noise, envelopes, filters, a reverb, a few
## instruments and a WAV writer. A buffer is a mono PackedFloat32Array at
## `rate` samples a second. Functions that take a buffer change it in place and
## return it; the others make a new one. Times are in seconds.
##
## Envelope and filter paths are either one number or a list of [time, value]
## points, joined by straight lines (levels) or by even steps in pitch (Hz).
extends RefCounted

enum Wave { SINE, TRIANGLE, SAW, SQUARE }
enum Filter { LOW, HIGH, BAND }

## A bell's partials: [ratio to the strike note, level, share of the ring time].
const BELL_PARTIALS := [
	[0.5, 0.9, 1.0], [1.0, 0.8, 0.8], [1.19, 0.55, 0.6], [1.5, 0.4, 0.5], [2.0, 0.5, 0.4],
	[2.51, 0.28, 0.3], [2.66, 0.22, 0.28], [3.01, 0.2, 0.22], [4.17, 0.14, 0.16], [5.43, 0.08, 0.12],
]
## Formant centres and levels of sung vowels, for `choir`.
const VOWELS := {
	&"a": [[800.0, 1.0], [1150.0, 0.5], [2900.0, 0.2]],
	&"o": [[450.0, 1.0], [800.0, 0.45], [2830.0, 0.12]],
	&"u": [[325.0, 1.0], [700.0, 0.3], [2530.0, 0.08]],
}
## Freeverb's delay lengths at 44.1 kHz.
const COMBS := [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
const ALLPASSES := [556, 441, 341, 225]

var rate: int
var rng := RandomNumberGenerator.new()


func _init(sample_rate: int) -> void:
	rate = sample_rate


func frames(seconds: float) -> int:
	return maxi(1, roundi(seconds * rate))


## The frequency of MIDI note `note` (69 is A4, 440 Hz).
func hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


# --- Sources ---

func silence(seconds: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(frames(seconds))
	buf.fill(0.0)
	return buf


## A tone along a pitch path (Hz), at full level.
func tone(seconds: float, pitch: Variant, wave := Wave.SINE) -> PackedFloat32Array:
	var buf := silence(seconds)
	var phase := rng.randf() if wave != Wave.SINE else 0.0
	for i in buf.size():
		var step := _at(pitch, float(i) / rate, true) / rate
		phase += step
		phase -= floorf(phase)
		buf[i] = _wave(wave, phase, step)
	return buf


## Several detuned copies of a tone, spread over `cents`, with a vibrato of
## `vibrato` (a share of the pitch) that fades in over the first second.
func ensemble(pitch: float, seconds: float, voices := 3, cents := 10.0, wave := Wave.SAW,
		vibrato := 0.0) -> PackedFloat32Array:
	var buf := silence(seconds)
	for v in voices:
		var spread := 0.0 if voices == 1 else (float(v) / (voices - 1) - 0.5) * cents
		var step := pitch * pow(2.0, spread / 1200.0) / rate
		var phase := rng.randf()
		var wobble := rng.randf() * TAU
		var wobble_step := TAU * rng.randf_range(4.6, 5.6) / rate
		for i in buf.size():
			var depth := vibrato * minf(1.0, float(i) / rate)
			var now := step * (1.0 + depth * sin(wobble))
			wobble += wobble_step
			phase += now
			phase -= floorf(phase)
			buf[i] += _wave(wave, phase, now) / voices
	return buf


## White noise at full level.
func noise(seconds: float) -> PackedFloat32Array:
	var buf := silence(seconds)
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0)
	return buf


## Brown noise: a slow, rumbling random walk.
func brown(seconds: float) -> PackedFloat32Array:
	var buf := silence(seconds)
	var level := 0.0
	for i in buf.size():
		level = clampf(level * 0.998 + rng.randf_range(-0.04, 0.04), -1.0, 1.0)
		buf[i] = level
	return normalize(buf, 1.0)


func _wave(wave: Wave, phase: float, step: float) -> float:
	match wave:
		Wave.TRIANGLE:
			return 4.0 * absf(phase - 0.5) - 1.0
		Wave.SAW:
			return 2.0 * phase - 1.0 - _blep(phase, step)
		Wave.SQUARE:
			var half := phase + 0.5
			return (1.0 if phase < 0.5 else -1.0) + _blep(phase, step) - _blep(half - floorf(half), step)
	return sin(TAU * phase)


## Smooths a saw or square's jumps, so high notes don't alias.
func _blep(t: float, step: float) -> float:
	if t < step:
		t /= step
		return t + t - t * t - 1.0
	if t > 1.0 - step:
		t = (t - 1.0) / step
		return t * t + t + t + 1.0
	return 0.0


# --- Envelopes ---

## A straight rise over `attack`, then a fall that is 60 dB down `decay` later.
func perc(buf: PackedFloat32Array, attack: float, decay: float) -> PackedFloat32Array:
	var rise := frames(attack)
	var fall := exp(-6.9078 / maxf(decay * rate, 1.0))
	var level := 1.0
	for i in buf.size():
		if i < rise:
			buf[i] *= float(i) / rise
		else:
			buf[i] *= level
			level *= fall
	return buf


## A note's envelope: a smooth rise, a fall to `sustain`, and a release over the last `release` seconds.
func adsr(buf: PackedFloat32Array, attack: float, decay: float, sustain: float, release: float) -> PackedFloat32Array:
	var rise := frames(attack)
	var fall := frames(decay)
	var end := frames(release)
	var n := buf.size()
	for i in n:
		var level := sustain
		if i < rise:
			level = sin(PI * 0.5 * float(i) / rise)
		elif i < rise + fall:
			level = lerpf(1.0, sustain, float(i - rise) / fall)
		if i > n - end:
			var left := float(n - i) / end
			level *= left * left
		buf[i] *= level
	return buf


## Multiplies by a level path.
func shape(buf: PackedFloat32Array, levels: Variant) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] *= _at(levels, float(i) / rate, false)
	return buf


func fade(buf: PackedFloat32Array, fade_in: float, fade_out: float) -> PackedFloat32Array:
	var rise := frames(fade_in)
	var fall := frames(fade_out)
	var n := buf.size()
	for i in mini(rise, n):
		buf[i] *= float(i) / rise
	for i in mini(fall, n):
		buf[n - 1 - i] *= float(i) / fall
	return buf


## A wobble in level, `depth` deep, `speed` times a second.
func tremolo(buf: PackedFloat32Array, speed: float, depth: float) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] *= 1.0 - depth * 0.5 * (1.0 + sin(TAU * speed * i / rate))
	return buf


# --- Filters ---

## A resonant low-pass along a cutoff path (Hz).
func lowpass(buf: PackedFloat32Array, cutoff: Variant, q := 0.707) -> PackedFloat32Array:
	return _biquad(buf, Filter.LOW, cutoff, q)


func highpass(buf: PackedFloat32Array, cutoff: Variant, q := 0.707) -> PackedFloat32Array:
	return _biquad(buf, Filter.HIGH, cutoff, q)


## A band-pass with its peak at full level, along a centre path (Hz).
func bandpass(buf: PackedFloat32Array, center: Variant, q := 1.0) -> PackedFloat32Array:
	return _biquad(buf, Filter.BAND, center, q)


func _biquad(buf: PackedFloat32Array, kind: Filter, path: Variant, q: float) -> PackedFloat32Array:
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var fixed := not path is Array
	for i in buf.size():
		if i == 0 or (not fixed and i % 16 == 0):
			var f := clampf(_at(path, float(i) / rate, true), 10.0, rate * 0.45)
			var w := TAU * f / rate
			var cos_w := cos(w)
			var alpha := sin(w) / (2.0 * q)
			var a0 := 1.0 + alpha
			match kind:
				Filter.LOW:
					b0 = (1.0 - cos_w) * 0.5
					b1 = 1.0 - cos_w
					b2 = b0
				Filter.HIGH:
					b0 = (1.0 + cos_w) * 0.5
					b1 = -(1.0 + cos_w)
					b2 = b0
				Filter.BAND:
					b0 = alpha
					b1 = 0.0
					b2 = -alpha
			b0 /= a0
			b1 /= a0
			b2 /= a0
			a1 = -2.0 * cos_w / a0
			a2 = (1.0 - alpha) / a0
		var x := buf[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[i] = y
	return buf


## A value of a path at `time`: pitches step evenly in octaves, levels in straight lines.
func _at(path: Variant, time: float, pitch: bool) -> float:
	if not path is Array:
		return float(path)
	var points: Array = path
	if time <= points[0][0]:
		return points[0][1]
	for k in range(1, points.size()):
		if time <= points[k][0]:
			var from: Array = points[k - 1]
			var to: Array = points[k]
			var t: float = (time - from[0]) / maxf(to[0] - from[0], 0.000001)
			if pitch:
				return from[1] * pow(to[1] / from[1], t)
			return lerpf(from[1], to[1], t)
	return points[-1][1]


# --- Mixing ---

func scale(buf: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	for i in buf.size():
		buf[i] *= gain
	return buf


## Adds `source` into `buf` from `at` on, as far as `buf` reaches.
func add(buf: PackedFloat32Array, source: PackedFloat32Array, at := 0.0, gain := 1.0) -> PackedFloat32Array:
	var start := roundi(at * rate)
	for i in mini(source.size(), buf.size() - start):
		if start + i >= 0:
			buf[start + i] += source[i] * gain
	return buf


## A new buffer of `parts` mixed together, each [buffer, start, gain].
func layer(seconds: float, parts: Array) -> PackedFloat32Array:
	var buf := silence(seconds)
	for part: Array in parts:
		add(buf, part[0], part[1], part[2])
	return buf


## Soft clipping: louder and rounder as `amount` grows, peaks kept below 1.
func drive(buf: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var top := tanh(amount)
	for i in buf.size():
		buf[i] = tanh(buf[i] * amount) / top
	return buf


func peak(buf: PackedFloat32Array) -> float:
	var top := 0.0
	for value in buf:
		top = maxf(top, absf(value))
	return top


func rms(buf: PackedFloat32Array) -> float:
	var sum := 0.0
	for value in buf:
		sum += value * value
	return sqrt(sum / maxi(buf.size(), 1))


func normalize(buf: PackedFloat32Array, top: float) -> PackedFloat32Array:
	var now := peak(buf)
	return scale(buf, top / now) if now > 0.0 else buf


## A hall reverb after Freeverb: `room` (0-1) sets how long it rings, `damp`
## (0-1) how dark, `wet` how much is mixed in. Returns a new buffer, `tail` longer.
func reverb(buf: PackedFloat32Array, room: float, damp: float, wet: float, tail: float) -> PackedFloat32Array:
	var n := buf.size() + frames(tail)
	var dry := buf.duplicate()
	dry.resize(n)
	for i in range(buf.size(), n):
		dry[i] = 0.0
	var echoes := PackedFloat32Array()
	echoes.resize(n)
	echoes.fill(0.0)
	var stretch := rate / 44100.0
	var feedback := room * 0.28 + 0.7
	var darkness := damp * 0.4
	for length: int in COMBS:
		var size := maxi(1, roundi(length * stretch))
		var line := PackedFloat32Array()
		line.resize(size)
		line.fill(0.0)
		var index := 0
		var store := 0.0
		for i in n:
			var out := line[index]
			store = out * (1.0 - darkness) + store * darkness
			line[index] = dry[i] * 0.015 + store * feedback
			index += 1
			if index == size:
				index = 0
			echoes[i] += out
	for length: int in ALLPASSES:
		var size := maxi(1, roundi(length * stretch))
		var line := PackedFloat32Array()
		line.resize(size)
		line.fill(0.0)
		var index := 0
		for i in n:
			var held := line[index]
			var x := echoes[i]
			echoes[i] = held - x
			line[index] = x + held * 0.5
			index += 1
			if index == size:
				index = 0
	for i in n:
		dry[i] += echoes[i] * wet * 3.0
	return dry


## Folds everything past `length` seconds back onto the start, so a loop's
## tails ring on into its beginning. Returns the buffer cut to `length`.
func fold(buf: PackedFloat32Array, length: float) -> PackedFloat32Array:
	var n := frames(length)
	for i in range(n, buf.size()):
		buf[i % n] += buf[i]
	buf.resize(n)
	return buf


## Takes out any DC offset and rumble below 25 Hz.
func clean(buf: PackedFloat32Array) -> PackedFloat32Array:
	return highpass(buf, 25.0)


# --- Instruments ---

## A struck bell: inharmonic partials, the higher ones dying sooner, each a
## pair slightly apart so it shimmers. `brightness` (0-1) keeps the high ones.
func bell(pitch: float, seconds: float, brightness := 0.6) -> PackedFloat32Array:
	var buf := silence(seconds)
	for partial: Array in BELL_PARTIALS:
		var f: float = pitch * partial[0]
		if f > rate * 0.42:
			continue
		var level: float = partial[1] * lerpf(1.0, brightness, clampf((partial[0] - 1.0) / 4.0, 0.0, 1.0))
		for twin: float in [0.999, 1.0013]:
			add(buf, perc(tone(seconds, f * twin), 0.002, seconds * partial[2]), 0.0, level * 0.5)
	var strike := bandpass(noise(0.03), minf(pitch * 3.0, rate * 0.4), 1.5)
	add(buf, perc(strike, 0.0005, 0.03), 0.0, 0.3 * brightness)
	return buf


## A plucked string (Karplus-Strong). `brightness` (0-1) colours the pluck.
func pluck(pitch: float, seconds: float, brightness := 0.5) -> PackedFloat32Array:
	var buf := silence(seconds)
	var size := maxi(2, roundi(rate / pitch))
	var line := lowpass(noise(float(size) / rate), lerpf(800.0, 9000.0, brightness))
	normalize(line, 1.0)
	var keep := exp(-6.9078 / (seconds * pitch))
	var index := 0
	for i in buf.size():
		var a := line[index]
		var b := line[(index + 1) % size]
		buf[i] = a
		line[index] = (a + b) * 0.5 * keep
		index = (index + 1) % size
	return fade(buf, 0.0, 0.05)


## A sung note: saws through the formants of `vowel`.
func choir(pitch: float, seconds: float, vowel: StringName) -> PackedFloat32Array:
	var source := ensemble(pitch, seconds, 4, 14.0, Wave.SAW, 0.006)
	var buf := silence(seconds)
	for formant: Array in VOWELS[vowel]:
		add(buf, bandpass(source.duplicate(), formant[0], 6.0), 0.0, formant[1] * 2.5)
	return buf


## A drum: a body falling from `from_hz` to `to_hz`, and a slap of noise low-passed at `noise_hz`.
func drum(seconds: float, from_hz: float, to_hz: float, slap: float, noise_hz: float) -> PackedFloat32Array:
	var body := perc(tone(seconds, [[0.0, from_hz], [0.12, to_hz]]), 0.001, seconds)
	var hit := perc(lowpass(noise(0.12), noise_hz), 0.0005, 0.1)
	return add(body, hit, 0.0, slap)


# --- Files ---

## Writes `buf` as a 16-bit mono WAV. A loop gets a sampler chunk marking the
## whole file, which Godot's importer reads as a forward loop.
func write_wav(path: String, buf: PackedFloat32Array, loop := false) -> Error:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var dither := (rng.randf() - rng.randf()) / 32768.0
		data.encode_s16(i * 2, clampi(roundi((buf[i] + dither) * 32767.0), -32768, 32767))
	var chunks := PackedByteArray()
	chunks.append_array(_chunk("fmt ", _fmt()))
	chunks.append_array(_chunk("data", data))
	if loop:
		chunks.append_array(_chunk("smpl", _sampler(n)))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(4 + chunks.size())
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer(chunks)
	return OK


func _chunk(id: String, body: PackedByteArray) -> PackedByteArray:
	var out := id.to_ascii_buffer()
	var size := PackedByteArray()
	size.resize(4)
	size.encode_u32(0, body.size())
	out.append_array(size)
	out.append_array(body)
	return out


func _fmt() -> PackedByteArray:
	var body := PackedByteArray()
	body.resize(16)
	body.encode_u16(0, 1)
	body.encode_u16(2, 1)
	body.encode_u32(4, rate)
	body.encode_u32(8, rate * 2)
	body.encode_u16(12, 2)
	body.encode_u16(14, 16)
	return body


## A sampler chunk with one forward loop over every frame.
func _sampler(n: int) -> PackedByteArray:
	var body := PackedByteArray()
	body.resize(60)
	body.fill(0)
	body.encode_u32(8, int(1e9 / rate))
	body.encode_u32(12, 60)
	body.encode_u32(28, 1)
	body.encode_u32(44, 0)
	body.encode_u32(48, n)
	return body
