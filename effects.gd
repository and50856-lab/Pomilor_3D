class_name Effects
extends RefCounted
# Визуальные эффекты: вспышка, искры, кровь, взрыв, дым, огонь, пулевые отверстия.

static var _spark_mesh: Mesh = null
static var _smoke_mesh: Mesh = null
static var _hole_tex: Texture2D = null
static var _soot_tex: Texture2D = null
static var _hole_mat: StandardMaterial3D = null


static func reset() -> void:
    pass


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
    flash(pos + Vector3(0, 1.2, 0), 7.0, 0.35, Color(1.0, 0.65, 0.25))


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


# Вспышка без источника света: светящийся шар быстро растёт и гаснет (свет в Mobile-рендерере даёт подвисания).
static func flash(pos: Vector3, size: float, dur: float, col: Color) -> void:
    if Game.world == null:
        return
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.5
    sm.height = 1.0
    sm.radial_segments = 8
    sm.rings = 4
    mi.mesh = sm
    var mt := StandardMaterial3D.new()
    mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mt.albedo_color = Color(col.r, col.g, col.b, 0.85)
    mi.material_override = mt
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    Game.world.add_child(mi)
    mi.global_position = pos
    mi.scale = Vector3.ONE * size * 0.3
    var tw: Tween = mi.create_tween()
    tw.set_parallel(true)
    tw.tween_property(mi, "scale", Vector3.ONE * size, dur)
    tw.tween_property(mt, "albedo_color:a", 0.0, dur)
    tw.chain().tween_callback(mi.queue_free)


static func surface_basis(normal: Vector3) -> Basis:
    var y: Vector3 = normal.normalized()
    var x: Vector3 = y.cross(Vector3.UP)
    if x.length() < 0.01:
        x = y.cross(Vector3.RIGHT)
    x = x.normalized()
    var z: Vector3 = x.cross(y)
    return Basis(x, y, z)


static func hole_texture() -> Texture2D:
    if _hole_tex == null:
        _hole_tex = _make_hole_tex()
    return _hole_tex


static func soot_texture() -> Texture2D:
    if _soot_tex == null:
        var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
        var n := FastNoiseLite.new()
        n.frequency = 0.08
        for y in 64:
            for x in 64:
                var d: float = Vector2(float(x) - 31.5, float(y) - 31.5).length() / 31.5
                var a: float = clampf(1.0 - d, 0.0, 1.0)
                a = a * a * (0.7 + 0.3 * n.get_noise_2d(float(x), float(y)))
                img.set_pixel(x, y, Color(0.04, 0.04, 0.04, clampf(a * 1.3, 0.0, 0.88)))
        _soot_tex = ImageTexture.create_from_image(img)
    return _soot_tex


static func hole_material() -> StandardMaterial3D:
    if _hole_mat == null:
        _hole_mat = StandardMaterial3D.new()
        _hole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _hole_mat.albedo_texture = hole_texture()
        _hole_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return _hole_mat


# След от пули / царапина: на машине крепится к ней, на мире — в общий пул.
static func bullet_hole(pos: Vector3, normal: Vector3, parent: Node) -> void:
    if parent != null and is_instance_valid(parent) and parent is Vehicle:
        (parent as Vehicle).add_hole(pos, normal)
        return
    if Game.holes != null:
        Game.holes.add(pos, normal, 0.14)


# Чёрная копоть после взрыва.
static func scorch(pos: Vector3, normal: Vector3, size: float) -> void:
    if Game.scorch_marks != null:
        Game.scorch_marks.add(pos, normal, size)


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
