extends RefCounted
## .slau — SILLYSOFT audio. 16-bit PCM, mono/stereo, optional loop points.

const Core = preload("res://scripts/sillysoft/silly_core.gd")

const FLAG_LOOP := 1

static func pack(stream: AudioStreamWAV, name: String) -> PackedByteArray:
	var w := Core.Writer.new()
	Core.write_header(w, Core.MAGIC_AUDIO)
	w.u32(stream.mix_rate)
	var ch := 2 if stream.stereo else 1
	w.u8(ch)
	var flags := 0
	if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		flags |= FLAG_LOOP
	w.u8(flags)
	w.cstr(name)
	var frames := stream.data.size() / (2 * ch)
	w.u32(frames)
	w.raw(stream.data)
	if flags & FLAG_LOOP:
		w.u32(stream.loop_begin)
		w.u32(stream.loop_end)
	return Core.seal(w)

static func unpack(b: PackedByteArray) -> Dictionary:
	var r := Core.Reader.new(b)
	if not Core.read_header(r, Core.MAGIC_AUDIO):
		push_error("slau: bad header")
		return {}
	var rate: int = r.u32()
	var ch: int = r.u8()
	var flags: int = r.u8()
	var name: String = r.cstr()
	var frames: int = r.u32()
	var data: PackedByteArray = r.bytes(frames * 2 * ch)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = ch == 2
	s.data = data
	if flags & FLAG_LOOP:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = r.u32()
		s.loop_end = r.u32()
	var out := {"name": name, "stream": s, "rate": rate, "channels": ch, "frames": frames}
	if not Core.verify_crc(b):
		push_error("slau: crc mismatch")
		return {}
	return out

static func load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return unpack(Core.read_file(path))

static func save(path: String, stream: AudioStreamWAV, name: String) -> bool:
	return Core.write_file(path, pack(stream, name))
