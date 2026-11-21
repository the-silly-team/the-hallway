extends RefCounted
## .slcl — SILLYSOFT collision. A flat list of boxes (center + half extents + type).

const Core = preload("res://scripts/sillysoft/silly_core.gd")

static func pack(entries: Array, name: String) -> PackedByteArray:
	var w := Core.Writer.new()
	Core.write_header(w, Core.MAGIC_COLLISION)
	w.u16(entries.size())
	w.cstr(name)
	for e in entries:
		var c: Vector3 = e.get("center", Vector3.ZERO)
		var h: Vector3 = e.get("half", Vector3.ZERO)
		w.f32(c.x); w.f32(c.y); w.f32(c.z)
		w.f32(h.x); w.f32(h.y); w.f32(h.z)
		w.u8(int(e.get("type", 0)))
	return Core.seal(w)

static func unpack(b: PackedByteArray) -> Dictionary:
	var r := Core.Reader.new(b)
	if not Core.read_header(r, Core.MAGIC_COLLISION):
		push_error("slcl: bad header")
		return {}
	var count: int = r.u16()
	var name: String = r.cstr()
	var entries := []
	for i in count:
		var c := Vector3(r.f32(), r.f32(), r.f32())
		var h := Vector3(r.f32(), r.f32(), r.f32())
		entries.append({"center": c, "half": h, "type": r.u8()})
	var out := {"name": name, "entries": entries}
	if not Core.verify_crc(b):
		push_error("slcl: crc mismatch")
		return {}
	return out

## convenience: turn unpacked entries into Godot BoxShape3D nodes
static func to_shapes(entries: Array) -> Array:
	var shapes := []
	for e in entries:
		var bs := BoxShape3D.new()
		bs.size = (e["half"] as Vector3) * 2.0
		shapes.append(bs)
	return shapes

static func load(path: String) -> Dictionary:
	return unpack(Core.read_file(path))

static func save(path: String, entries: Array, name: String) -> bool:
	return Core.write_file(path, pack(entries, name))
