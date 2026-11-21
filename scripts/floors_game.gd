extends Node3D

## THE HALLWAY - original doors-inspired v1 slice.
## An endless apartment building. Find the keycard, reach the stairwell, survive
## the thing that hunts noise. Closets are the only safe place - but don't move.

const X_HALF := 7.0
const Z_MIN := -18.0
const Z_MAX := 14.0
const START_Z := 10.0
const INTERACT_DIST := 2.8

const Tex = preload("res://scripts/texgen.gd")
const DoorScript = preload("res://scripts/door.gd")
const PauseMenuScript = preload("res://scripts/pause_menu.gd")
const SettingsUIScript = preload("res://scripts/settings_ui.gd")
const UIRef = preload("res://scripts/ui_utils.gd")

var player: CharacterBody3D
var pause_menu: Control
var settings_panel: Control
var fade_rect: ColorRect

var hud_floor: Label
var hud_stats: Label
var hud_obj: Label
var warning: Label
var prompt: Label
var popup: Label
var caught_panel: PanelContainer
var caught_lbl: Label
var shop_panel: PanelContainer

var floor_root: Node3D
var kiosk = null
var exit_door
var closets: Array = []
var key_pickup: Area3D
var key_glow: MeshInstance3D
var coins: Array = []
var lights: Array = []
var entity_node: Node3D

var floor_num := 1
var coin_count := 0
var lives := 3
var has_key := false
var hidden := false
var hiding_spot = null
var saved_pos := Vector3.ZERO
var shopping := false
var dead := false
var transitioning := false
var skip_next := false

var entity_active := false
var entity_in := 30.0
var entity_t := 0.0
var warned := false
var entity_speed := 9.0

var _popup_t := 0.0
var _flicker_t := 0.0
var _hint_t := 0.0

func _ready() -> void:
    add_to_group("game")
    randomize()
    _ui()
    _env()
    _player()
    _next_floor(1)
    Audio.play_music("game")
    fade_rect.color.a = 1.0
    create_tween().tween_property(fade_rect, "color:a", 0.0, 0.9)

func toggle_pause() -> void:
    if settings_panel != null and settings_panel.visible:
        return
    if shopping or dead:
        return
    if pause_menu.visible:
        _close_pause()
    else:
        pause_menu.visible = true
        pause_menu.notify_opened()
        get_tree().paused = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        pause_menu.modulate.a = 0.0
        pause_menu.create_tween().tween_property(pause_menu, "modulate:a", 1.0, 0.14)

func _close_pause() -> void:
    pause_menu.visible = false
    get_tree().paused = false
    if not hidden:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _go_menu() -> void:
    get_tree().paused = false
    Audio.sfx("confirm")
    var tw := create_tween()
    tw.tween_property(fade_rect, "color:a", 1.0, 0.45)
    tw.tween_callback(func(): get_tree().change_scene_to_file("res://menu.tscn"))

func _quit_game() -> void:
    get_tree().paused = false
    get_tree().quit()

