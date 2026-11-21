extends Node

const DrAud = preload("res://scripts/dr/dr_audio.gd")
const AudioGen = preload("res://scripts/audio_gen.gd")
const ASSET_DIR := "res://assets/drau/"
const SETTING_PREFIX := "doordsoft/drau/"

var _sfx := {}
var music := {}
var _mp: AudioStreamPlayer
var _pool: Array = []
var _pi := 0
var _cur := ""

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _bus("Music")
    _bus("SFX")
    _gen_sfx()
    _mp = AudioStreamPlayer.new()
    _mp.bus = "Music"
    add_child(_mp)
    for i in 8:
        var p := AudioStreamPlayer.new()
        p.bus = "SFX"
        add_child(p)
        _pool.append(p)
    Settings.apply()
    call_deferred("_gen_music_deferred")

func _gen_music_deferred() -> void:
    music["menu"] = _music_or_gen("menu")
    music["game"] = _music_or_gen("game")
    if not _cur.is_empty():
        var k := _cur
        _cur = ""
        play_music(k)

func _drau_paths(id: String, group: String) -> Array:
    var out := []
    var key := SETTING_PREFIX + group + "/" + id
    if ProjectSettings.has_setting(key):
        var override := str(ProjectSettings.get_setting(key))
        if not override.is_empty():
            out.append(override)
    out.append(ASSET_DIR + group + "/" + id + ".drau")
    out.append(ASSET_DIR + id + ".drau")
    return out

func _load_drau(id: String, group: String) -> AudioStreamWAV:
    for path in _drau_paths(id, group):
        if not FileAccess.file_exists(path):
            continue
        var d := DrAud.load(path)
        if d.is_empty():
            continue
        var s: AudioStreamWAV = d.get("stream")
        if s != null and s.format == AudioStreamWAV.FORMAT_16_BITS and not s.data.is_empty():
            return s
    return null

func _music_or_gen(kind: String) -> AudioStreamWAV:
    var s := _load_drau(kind, "music")
    return s if s != null else AudioGen._mk_music(kind)

func _bus(n: String) -> void:
    if AudioServer.get_bus_index(n) == -1:
        AudioServer.add_bus()
        var i := AudioServer.bus_count - 1
        AudioServer.set_bus_name(i, n)
        AudioServer.set_bus_send(i, "Master")

func play_music(kind: String) -> void:
    _cur = kind
    if not music.has(kind):
        return
    if _mp.playing and _mp.stream == music[kind]:
        return
    _mp.stream = music[kind]
    _mp.play()

func stop_music() -> void:
    _cur = ""
    _mp.stop()

func sfx(id: String, vol_db := 0.0) -> void:
    if not _sfx.has(id) or _pool.is_empty():
        return
    var p: AudioStreamPlayer = _pool[_pi]
    _pi = (_pi + 1) % _pool.size()
    p.stream = _sfx[id]
    p.volume_db = vol_db
    p.pitch_scale = randf_range(0.93, 1.07)
    p.play()

func _gen_sfx() -> void:
    var s := _load_drau("click", "sfx")
    _sfx["click"] = s if s != null else AudioGen._mk_blip(980.0, 620.0, 0.06, 0.7)
    s = _load_drau("hover", "sfx")
    _sfx["hover"] = s if s != null else AudioGen._mk_blip(1400.0, 1250.0, 0.04, 0.28)
    s = _load_drau("confirm", "sfx")
    _sfx["confirm"] = s if s != null else AudioGen._mk_confirm()
    s = _load_drau("door_open", "sfx")
    _sfx["door_open"] = s if s != null else AudioGen._mk_door_open()
    s = _load_drau("door_close", "sfx")
    _sfx["door_close"] = s if s != null else AudioGen._mk_door_close()
    s = _load_drau("step", "sfx")
    _sfx["step"] = s if s != null else AudioGen._mk_step()
