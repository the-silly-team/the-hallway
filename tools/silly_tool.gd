extends SceneTree
## SILLYSOFT resource tool (headless).
##
##   godot --headless --path . --script res://tools/silly_tool.gd -- <cmd> [args]
##
##   info <file>                          header + crc status
##   tex-pack <in.png> <out.sltx> [name]  pack a PNG into a .sltx
##   tex-unpack <in.sltx> <out.png>       unpack a .sltx to PNG
##   aud-pack <in.wav> <out.slau> [name]  pack a WAV into a .slau
##   aud-unpack <in.slau> <out.wav>       unpack a .slau to WAV
##   coll-pack <out.slcl> <name> <cx cy cz hx hy hz>...
##   coll-unpack <in.slcl>                print collision boxes
##   lv-pack <in.json> <out.sllv>         pack a JSON level definition
##   lv-unpack <in.sllv>                  print a level as JSON
##   sc-pack <in.json> <out.slsc>         pack a JSON compiled scene
##   sc-unpack <in.slsc>                  print a scene as JSON
##   mf-pack <in.json> <out.slmf>         pack a JSON package manifest
##   mf-unpack <in.slmf>                  print a manifest as JSON
##   tex-gen-pack <kind> <out.sltx>       export procedural texture + normal
##   aud-gen-pack <id> <out.slau>         export procedural sfx/music
##   gen-assets [tex_dir] [aud_dir]       export all defaults into asset dirs
##   roundtrip                            self-test: pack/unpack + crc checks

