extends RefCounted
## .drsc — DOORSOFT compiled scene. Runtime instances with resource references.

const Core = preload("res://scripts/dr/dr_core.gd")
const Lvl = preload("res://scripts/dr/dr_level.gd")

static func pack(data: Dictionary) -> PackedByteArray:
	var w := Core.Writer.new()
	Core.write_header(w, Core.MAGIC_SCENE)
	w.cstr(String(data.get("name", "scene")))
	w.cstr(String(data.get("source", "")))
	var objects: Array = data.get("objects", [])
	w.u16(min(objects.size(), 65535))
	for item in objects:
		if not (item is Dictionary):
			continue
		var o: Dictionary = item
		w.u32(int(o.get("id", 0)) & 0xFFFFFFFF)
		w.cstr(String(o.get("template", "box")))
		w.vec3(Lvl.vec(o.get("position", Vector3.ZERO)))
		w.vec3(Lvl.vec(o.get("rotation", Vector3.ZERO)))
		w.vec3(Lvl.vec(o.get("scale", Vector3.ONE)))
		w.u16(int(o.get("flags", 0)) & 0xFFFF)
		var assets: Array = o.get("assets", [])
		w.u16(min(assets.size(), 65535))
		for asset in assets:
			w.cstr(String(asset))
	return Core.seal(w)

static func unpack(b: PackedByteArray) -> Dictionary:
	if not Core.verify_crc(b):
		push_error("drsc: crc mismatch")
		return {}
	var r := Core.Reader.new(b)
	if not Core.read_header(r, Core.MAGIC_SCENE):
		push_error("drsc: bad header")
		return {}
	var out := {"name": r.cstr(), "source": r.cstr()}
	var objects := []
	var n: int = r.u16()
	for _i in n:
		var o := {
			"id": r.u32(),
			"template": r.cstr(),
			"position": _arr(r.vec3()),
			"rotation": _arr(r.vec3()),
			"scale": _arr(r.vec3()),
			"flags": r.u16(),
		}
		var assets := []
		var an: int = r.u16()
		for _j in an:
			assets.append(r.cstr())
		o["assets"] = assets
		objects.append(o)
	out["objects"] = objects
	return out

static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func load(path: String) -> Dictionary:
	return unpack(Core.read_file(path))

static func save(path: String, data: Dictionary) -> bool:
	return Core.write_file(path, pack(data))
