extends RefCounted
## DOORSOFT resource format core: magics, versioning, CRC32, byte reader/writer.
## Every .dr* file is: magic(4) + vendor(6) + version(u16) + payload + crc32(u32).

const VENDOR := "DRSOFT"
const VERSION := 1

const MAGIC_TEXTURE := "DRTX"
const MAGIC_AUDIO := "DRAU"
const MAGIC_COLLISION := "DRCL"
const MAGIC_LEVEL := "DRLV"      # reserved for the level editor
const MAGIC_SCENE := "DRSC"      # reserved: compiled level
const MAGIC_MANIFEST := "DRMF"   # reserved: package manifest

static var _table: PackedInt32Array = PackedInt32Array()

static func _init_table() -> void:
	if not _table.is_empty():
		return
	_table.resize(256)
	for i in 256:
		var c := i
		for k in 8:
			c = (0xEDB88320 ^ (c >> 1)) if (c & 1) else (c >> 1)
		_table[i] = c

static func crc32(data: PackedByteArray) -> int:
	_init_table()
	var c := 0xFFFFFFFF
	for i in data.size():
		var t: int = _table[(c ^ data[i]) & 0xFF] & 0xFFFFFFFF
		c = (t ^ (c >> 8)) & 0xFFFFFFFF
	return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF

static func write_header(w: Object, magic: String) -> void:
	w.magic(magic)
	w.raw(VENDOR.to_utf8_buffer())
	w.u16(VERSION)

## returns false (and consumes the header) if magic/vendor/version mismatch
static func read_header(r: Object, magic: String) -> bool:
	if r.magic() != magic:
		return false
	if r.raw_str(6) != VENDOR:
		return false
	return r.u16() == VERSION

static func seal(w: Object) -> PackedByteArray:
	w.u32(crc32(w.buf))
	return w.buf

static func verify_crc(b: PackedByteArray) -> bool:
	if b.size() < 4:
		return false
	var body := b.slice(0, b.size() - 4)
	var got := b.decode_u32(b.size() - 4)
	return crc32(body) == got

static func read_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b := f.get_buffer(f.get_length())
	f.close()
	return b

static func write_file(path: String, b: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(b)
	f.close()
	return true

class Writer:
	var buf := PackedByteArray()

	func magic(m: String) -> void:
		buf.append_array(m.to_utf8_buffer())

	func u8(v: int) -> void:
		buf.append(v & 0xFF)

	func u16(v: int) -> void:
		buf.append(v & 0xFF)
		buf.append((v >> 8) & 0xFF)

	func u32(v: int) -> void:
		for i in 4:
			buf.append((v >> (i * 8)) & 0xFF)

	func f32(v: float) -> void:
		var b := PackedByteArray()
		b.resize(4)
		b.encode_float(0, v)
		buf.append_array(b)

	func vec3(v: Vector3) -> void:
		f32(v.x)
		f32(v.y)
		f32(v.z)

	func raw(b: PackedByteArray) -> void:
		buf.append_array(b)

	func cstr(s: String) -> void:
		var b := s.to_utf8_buffer()
		u8(b.size())
		buf.append_array(b)

class Reader:
	var buf := PackedByteArray()
	var pos := 0

	func _init(b: PackedByteArray = PackedByteArray()) -> void:
		buf = b

	func magic() -> String:
		return str_at(4)

	func raw_str(n: int) -> String:
		return str_at(n)

	func cstr() -> String:
		var n: int = u8()
		return str_at(n)

	func str_at(n: int) -> String:
		var s := buf.slice(pos, pos + n).get_string_from_utf8()
		pos += n
		return s

	func u8() -> int:
		var v := buf[pos]
		pos += 1
		return v

	func u16() -> int:
		var v := int(buf[pos]) | (int(buf[pos + 1]) << 8)
		pos += 2
		return v

	func u32() -> int:
		var v := 0
		for i in 4:
			v |= int(buf[pos + i]) << (i * 8)
		pos += 4
		return v

	func f32() -> float:
		var v := buf.decode_float(pos)
		pos += 4
		return v

	func vec3() -> Vector3:
		return Vector3(f32(), f32(), f32())

	func bytes(n: int) -> PackedByteArray:
		var v := buf.slice(pos, pos + n)
		pos += n
		return v

	func eof() -> bool:
		return pos >= buf.size()
