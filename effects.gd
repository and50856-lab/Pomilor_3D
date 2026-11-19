class_name Effects
extends RefCounted
# Визуальные эффекты: вспышка выстрела, искры, кровь, взрыв.

static var _spark_mesh: Mesh = null
static var _smoke_mesh: Mesh = null


static func _get_spark_mesh() -> Mesh:
    if _spark_mesh == null:
        var m := BoxMesh.new()
        m.size = Vector3(0.04, 0.04, 0.12)
        var mt := StandardMaterial3D.new()
        mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mt.vertex_color_use_as_albedo = true
        m.material = mt
        _spark_mesh = m
    return _spark_mesh


static func _get_smoke_mesh() -> Mesh:
    if _smoke_mesh == null:
        var m := SphereMesh.new()
        m.radius = 0.5
        m.height = 1.0
        m.radial_segments = 8
        m.rings = 4
        var mt := StandardMaterial3D.new()
        mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mt.vertex_color_use_as_albedo = true
        mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.material = mt
        _smoke_mesh = m
    return _smoke_mesh


static func _amount(base: int) -> int:
    return maxi(2, int(float(base) * Settings.particle_scale()))


static func _burst(pos: Vector3, dir: Vector3, mesh: Mesh, amount: int, life: float, vmin: float, vmax: float, spread: float, grav: float, col: Color, smin: float, smax: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.mesh = mesh
    p.one_shot = true
    p.explosiveness = 1.0
    p.amount = amount
    p.lifetime = life
    p.direction = dir
    p.spread = spread
    p.initial_velocity_min = vmin
    p.initial_velocity_max = vmax
    p.gravity = Vector3(0.0, -grav, 0.0)
    p.color = col
    p.scale_amount_min = smin
    p.scale_amount_max = smax
    p.finished.connect(p.queue_free)
    Game.world.add_child(p)
    p.global_position = pos
    p.emitting = true
    return p


static func sparks(pos: Vector3, normal: Vector3, col: Color = Color(1.0, 0.8, 0.4)) -> void:
    if Game.world == null:
        return
    _burst(pos, normal, _get_spark_mesh(), _amount(8), 0.35, 2.0, 6.0, 45.0, 9.0, col, 0.6, 1.2)


static func blood(pos: Vector3, normal: Vector3) -> void:
    if Game.world == null:
        return
    _burst(pos, normal, _get_spark_mesh(), _amount(6), 0.45, 1.0, 3.5, 55.0, 9.0, Color(0.55, 0.02, 0.02), 0.6, 1.0)


static func muzzle_flash(parent: Node3D, local_pos: Vector3 = Vector3.ZERO) -> void:
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.75, 0.4)
    l.light_energy = 4.0
    l.omni_range = 9.0
    l.shadow_enabled = false
    l.position = local_pos
    parent.add_child(l)
    var tw: Tween = l.create_tween()
    tw.tween_property(l, "light_energy", 0.0, 0.07)
    tw.tween_callback(l.queue_free)


static func explosion(pos: Vector3) -> void:
    if Game.world == null:
        return
    var fire: CPUParticles3D = _burst(pos + Vector3(0, 0.6, 0), Vector3.UP, _get_smoke_mesh(), _amount(40), 0.9, 3.0, 9.0, 80.0, -1.0, Color(1.0, 0.55, 0.15), 1.5, 3.5)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1.0, 0.8, 0.3, 1.0), Color(0.9, 0.25, 0.05, 0.8), Color(0.1, 0.1, 0.1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
    fire.color_ramp = g
    var smoke: CPUParticles3D = _burst(pos + Vector3(0, 1.0, 0), Vector3.UP, _get_smoke_mesh(), _amount(22), 2.6, 1.0, 4.0, 60.0, -0.6, Color(0.2, 0.2, 0.2), 2.0, 4.5)
    var g2 := Gradient.new()
    g2.colors = PackedColorArray([Color(0.25, 0.25, 0.25, 0.8), Color(0.15, 0.15, 0.15, 0.0)])
    g2.offsets = PackedFloat32Array([0.0, 1.0])
    smoke.color_ramp = g2
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.6, 0.25)
    l.light_energy = 12.0
    l.omni_range = 28.0
    Game.world.add_child(l)
    l.global_position = pos + Vector3(0, 1.5, 0)
    var tw: Tween = l.create_tween()
    tw.tween_property(l, "light_energy", 0.0, 0.5)
    tw.tween_callback(l.queue_free)
