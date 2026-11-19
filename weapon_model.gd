class_name WeaponModel
extends RefCounted
# Процедурные 3D-модели оружия. Перед = -Z, начало координат в рукоятке.
# Потом можно положить свою модель в res://assets/weapons/<id>.glb — она подхватится.

static var _mats: Dictionary = {}


static func mat(c: Color, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
    var k: String = "%s_%s_%s" % [c.to_html(), metal, rough]
    if _mats.has(k):
        return _mats[k]
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.metallic = metal
    m.roughness = rough
    _mats[k] = m
    return m


static func _box(p: Node3D, size: Vector3, pos: Vector3, c: Color, metal: float = 0.0, rough: float = 0.6, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat(c, metal, rough)
    mi.position = pos
    mi.rotation = rot
    p.add_child(mi)
    return mi


static func _cyl(p: Node3D, r_top: float, r_bot: float, length: float, pos: Vector3, c: Color, metal: float = 0.0, rough: float = 0.6) -> MeshInstance3D:
    # цилиндр вдоль оси Z (верх цилиндра смотрит в -Z)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r_top
    cm.bottom_radius = r_bot
    cm.height = length
    cm.radial_segments = 10
    cm.rings = 1
    mi.mesh = cm
    mi.material_override = mat(c, metal, rough)
    mi.position = pos
    mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    p.add_child(mi)
    return mi


static func _muzzle(p: Node3D, pos: Vector3) -> void:
    var m := Node3D.new()
    m.name = "Muzzle"
    m.position = pos
    p.add_child(m)


static func build(id: String) -> Node3D:
    var root := Node3D.new()
    root.name = "Model"
    var path: String = "res://assets/weapons/%s.glb" % id
    if ResourceLoader.exists(path):
        var res: Resource = load(path)
        if res is PackedScene:
            var inst: Node = (res as PackedScene).instantiate()
            root.add_child(inst)
            return root
    var steel := Color(0.16, 0.17, 0.19)
    var silver := Color(0.62, 0.64, 0.68)
    var wood := Color(0.42, 0.24, 0.11)
    var black := Color(0.06, 0.06, 0.07)
    match id:
        "deagle":
            _box(root, Vector3(0.036, 0.05, 0.26), Vector3(0, 0.03, -0.08), silver, 0.8, 0.35)
            _box(root, Vector3(0.03, 0.035, 0.06), Vector3(0, 0.025, -0.23), silver, 0.8, 0.35)
            _box(root, Vector3(0.034, 0.12, 0.055), Vector3(0, -0.055, 0.03), black, 0.1, 0.7, Vector3(0.22, 0, 0))
            _box(root, Vector3(0.02, 0.03, 0.07), Vector3(0, -0.015, -0.01), black)
            _muzzle(root, Vector3(0, 0.03, -0.27))
        "ak47":
            _box(root, Vector3(0.05, 0.07, 0.4), Vector3(0, 0.02, -0.05), steel, 0.5, 0.45)
            _cyl(root, 0.012, 0.012, 0.36, Vector3(0, 0.03, -0.44), steel, 0.7, 0.35)
            _box(root, Vector3(0.056, 0.05, 0.24), Vector3(0, 0.0, -0.3), wood, 0.0, 0.7)
            _box(root, Vector3(0.036, 0.16, 0.07), Vector3(0, -0.12, -0.1), steel, 0.4, 0.5, Vector3(0.35, 0, 0))
            _box(root, Vector3(0.036, 0.1, 0.05), Vector3(0, -0.08, 0.11), wood, 0.0, 0.7, Vector3(-0.3, 0, 0))
            _box(root, Vector3(0.042, 0.09, 0.24), Vector3(0, -0.01, 0.3), wood, 0.0, 0.7)
            _box(root, Vector3(0.012, 0.03, 0.012), Vector3(0, 0.07, -0.58), steel)
            _muzzle(root, Vector3(0, 0.03, -0.64))
        "mossberg":
            _cyl(root, 0.017, 0.017, 0.66, Vector3(0, 0.035, -0.36), steel, 0.7, 0.35)
            _cyl(root, 0.014, 0.014, 0.5, Vector3(0, 0.0, -0.3), steel, 0.7, 0.35)
            _box(root, Vector3(0.052, 0.046, 0.2), Vector3(0, -0.005, -0.3), wood, 0.0, 0.7)
            _box(root, Vector3(0.046, 0.075, 0.22), Vector3(0, 0.01, 0.0), steel, 0.5, 0.45)
            _box(root, Vector3(0.04, 0.1, 0.3), Vector3(0, -0.015, 0.28), wood, 0.0, 0.7, Vector3(-0.08, 0, 0))
            _muzzle(root, Vector3(0, 0.035, -0.7))
        "rpg":
            _cyl(root, 0.045, 0.045, 0.95, Vector3(0, 0.05, -0.1), Color(0.22, 0.26, 0.18), 0.3, 0.6)
            _cyl(root, 0.075, 0.045, 0.12, Vector3(0, 0.05, 0.42), steel, 0.4, 0.5)
            _cyl(root, 0.0, 0.075, 0.3, Vector3(0, 0.05, -0.72), Color(0.3, 0.3, 0.22), 0.3, 0.5)
            _box(root, Vector3(0.036, 0.13, 0.045), Vector3(0, -0.06, 0.0), black, 0.1, 0.7, Vector3(0.2, 0, 0))
            _box(root, Vector3(0.03, 0.06, 0.04), Vector3(0, 0.11, -0.2), steel)
            _muzzle(root, Vector3(0, 0.05, -0.9))
        "bat":
            _cyl(root, 0.042, 0.015, 0.86, Vector3(0, 0, -0.38), Color(0.72, 0.55, 0.3), 0.0, 0.65)
            _cyl(root, 0.02, 0.02, 0.2, Vector3(0, 0, -0.02), black, 0.0, 0.9)
            _muzzle(root, Vector3(0, 0, -0.8))
        _:
            _box(root, Vector3(0.05, 0.05, 0.3), Vector3(0, 0, -0.1), steel)
            _muzzle(root, Vector3(0, 0, -0.26))
    return root


static func set_shadow_mode(n: Node, mode: int) -> void:
    if n is GeometryInstance3D:
        (n as GeometryInstance3D).cast_shadow = mode
    for c in n.get_children():
        set_shadow_mode(c, mode)
