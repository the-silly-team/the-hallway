extends CharacterBody3D

const SPEED := 5.5

var head: Node3D
var cam: Camera3D
var ray: RayCast3D
var _bob := 0.0
var _step_dist := 0.0

func _ready():
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.35
    cap.height = 1.7
    cs.shape = cap
    cs.position.y = 0.85
    add_child(cs)

    head = Node3D.new()
    head.position.y = 1.5
    add_child(head)

    cam = Camera3D.new()
    cam.fov = Settings.fov
    head.add_child(cam)

    ray = RayCast3D.new()
    ray.target_position = Vector3(0.0, 0.0, -2.5)
    ray.enabled = true
    cam.add_child(ray)

    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func get_ray() -> RayCast3D:
    return ray

func _process(_d: float) -> void:
    if cam != null and absf(cam.fov - Settings.fov) > 0.01:
        cam.fov = Settings.fov

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
            var s := 0.0022 * Settings.sensitivity
            rotate_y(-event.relative.x * s)
            head.rotation.x = clampf(head.rotation.x - event.relative.y * s, -1.45, 1.45)
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if get_tree().get_nodes_in_group("game").is_empty():
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            else:
                get_tree().call_group("game", "toggle_pause")
    elif event is InputEventMouseButton and event.pressed:
        if not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 14.0 * delta
    var dir := Vector3.ZERO
    if Input.is_key_pressed(KEY_W): dir -= transform.basis.z
    if Input.is_key_pressed(KEY_S): dir += transform.basis.z
    if Input.is_key_pressed(KEY_A): dir -= transform.basis.x
    if Input.is_key_pressed(KEY_D): dir += transform.basis.x
    dir.y = 0.0
    if dir.length_squared() > 0.0:
        dir = dir.normalized()
    velocity.x = dir.x * SPEED
    velocity.z = dir.z * SPEED
    move_and_slide()

    var hs := Vector2(velocity.x, velocity.z).length()
    if is_on_floor() and hs > 0.5:
        _bob += delta * (4.5 + hs * 0.9)
        _step_dist += hs * delta
        if _step_dist >= 2.0:
            _step_dist = 0.0
            Audio.sfx("step", -6.0)
        cam.position.y = sin(_bob) * 0.05
        cam.position.x = cos(_bob * 0.5) * 0.035
        head.rotation.z = sin(_bob * 0.5) * 0.012
    else:
        cam.position.y = lerpf(cam.position.y, 0.0, 8.0 * delta)
        cam.position.x = lerpf(cam.position.x, 0.0, 8.0 * delta)
        head.rotation.z = lerpf(head.rotation.z, 0.0, 8.0 * delta)
