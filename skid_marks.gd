class_name SkidMarks
extends Node3D
# Чёрные следы от шин на асфальте (кольцевой буфер в одном MultiMesh).

var cap: int = 0
var mm: MultiMesh = null
var ages: PackedFloat32Array = PackedFloat32Array()
var head: int = 0
var _t: float = 0.0


func _ready() -> void:
    cap = int(Settings.SKID_CAP[Settings.graphics])
    if cap <= 0:
        set_process(false)
        return
    mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    var pm := PlaneMesh.new()
    pm.size = Vector2(1.0, 1.0)
    mm.mesh = pm
    mm.instance_count = cap
    ages.resize(cap)
    for i in cap:
        _hide(i)
        ages[i] = 999.0
    mm.custom_aabb = AABB(Vector3(-400, -10, -400), Vector3(800, 20, 800))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mmi.material_override = mat
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)


func _hide(i: int) -> void:
    mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -100, 0)))
    mm.set_instance_color(i, Color(0, 0, 0, 0))


func add(from: Vector3, to: Vector3, width: float) -> void:
    if cap <= 0 or mm == null:
        return
    var d: Vector3 = to - from
    d.y = 0.0
    var ln: float = d.length()
    if ln < 0.05:
        return
    var dir: Vector3 = d / ln
    var mid: Vector3 = (from + to) * 0.5
    mid.y = maxf(from.y, to.y) + 0.015
    var right: Vector3 = Vector3(dir.z, 0.0, -dir.x)
    var b := Basis(right * width, Vector3.UP, dir * ln)
    mm.set_instance_transform(head, Transform3D(b, mid))
    mm.set_instance_color(head, Color(0.02, 0.02, 0.02, 0.6))
    ages[head] = 0.0
    head = (head + 1) % cap


func _process(delta: float) -> void:
    _t += delta
    if _t < 0.5:
        return
    var dt: float = _t
    _t = 0.0
    for i in cap:
        if ages[i] < 60.0:
            ages[i] += dt
            var a: float = ages[i]
            if a > 25.0:
                var k: float = clampf(1.0 - (a - 25.0) / 20.0, 0.0, 1.0)
                if k <= 0.0:
                    _hide(i)
                    ages[i] = 999.0
                else:
                    mm.set_instance_color(i, Color(0.02, 0.02, 0.02, 0.6 * k))
