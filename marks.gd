class_name MarkQuads
extends Node3D
# Следы на поверхностях (пулевые отверстия, копоть): плоские квадраты в одном MultiMesh.
# Без Decal и без света — это не вызывает подвисаний на мобильных GPU.

var cap: int = 0
var mm: MultiMesh = null
var head: int = 0


func setup(capacity: int, tex: Texture2D) -> void:
    cap = capacity
    if cap <= 0:
        return
    mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    var pm := PlaneMesh.new()
    pm.size = Vector2(1.0, 1.0)
    mm.mesh = pm
    mm.instance_count = cap
    for i in cap:
        mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -100, 0)))
        mm.set_instance_color(i, Color(1, 1, 1, 1))
    mm.custom_aabb = AABB(Vector3(-400, -10, -400), Vector3(800, 60, 800))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_texture = tex
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mmi.material_override = mat
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)


func add(pos: Vector3, normal: Vector3, size: float) -> void:
    if cap <= 0 or mm == null:
        return
    var b: Basis = Effects.surface_basis(normal)
    var xf := Transform3D(Basis(b.x * size, b.y, b.z * size), pos + normal.normalized() * 0.02)
    mm.set_instance_transform(head, xf)
    head = (head + 1) % cap
