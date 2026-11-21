extends StaticBody3D

signal opened(id)

var id := ""
var is_open := false
var locked := false
var line := ""
var pivot: Node3D
var mesh_inst: MeshInstance3D
var col_shape: CollisionShape3D
var target := 0.0

func can_interact() -> bool:
    return not is_open and not locked

const Tex = preload("res://scripts/texgen.gd")

func build(w: float, h: float, t: float, col: Color) -> void:
    pivot = Node3D.new()
    pivot.position = Vector3(-w / 2.0, 0.0, 0.0)
    add_child(pivot)

    var mesh := BoxMesh.new()
    mesh.size = Vector3(w, h, t)
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = Tex.albedo("metal")
    mat.normal_enabled = true
    mat.normal_texture = Tex.normal("metal")
    mat.albedo_color = col
    mat.uv1_triplanar = true
    mat.uv1_scale = Vector3(2.0, 2.0, 2.0)
    mat.metallic = 0.35
    mat.roughness = 0.55
    mi.material_override = mat
    mi.position = Vector3(w / 2.0, h / 2.0, 0.0)
    pivot.add_child(mi)
    mesh_inst = mi

    # collision must be a DIRECT child of this StaticBody3D (not the pivot)
    # or Godot never registers it with the physics body
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(w, h, t)
    cs.shape = sh
    cs.position = Vector3(0.0, h / 2.0, 0.0)
    add_child(cs)
    col_shape = cs

func interact() -> void:
    if is_open:
        return
    is_open = true
    target = -PI / 2.0
    Audio.sfx("door_open", -4.0)
    opened.emit(id)

func close() -> void:
    is_open = false
    target = 0.0
    Audio.sfx("door_close", -4.0)

func _process(delta: float) -> void:
    if pivot == null:
        return
    if absf(pivot.rotation.y - target) > 0.001:
        pivot.rotation.y = lerp_angle(pivot.rotation.y, target, delta * 6.0)
    # keep collision following the swinging door so it stays solid
    if col_shape != null and mesh_inst != null:
        col_shape.global_position = mesh_inst.global_position
        col_shape.global_rotation = mesh_inst.global_rotation
