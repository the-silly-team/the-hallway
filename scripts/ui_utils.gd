extends RefCounted

static func style_button(b: Button, font_size := 17) -> void:
    var n := StyleBoxFlat.new()
    n.bg_color = Color(0.13, 0.17, 0.24, 0.95)
    n.border_color = Color(0.3, 0.4, 0.55)
    n.set_border_width_all(1)
    n.set_corner_radius_all(5)
    n.content_margin_top = 8.0
    n.content_margin_bottom = 8.0
    var h := n.duplicate() as StyleBoxFlat
    h.bg_color = Color(0.2, 0.28, 0.4)
    h.border_color = Color(0.45, 0.6, 0.8)
    var p := n.duplicate() as StyleBoxFlat
    p.bg_color = Color(0.09, 0.12, 0.17)
    b.add_theme_stylebox_override("normal", n)
    b.add_theme_stylebox_override("hover", h)
    b.add_theme_stylebox_override("pressed", p)
    b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    b.add_theme_font_size_override("font_size", font_size)
    b.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
    b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
    b.mouse_entered.connect(func(): Audio.sfx("hover", -8.0))
    b.pressed.connect(func(): Audio.sfx("click"))

static func dim(color: Color) -> ColorRect:
    var r := ColorRect.new()
    r.color = color
    r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    return r

static func panel_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.07, 0.085, 0.12, 0.97)
    sb.border_color = Color(0.24, 0.31, 0.44)
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 34.0
    sb.content_margin_right = 34.0
    sb.content_margin_top = 26.0
    sb.content_margin_bottom = 26.0
    return sb

static func label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l
