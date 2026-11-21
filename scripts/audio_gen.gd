extends RefCounted
## Procedural audio generators, shared by the runtime autoload and the CLI.
## Kept free of autoload dependencies so headless tools can preload it.

const RATE := 22050
const RATE_M := 16000
const T_M := 10.0

static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
    var w := AudioStreamWAV.new()
    w.format = AudioStreamWAV.FORMAT_16_BITS
    w.mix_rate = RATE
    w.stereo = false
    var data := PackedByteArray()
    data.resize(samples.size() * 2)
    for i in samples.size():
        data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
    w.data = data
    if loop:
        w.loop_mode = AudioStreamWAV.LOOP_FORWARD
        w.loop_begin = 0
        w.loop_end = samples.size()
    return w

static func _mk_blip(f0: float, f1: float, dur: float, amp: float) -> AudioStreamWAV:
    var n := int(dur * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    for i in n:
        var t := float(i) / RATE
        var f := lerpf(f0, f1, t / dur)
        ph += TAU * f / RATE
        out[i] = (sin(ph) * 0.7 + (randf() * 2.0 - 1.0) * 0.3) * exp(-t * 42.0) * amp
    return _wav(out)

static func _mk_confirm() -> AudioStreamWAV:
    var n := int(0.18 * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    for i in n:
        var t := float(i) / RATE
        var f := 620.0 if t < 0.08 else 880.0
        ph += TAU * f / RATE
        var env := 1.0 if t < 0.08 else exp(-(t - 0.08) * 16.0)
        out[i] = sin(ph) * env * 0.6
    return _wav(out)

static func _mk_door_open() -> AudioStreamWAV:
    var n := int(0.65 * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    var lp := 0.0
    var nl := 0.0
    for i in n:
        var t := float(i) / RATE
        # smooth descending frequency, no sinusoidal wobble
        var f := 200.0 - t * 150.0
        if f < 55.0:
            f = 55.0
        ph += TAU * f / RATE
        # triangle wave
        var tri := 2.0 * absf(2.0 * (ph / TAU - floorf(ph / TAU + 0.5))) - 1.0
        lp += 0.07 * (tri - lp)
        var nz := randf() * 2.0 - 1.0
        nl += 0.18 * (nz - nl)
        var env := smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.4, 0.65, t))
        out[i] = (lp * 0.65 + nl * 0.45) * env * 0.7
    return _wav(out)

static func _mk_door_close() -> AudioStreamWAV:
    var n := int(0.45 * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    var nl := 0.0
    for i in n:
        var t := float(i) / RATE
        var f := 45.0 + 110.0 * exp(-t * 16.0)
        ph += TAU * f / RATE
        var thud := sin(ph) * exp(-t * 8.0)
        var nz := randf() * 2.0 - 1.0
        nl += 0.3 * (nz - nl)
        var latch := 0.0
        if t > 0.1 and t < 0.16:
            latch = nl * exp(-(t - 0.1) * 60.0) * 1.6
        out[i] = clampf(thud * 0.9 + nl * exp(-t * 22.0) * 0.5 + latch, -1.0, 1.0) * 0.85
    return _wav(out)

static func _mk_step() -> AudioStreamWAV:
    var n := int(0.11 * RATE)
    var out := PackedFloat32Array()
    out.resize(n)
    var ph := 0.0
    var lp := 0.0
    for i in n:
        var t := float(i) / RATE
        var nz := randf() * 2.0 - 1.0
        lp += 0.09 * (nz - lp)
        var f := 68.0 - t * 90.0
        if f < 20.0:
            f = 20.0
        ph += TAU * f / RATE
        var thump := sin(ph) * exp(-t * 34.0)
        var env := exp(-t * 26.0)
        out[i] = (lp * env * 2.2 + thump * 0.45) * 0.7
    return _wav(out)

static func _mk_music(kind: String) -> AudioStreamWAV:
    var n := int(T_M * RATE_M)
    var out := PackedFloat32Array()
    out.resize(n)
    var freqs: Array = []
    var amps: Array = []
    if kind == "menu":
        freqs = [55.0, 110.0, 130.81, 164.81, 220.0, 261.63]
        amps = [0.5, 0.4, 0.22, 0.26, 0.16, 0.12]
    else:
        freqs = [36.71, 73.42, 110.0, 146.83, 220.0]
        amps = [0.55, 0.4, 0.26, 0.16, 0.1]
    for pi in freqs.size():
        var f: float = freqs[pi]
        var k := maxi(1, int(round(f * T_M)))
        var inc1 := TAU * (float(k) / T_M) / RATE_M
        var inc2 := TAU * (float(k + 1) / T_M) / RATE_M
        var a: float = amps[pi]
        var p1 := 0.0
        var p2 := randf() * TAU
        for i in n:
            p1 += inc1
            p2 += inc2
            out[i] += (sin(p1) + sin(p2) * 0.85) * a * 0.5
    if kind == "game":
        var pk := maxi(1, int(round(55.0 * T_M)))
        var inc := TAU * (float(pk) / T_M) / RATE_M
        var p3 := 0.0
        for i in n:
            p3 += inc
            var pulse := pow(0.5 + 0.5 * sin(TAU * 3.0 * float(i) / n), 3.0)
            out[i] += sin(p3) * pulse * 0.22
    else:
        for note in [[1.5, 659.25], [4.0, 523.25], [6.5, 783.99], [8.5, 587.33]]:
            var t0: float = note[0]
            var f: float = note[1]
            var k := maxi(1, int(round(f * T_M)))
            var inc := TAU * (float(k) / T_M) / RATE_M
            var p := 0.0
            var start := int(t0 * RATE_M)
            for i in range(start, n):
                p += inc
                var t := float(i) / RATE_M
                out[i] += sin(p) * exp(-(t - t0) * 3.0) * 0.15
    var peak := 0.0001
    for i in n:
        peak = maxf(peak, absf(out[i]))
    var g := 0.34 / peak
    for i in n:
        out[i] *= g
    var w := _wav(out, true)
    w.mix_rate = RATE_M
    return w
