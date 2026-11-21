extends Node3D

const WH := 3.0
const WT := 0.3
const DH := 2.4
const DW := 2.5

const C_FLOOR := Color(0.32, 0.33, 0.37)
const C_WALL := Color(0.76, 0.77, 0.81)
const C_CEIL := Color(0.84, 0.86, 0.90)
const C_DOOR := Color(0.30, 0.45, 0.68)

const DoorScript = preload("res://scripts/door.gd")
const Tex = preload("res://scripts/texgen.gd")
const PauseMenuScript = preload("res://scripts/pause_menu.gd")
const SettingsUIScript = preload("res://scripts/settings_ui.gd")
const UIRef = preload("res://scripts/ui_utils.gd")

var subtitle: Label
var prompt: Label
var room_lbl: Label
var narrator: Node
var player: CharacterBody3D
var chosen := ""
var triggered := {}
var doors: Array = []
var pause_menu: Control
var settings_panel: Control
var fade_rect: ColorRect

func _ready():
    add_to_group("game")
    _ui()
    _env()
    _world()
    _doors()
    _player()
    _triggers()

    narrator = load("res://scripts/narrator.gd").new()
    narrator.subtitle_label = subtitle
    add_child(narrator)

    _set_room("the room")

    Audio.play_music("game")
    fade_rect.color.a = 1.0
    create_tween().tween_property(fade_rect, "color:a", 0.0, 0.9)

func toggle_pause() -> void:
    if settings_panel != null and settings_panel.visible:
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

func _set_room(t: String) -> void:
    room_lbl.text = t
    room_lbl.modulate.a = 0.0
    create_tween().tween_property(room_lbl, "modulate:a", 1.0, 0.5)

func _ui():
    var cl := CanvasLayer.new()
    add_child(cl)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cl.add_child(root)

    subtitle = Label.new()
    subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    subtitle.offset_left = 140.0
    subtitle.offset_right = -140.0
    subtitle.offset_top = -130.0
    subtitle.offset_bottom = -40.0
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    subtitle.add_theme_font_size_override("font_size", 25)
    subtitle.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
    subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
    subtitle.add_theme_constant_override("outline_size", 8)
    root.add_child(subtitle)

    prompt = Label.new()
    prompt.set_anchors_preset(Control.PRESET_CENTER)
    prompt.offset_left = -220.0
    prompt.offset_right = 220.0
    prompt.offset_top = 20.0
    prompt.offset_bottom = 60.0
    prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt.add_theme_font_size_override("font_size", 19)
    prompt.add_theme_color_override("font_color", Color(0.75, 0.87, 1.0))
    prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
    prompt.add_theme_constant_override("outline_size", 6)
    root.add_child(prompt)

    room_lbl = Label.new()
    room_lbl.position = Vector2(24, 18)
    room_lbl.add_theme_font_size_override("font_size", 15)
    room_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
    room_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
    room_lbl.add_theme_constant_override("outline_size", 4)
    root.add_child(room_lbl)

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
    cross.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
    root.add_child(cross)

    pause_menu = PauseMenuScript.new()
    cl.add_child(pause_menu)
    pause_menu.resume_requested.connect(_close_pause)
    pause_menu.settings_requested.connect(func(): settings_panel.open())
    pause_menu.menu_requested.connect(_go_menu)
    pause_menu.quit_requested.connect(_quit_game)

    settings_panel = SettingsUIScript.new()
    cl.add_child(settings_panel)

    fade_rect = UIRef.dim(Color(0, 0, 0, 0))
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cl.add_child(fade_rect)

func _env():
    var env := Environment.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.52, 0.55, 0.62)
    env.ambient_light_energy = 0.55
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.02, 0.02, 0.03)
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)

    for pos in [Vector3(0, 2.7, 6.0), Vector3(0, 2.7, -6.0), Vector3(0, 2.7, -20.0)]:
        var l := OmniLight3D.new()
        l.position = pos
        l.light_energy = 1.6
        l.light_color = Color(1.0, 0.96, 0.88)
        l.omni_range = 16.0
        add_child(l)

