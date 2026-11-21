extends Control

const MenuBG3D := preload("res://scripts/menu_bg3d.gd")
const SettingsUI := preload("res://scripts/settings_ui.gd")
const UI := preload("res://scripts/ui_utils.gd")

const TITLE := "MOW THE LAWN"

var _fade: ColorRect
var _title: Label
var _tagline: Label
var _settings: Control
var _t := 0.0
var _reveal := 0.0
var _tagged := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    # 3D background rendered into a viewport behind the UI
    var svc := SubViewportContainer.new()
    svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    svc.stretch = true
    svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(svc)
    var sv := SubViewport.new()
    sv.size = Vector2i(1280, 720)
    sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    svc.add_child(sv)
    sv.add_child(MenuBG3D.new())

    _vignette()
    _build_ui()

    _settings = SettingsUI.new()
    add_child(_settings)

    _fade = UI.dim(Color(0, 0, 0, 1))
    _fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_fade)
    create_tween().tween_property(_fade, "color:a", 0.0, 0.7)

    Audio.play_music("menu")

func _vignette() -> void:
    var g := Gradient.new()
    g.offsets = PackedFloat32Array([0.3, 1.0])
    g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.72)])
    var gt := GradientTexture2D.new()
    gt.gradient = g
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(0.5, 0.0)
    gt.width = 512
    gt.height = 512
    var vig := TextureRect.new()
    vig.texture = gt
    vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vig.stretch_mode = TextureRect.STRETCH_SCALE
    vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(vig)

func _build_ui() -> void:
    _title = Label.new()
    _title.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _title.offset_left = -400.0
    _title.offset_right = 400.0
    _title.offset_top = 86.0
    _title.offset_bottom = 186.0
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 74)
    _title.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0))
    _title.add_theme_color_override("font_shadow_color", Color(0.18, 0.4, 0.75, 0.6))
    _title.add_theme_constant_override("shadow_offset_x", 0)
    _title.add_theme_constant_override("shadow_offset_y", 5)
    add_child(_title)

    _tagline = Label.new()
    _tagline.text = "a lawn that refuses to stay mowed"
    _tagline.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _tagline.offset_left = -400.0
    _tagline.offset_right = 400.0
    _tagline.offset_top = 186.0
    _tagline.offset_bottom = 226.0
    _tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tagline.add_theme_font_size_override("font_size", 19)
    _tagline.add_theme_color_override("font_color", Color(0.6, 0.68, 0.82))
    _tagline.modulate.a = 0.0
    add_child(_tagline)

    var box := VBoxContainer.new()
    box.set_anchors_preset(Control.PRESET_CENTER)
    box.offset_left = -180.0
    box.offset_right = 180.0
    box.offset_top = -70.0
    box.offset_bottom = 130.0
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 16)
    add_child(box)

    var specs: Array = [["PLAY", _on_play], ["SETTINGS", _on_settings], ["QUIT", _on_quit]]
    for i in specs.size():
        var b := Button.new()
        b.text = specs[i][0]
        b.custom_minimum_size = Vector2(340, 52)
        UI.style_button(b, 20)
        b.pressed.connect(specs[i][1])
        b.modulate.a = 0.0
        box.add_child(b)
        var tw := create_tween()
        tw.tween_interval(0.5 + float(i) * 0.14)
        tw.tween_property(b, "modulate:a", 1.0, 0.35)

    var hint := Label.new()
    hint.text = "wasd move  ·  mouse look  ·  e open doors  ·  esc pause"
    hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    hint.offset_top = -44.0
    hint.offset_bottom = -16.0
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 15)
    hint.add_theme_color_override("font_color", Color(0.5, 0.57, 0.7, 0.9))
    add_child(hint)

    var ver := Label.new()
    ver.text = "mow the lawn  ·  v0.1"
    ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    ver.offset_left = -220.0
    ver.offset_right = -24.0
    ver.offset_top = -40.0
    ver.offset_bottom = -16.0
    ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    ver.add_theme_font_size_override("font_size", 14)
    ver.add_theme_color_override("font_color", Color(0.42, 0.48, 0.6))
    add_child(ver)

func _process(d: float) -> void:
    _t += d
    if _reveal < float(TITLE.length()):
        _reveal = minf(_reveal + d * 9.0, float(TITLE.length()))
        _title.text = TITLE.substr(0, int(_reveal))
    elif not _tagged:
        _tagged = true
        create_tween().tween_property(_tagline, "modulate:a", 1.0, 0.8)

func _on_play() -> void:
    Audio.sfx("confirm")
    _transition("res://main.tscn")

func _on_settings() -> void:
    _settings.open()

func _on_quit() -> void:
    _transition("")

func _transition(path: String) -> void:
    _fade.mouse_filter = Control.MOUSE_FILTER_STOP
    var tw := create_tween()
    tw.tween_property(_fade, "color:a", 1.0, 0.55)
    if path.is_empty():
        tw.tween_callback(get_tree().quit)
    else:
        tw.tween_callback(func(): get_tree().change_scene_to_file(path))
