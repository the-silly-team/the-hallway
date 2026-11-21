extends Control

const SEG := 6.0
const SEGS := 14
const HW := 3.2
const CH := 3.1
const SPEED := 2.4

var _t := 0.0
var _off := 0.0
var _dust: Array = []

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for i in 70:
        _dust.append(Vector3(
            randf_range(-HW, HW),
            randf_range(0.1, CH - 0.1),
            randf_range(0.0, SEGS * SEG)))

func _process(d: float) -> void:
    _t += d
    _off = fmod(_off + SPEED * d, SEG)
    queue_redraw()

func _p(x: float, y: float, z: float) -> Vector2:
    var s := 560.0 / maxf(z, 0.3)
    var sway_x := sin(_t * 0.17) * 0.4
    var sway_y := sin(_t * 0.13) * 0.14
    return Vector2(
        size.x * 0.5 + (x - sway_x) * s,
        size.y * 0.47 - (y - 1.55 - sway_y) * s)

func _fog(c: Color, z: float) -> Color:
    var f := clampf(z / (SEGS * SEG), 0.0, 1.0)
    return c.lerp(Color(0.62, 0.64, 0.68), f * 0.55)

func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
    draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.64, 0.68))

    for i in range(SEGS, 0, -1):
        var rz0 := (i - 1) * SEG - _off
        var z0 := maxf(rz0, 0.35)
        var z1 := i * SEG - _off
        if z1 <= 0.35:
            continue

        _quad(_p(-HW, 0, z1), _p(HW, 0, z1), _p(HW, 0, z0), _p(-HW, 0, z0),
            _fog(Color(0.72, 0.73, 0.76), z1))
        _quad(_p(-HW, CH, z1), _p(HW, CH, z1), _p(HW, CH, z0), _p(-HW, CH, z0),
            _fog(Color(0.82, 0.83, 0.87), z1))
        _quad(_p(-HW, CH, z1), _p(-HW, 0, z1), _p(-HW, 0, z0), _p(-HW, CH, z0),
            _fog(Color(0.74, 0.75, 0.79), z1))
        _quad(_p(HW, CH, z1), _p(HW, 0, z1), _p(HW, 0, z0), _p(HW, CH, z0),
            _fog(Color(0.74, 0.75, 0.79), z1))

        var zc := rz0 + SEG * 0.5
        if zc >= 6.0 and zc <= 54.0:
            _quad(_p(-0.8, CH - 0.04, zc + 0.5), _p(0.8, CH - 0.04, zc + 0.5),
                _p(0.8, CH - 0.04, zc - 0.5), _p(-0.8, CH - 0.04, zc - 0.5),
                _fog(Color(1.0, 0.96, 0.86), zc * 0.85))
            draw_circle(_p(0, CH - 0.04, zc), minf(560.0 / zc * 1.2, 180.0),
                Color(1.0, 0.95, 0.8, 0.05))

        if rz0 >= 0.35:
            var side := -1.0 if i % 2 == 0 else 1.0
            var dz0 := rz0 + 1.8
            var dz1 := minf(dz0 + 1.7, z1)
            if dz1 > dz0:
                var xw := side * HW
                var zm := (dz0 + dz1) * 0.5
                _quad(_p(xw, 0.0, dz1), _p(xw, 2.45, dz1),
                    _p(xw, 2.45, dz0), _p(xw, 0.0, dz0),
                    _fog(Color(0.28, 0.42, 0.62), zm))
                _quad(_p(xw, 0.05, dz1 - 0.1), _p(xw, 2.35, dz1 - 0.1),
                    _p(xw, 2.35, dz0 + 0.1), _p(xw, 0.05, dz0 + 0.1),
                    _fog(Color(0.20, 0.32, 0.52), zm))

    var zf := SEGS * SEG - _off
    _quad(_p(-HW, CH, zf), _p(HW, CH, zf), _p(HW, 0, zf), _p(-HW, 0, zf),
        _fog(Color(0.14, 0.16, 0.21), zf))
    var glow := 0.55 + 0.2 * sin(_t * 1.6)
    var dc := _fog(Color(0.28, 0.45, 0.72).lightened(0.12 * glow), zf)
    _quad(_p(-1.1, 0.0, zf), _p(-1.1, 2.5, zf), _p(1.1, 2.5, zf), _p(1.1, 0.0, zf), dc)
    draw_circle(_p(0, 1.25, zf), 560.0 / zf * 1.5,
        Color(0.4, 0.6, 0.9, 0.10 + 0.06 * sin(_t * 1.6)))

    for d: Vector3 in _dust:
        var z := d.z - _off
        while z < 0.4:
            z += SEGS * SEG
        while z > SEGS * SEG:
            z -= SEGS * SEG
        if z > 62.0:
            continue
        var pt := _p(d.x, d.y + sin(_t * 0.6 + d.x) * 0.15, z)
        var a := clampf(1.0 - z / (SEGS * SEG), 0.0, 1.0) * 0.35
        draw_circle(pt, 1.6, Color(0.5, 0.55, 0.7, a))