func _ui() -> void:
    var cl := CanvasLayer.new()
    add_child(cl)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cl.add_child(root)

    hud_floor = _label(root, Vector2(24, 16), 26, Color(0.96, 0.93, 0.82))
    hud_stats = _label(root, Vector2(24, 50), 16, Color(0.78, 0.86, 0.80))
    hud_obj = _label(root, Vector2(24, 76), 16, Color(0.86, 0.78, 0.52))

    warning = _label(root, Vector2(0, 0), 30, Color(1.0, 0.42, 0.38))
    warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
    warning.offset_left = -420.0
    warning.offset_right = 420.0
    warning.offset_top = 74.0
    warning.offset_bottom = 124.0
    warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    prompt = _label(root, Vector2(0, 0), 18, Color(0.80, 0.90, 0.98))
    prompt.set_anchors_preset(Control.PRESET_CENTER)
    prompt.offset_left = -360.0
    prompt.offset_right = 360.0
    prompt.offset_top = 18.0
    prompt.offset_bottom = 62.0
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    popup = _label(root, Vector2(0, 0), 24, Color(1.0, 0.91, 0.52))
    popup.set_anchors_preset(Control.PRESET_CENTER)
    popup.offset_left = -400.0
    popup.offset_right = 400.0
    popup.offset_top = -130.0
    popup.offset_bottom = -80.0
    popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    popup.modulate.a = 0.0

    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_preset(Control.PRESET_CENTER)
    cross.offset_left = -12.0
    cross.offset_right = 12.0
    cross.offset_top = -14.0
    cross.offset_bottom = 14.0
    cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    cross.add_theme_font_size_override("font_size", 18)
    cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
    root.add_child(cross)

    pause_menu = PauseMenuScript.new()
    cl.add_child(pause_menu)
    pause_menu.resume_requested.connect(_close_pause)
    pause_menu.settings_requested.connect(func(): settings_panel.open())
    pause_menu.menu_requested.connect(_go_menu)
    pause_menu.quit_requested.connect(_quit_game)

    settings_panel = SettingsUIScript.new()
    cl.add_child(settings_panel)

    caught_panel = PanelContainer.new()
    caught_panel.set_anchors_preset(Control.PRESET_CENTER)
    caught_panel.offset_left = -260.0
    caught_panel.offset_right = 260.0
    caught_panel.offset_top = -90.0
    caught_panel.offset_bottom = 90.0
    caught_panel.add_theme_stylebox_override("panel", UIRef.panel_style())
    caught_panel.visible = false
    cl.add_child(caught_panel)
    var cv := VBoxContainer.new()
    cv.add_theme_constant_override("separation", 14)
    caught_panel.add_child(cv)
    caught_lbl = UIRef.label("CAUGHT", 30, Color(1.0, 0.52, 0.44))
    caught_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cv.add_child(caught_lbl)

    _build_shop(cl)

    fade_rect = UIRef.dim(Color(0, 0, 0, 0))
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cl.add_child(fade_rect)

func _label(parent: Control, pos: Vector2, size: int, col: Color) -> Label:
    var l := Label.new()
    l.position = pos
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", col)
    l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    l.add_theme_constant_override("outline_size", 5)
    parent.add_child(l)
    return l

func _build_shop(cl: CanvasLayer) -> void:
    shop_panel = PanelContainer.new()
    shop_panel.set_anchors_preset(Control.PRESET_CENTER)
    shop_panel.offset_left = -230.0
    shop_panel.offset_right = 230.0
    shop_panel.offset_top = -190.0
    shop_panel.offset_bottom = 190.0
    shop_panel.add_theme_stylebox_override("panel", UIRef.panel_style())
    shop_panel.visible = false
    cl.add_child(shop_panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    shop_panel.add_child(v)
    var t := UIRef.label("MAINTENANCE KIOSK", 22, Color(0.82, 0.92, 0.78))
    t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(t)
    var items: Array = [
        ["extra time  ·  3c", "time"],
        ["keycard hint  ·  2c", "hint"],
        ["extra life  ·  5c", "life"],
        ["silence next visit  ·  4c", "skip"],
        ["LEAVE", "leave"],
    ]
    for spec in items:
        var b := Button.new()
        b.text = spec[0]
        b.custom_minimum_size = Vector2(0, 42)
        UIRef.style_button(b, 16)
        b.pressed.connect(func(): _buy(spec[1]))
        v.add_child(b)

func _env() -> void:
    var env := Environment.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.20, 0.22, 0.28)
    env.ambient_light_energy = 0.32
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.01, 0.01, 0.02)
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