const Core = preload("res://scripts/sillysoft/silly_core.gd")
const Tex := preload("res://scripts/sillysoft/silly_texture.gd")
const Aud := preload("res://scripts/sillysoft/silly_audio.gd")
const Coll := preload("res://scripts/sillysoft/silly_collision.gd")
const Lvl := preload("res://scripts/sillysoft/silly_level.gd")
const Scn := preload("res://scripts/sillysoft/silly_scene.gd")
const Mft := preload("res://scripts/sillysoft/silly_manifest.gd")
const Texgen := preload("res://scripts/texgen.gd")
const AudGen := preload("res://scripts/audio_gen.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("silly_tool: no command (try 'roundtrip' or 'info <file>')")
		quit(1)
		return
	var cmd := args[0]
	match cmd:
		"info":
			_info(args)
		"tex-pack":
			_tex_pack(args)
		"tex-unpack":
			_tex_unpack(args)
		"aud-pack":
			_aud_pack(args)
		"aud-unpack":
			_aud_unpack(args)
		"coll-pack":
			_coll_pack(args)
		"coll-unpack":
			_coll_unpack(args)
		"lv-pack":
			_lv_pack(args)
		"lv-unpack":
			_lv_unpack(args)
		"sc-pack":
			_sc_pack(args)
		"sc-unpack":
			_sc_unpack(args)
		"mf-pack":
			_mf_pack(args)
		"mf-unpack":
			_mf_unpack(args)
		"tex-gen-pack":
			_tex_gen_pack(args)
		"aud-gen-pack":
			_aud_gen_pack(args)
		"gen-assets":
			_gen_assets(args)
		"roundtrip":
			_roundtrip()
		_:
			print("silly_tool: unknown command '%s'" % cmd)
			quit(1)
			return
	quit(1 if _fails > 0 else 0)

func _ok(msg: String) -> void:
	print("  PASS  ", msg)

func _bad(msg: String) -> void:
	_fails += 1
	print("  FAIL  ", msg)

# ---------------------------------------------------------------- commands

func _info(args: Array) -> void:
	if args.size() < 2:
		_bad("info: missing file")
		return
	var b := Core.read_file(args[1])
	if b.is_empty():
		_bad("info: cannot read '%s'" % args[1])
		return
	var magic := b.slice(0, 4).get_string_from_utf8()
	var vendor := b.slice(4, 10).get_string_from_utf8()
	var ver := b.decode_u16(10)
	print("%s  magic=%s vendor=%s version=%d size=%d crc=%s" % [
		args[1], magic, vendor, ver, b.size(),
		"OK" if Core.verify_crc(b) else "BAD"])

func _tex_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("tex-pack: need <in.png> <out.sltx>")
		return
	var img := Image.new()
	if img.load(args[1]) != OK:
		_bad("tex-pack: cannot load '%s'" % args[1])
		return
	var name: String = String(args[3]) if args.size() > 3 else String(args[1]).get_file().get_basename()
	if Tex.save(args[2], img, name):
		_ok("tex-pack: %s -> %s (%dx%d)" % [args[1], args[2], img.get_width(), img.get_height()])
	else:
		_bad("tex-pack: cannot write '%s'" % args[2])

func _tex_unpack(args: Array) -> void:
	if args.size() < 3:
		_bad("tex-unpack: need <in.sltx> <out.png>")
		return
	var d := Tex.load(args[1])
	if d.is_empty():
		_bad("tex-unpack: cannot read '%s'" % args[1])
		return
	var png: PackedByteArray = (d["image"] as Image).save_png_to_buffer()
	if not png.is_empty() and Core.write_file(args[2], png):
		_ok("tex-unpack: %s -> %s (%dx%d)" % [args[1], args[2], d["width"], d["height"]])
	else:
		_bad("tex-unpack: cannot write '%s'" % args[2])

func _aud_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("aud-pack: need <in.wav> <out.slau>")
		return
	var s := ResourceLoader.load(args[1], "AudioStreamWAV", ResourceLoader.CACHE_MODE_IGNORE)
	if not (s is AudioStreamWAV):
		_bad("aud-pack: cannot load '%s'" % args[1])
		return
	if (s as AudioStreamWAV).format != AudioStreamWAV.FORMAT_16_BITS:
		_bad("aud-pack: '%s' is not 16-bit PCM (import with compress/mode=0)" % args[1])
		return
	var name: String = String(args[3]) if args.size() > 3 else String(args[1]).get_file().get_basename()
	if Aud.save(args[2], s, name):
		_ok("aud-pack: %s -> %s (%d frames @ %d Hz)" % [args[1], args[2], s.data.size() / 2, s.mix_rate])
	else:
		_bad("aud-pack: cannot write '%s'" % args[2])

func _aud_unpack(args: Array) -> void:
	if args.size() < 3:
		_bad("aud-unpack: need <in.slau> <out.wav>")
		return
	var d := Aud.load(args[1])
	if d.is_empty():
		_bad("aud-unpack: cannot read '%s'" % args[1])
		return
	if (d["stream"] as AudioStreamWAV).save_to_wav(args[2]) == OK:
		_ok("aud-unpack: %s -> %s (%d frames)" % [args[1], args[2], d["frames"]])
	else:
		_bad("aud-unpack: cannot write '%s'" % args[2])

func _coll_pack(args: Array) -> void:
	if args.size() < 4 or (args.size() - 3) % 6 != 0:
		_bad("coll-pack: need <out.slcl> <name> then groups of cx cy cz hx hy hz")
		return
	var entries := []
	var i := 3
	while i < args.size():
		entries.append({
			"center": Vector3(float(args[i]), float(args[i + 1]), float(args[i + 2])),
			"half": Vector3(float(args[i + 3]), float(args[i + 4]), float(args[i + 5])),
			"type": 0,
		})
		i += 6
	if Coll.save(args[1], entries, args[2]):
		_ok("coll-pack: %s (%d boxes)" % [args[1], entries.size()])
	else:
		_bad("coll-pack: cannot write '%s'" % args[1])

func _coll_unpack(args: Array) -> void:
	if args.size() < 2:
		_bad("coll-unpack: need <in.slcl>")
		return
	var d := Coll.load(args[1])
	if d.is_empty():
		_bad("coll-unpack: cannot read '%s'" % args[1])
		return
	print("  %s: %d boxes" % [d["name"], (d["entries"] as Array).size()])
	for e in d["entries"]:
		print("    center=%s half=%s type=%d" % [e["center"], e["half"], e["type"]])
	_ok("coll-unpack: %s" % args[1])

func _json_file(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func _print_json(d: Dictionary) -> void:
	print(JSON.stringify(d, "  "))

func _lv_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("lv-pack: need <in.json> <out.sllv>")
		return
	var d := _json_file(args[1])
	if d.is_empty():
		_bad("lv-pack: cannot read JSON '%s'" % args[1])
		return
	if Lvl.save(args[2], d):
		_ok("lv-pack: %s -> %s" % [args[1], args[2]])
	else:
		_bad("lv-pack: cannot write '%s'" % args[2])

func _lv_unpack(args: Array) -> void:
	if args.size() < 2:
		_bad("lv-unpack: need <in.sllv>")
		return
	var d := Lvl.load(args[1])
	if d.is_empty():
		_bad("lv-unpack: cannot read '%s'" % args[1])
		return
	_print_json(d)
	_ok("lv-unpack: %s" % args[1])

func _sc_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("sc-pack: need <in.json> <out.slsc>")
		return
	var d := _json_file(args[1])
	if d.is_empty():
		_bad("sc-pack: cannot read JSON '%s'" % args[1])
		return
	if Scn.save(args[2], d):
		_ok("sc-pack: %s -> %s" % [args[1], args[2]])
	else:
		_bad("sc-pack: cannot write '%s'" % args[2])

func _sc_unpack(args: Array) -> void:
	if args.size() < 2:
		_bad("sc-unpack: need <in.slsc>")
		return
	var d := Scn.load(args[1])
	if d.is_empty():
		_bad("sc-unpack: cannot read '%s'" % args[1])
		return
	_print_json(d)
	_ok("sc-unpack: %s" % args[1])

func _mf_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("mf-pack: need <in.json> <out.slmf>")
		return
	var d := _json_file(args[1])
	if d.is_empty():
		_bad("mf-pack: cannot read JSON '%s'" % args[1])
		return
	if Mft.save(args[2], d):
		_ok("mf-pack: %s -> %s" % [args[1], args[2]])
	else:
		_bad("mf-pack: cannot write '%s'" % args[2])

func _mf_unpack(args: Array) -> void:
	if args.size() < 2:
		_bad("mf-unpack: need <in.slmf>")
		return
	var d := Mft.load(args[1])
	if d.is_empty():
		_bad("mf-unpack: cannot read '%s'" % args[1])
		return
	_print_json(d)
	_ok("mf-unpack: %s" % args[1])

func _tex_gen_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("tex-gen-pack: need <kind> <out.sltx>")
		return
	var img := Texgen.albedo(args[1]).get_image()
	var nrm := Texgen.normal(args[1]).get_image()
	if Tex.save(args[2], img, args[1], nrm):
		_ok("tex-gen-pack: %s -> %s" % [args[1], args[2]])
	else:
		_bad("tex-gen-pack: cannot write '%s'" % args[2])

func _generated_audio(id: String) -> AudioStreamWAV:
	match id:
		"click":
			return AudGen._mk_blip(980.0, 620.0, 0.06, 0.7)
		"hover":
			return AudGen._mk_blip(1400.0, 1250.0, 0.04, 0.28)
		"confirm":
			return AudGen._mk_confirm()
		"door_open":
			return AudGen._mk_door_open()
		"door_close":
			return AudGen._mk_door_close()
		"step":
			return AudGen._mk_step()
		"menu", "game":
			return AudGen._mk_music(id)
	return null

func _aud_gen_pack(args: Array) -> void:
	if args.size() < 3:
		_bad("aud-gen-pack: need <id> <out.slau>")
		return
	var s := _generated_audio(args[1])
	if s == null:
		_bad("aud-gen-pack: unknown id '%s'" % args[1])
		return
	if Aud.save(args[2], s, args[1]):
		_ok("aud-gen-pack: %s -> %s" % [args[1], args[2]])
	else:
		_bad("aud-gen-pack: cannot write '%s'" % args[2])

func _gen_assets(args: Array) -> void:
	var tex_dir: String = args[1] if args.size() > 1 else "res://assets/sltx"
	var aud_dir: String = args[2] if args.size() > 2 else "res://assets/slau"
	DirAccess.make_dir_recursive_absolute(tex_dir)
	DirAccess.make_dir_recursive_absolute(aud_dir + "/sfx")
	DirAccess.make_dir_recursive_absolute(aud_dir + "/music")
	var n := 0
	for kind in ["floor", "wall", "ceil", "metal"]:
		var img := Texgen.albedo(kind).get_image()
		var nrm := Texgen.normal(kind).get_image()
		if Tex.save(tex_dir + "/" + kind + ".sltx", img, kind, nrm):
			n += 1
	for id in ["click", "hover", "confirm", "door_open", "door_close", "step"]:
		var sfx_stream := _generated_audio(id)
		if sfx_stream != null and Aud.save(aud_dir + "/sfx/" + id + ".slau", sfx_stream, id):
			n += 1
	for id in ["menu", "game"]:
		var music_stream := _generated_audio(id)
		if music_stream != null and Aud.save(aud_dir + "/music/" + id + ".slau", music_stream, id):
			n += 1
	_ok("gen-assets: %d files -> %s, %s" % [n, tex_dir, aud_dir])

# ---------------------------------------------------------------- self-test

func _roundtrip() -> void:
	print("SILLYSOFT roundtrip test")
	_test_texture()
	_test_texture_normal()
	_test_audio()
	_test_collision()
	_test_level()
	_test_scene()
	_test_manifest()
	_test_crc()
	_test_magic()
	print("---")
	print("%d failure(s)" % _fails)

func _test_texture() -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, Color(float(x) / 63.0, float(y) / 63.0, 0.5, 1.0))
	var packed := Tex.pack(img, "test_grad")
	var d := Tex.unpack(packed)
	if d.is_empty():
		_bad("texture: unpack failed")
		return
	if d["image"].get_data() != img.get_data():
		_bad("texture: pixel data mismatch")
	else:
		_ok("texture: 64x64 RGBA8 roundtrip byte-exact (%d bytes)" % packed.size())

func _test_texture_normal() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var nrm := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, Color(0.2, 0.4, 0.6, 1.0))
			nrm.set_pixel(x, y, Color(0.5, 0.5, 1.0, 1.0))
	var d := Tex.unpack(Tex.pack(img, "n", nrm))
	if d.is_empty() or not d.has("normal"):
		_bad("texture+normal: unpack failed")
		return
	if d["normal"].get_data() != nrm.get_data():
		_bad("texture+normal: normal data mismatch")
	else:
		_ok("texture+normal: albedo + normal roundtrip")

