extends Node3D

# 3D menu background: a corridor the camera flies through. The geometry repeats
# with period L, so teleporting back by exactly L is invisible -- looking through
# any open door shows a copy of the same corridor (Stanley Parable trick).
# Materials and lighting mirror game.gd so the menu looks like the game.

const Tex = preload("res://scripts/texgen.gd")

const L := 40.0          # loop period
const PERIODS := 6       # copies built (far end is well beyond sight)
const SPEED := 4.0
const HW := 4.0
const CH := 3.0
const WT := 0.25
const FAR := -L * PERIODS

const C_FLOOR := Color(1.0, 1.0, 1.0)
const C_CEIL := Color(0.84, 0.86, 0.90)
const C_WALL := Color(0.76, 0.77, 0.81)
const C_DOOR := Color(0.30, 0.45, 0.68)

var _cam: Camera3D

func _ready() -> void:
	_build_corridor()
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.position = Vector3(0.0, 1.5, -0.5)
	add_child(_cam)

	# lighting mirrors game.gd: cool ambient + warm ceiling omni lights
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.55, 0.62)
	env.ambient_light_energy = 0.55
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	amb.environment = env
	add_child(amb)

	# lights ride with the camera so the corridor is lit the same everywhere
	for lz in [-2.0, -12.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(0.0, 1.2, lz)
		l.light_energy = 1.6
		l.light_color = Color(1.0, 0.96, 0.88)
		l.omni_range = 16.0
		l.shadow_enabled = false
		_cam.add_child(l)

func _build_corridor() -> void:
	var z0 := 2.0
	var z1 := FAR - 2.0
	var mid := (z0 + z1) * 0.5
	var len := z0 - z1
	_box(Vector3(0, -0.2, mid), Vector3(HW * 2 + 2, 0.4, len), C_FLOOR, "floor")
	_box(Vector3(0, CH + 0.2, mid), Vector3(HW * 2 + 2, 0.4, len), C_CEIL, "ceil")
	_box(Vector3(-HW - WT * 0.5, CH * 0.5, mid), Vector3(WT, CH, len), C_WALL, "wall")
	_box(Vector3(HW + WT * 0.5, CH * 0.5, mid), Vector3(WT, CH, len), C_WALL, "wall")

	for k in PERIODS + 1:
		var dz := -L * float(k)
		_box(Vector3(-2.55, CH * 0.5, dz), Vector3(2.9, CH, WT), C_WALL, "wall")
		_box(Vector3(2.55, CH * 0.5, dz), Vector3(2.9, CH, WT), C_WALL, "wall")
		_box(Vector3(0, (CH + 2.4) * 0.5, dz), Vector3(2.2, CH - 2.4, WT), C_WALL, "wall")
		# open door panel, hinged left, swung toward the camera (+Z)
		_box(Vector3(-1.16, 1.2, dz + 1.1), Vector3(0.12, 2.4, 2.2), C_DOOR, "metal")
		if k < PERIODS:
			for i in 4:
				var sz := dz - (i + 1) * 8.0 + 2.0
				var side := -1.0 if i % 2 == 0 else 1.0
				_box(Vector3(side * (HW - 0.15), 1.2, sz),
					Vector3(0.12, 2.4, 1.8), C_DOOR, "metal")

	# solid cap far beyond anything visible
	_box(Vector3(0, CH * 0.5, FAR - 1.0), Vector3(HW * 2, CH, WT), C_WALL, "wall")

# exact copy of game.gd's material so the menu matches the game's surfaces
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

func _box(pos: Vector3, size: Vector3, col: Color, kind: String = "wall") -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = pos
	# doors use the same denser UV as door.gd
	var uv := 2.0 if kind == "metal" else 1.0
	mi.material_override = _mat(kind, col, uv)
	add_child(mi)

func _process(d: float) -> void:
	_cam.position.z -= SPEED * d
	# crossing a door shifts back exactly one period -- view is identical
	if _cam.position.z <= -L + 0.2:
		_cam.position.z += L