func _mat(kind: String, tint: Color, scale := 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = Tex.albedo(kind)
    m.normal_enabled = true
    m.normal_texture = Tex.normal(kind)
    m.albedo_color = tint
    m.uv1_triplanar = true
    m.uv1_scale = Vector3(scale, scale, scale)
    m.normal_scale = 0.7
    m.roughness = 0.86
    return m

func _solid(parent: Node, pos: Vector3, size: Vector3, kind: String, tint: Color, collide := true) -> StaticBody3D:
    var b := StaticBody3D.new()
    b.position = pos
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _mat(kind, tint)
    b.add_child(mi)
    if collide:
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = size
        cs.shape = sh
        b.add_child(cs)
    parent.add_child(b)
    return b

func _player() -> void:
    var p = load("res://scripts/player.gd").new()
    p.position = Vector3(0.0, 0.1, START_Z)
    add_child(p)
    player = p

func _next_floor(n: int) -> void:
    floor_num = n
    dead = false
    transitioning = false
    hidden = false
    hiding_spot = null
    shopping = false
    has_key = false
    skip_next = false
    entity_active = false
    warned = false
    entity_t = 0.0
    caught_panel.visible = false
    shop_panel.visible = false
    warning.text = ""
    if floor_root != null:
        floor_root.queue_free()
        floor_root = null
    floor_root = Node3D.new()
    add_child(floor_root)
    closets.clear()
    coins.clear()
    lights.clear()
    key_pickup = null

    _build_room()
    _build_props()
    _spawn_entity()

    player.global_position = Vector3(0.0, 0.1, START_Z)
    player.rotation.y = 0.0
    player.velocity = Vector3.ZERO
    player.set_physics_process(true)
    player.set_process(true)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    entity_in = maxf(15.0, 31.0 - float(floor_num) * 1.8) + randf_range(0.0, 7.0)
    _set_room()

func _set_room() -> void:
    hud_floor.text = "floor %d" % floor_num

func _build_room() -> void:
    var lz := (Z_MIN + Z_MAX) * 0.5
    var room_len := Z_MAX - Z_MIN + 4.0
    _solid(floor_root, Vector3(0, -0.25, lz), Vector3(X_HALF * 2.0 + 2.0, 0.5, room_len), "floor", Color.WHITE)
    _solid(floor_root, Vector3(0, 3.25, lz), Vector3(X_HALF * 2.2, 0.5, room_len), "ceil", Color(0.72, 0.70, 0.66))
    _solid(floor_root, Vector3(-X_HALF, 1.5, lz), Vector3(0.4, 3.0, room_len), "wall", Color(0.46, 0.42, 0.38))
    _solid(floor_root, Vector3(X_HALF, 1.5, lz), Vector3(0.4, 3.0, room_len), "wall", Color(0.46, 0.42, 0.38))
    _solid(floor_root, Vector3(0, 1.5, Z_MAX + 1.0), Vector3(X_HALF * 2.0, 3.0, 0.4), "wall", Color(0.50, 0.46, 0.42))
    _solid(floor_root, Vector3(-4.75, 1.5, Z_MIN), Vector3(4.5, 3.0, 0.4), "wall", Color(0.50, 0.46, 0.42))
    _solid(floor_root, Vector3(4.75, 1.5, Z_MIN), Vector3(4.5, 3.0, 0.4), "wall", Color(0.50, 0.46, 0.42))
    _solid(floor_root, Vector3(0, 2.45, Z_MIN), Vector3(5.0, 1.1, 0.4), "wall", Color(0.50, 0.46, 0.42))

    for z in [11.0, 2.0, -7.0, -15.0]:
        var l := OmniLight3D.new()
        l.position = Vector3(0.0, 2.75, z)
        l.light_energy = 1.15
        l.light_color = Color(1.0, 0.91, 0.72)
        l.omni_range = 11.0
        floor_root.add_child(l)
        lights.append(l)
        var fixture := MeshInstance3D.new()
        var fm := BoxMesh.new()
        fm.size = Vector3(1.4, 0.1, 0.5)
        fixture.mesh = fm
        fixture.position = Vector3(0.0, 2.95, z)
        var fm_mat := StandardMaterial3D.new()
        fm_mat.albedo_color = Color(0.9, 0.86, 0.7)
        fm_mat.emission = Color(0.8, 0.7, 0.45)
        fm_mat.emission_energy_multiplier = 0.7
        fixture.material_override = fm_mat
        floor_root.add_child(fixture)

func _build_props() -> void:
    # stairwell door (locked until keycard)
    var d = DoorScript.new()
    d.id = "stairwell"
    d.locked = true
    floor_root.add_child(d)
    d.build(2.5, 2.4, 0.14, Color(0.34, 0.40, 0.48))
    d.position = Vector3(0.0, 0.0, Z_MIN)
    d.opened.connect(_on_stairwell)
    exit_door = d

    # apartment doors along the walls, purely scenery
    for z in [6.0, -2.0, -10.0]:
        for side in [-1.0, 1.0]:
            var ad := MeshInstance3D.new()
            var am := BoxMesh.new()
            am.size = Vector3(0.12, 2.2, 1.3)
            ad.mesh = am
            ad.position = Vector3(side * (X_HALF - 0.24), 1.1, z)
            ad.material_override = _mat("metal", Color(0.32, 0.26, 0.22))
            floor_root.add_child(ad)

    # closets: the only hiding spots
    for spec in [[-5.5, 1.0], [5.5, -5.0], [-5.5, -12.0]]:
        var c := StaticBody3D.new()
        c.position = Vector3(spec[0], 0.0, spec[1])
        var body := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(1.5, 2.5, 1.1)
        body.mesh = bm
        body.position.y = 1.25
        body.material_override = _mat("wall", Color(0.30, 0.20, 0.13))
        c.add_child(body)
        var door := MeshInstance3D.new()
        var dm := BoxMesh.new()
        dm.size = Vector3(1.42, 2.35, 0.08)
        door.mesh = dm
        door.position = Vector3(0.0, 1.25, -0.58)
        door.material_override = _mat("metal", Color(0.36, 0.25, 0.16))
        c.add_child(door)
        var cs := CollisionShape3D.new()
        var sh := BoxShape3D.new()
        sh.size = Vector3(1.5, 2.5, 1.1)
        cs.shape = sh
        cs.position.y = 1.25
        c.add_child(cs)
        floor_root.add_child(c)
        closets.append(c)

    # maintenance kiosk
    var k := StaticBody3D.new()
    k.position = Vector3(5.4, 0.0, 9.0)
    var km := MeshInstance3D.new()
    var kbox := BoxMesh.new()
    kbox.size = Vector3(1.4, 1.7, 0.8)
    km.mesh = kbox
    km.position.y = 0.85
    km.material_override = _mat("metal", Color(0.24, 0.38, 0.32))
    k.add_child(km)
    var screen := MeshInstance3D.new()
    var sm := BoxMesh.new()
    sm.size = Vector3(0.9, 0.5, 0.06)
    screen.mesh = sm
    screen.position = Vector3(0.0, 1.35, -0.43)
    var scr_mat := StandardMaterial3D.new()
    scr_mat.albedo_color = Color(0.12, 0.5, 0.34)
    scr_mat.emission = Color(0.05, 0.35, 0.20)
    scr_mat.emission_energy_multiplier = 1.0
    screen.material_override = scr_mat
    k.add_child(screen)
    var kcs := CollisionShape3D.new()
    var ksh := BoxShape3D.new()
    ksh.size = Vector3(1.4, 1.7, 0.8)
    kcs.shape = ksh
    kcs.position.y = 0.85
    k.add_child(kcs)
    k.set_meta("kind", "shop")
    floor_root.add_child(k)
    kiosk = k

    # keycard in one of four hiding nooks
    var spots: Array = [
        Vector3(-5.6, 0.16, 7.0), Vector3(5.6, 0.16, 3.0),
        Vector3(-5.6, 0.16, -8.0), Vector3(5.6, 0.16, -14.0),
    ]
    var kp: Vector3 = spots[randi() % spots.size()]
    var key := Area3D.new()
    key.position = kp
    var km2 := MeshInstance3D.new()
    var kbm := BoxMesh.new()
    kbm.size = Vector3(0.38, 0.06, 0.26)
    km2.mesh = kbm
    var key_mat := StandardMaterial3D.new()
    key_mat.albedo_color = Color(1.0, 0.82, 0.22)
    key_mat.emission = Color(0.9, 0.6, 0.1)
    key_mat.emission_energy_multiplier = 1.4
    km2.material_override = key_mat
    key.add_child(km2)
    var kcol := CollisionShape3D.new()
    var kshp := BoxShape3D.new()
    kshp.size = Vector3(0.6, 0.6, 0.6)
    kcol.shape = kshp
    key.add_child(kcol)
    key.body_entered.connect(_on_key)
    floor_root.add_child(key)
    key_pickup = key
    key_glow = km2

    # loose coins
    for i in range(5 + floor_num):
        var c := Area3D.new()
        c.position = Vector3(randf_range(-6.0, 6.0), 0.16, randf_range(Z_MIN + 2.0, Z_MAX - 1.0))
        var cm := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.16
        cyl.bottom_radius = 0.16
        cyl.height = 0.05
        cm.mesh = cyl
        var cmat := StandardMaterial3D.new()
        cmat.albedo_color = Color(0.92, 0.74, 0.20)
        cmat.metallic = 0.7
        cmat.roughness = 0.3
        cm.material_override = cmat
        c.add_child(cm)
        var ccol := CollisionShape3D.new()
        var cshape := SphereShape3D.new()
        cshape.radius = 0.4
        ccol.shape = cshape
        c.add_child(ccol)
        c.body_entered.connect(_on_coin.bind(c))
        floor_root.add_child(c)
        coins.append(c)

func _spawn_entity() -> void:
    var e := Node3D.new()
    e.position = Vector3(0.0, 0.0, Z_MIN - 4.0)
    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.48
    cap.height = 2.5
    body.mesh = cap
    body.position.y = 1.25
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.02, 0.02, 0.03)
    m.roughness = 1.0
    body.material_override = m
    e.add_child(body)
    for x in [-0.18, 0.18]:
        var eye := MeshInstance3D.new()
        var sph := SphereMesh.new()
        sph.radius = 0.07
        sph.height = 0.14
        eye.mesh = sph
        eye.position = Vector3(x, 1.85, -0.42)
        var em := StandardMaterial3D.new()
        em.albedo_color = Color(1.0, 0.28, 0.18)
        em.emission = Color(1.0, 0.12, 0.06)
        em.emission_energy_multiplier = 3.0
        eye.material_override = em
        e.add_child(eye)
    var glow := OmniLight3D.new()
    glow.light_color = Color(1.0, 0.15, 0.08)
    glow.light_energy = 2.2
    glow.omni_range = 7.0
    glow.position.y = 1.7
    e.add_child(glow)
    e.visible = false
    floor_root.add_child(e)
    entity_node = e

