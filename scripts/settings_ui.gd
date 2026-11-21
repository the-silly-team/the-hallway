extends Control

signal closed

const UI := preload("res://scripts/ui_utils.gd")

var _vals := {}
var _panel: PanelContainer

func _ready() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build()

func open() -> void:
    _refresh()
    visible = true
    modulate.a = 0.0
    _panel.pivot_offset = _panel.size * 0.5
    _panel.scale = Vector2(0.94, 0.94)
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 1.0, 0.16)
    tw.parallel().tween_property(_panel, "scale", Vector2.ONE, 0.2) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 0.13)
    tw.tween_callback(_finish)

func _finish() -> void:
    visible = false
    closed.emit()

func _unhandled_input(e: InputEvent) -> void:
    if visible and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        Audio.sfx("click")
        close()

func _refresh() -> void:
    for k in _vals:
        _vals[k][0].text = _vals[k][1].call(float(Settings.get(k)))

func _build() -> void:
    add_child(UI.dim(Color(0.02, 0.03, 0.05, 0.72)))

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    _panel = PanelContainer.new()
    _panel.custom_minimum_size = Vector2(560, 0)
    _panel.add_theme_stylebox_override("panel", UI.panel_style())
    center.add_child(_panel)

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 14)
    _panel.add_child(v)

    var title := UI.label("SETTINGS", 26, Color(0.85, 0.9, 1.0))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(title)

    var sep := HSeparator.new()
    sep.modulate = Color(1, 1, 1, 0.35)
    v.add_child(sep)

    _slider(v, "sensitivity", "mouse sensitivity", 0.3, 3.0, 0.05,
        func(x): return "%.2f" % x)
    _slider(v, "fov", "field of view", 60.0, 100.0, 1.0,
        func(x): return "%d deg" % int(round(x)))
    _slider(v, "master_vol", "master volume", 0.0, 1.0, 0.01,
        func(x): return "%d%%" % int(round(x * 100)))
    _slider(v, "music_vol", "music volume", 0.0, 1.0, 0.01,
        func(x): return "%d%%" % int(round(x * 100)))
    _slider(v, "sfx_vol", "sfx volume", 0.0, 1.0, 0.01,
        func(x): return "%d%%" % int(round(x * 100)))
    _toggle(v, "fullscreen", "fullscreen")
    _toggle(v, "subtitles", "subtitles")

    var back := Button.new()
    back.text = "BACK"
    back.custom_minimum_size = Vector2(0, 44)
    UI.style_button(back, 18)
    back.pressed.connect(close)
    v.add_child(back)

func _slider(parent: Node, key: String, label: String, mn: float, mx: float, st: float, fmt: Callable) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    parent.add_child(row)

    var l := UI.label(label, 16, Color(0.72, 0.78, 0.9))
    l.custom_minimum_size = Vector2(200, 0)
    row.add_child(l)

    var s := HSlider.new()
    s.min_value = mn
    s.max_value = mx
    s.step = st
    s.value = float(Settings.get(key))
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    s.custom_minimum_size = Vector2(220, 0)
    row.add_child(s)

    var val := UI.label("", 16, Color(0.55, 0.7, 0.95))
    val.custom_minimum_size = Vector2(72, 0)
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(val)
    _vals[key] = [val, fmt]

    s.value_changed.connect(_on_slider.bind(key, fmt))

func _on_slider(v: float, key: String, fmt: Callable) -> void:
    Settings.set(key, v)
    Settings.apply()
    Settings.save()
    _vals[key][0].text = fmt.call(v)

func _toggle(parent: Node, key: String, label: String) -> void:
    var c := CheckButton.new()
    c.text = label
    c.button_pressed = bool(Settings.get(key))
    c.add_theme_font_size_override("font_size", 16)
    c.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9))
    c.toggled.connect(_on_toggle.bind(key))
    parent.add_child(c)

func _on_toggle(pressed: bool, key: String) -> void:
    Settings.set(key, pressed)
    Settings.apply()
    Settings.save()