func _mat(kind: String, tint: Color, uv_scale: float = 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = Tex.albedo(kind)
    m.normal_enabled = true
    m.normal_texture = Tex.normal(kind)
    m.albedo_color = tint
    m.uv1_triplanar = true
    m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
    m.normal_scale = 0.8
    m.roughness = 0.85
    m.metallic = 0.0
    return m

func _solid(pos: Vector3, size: Vector3, col: Color, kind: String = "wall") -> void:
    var body := StaticBody3D.new()
    body.position = pos
    var mesh := BoxMesh.new()
    mesh.size = size
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = _mat(kind, col)
    body.add_child(mi)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    body.add_child(cs)
    add_child(body)

func _wall_x(z: float, x0: float, x1: float, gaps: Array) -> void:
    var cur := x0
    for g in gaps:
        if g[0] > cur:
            _solid(Vector3((cur + g[0]) * 0.5, WH * 0.5, z), Vector3(g[0] - cur, WH, WT), C_WALL)
        _solid(Vector3((g[0] + g[1]) * 0.5, (WH + DH) * 0.5, z), Vector3(g[1] - g[0], WH - DH, WT), C_WALL)
        cur = g[1]
    if cur < x1:
        _solid(Vector3((cur + x1) * 0.5, WH * 0.5, z), Vector3(x1 - cur, WH, WT), C_WALL)

func _wall_z(x: float, z0: float, z1: float, gaps: Array) -> void:
    var cur := z0
    for g in gaps:
        if g[0] > cur:
            _solid(Vector3(x, WH * 0.5, (cur + g[0]) * 0.5), Vector3(WT, WH, g[0] - cur), C_WALL)
        _solid(Vector3(x, (WH + DH) * 0.5, (g[0] + g[1]) * 0.5), Vector3(WT, WH - DH, g[1] - g[0]), C_WALL)
        cur = g[1]
    if cur < z1:
        _solid(Vector3(x, WH * 0.5, (cur + z1) * 0.5), Vector3(WT, WH, z1 - cur), C_WALL)

func _world():
    _solid(Vector3(0, -0.2, -8), Vector3(18, 0.4, 42), Color.WHITE, "floor")
    _solid(Vector3(0, WH + 0.2, -8), Vector3(18, 0.4, 42), Color.WHITE, "ceil")

    # Room A (widened to match Room B so the transition doesn't show void)
    _wall_x(0.0, -8.0, 8.0, [[-1.25, 1.25]])
    _wall_z(-8.0, 0.0, 12.0, [])
    _wall_z(8.0, 0.0, 12.0, [])
    _wall_x(12.0, -8.0, 8.0, [])

    # Room B
    _wall_x(-14.0, -8.0, 8.0, [[-6.0, -3.5], [3.5, 6.0]])
    _wall_z(-8.0, -14.0, 0.0, [])
    _wall_z(8.0, -14.0, 0.0, [])

    # Room C
    _wall_x(-28.0, -8.0, 8.0, [[-1.25, 1.25]])
    _wall_z(-8.0, -28.0, -14.0, [])
    _wall_z(8.0, -28.0, -14.0, [])

    # corridor side walls (between A and B)
    _wall_z(-2.0, 0.0, -14.0, [])
    _wall_z(2.0, 0.0, -14.0, [])

func _doors():
    _door(0.0, 0.0, "a_to_b", 2.5, "There you go. A door, opened. We are doing wonderfully.")
    _door(-4.75, -14.0, "b_left", 2.5, "The left door. A bold choice.")
    _door(4.75, -14.0, "b_right", 2.5, "The right door. A predictable choice.")
    _door(0.0, -28.0, "c_back", 2.5, "And so we return. Nothing was learned. Perfect.")

func _door(x: float, z: float, id: String, w: float, line: String) -> void:
    var d = DoorScript.new()
    d.id = id
    add_child(d)
    d.build(w, DH, 0.12, C_DOOR)
    d.position = Vector3(x, 0.0, z)
    d.opened.connect(_on_door_opened)
    doors.append(d)
    d.set("line", line)

func _player():
    var p = load("res://scripts/player.gd").new()
    p.position = Vector3(0.0, 0.1, 8.0)
    p.rotation.y = 0.0
    add_child(p)
    player = p

func _triggers():
    _zone("choice", Vector3(0.0, 1.5, -5.0), Vector3(14.0, 3.0, 6.0))
    _zone("c_enter", Vector3(0.0, 1.5, -20.0), Vector3(16.0, 3.0, 8.0))

func _zone(id: String, pos: Vector3, size: Vector3) -> void:
    var a := Area3D.new()
    a.position = pos
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    a.add_child(cs)
    a.body_entered.connect(func(body): _on_zone(id, body))
    add_child(a)

func _on_zone(id: String, body: Node3D) -> void:
    if body != player:
        return
    if triggered.has(id):
        return
    triggered[id] = true
    _fire(id)

func _fire(id: String) -> void:
    match id:
        "choice":
            _set_room("the choice")
        "c_enter":
            _set_room("the third room")

func _on_door_opened(id: String) -> void:
    match id:
        "a_to_b":
            _set_room("the corridor")
        "b_left":
            chosen = "left"
        "b_right":
            chosen = "right"
        "c_back":
            get_tree().create_timer(1.5).timeout.connect(func():
                player.global_position = Vector3(0.0, 0.1, 8.0)
                player.rotation.y = PI
                player.velocity = Vector3.ZERO
                triggered.erase("choice")
                triggered.erase("c_enter")
                chosen = ""
                _set_room("the room")
                for d in doors:
                    d.close()
            )

func _process(_delta: float) -> void:
    if player == null:
        return
    var ray: RayCast3D = player.get_ray()
    if ray == null:
        return
    var c = ray.get_collider()
    if c != null and c.has_method("interact") and c.has_method("can_interact") and c.can_interact():
        prompt.text = "[E]  open the door"
    else:
        prompt.text = ""

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_E and not get_tree().paused:
            if player == null:
                return
            var ray: RayCast3D = player.get_ray()
            if ray == null:
                return
            var c = ray.get_collider()
            if c != null and c.has_method("interact") and c.has_method("can_interact") and c.can_interact():
                c.interact()