func _on_key(body: Node3D) -> void:
    if body != player or has_key:
        return
    has_key = true
    if key_pickup != null:
        key_pickup.visible = false
    exit_door.locked = false
    Audio.sfx("confirm")
    _popup("keycard acquired - the stairwell is open", 2.6)

func _on_coin(body: Node3D, node: Area3D) -> void:
    if body != player or not is_instance_valid(node):
        return
    coin_count += 1
    Audio.sfx("click", -16.0)
    node.queue_free()
    coins.erase(node)

func _on_stairwell(_id: String) -> void:
    if transitioning or dead:
        return
    transitioning = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    Audio.sfx("confirm")
    var tw := create_tween()
    tw.tween_property(fade_rect, "color:a", 1.0, 0.6)
    tw.tween_callback(func(): _next_floor(floor_num + 1))
    tw.tween_property(fade_rect, "color:a", 0.0, 0.8)

func _process(delta: float) -> void:
    if get_tree().paused or player == null or dead or shopping:
        return
    _update_entity(delta)
    _update_prompt()
    _update_hud()
    if _popup_t > 0.0:
        _popup_t -= delta
        popup.modulate.a = clampf(_popup_t, 0.0, 1.0)
    if _hint_t > 0.0:
        _hint_t -= delta
        if key_glow != null and is_instance_valid(key_glow):
            key_glow.scale = Vector3.ONE * (1.0 + sin(_hint_t * 12.0) * 0.6)
            if _hint_t <= 0.0:
                key_glow.scale = Vector3.ONE