func _test_audio() -> void:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 22050
	s.stereo = false
	var n := 2205
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(sin(TAU * 440.0 * float(i) / 22050.0) * 30000.0))
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	var d := Aud.unpack(Aud.pack(s, "sine"))
	if d.is_empty():
		_bad("audio: unpack failed")
		return
	var o: AudioStreamWAV = d["stream"]
	if o.data != data or o.mix_rate != 22050 or o.loop_end != n:
		_bad("audio: data/rate/loop mismatch")
	else:
		_ok("audio: 1s 440Hz mono 16-bit roundtrip byte-exact")

func _test_collision() -> void:
	var entries := [
		{"center": Vector3(0, 1.5, 0), "half": Vector3(1, 1.5, 0.1), "type": 0},
		{"center": Vector3(-8, 1.5, -6), "half": Vector3(0.2, 1.5, 6), "type": 1},
		{"center": Vector3(8, 1.5, -6), "half": Vector3(0.2, 1.5, 6), "type": 1},
	]
	var d := Coll.unpack(Coll.pack(entries, "room_a"))
	if d.is_empty():
		_bad("collision: unpack failed")
		return
	var got: Array = d["entries"]
	var same := got.size() == entries.size()
	if same:
		for i in got.size():
			if got[i]["center"] != entries[i]["center"] or got[i]["half"] != entries[i]["half"]:
				same = false
	if same:
		_ok("collision: 3 boxes roundtrip (center/half/type exact)")
	else:
		_bad("collision: box data mismatch")

