extends RefCounted

const S := 256
const SlTex = preload("res://scripts/sillysoft/silly_texture.gd")
const ASSET_DIR := "res://assets/sltx/"
const SETTING_PREFIX := "sillysoft/sltx/"

static var _alb := {}
static var _nrm := {}

# periodic value noise: lattice wraps at integer periods so edges match exactly
static func _hash(x: int, y: int, s: int) -> float:
    var h := x * 374761393 + y * 668265263 + s * 1442695041
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return float(h & 0xffffff) / float(0xffffff) * 2.0 - 1.0

static func _ss(t: float) -> float:
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

# seamless 2D sample: u,v in [0,1), period = lattice cells across the tile
static func _w(seed: int, u: float, v: float, pu: int, pv: int) -> float:
    var x := u * pu
    var y := v * pv
    var xi := floori(x)
    var yi := floori(y)
    var xf := x - float(xi)
    var yf := y - float(yi)
    var x0 := posmod(xi, pu)
    var x1 := posmod(xi + 1, pu)
    var y0 := posmod(yi, pv)
    var y1 := posmod(yi + 1, pv)
    var a := _hash(x0, y0, seed)
    var b := _hash(x1, y0, seed)
    var c := _hash(x0, y1, seed)
    var d := _hash(x1, y1, seed)
    var sx := _ss(xf)
    var sy := _ss(yf)
    return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)

# fBm: sum octaves, each doubling the period (stays seamless)
static func _fbm(seed: int, u: float, v: float, pu: int, pv: int, oct: int = 3) -> float:
    var sum := 0.0
    var amp := 1.0
    var norm := 0.0
    var f := 1
    for i in range(oct):
        sum += _w(seed + i * 17, u, v, pu * f, pv * f) * amp
        norm += amp
        amp *= 0.5
        f *= 2
    return sum / norm

static func _img() -> Image:
    return Image.create(S, S, false, Image.FORMAT_RGBA8)

static func _height() -> Image:
    return Image.create(S, S, false, Image.FORMAT_L8)

static func _normal(h: Image, strength: float) -> ImageTexture:
    var w := h.get_width()
    var ht := h.get_height()
    var out := Image.create(w, ht, false, Image.FORMAT_RGBA8)
    for y in range(ht):
        for x in range(w):
            var l := h.get_pixel((x - 1 + w) % w, y).r
            var r := h.get_pixel((x + 1) % w, y).r
            var u := h.get_pixel(x, (y - 1 + ht) % ht).r
            var d := h.get_pixel(x, (y + 1) % ht).r
            var dx := (r - l) * strength
            var dy := (d - u) * strength
            var lenv := sqrt(dx * dx + dy * dy + 1.0)
            out.set_pixel(x, y, Color(-dx / lenv * 0.5 + 0.5, -dy / lenv * 0.5 + 0.5, 1.0 / lenv * 0.5 + 0.5))
    return ImageTexture.create_from_image(out)

static func _floor() -> Array:
    var img := _img()
    var h := _height()
    for y in range(S):
        for x in range(S):
            var u := float(x) / S
            var v := float(y) / S
            var big := _fbm(11, u, v, 4, 4, 2) * 0.5 + 0.5
            var fine := _fbm(12, u, v, 16, 16, 3) * 0.5 + 0.5
            var t := clampf(big * 0.55 + fine * 0.45, 0.0, 1.0)
            var base := Color(0.42, 0.44, 0.50)
            img.set_pixel(x, y, base * (0.80 + t * 0.44))
            h.set_pixel(x, y, Color(fine, fine, fine))
    return [ImageTexture.create_from_image(img), _normal(h, 3.0)]