func _update_entity(delta: float) -> void:
    if not entity_active:
        entity_in -= delta
        if entity_in <= 5.0 and not warned:
            warned = true
            warning.text = "the lights are flickering..."
        if warned:
            _flicker_t += delta
            var pulse := 0.35 + absf(sin(_flicker_t * 9.0)) * 0.8
            for l in lights:
                if is_instance_valid(l):
                    l.light_energy = pulse
        if entity_in <= 0.0:
            _start_visit()
        return

    entity_t += delta
    entity_node.position.z += entity_speed * delta
    if not hidden and absf(entity_node.position.z - player.global_position.z) < 1.7:
        _caught()
        return
    if entity_node.position.z > Z_MAX + 5.0:
        entity_active = false
        entity_node.visible = false
        warning.text = ""
        for l in lights:
            if is_instance_valid(l):
                l.light_energy = 1.15
        if hidden:
            _unhide()
        entity_in = maxf(14.0, 27.0 - float(floor_num)) + randf_range(0.0, 6.0)

func _start_visit() -> void:
    warned = false
    if skip_next:
        skip_next = false
        warning.text = "silence. it passed the floor."
        entity_in = 22.0
        return
    entity_active = true
    entity_t = 0.0
    entity_node.visible = true
    entity_node.position.z = Z_MIN - 4.0
    entity_speed = 8.0 + float(floor_num) * 0.5
    warning.text = "IT IS IN THE HALL - HIDE"
    Audio.sfx("door_close", -2.0)