func _test_level() -> void:
	var src := {
		"name": "test_lv",
		"spawn": [1.5, 2.0, -3.25],
		"ambient": [0.25, 0.5, 0.75],
		"objects": [{
			"type": "box",
			"name": "wall",
			"position": [0.0, 1.5, 0.0],
			"rotation": [0.0, 90.0, 0.0],
			"scale": [2.0, 3.0, 0.5],
			"props": {"tag": "alpha"},
		}],
	}
	var d := Lvl.unpack(Lvl.pack(src))
	if d == src:
		_ok("level: 1 object roundtrip (spawn/ambient/props exact)")
	else:
		_bad("level: data mismatch")

func _test_scene() -> void:
	var src := {
		"name": "test_scene",
		"source": "test_lv",
		"objects": [{
			"id": 7,
			"template": "cube",
			"position": [1.5, 0.0, -2.0],
			"rotation": [0.0, 45.0, 0.0],
			"scale": [1.0, 1.0, 1.0],
			"flags": 3,
			"assets": ["wall.sltx", "ping.slau"],
		}],
	}
	var d := Scn.unpack(Scn.pack(src))
	if d == src:
		_ok("scene: 1 instance roundtrip (transform/assets exact)")
	else:
		_bad("scene: data mismatch")

func _test_manifest() -> void:
	var src := {
		"title": "test_pack",
		"author": "lux",
		"entries": [{
			"path": "wall.sltx",
			"magic": "SLTX",
			"size": 1234,
			"crc": 4294967295,
			"deps": ["ping.slau"],
		}],
	}
	var d := Mft.unpack(Mft.pack(src))
	if d == src:
		_ok("manifest: 1 entry roundtrip (size/crc/deps exact)")
	else:
		_bad("manifest: data mismatch")

func _test_crc() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var packed := Tex.pack(img, "crc")
	if not Core.verify_crc(packed):
		_bad("crc: fresh file should verify")
		return
	var bad := packed.duplicate()
	bad[20] = bad[20] ^ 0xFF
	if Core.verify_crc(bad):
		_bad("crc: corrupted file should fail")
	else:
		_ok("crc: corruption detected")

func _test_magic() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var packed := Tex.pack(img, "magic")
	var r := Core.Reader.new(packed)
	if Core.read_header(r, "XXXX"):
		_bad("magic: wrong magic accepted")
	elif not Core.read_header(Core.Reader.new(packed), Core.MAGIC_TEXTURE):
		_bad("magic: correct magic rejected")
	else:
		_ok("magic: wrong magic rejected, correct magic accepted")
