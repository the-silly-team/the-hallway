extends RefCounted
## .drtx — DOORSOFT texture. RGBA8 pixels, optional RGBA8 tangent-space normal map.

const Core = preload("res://scripts/dr/dr_core.gd")

const FLAG_NORMAL := 1

static func pack(img: Image, name: String, normal: Image = null) -> PackedByteArray:
	var im := img.duplicate()
	im.convert(Image.FORMAT_RGBA8)
	var w := Core.Writer.new()
	Core.write_header(w, Core.MAGIC_TEXTURE)
	w.u16(im.get_width())
	w.u16(im.get_height())
	var flags := 0
	if normal != null:
		flags |= FLAG_NORMAL
	w.u8(flags)
	w.u8(4) # channels
	w.cstr(name)
	w.raw(im.get_data())
	if normal != null:
		var nm := normal.duplicate()
		nm.convert(Image.FORMAT_RGBA8)
		w.raw(nm.get_data())
	return Core.seal(w)

static func unpack(b: PackedByteArray) -> Dictionary:
	var r := Core.Reader.new(b)
	if not Core.read_header(r, Core.MAGIC_TEXTURE):
		push_error("drtx: bad header")
		return {}
	var wdt: int = r.u16()
	var hgt: int = r.u16()
	var flags: int = r.u8()
	var ch: int = r.u8()
	var name: String = r.cstr()
	var n := wdt * hgt * ch
	var img := Image.create_from_data(wdt, hgt, false, Image.FORMAT_RGBA8, r.bytes(n))
	var out := {"name": name, "image": img, "width": wdt, "height": hgt}
	if flags & FLAG_NORMAL:
		out["normal"] = Image.create_from_data(wdt, hgt, false, Image.FORMAT_RGBA8, r.bytes(n))
	if not Core.verify_crc(b):
		push_error("drtx: crc mismatch")
		return {}
	return out

static func load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return unpack(Core.read_file(path))

static func save(path: String, img: Image, name: String, normal: Image = null) -> bool:
	return Core.write_file(path, pack(img, name, normal))