static func _wall() -> Array:
    var img := _img()
    var h := _height()
    for y in range(S):
        for x in range(S):
            var u := float(x) / S
            var v := float(y) / S
            var g := _fbm(33, u, v, 12, 12, 3) * 0.5 + 0.5
            var m := _fbm(34, u, v, 3, 3, 2) * 0.5 + 0.5
            var base := Color(0.73, 0.75, 0.80)
            var col := base * (0.90 + g * 0.14 + m * 0.08)
            var eu := minf(u, 1.0 - u)
            var ev := minf(v, 1.0 - v)
            var seam := eu < 0.006 or ev < 0.006 or absf(u - 0.5) < 0.006 or absf(v - 0.5) < 0.006
            if seam:
                col = base * 0.78
            img.set_pixel(x, y, col)
            var hh := 0.6 + g * 0.4
            if seam:
                hh = 0.0
            h.set_pixel(x, y, Color(hh, hh, hh))
    return [ImageTexture.create_from_image(img), _normal(h, 6.0)]

static func _ceil() -> Array:
    var img := _img()
    var h := _height()
    for y in range(S):
        for x in range(S):
            var u := float(x) / S
            var v := float(y) / S
            var n := _fbm(55, u, v, 8, 8, 2) * 0.5 + 0.5
            var base := Color(0.85, 0.86, 0.89)
            var col := base * (0.93 + n * 0.12)
            var gu := absf(fmod(u * 4.0, 1.0))
            var gv := absf(fmod(v * 4.0, 1.0))
            var grout := gu < 0.05 or gv < 0.05
            if grout:
                col = base * 0.82
            img.set_pixel(x, y, col)
            var hh := 0.7 + n * 0.3
            if grout:
                hh = 0.3
            h.set_pixel(x, y, Color(hh, hh, hh))
    return [ImageTexture.create_from_image(img), _normal(h, 4.0)]

static func _metal() -> Array:
    var img := _img()
    var h := _height()
    for y in range(S):
        for x in range(S):
            var u := float(x) / S
            var v := float(y) / S
            var s := _fbm(77, u, v, 48, 4, 2) * 0.5 + 0.5
            var m := _fbm(78, u, v, 3, 3, 2) * 0.5 + 0.5
            var base := Color(0.34, 0.40, 0.50)
            var col := base * (0.85 + s * 0.25 + m * 0.12)
            img.set_pixel(x, y, col)
            h.set_pixel(x, y, Color(0.5 + s * 0.5, 0.5 + s * 0.5, 0.5 + s * 0.5))
    return [ImageTexture.create_from_image(img), _normal(h, 2.0)]

static func _make(kind: String) -> Array:
    match kind:
        "floor":
            return _floor()
        "wall":
            return _wall()
        "ceil":
            return _ceil()
        "metal":
            return _metal()
    return _wall()

static func _sltx_path(kind: String) -> String:
    var key := SETTING_PREFIX + kind
    if ProjectSettings.has_setting(key):
        var override := str(ProjectSettings.get_setting(key))
        if not override.is_empty():
            return override
    return ASSET_DIR + kind + ".sltx"

static func _try_load_sltx(kind: String) -> bool:
    var path := _sltx_path(kind)
    if not FileAccess.file_exists(path):
        return false
    var d := SlTex.load(path)
    if d.is_empty():
        return false
    var img: Image = d.get("image")
    if img == null:
        return false
    _alb[kind] = ImageTexture.create_from_image(img)
    if d.has("normal") and d["normal"] is Image:
        _nrm[kind] = ImageTexture.create_from_image(d["normal"])
    else:
        _nrm[kind] = _normal_from_color(img)
    return true

static func _normal_from_color(img: Image) -> ImageTexture:
    var h := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_L8)
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var c := img.get_pixel(x, y)
            var l := (c.r + c.g + c.b) / 3.0
            h.set_pixel(x, y, Color(l, l, l))
    return _normal(h, 4.0)

static func albedo(kind: String) -> ImageTexture:
    if _alb.has(kind):
        return _alb[kind]
    if _try_load_sltx(kind):
        return _alb[kind]
    var pair := _make(kind)
    _alb[kind] = pair[0]
    _nrm[kind] = pair[1]
    return pair[0]

static func normal(kind: String) -> ImageTexture:
    if not _nrm.has(kind):
        albedo(kind)
    return _nrm[kind]