func _caught() -> void:
    dead = true
    entity_active = false
    entity_node.visible = false
    lives -= 1
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    caught_panel.visible = true
    Audio.sfx("door_close", -1.0)
    if lives <= 0:
        caught_lbl.text = "GAME OVER\n\nfloor %d" % floor_num
        get_tree().create_timer(2.4).timeout.connect(func():
            caught_panel.visible = false
            lives = 3
            coin_count = 0
            _next_floor(1)
        )
    else:
        caught_lbl.text = "CAUGHT\n\n%d left" % lives
        get_tree().create_timer(2.0).timeout.connect(func():
            caught_panel.visible = false
            entity_in = 14.0
            _next_floor(floor_num)
        )

func _hide_in(spot) -> void:
    hidden = true
    hiding_spot = spot
    saved_pos = player.global_position
    player.global_position = spot.global_position + Vector3(0.0, 0.1, 0.0)
    player.set_physics_process(false)
    player.set_process(false)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    warning.text = "inside the closet. do not move."

func _unhide() -> void:
    if not hidden:
        return
    hidden = false
    hiding_spot = null
    player.global_position = saved_pos
    player.set_physics_process(true)
    player.set_process(true)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    warning.text = ""

func _nearest() -> Dictionary:
    var best := {}
    var p := player.global_position
    if exit_door != null and not exit_door.is_open:
        var d := p.distance_to(exit_door.global_position)
        if d < INTERACT_DIST and (best.is_empty() or d < best["d"]):
            best = {"kind": "door", "d": d}
    for c in closets:
        if not is_instance_valid(c):
            continue
        var d := p.distance_to(c.global_position)
        if d < INTERACT_DIST and (best.is_empty() or d < best["d"]):
            best = {"kind": "closet", "d": d, "node": c}
    if kiosk != null:
        var d := p.distance_to(kiosk.global_position)
        if d < INTERACT_DIST and (best.is_empty() or d < best["d"]):
            best = {"kind": "shop", "d": d}
    return best

func _update_prompt() -> void:
    if hidden:
        prompt.text = "stay still. [E] leave when it is safe"
        return
    var n := _nearest()
    match n.get("kind", ""):
        "door":
            prompt.text = "[E]  unlock stairwell" if has_key else "[E]  locked - find the keycard"
        "closet":
            prompt.text = "[E]  hide in closet"
        "shop":
            prompt.text = "[E]  maintenance kiosk"
        _:
            prompt.text = ""

func _update_hud() -> void:
    hud_stats.text = "coins %d    lives %d" % [coin_count, lives]
    hud_obj.text = "objective: " + ("reach the stairwell" if has_key else "find the keycard")

func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo or get_tree().paused:
        return
    if event.keycode != KEY_E:
        return
    if hidden:
        if not entity_active:
            _unhide()
        return
    if dead or shopping or transitioning:
        return
    var n := _nearest()
    match n.get("kind", ""):
        "door":
            if has_key:
                exit_door.interact()
            else:
                Audio.sfx("door_close", -8.0)
                _popup("locked", 1.2)
        "closet":
            _hide_in(n["node"])
        "shop":
            _open_shop()

func _open_shop() -> void:
    shopping = true
    shop_panel.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    player.set_physics_process(false)

func _buy(what: String) -> void:
    if what == "leave":
        _close_shop()
        return
    var prices := {"time": 3, "hint": 2, "life": 5, "skip": 4}
    var cost: int = prices.get(what, 999)
    if coin_count < cost:
        _popup("need %d coins" % cost, 1.4)
        return
    coin_count -= cost
    match what:
        "time":
            entity_in += 15.0
            warned = false
            _popup("you bought 15 seconds", 1.8)
        "hint":
            _hint_t = 5.0
            _popup("the keycard is glowing", 1.8)
        "life":
            lives += 1
            _popup("+1 life", 1.8)
        "skip":
            skip_next = true
            _popup("it will pass this floor", 1.8)
    Audio.sfx("confirm")
    _close_shop()

func _close_shop() -> void:
    shopping = false
    shop_panel.visible = false
    player.set_physics_process(true)
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _popup(text: String, seconds: float) -> void:
    popup.text = text
    popup.modulate.a = 1.0
    _popup_t = seconds

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
        pass
