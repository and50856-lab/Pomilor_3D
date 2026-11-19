class_name VehicleModel
extends RefCounted
# Процедурные кузова. Для своей модели из Blender положи res://assets/vehicles/<id>.glb
# с узлами: Wheel_FL, Wheel_FR, Wheel_RL, Wheel_RR, Door_L, Seat — они подхватятся.

static var _kit: Dictionary = {}


static func _mesh_box(size: Vector3) -> BoxMesh:
    var bm := BoxMesh.new()
    bm.size = size
    return bm


static func _add(st: SurfaceTool, mesh: Mesh, pos: Vector3, rot_x: float = 0.0) -> void:
    var xf := Transform3D(Basis(Vector3.RIGHT, rot_x), pos)
    st.append_from(mesh, 0, xf)


static func _commit(parts: Array, mat: Material) -> MeshInstance3D:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p in parts:
        _add(st, p[0], p[1], p[2])
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = mat
    return mi


static func _paint(c: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = 0.55
    m.roughness = 0.28
    if Settings.graphics >= 3:
        m.clearcoat_enabled = true
        m.clearcoat = 0.8
        m.clearcoat_roughness = 0.08
    return m


static func _glass() -> StandardMaterial3D:
    var key: String = "glass"
    if _kit.has(key):
        return _kit[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(0.08, 0.12, 0.16, 0.55)
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.metallic = 0.3
    m.roughness = 0.05
    _kit[key] = m
    return m


static func _emit(c: Color, energy: float) -> StandardMaterial3D:
    var key: String = "em_%s" % c.to_html()
    if _kit.has(key):
        return _kit[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    _kit[key] = m
    return m


static func build(id: String, color: Color) -> Dictionary:
    var d: Dictionary = VehicleDefs.get_def(id)
    var root := Node3D.new()
    root.name = "Model"
    var r: float = d["wheel_r"]
    var track: float = d["track"]
    var wb: float = d["wheelbase"]
    var body: Vector3 = d["body"]
    var body_c: Vector3 = d["body_c"]
    var cab: Vector3 = d["cab"]
    var cab_c: Vector3 = d["cab_c"]
    var width: float = d["width"]
    var length: float = d["length"]
    var out: Dictionary = {"root": root, "wheels": [], "spins": [], "door": null, "seat": d["seat"], "steer": null}

    var paint: Array = []
    var glass: Array = []
    var dark: Array = []
    var head: Array = []
    var tail: Array = []
    var door_node := Node3D.new()
    door_node.name = "Door_L"
    var dz: Vector3 = d["door"]
    var door_h: float = d["door_h"]

    paint.append([_mesh_box(body), body_c, 0.0])
    paint.append([_mesh_box(cab), cab_c, 0.0])
    var cab_top: float = cab_c.y + cab.y * 0.5
    var glass_h: float = cab.y * 0.78
    var gy: float = cab_c.y + 0.02
    glass.append([_mesh_box(Vector3(cab.x + 0.04, glass_h, cab.z * 0.78)), Vector3(0.0, gy, cab_c.z), 0.0])
    match id:
        "g_class":
            glass.append([_mesh_box(Vector3(cab.x - 0.1, glass_h, 0.06)), Vector3(0.0, gy, cab_c.z - cab.z * 0.5 - 0.02), 0.12])
            glass.append([_mesh_box(Vector3(cab.x - 0.1, glass_h, 0.06)), Vector3(0.0, gy, cab_c.z + cab.z * 0.5 + 0.02), 0.0])
            dark.append([_mesh_box(Vector3(1.0, 0.32, 0.05)), Vector3(0.0, 0.5, -body.z * 0.5 - 0.02), 0.0])
            dark.append([_mesh_box(Vector3(0.9, 0.9, 0.25)), Vector3(0.0, 0.55, body.z * 0.5 + 0.12), 0.0])
        "vaz":
            glass.append([_mesh_box(Vector3(cab.x - 0.12, 0.62, 0.05)), Vector3(0.0, cab_c.y + 0.02, cab_c.z - cab.z * 0.5 - 0.1), 0.95])
            glass.append([_mesh_box(Vector3(cab.x - 0.12, 0.62, 0.05)), Vector3(0.0, cab_c.y + 0.02, cab_c.z + cab.z * 0.5 + 0.1), -0.95])
            dark.append([_mesh_box(Vector3(0.8, 0.12, 0.04)), Vector3(0.0, 0.25, -body.z * 0.5 - 0.01), 0.0])
        "gallardo":
            glass.append([_mesh_box(Vector3(cab.x - 0.12, 0.62, 0.05)), Vector3(0.0, cab_c.y + 0.03, cab_c.z - cab.z * 0.5 - 0.14), 1.1])
            paint.append([_mesh_box(Vector3(1.6, 0.2, 1.3)), Vector3(0.0, 0.42, 1.5), 0.0])
            paint.append([_mesh_box(Vector3(1.7, 0.08, 1.4)), Vector3(0.0, 0.33, -1.3), -0.06])
            dark.append([_mesh_box(Vector3(width, 0.1, 0.3)), Vector3(0.0, -0.1, -body.z * 0.5 - 0.05), 0.0])
            dark.append([_mesh_box(Vector3(0.05, 0.2, 0.6)), Vector3(width * 0.5 + 0.0, 0.15, 0.7), 0.0])
            dark.append([_mesh_box(Vector3(0.05, 0.2, 0.6)), Vector3(-width * 0.5, 0.15, 0.7), 0.0])
    dark.append([_mesh_box(Vector3(width, 0.22, 0.16)), Vector3(0.0, -0.04, -length * 0.5 + 0.06), 0.0])
    dark.append([_mesh_box(Vector3(width, 0.22, 0.16)), Vector3(0.0, -0.04, length * 0.5 - 0.06), 0.0])
    var ly: float = body_c.y + body.y * 0.1
    for sx in [-1.0, 1.0]:
        head.append([_mesh_box(Vector3(0.28, 0.14, 0.05)), Vector3(sx * width * 0.34, ly, -length * 0.5 + 0.02), 0.0])
        tail.append([_mesh_box(Vector3(0.24, 0.14, 0.05)), Vector3(sx * width * 0.36, ly, length * 0.5 - 0.02), 0.0])

    root.add_child(_commit(paint, _paint(color)))
    root.add_child(_commit(glass, _glass()))
    var dark_mat: StandardMaterial3D = WeaponModel.mat(Color(0.05, 0.05, 0.06), 0.2, 0.7)
    root.add_child(_commit(dark, dark_mat))
    root.add_child(_commit(head, _emit(Color(1.0, 0.95, 0.8), 1.6)))
    root.add_child(_commit(tail, _emit(Color(0.9, 0.05, 0.05), 1.2)))

    # дверь водителя (слева)
    door_node.position = Vector3(-width * 0.5 - 0.02, dz.z, dz.x)
    var dpanel := MeshInstance3D.new()
    dpanel.mesh = _mesh_box(Vector3(0.05, door_h * 0.55, dz.y))
    dpanel.material_override = _paint(color)
    dpanel.position = Vector3(0.0, -door_h * 0.2, dz.y * 0.5)
    door_node.add_child(dpanel)
    var dglass := MeshInstance3D.new()
    dglass.mesh = _mesh_box(Vector3(0.055, door_h * 0.32, dz.y * 0.8))
    dglass.material_override = _glass()
    dglass.position = Vector3(0.0, door_h * 0.17, dz.y * 0.5)
    door_node.add_child(dglass)
    root.add_child(door_node)
    out["door"] = door_node

    # колёса
    var tire_mat: StandardMaterial3D = WeaponModel.mat(Color(0.03, 0.03, 0.035), 0.0, 0.9)
    var rim_mat: StandardMaterial3D = WeaponModel.mat(Color(0.7, 0.72, 0.76), 0.9, 0.25)
    var tire_m := CylinderMesh.new()
    tire_m.top_radius = r
    tire_m.bottom_radius = r
    tire_m.height = 0.26
    tire_m.radial_segments = 16
    tire_m.rings = 1
    var rim_m := CylinderMesh.new()
    rim_m.top_radius = r * 0.62
    rim_m.bottom_radius = r * 0.62
    rim_m.height = 0.275
    rim_m.radial_segments = 10
    rim_m.rings = 1
    var names: Array = ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
    for i in 4:
        var sx: float = -1.0 if (i % 2) == 0 else 1.0
        var sz: float = -1.0 if i < 2 else 1.0
        var wn := Node3D.new()
        wn.name = names[i]
        wn.position = Vector3(sx * track * 0.5, 0.0, sz * wb * 0.5)
        var spin := Node3D.new()
        wn.add_child(spin)
        var t := MeshInstance3D.new()
        t.mesh = tire_m
        t.material_override = tire_mat
        t.rotation = Vector3(0.0, 0.0, PI * 0.5)
        spin.add_child(t)
        var rm := MeshInstance3D.new()
        rm.mesh = rim_m
        rm.material_override = rim_mat
        rm.rotation = Vector3(0.0, 0.0, PI * 0.5)
        spin.add_child(rm)
        root.add_child(wn)
        out["wheels"].append(wn)
        out["spins"].append(spin)

    # руль
    var steer := Node3D.new()
    var seat: Vector3 = d["seat"]
    steer.position = seat + Vector3(0.0, 0.42, -0.5)
    steer.rotation = Vector3(-0.9, 0.0, 0.0)
    var torus := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.13
    tm.outer_radius = 0.17
    tm.rings = 12
    tm.ring_segments = 6
    torus.mesh = tm
    torus.material_override = dark_mat
    steer.add_child(torus)
    root.add_child(steer)
    out["steer"] = steer

    # подхват своей модели из Blender (если есть)
    var path: String = "res://assets/vehicles/%s.glb" % id
    if ResourceLoader.exists(path):
        var res: Resource = load(path)
        if res is PackedScene:
            out = _from_glb(res as PackedScene, out)
    return out


static func _from_glb(ps: PackedScene, fallback: Dictionary) -> Dictionary:
    var inst: Node = ps.instantiate()
    var root := Node3D.new()
    root.name = "Model"
    root.add_child(inst)
    var wheels: Array = []
    var spins: Array = []
    for n in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
        var w: Node3D = inst.find_child(n, true, false) as Node3D
        if w == null:
            return fallback
        wheels.append(w)
        spins.append(w)
    var door: Node3D = inst.find_child("Door_L", true, false) as Node3D
    var seat_n: Node3D = inst.find_child("Seat", true, false) as Node3D
    var out: Dictionary = {"root": root, "wheels": wheels, "spins": spins, "door": door, "seat": fallback["seat"], "steer": null}
    if seat_n != null:
        out["seat"] = seat_n.position
    (fallback["root"] as Node3D).queue_free()
    return out
