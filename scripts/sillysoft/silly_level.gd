extends RefCounted
## .sllv — SILLYSOFT level source. Editable object list, JSON-friendly dictionaries.

const Core = preload("res://scripts/sillysoft/silly_core.gd")

static func vec(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(
			float((value as Dictionary).get("x", 0.0)),
			float((value as Dictionary).get("y", 0.0)),
			float((value as Dictionary).get("z", 0.0))
		)
	if value is Array and (value as Array).size() >= 3:
		var a: Array = value
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO

static func rgb(value: Variant) -> Color:
	if value is Color:
		return value
	if value is Dictionary:
		var d: Dictionary = value
		return Color(
			float(d.get("r", 0.0)), float(d.get("g", 0.0)), float(d.get("b", 0.0)), 1.0
		)
	if value is Array and (value as Array).size() >= 3:
		var a: Array = value
		return Color(float(a[0]), float(a[1]), float(a[2]), 1.0)
	return Color(0.05, 0.05, 0.07, 1.0)

static func pack(data: Dictionary) -> PackedByteArray:
	var w := Core.Writer.new()
	Core.write_header(w, Core.MAGIC_LEVEL)
	w.cstr(String(data.get("name", "untitled")))
	w.vec3(vec(data.get("spawn", Vector3.ZERO)))
	var amb := rgb(data.get("ambient", Color(0.05, 0.05, 0.07)))
	w.f32(amb.r)
	w.f32(amb.g)
	w.f32(amb.b)
	var objects: Array = data.get("objects", [])
	w.u16(min(objects.size(), 65535))
	for item in objects:
		if not (item is Dictionary):
			continue
		var o: Dictionary = item
		w.cstr(String(o.get("type", "box")))
		w.cstr(String(o.get("name", "object")))
		w.vec3(vec(o.get("position", Vector3.ZERO)))
		w.vec3(vec(o.get("rotation", Vector3.ZERO)))
		w.vec3(vec(o.get("scale", Vector3.ONE)))
		var props: Dictionary = o.get("props", {})
		w.u16(min(props.size(), 65535))
		for key in props.keys():
			w.cstr(String(key))
			w.cstr(String(props[key]))
	return Core.seal(w)

static func unpack(b: PackedByteArray) -> Dictionary:
	if not Core.verify_crc(b):
		push_error("sllv: crc mismatch")
		return {}
	var r := Core.Reader.new(b)
	if not Core.read_header(r, Core.MAGIC_LEVEL):
		push_error("sllv: bad header")
		return {}
	var out := {
		"name": r.cstr(),
		"spawn": _arr(r.vec3()),
	}
	var amb := [r.f32(), r.f32(), r.f32()]
	out["ambient"] = amb
	var objects := []
	var n: int = r.u16()
	for _i in n:
		var o := {
			"type": r.cstr(),
			"name": r.cstr(),
			"position": _arr(r.vec3()),
			"rotation": _arr(r.vec3()),
			"scale": _arr(r.vec3()),
		}
		var props := {}
		var pn: int = r.u16()
		for _j in pn:
			var key: String = r.cstr()
			var value: String = r.cstr()
			props[key] = value
		o["props"] = props
		objects.append(o)
	out["objects"] = objects
	return out

static func _arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func load(path: String) -> Dictionary:
	return unpack(Core.read_file(path))

static func save(path: String, data: Dictionary) -> bool:
	return Core.write_file(path, pack(data))
