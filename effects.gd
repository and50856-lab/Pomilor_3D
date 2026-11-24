class_name Effects
extends RefCounted
# Визуальные эффекты: вспышка, искры, кровь, взрыв, дым, огонь, пулевые отверстия.

static var _spark_mesh: Mesh = null
static var _smoke_mesh: Mesh = null
static var _hole_tex: Texture2D = null
static var _holes: Array = []
static var _hole_i: int = 0


static func reset() -> void:
    _holes.clear()
    _hole_i = 0


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


# Постоянный излучатель дыма (включается/выключается через emitting).
static func make_smoke(parent: Node3D, pos: Vector3, amount: int, life: float, col: Color, s0: float, s1: float, speed: float) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.mesh = _get_smoke_mesh()
    p.amount = maxi(amount, 2)
    p.lifetime = life
    p.explosiveness = 0.0
    p.direction = Vector3.UP
    p.spread = 22.0
    p.initial_velocity_min = speed * 0.6
    p.initial_velocity_max = speed
    p.gravity = Vector3(0.0, 0.5, 0.0)
    p.color = col
    p.scale_amount_min = s0
    p.scale_amount_max = s1
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 1.0])
    p.color_ramp = g
    p.emitting = false
    p.position = pos
    parent.add_child(p)
    return p


static func make_fire(parent: Node3D, pos: Vector3, amount: int) -> CPUParticles3D:
    var p: CPUParticles3D = make_smoke(parent, pos, amount, 0.7, Color(1.0, 0.55, 0.15), 0.45, 1.0, 2.2)
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1.0, 0.9, 0.4, 0.95), Color(0.95, 0.35, 0.05, 0.7), Color(0.1, 0.1, 0.1, 0.0)])
    g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
    p.color_ramp = g
    p.gravity = Vector3(0.0, 3.0, 0.0)
    return p


static func _make_hole_tex() -> Texture2D:
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    for y in 32:
        for x in 32:
            var d: float = Vector2(float(x) - 15.5, float(y) - 15.5).length() / 15.5
            var a: float = clampf(1.0 - d, 0.0, 1.0)
            var core: float = 1.0 if d < 0.4 else 0.5
            img.set_pixel(x, y, Color(0.03, 0.03, 0.03, clampf(a * 1.7, 0.0, 0.92) * core))
    return ImageTexture.create_from_image(img)


# След от пули. parent — объект, к которому крепим (машина), иначе мир.
static func bullet_hole(pos: Vector3, normal: Vector3, parent: Node) -> void:
    var cap: int = int(Settings.HOLE_CAP[Settings.graphics])
    if cap <= 0 or Game.world == null:
        return
    if _hole_tex == null:
        _hole_tex = _make_hole_tex()
    var d: Decal = null
    if _holes.size() < cap:
        d = Decal.new()
        d.texture_albedo = _hole_tex
        d.size = Vector3(0.16, 0.3, 0.16)
        _holes.append(d)
    else:
        var cur = _holes[_hole_i]
        if cur == null or not is_instance_valid(cur):
            d = Decal.new()
            d.texture_albedo = _hole_tex
            d.size = Vector3(0.16, 0.3, 0.16)
            _holes[_hole_i] = d
        else:
            d = cur
        _hole_i = (_hole_i + 1) % cap
    var par: Node = Game.world
    if parent != null and is_instance_valid(parent):
        par = parent
    if d.get_parent() != par:
        if d.get_parent() != null:
            d.get_parent().remove_child(d)
        par.add_child(d)
    var y: Vector3 = normal.normalized()
    var x: Vector3 = y.cross(Vector3.UP)
    if x.length() < 0.01:
        x = y.cross(Vector3.RIGHT)
    x = x.normalized()
    var z: Vector3 = x.cross(y)
    d.global_transform = Transform3D(Basis(x, y, z), pos + y * 0.02)


# Прогрев эффектов на экране загрузки (убирает подвисание при первом выстреле).
static func prewarm(pos: Vector3) -> void:
    if Game.world == null:
        return
    sparks(pos, Vector3.UP)
    blood(pos, Vector3.UP)
    explosion(pos)
    bullet_hole(pos, Vector3.UP, null)
    var e: CPUParticles3D = make_smoke(Game.world, pos, 6, 0.4, Color(0.5, 0.5, 0.5), 0.4, 0.8, 1.0)
    e.global_position = pos
    e.emitting = true
    var f: CPUParticles3D = make_fire(Game.world, pos, 6)
    f.global_position = pos
    f.emitting = true
    var t: SceneTreeTimer = Game.get_tree().create_timer(1.5)
    t.timeout.connect(e.queue_free)
    t.timeout.connect(f.queue_free)
