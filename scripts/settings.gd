extends Node

const PATH := "user://settings.cfg"

var sensitivity := 1.0
var fov := 75.0
var master_vol := 0.8
var music_vol := 0.6
var sfx_vol := 0.9
var fullscreen := false
var subtitles := true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load()
    apply()

func _load() -> void:
    var cf := ConfigFile.new()
    if cf.load(PATH) != OK:
        return
    sensitivity = float(cf.get_value("input", "sensitivity", sensitivity))
    fov = float(cf.get_value("input", "fov", fov))
    master_vol = float(cf.get_value("audio", "master", master_vol))
    music_vol = float(cf.get_value("audio", "music", music_vol))
    sfx_vol = float(cf.get_value("audio", "sfx", sfx_vol))
    fullscreen = bool(cf.get_value("video", "fullscreen", fullscreen))
    subtitles = bool(cf.get_value("ui", "subtitles", subtitles))

func save() -> void:
    var cf := ConfigFile.new()
    cf.set_value("input", "sensitivity", sensitivity)
    cf.set_value("input", "fov", fov)
    cf.set_value("audio", "master", master_vol)
    cf.set_value("audio", "music", music_vol)
    cf.set_value("audio", "sfx", sfx_vol)
    cf.set_value("video", "fullscreen", fullscreen)
    cf.set_value("ui", "subtitles", subtitles)
    cf.save(PATH)

func apply() -> void:
    _bus_vol("Master", master_vol)
    _bus_vol("Music", music_vol)
    _bus_vol("SFX", sfx_vol)
    var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
    if DisplayServer.window_get_mode() != mode:
        DisplayServer.window_set_mode(mode)

func _bus_vol(bus: String, lin: float) -> void:
    var i := AudioServer.get_bus_index(bus)
    if i < 0:
        return
    if lin <= 0.001:
        AudioServer.set_bus_mute(i, true)
    else:
        AudioServer.set_bus_mute(i, false)
        AudioServer.set_bus_volume_db(i, linear_to_db(clampf(lin, 0.001, 1.0)))
