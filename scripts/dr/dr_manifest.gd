extends RefCounted
## .drmf — DOORSOFT package manifest. Indexes asset files and dependencies.

const Core = preload("res://scripts/dr/dr_core.gd")

static func pack(data: Dictionary) -> PackedByteArray:
	var w := Core.Writer.new()
	Core.write_header(w, Core.MAGIC_MANIFEST)
	w.cstr(String(data.get("title", "package")))
	w.cstr(String(data.get("author", "unknown")))
	var entries: Array = data.get("entries", [])
	w.u16(min(entries.size(), 65535))
	for item in entries:
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		w.cstr(String(e.get("path", "")))
		w.cstr(String(e.get("magic", "")))
		w.u32(int(e.get("size", 0)) & 0xFFFFFFFF)
		w.u32(int(e.get("crc", 0)) & 0xFFFFFFFF)
		var deps: Array = e.get("deps", [])
		w.u16(min(deps.size(), 65535))
		for dep in deps:
			w.cstr(String(dep))
	return Core.seal(w)

static func unpack(b: PackedByteArray) -> Dictionary:
	if not Core.verify_crc(b):
		push_error("drmf: crc mismatch")
		return {}
	var r := Core.Reader.new(b)
	if not Core.read_header(r, Core.MAGIC_MANIFEST):
		push_error("drmf: bad header")
		return {}
	var out := {"title": r.cstr(), "author": r.cstr()}
	var entries := []
	var n: int = r.u16()
	for _i in n:
		var e := {
			"path": r.cstr(),
			"magic": r.cstr(),
			"size": r.u32(),
			"crc": r.u32(),
		}
		var deps := []
		var dn: int = r.u16()
		for _j in dn:
			deps.append(r.cstr())
		e["deps"] = deps
		entries.append(e)
	out["entries"] = entries
	return out

static func load(path: String) -> Dictionary:
	return unpack(Core.read_file(path))

static func save(path: String, data: Dictionary) -> bool:
	return Core.write_file(path, pack(data))
