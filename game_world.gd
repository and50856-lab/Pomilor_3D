class_name GameWorld
extends Node3D
# Собирает город и игру по шагам (с прогрессом для экрана загрузки), управляет паузой и меню.

signal exit_requested

const GROUND_SHADER: String = """
shader_type spatial;
uniform sampler2D noise_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 color_a : source_color = vec3(0.1);
uniform vec3 color_b : source_color = vec3(0.2);
uniform float tile = 0.15;
uniform float rough = 0.9;
uniform float paving = 0.0;
varying vec3 wp;
void vertex() {
    wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float n1 = texture(noise_tex, wp.xz * tile).r;
    float n2 = texture(noise_tex, wp.xz * tile * 5.0).r;
    vec3 col = mix(color_a, color_b, clamp(n1 * 0.65 + n2 * 0.35, 0.0, 1.0));
    vec2 g = fract(wp.xz * 0.5);
    float line = max(1.0 - step(0.04, g.x), 1.0 - step(0.04, g.y)) * paving;
    col *= 1.0 - line * 0.35;
    ALBEDO = col;
    ROUGHNESS = rough;
    SPECULAR = 0.25;
}
"""

const BUILDING_SHADER: String = """
shader_type spatial;
uniform sampler2D noise_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 wall : source_color = vec3(0.6);
uniform vec3 glass : source_color = vec3(0.1, 0.15, 0.2);
uniform vec2 cell = vec2(3.2, 3.6);
uniform float base_y = 0.12;
varying vec3 wp;
varying vec3 wn;
void vertex() {
    wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    float side = step(abs(wn.y), 0.5);
    float u = abs(wn.x) > 0.5 ? wp.z : wp.x;
    vec2 g = vec2(u / cell.x, (wp.y - base_y) / cell.y);
    vec2 f = fract(g);
    float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.22, f.y) * step(f.y, 0.78);
    win *= step(3.6, wp.y - base_y) * side;
    float n = texture(noise_tex, wp.xz * 0.07 + vec2(wp.y * 0.05)).r;
    vec3 base = wall * (0.8 + 0.4 * n);
    float roof = step(0.5, wn.y);
    base = mix(base, wall * 0.55, roof);
    float refl = texture(noise_tex, g * 0.31).r;
    vec3 gl = glass * (0.7 + 0.8 * refl);
    ALBEDO = mix(base, gl, win);
    ROUGHNESS = mix(0.85, 0.1, win);
    METALLIC = win * 0.35;
}
"""

var env: Environment
var sun: DirectionalLight3D
var player: Player
var hud: Hud
var pause_menu: PauseMenu
var inv_menu: InventoryMenu
var traffic: TrafficManager
var npc_mgr: NPCManager

var _progress: Callable
var _static: StaticBody3D
var _noise_a: Texture2D
var _noise_b: Texture2D
var _asphalt: ShaderMaterial
var _sidewalk: ShaderMaterial
var _grass: ShaderMaterial
var _bld_mats: Array = []
var _white: StandardMaterial3D
var _lamp_mats: Array = []
var _lamp_cols: Array = [Color(0.1, 0.95, 0.3), Color(1.0, 0.8, 0.1), Color(1.0, 0.1, 0.1)]
var _last_light: Array = [-1, -1]
var _tree_pts: Array = []
var _rng := RandomNumberGenerator.new()
var _paused: bool = false


func _p(v: float, text: String) -> void:
    if _progress.is_valid():
        _progress.call(v, text)


func build(cb: Callable) -> void:
    _progress = cb
    Game.reset()
    Game.world = self
    Effects.reset()
    Game.skids = SkidMarks.new()
    add_child(Game.skids)
    Game.holes = MarkQuads.new()
    add_child(Game.holes)
    Game.holes.setup(int(Settings.HOLE_CAP[Settings.graphics]), Effects.hole_texture())
    Game.scorch_marks = MarkQuads.new()
    add_child(Game.scorch_marks)
    Game.scorch_marks.setup([4, 8, 16, 30, 60][Settings.graphics], Effects.soot_texture())
    _rng.seed = 20260
    _p(0.0, "Звуки")
    while not Sfx.generate_next():
        _p(0.18 * Sfx.progress(), "Генерация звуков")
        await get_tree().process_frame
    _p(0.18, "Текстуры")
    await get_tree().process_frame
    _make_materials()
    _p(0.24, "Небо и свет")
    await get_tree().process_frame
    _make_environment()
    _p(0.28, "Земля")
    await get_tree().process_frame
    _make_ground()
    _p(0.32, "Кварталы и здания")
    await _make_blocks()
    _p(0.55, "Дороги и разметка")
    await get_tree().process_frame
    _make_markings()
    _p(0.62, "Светофоры и фонари")
    await get_tree().process_frame
    _make_furniture()
    _p(0.70, "Деревья")
    await get_tree().process_frame
    _make_trees()
    _p(0.74, "Игрок")
    await get_tree().process_frame
    _make_player()
    _p(0.78, "Тротуары")
    Game.ped_net = PedNet.new()
    Game.ped_net.build()
    await get_tree().process_frame
    await _spawn_people()
    await _spawn_traffic()
    _p(0.95, "Эффекты")
    Effects.prewarm(player.global_position + Vector3(0.0, 1.5, -3.0))
    await get_tree().process_frame
    await get_tree().process_frame
    _p(0.97, "Интерфейс")
    _make_ui()
    _p(1.0, "Готово")
    await get_tree().process_frame


func start() -> void:
    Game.running = true
    Settings.apply_all()
    Game.say("Нажми «ВЕЩИ» (вверху справа): там оружие и машины")


# ---------- материалы ----------

func _make_noise(freq: float, seed_: int, sz: int) -> ImageTexture:
    var n := FastNoiseLite.new()
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    n.frequency = freq
    n.seed = seed_
    n.fractal_octaves = 4
    var img: Image = n.get_seamless_image(sz, sz, false, false, 0.1, true)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


func _ground_mat(ca: Color, cb: Color, tile: float, rough: float, paving: float) -> ShaderMaterial:
    var sh := Shader.new()
    sh.code = GROUND_SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    m.set_shader_parameter("noise_tex", _noise_a)
    m.set_shader_parameter("color_a", ca)
    m.set_shader_parameter("color_b", cb)
    m.set_shader_parameter("tile", tile)
    m.set_shader_parameter("rough", rough)
    m.set_shader_parameter("paving", paving)
    return m


func _make_materials() -> void:
    var sz: int = int(Settings.TEX_SIZE[Settings.graphics])
    _noise_a = _make_noise(0.045, 11, sz)
    _noise_b = _make_noise(0.03, 23, sz)
    _asphalt = _ground_mat(Color(0.09, 0.09, 0.1), Color(0.19, 0.19, 0.2), 0.11, 0.92, 0.0)
    _sidewalk = _ground_mat(Color(0.52, 0.52, 0.5), Color(0.68, 0.67, 0.64), 0.09, 0.88, 1.0)
    _grass = _ground_mat(Color(0.14, 0.3, 0.1), Color(0.26, 0.45, 0.16), 0.06, 0.95, 0.0)
    var walls: Array = [
        Color(0.72, 0.68, 0.62), Color(0.55, 0.57, 0.6), Color(0.62, 0.4, 0.33),
        Color(0.8, 0.8, 0.76), Color(0.45, 0.5, 0.56), Color(0.68, 0.6, 0.45),
    ]
    for wc in walls:
        var sh := Shader.new()
        sh.code = BUILDING_SHADER
        var m := ShaderMaterial.new()
        m.shader = sh
        m.set_shader_parameter("noise_tex", _noise_b)
        m.set_shader_parameter("wall", wc)
        m.set_shader_parameter("glass", Color(0.1, 0.15, 0.2))
        m.set_shader_parameter("base_y", Const.CURB)
        _bld_mats.append(m)
    _white = StandardMaterial3D.new()
    _white.albedo_color = Color(0.93, 0.93, 0.9)
    _white.roughness = 0.8
    for a in 2:
        var arr: Array = []
        for c in 3:
            var lm := StandardMaterial3D.new()
            lm.albedo_color = (_lamp_cols[c] as Color).darkened(0.85)
            lm.emission_enabled = true
            lm.emission = _lamp_cols[c]
            lm.emission_energy_multiplier = 0.0
            arr.append(lm)
        _lamp_mats.append(arr)


func _make_environment() -> void:
    env = Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var low := ProceduralSkyMaterial.new()
    low.sky_top_color = Color(0.25, 0.46, 0.78)
    low.sky_horizon_color = Color(0.66, 0.78, 0.9)
    low.ground_horizon_color = Color(0.66, 0.78, 0.9)
    low.ground_bottom_color = Color(0.3, 0.32, 0.34)
    low.sun_angle_max = 25.0
    var high := PhysicalSkyMaterial.new()
    high.rayleigh_coefficient = 2.0
    high.mie_coefficient = 0.005
    high.turbidity = 8.0
    high.ground_color = Color(0.3, 0.32, 0.34)
    high.energy_multiplier = 1.0
    sky.sky_material = low
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 1.0
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)
    Settings.bind_world(env, sun, sky, low, high)


# ---------- земля, кварталы ----------

var _cyl_shapes: Dictionary = {}


# Круглый коллайдер (столб, ствол дерева): теперь о них можно удариться.
func _cyl_collider(radius: float, height: float, pos: Vector3) -> void:
    var key: String = "%s_%s" % [radius, height]
    var sh: CylinderShape3D = null
    if _cyl_shapes.has(key):
        sh = _cyl_shapes[key]
    else:
        sh = CylinderShape3D.new()
        sh.radius = radius
        sh.height = height
        _cyl_shapes[key] = sh
    var cs := CollisionShape3D.new()
    cs.shape = sh
    cs.position = pos
    _static.add_child(cs)


func _add_box_collider(size: Vector3, pos: Vector3) -> void:
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    cs.position = pos
    _static.add_child(cs)


func _make_ground() -> void:
    _static = StaticBody3D.new()
    _static.collision_layer = Const.L_WORLD
    _static.collision_mask = 0
    add_child(_static)
    var half: float = Const.half_size() + 12.0
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(half * 2.0, 0.2, half * 2.0)
    mi.mesh = bm
    mi.material_override = _asphalt
    mi.position = Vector3(0, -0.1, 0)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    var gr := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(3000.0, 3000.0)
    gr.mesh = pm
    gr.material_override = _grass
    gr.position = Vector3(0, -0.04, 0)
    gr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(gr)
    _add_box_collider(Vector3(3000.0, 4.0, 3000.0), Vector3(0, -2.0, 0))
    var w: float = half + 70.0
    _add_box_collider(Vector3(2.0, 60.0, w * 2.0), Vector3(w, 30.0, 0))
    _add_box_collider(Vector3(2.0, 60.0, w * 2.0), Vector3(-w, 30.0, 0))
    _add_box_collider(Vector3(w * 2.0, 60.0, 2.0), Vector3(0, 30.0, w))
    _add_box_collider(Vector3(w * 2.0, 60.0, 2.0), Vector3(0, 30.0, -w))


func _add_building(cx: float, cz: float, w: float, d: float, h: float, mat: Material) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(w, h, d)
    mi.mesh = bm
    mi.material_override = mat
    mi.position = Vector3(cx, Const.CURB + h * 0.5, cz)
    mi.visibility_range_end = Settings.view_far()
    mi.add_to_group("vis_range")
    add_child(mi)
    _add_box_collider(Vector3(w, h, d), mi.position)


func _make_blocks() -> void:
    var blk: float = Const.PITCH - Const.ROAD_W
    var count: int = 0
    var slab_mesh := BoxMesh.new()
    slab_mesh.size = Vector3(blk, Const.CURB, blk)
    var slab_st := SurfaceTool.new()
    slab_st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for bj in range(Const.N - 1):
        for bk in range(Const.N - 1):
            var a: Vector3 = Const.node_pos(bj, bk)
            var b: Vector3 = Const.node_pos(bj + 1, bk + 1)
            var c: Vector3 = (a + b) * 0.5
            var slab_pos: Vector3 = Vector3(c.x, Const.CURB * 0.5, c.z)
            slab_st.append_from(slab_mesh, 0, Transform3D(Basis.IDENTITY, slab_pos))
            _add_box_collider(Vector3(blk, Const.CURB, blk), slab_pos)
            var kind: int = _rng.randi() % 4
            if bj == 3 and bk == 3:
                kind = 3
            _fill_block(c, kind)
            count += 1
            if count % 4 == 0:
                await get_tree().process_frame
    var all_slabs := MeshInstance3D.new()
    all_slabs.mesh = slab_st.commit()
    all_slabs.material_override = _sidewalk
    all_slabs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(all_slabs)


func _bmat() -> Material:
    return _bld_mats[_rng.randi() % _bld_mats.size()]


func _fill_block(c: Vector3, kind: int) -> void:
    match kind:
        0:
            var w: float = _rng.randf_range(52.0, 60.0)
            var d: float = _rng.randf_range(52.0, 60.0)
            _add_building(c.x, c.z, w, d, _rng.randf_range(22.0, 58.0), _bmat())
        1:
            var split_x: bool = _rng.randf() < 0.5
            for s in [-1.0, 1.0]:
                var h: float = _rng.randf_range(14.0, 46.0)
                if split_x:
                    _add_building(c.x + s * 15.5, c.z, 28.0, _rng.randf_range(52.0, 58.0), h, _bmat())
                else:
                    _add_building(c.x, c.z + s * 15.5, _rng.randf_range(52.0, 58.0), 28.0, h, _bmat())
        2:
            for sx in [-1.0, 1.0]:
                for sz in [-1.0, 1.0]:
                    _add_building(c.x + sx * 15.5, c.z + sz * 15.5, _rng.randf_range(24.0, 28.0), _rng.randf_range(24.0, 28.0), _rng.randf_range(10.0, 40.0), _bmat())
        _:
            var park := MeshInstance3D.new()
            var pm := BoxMesh.new()
            pm.size = Vector3(66.0, 0.03, 66.0)
            park.mesh = pm
            park.material_override = _grass
            park.position = Vector3(c.x, Const.CURB + 0.015, c.z)
            park.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(park)
            var n: int = 8 + Settings.graphics * 3
            for i in n:
                _tree_pts.append(Vector3(c.x + _rng.randf_range(-28.0, 28.0), Const.CURB, c.z + _rng.randf_range(-28.0, 28.0)))


# ---------- разметка ----------

func _mm(mesh: Mesh, mat: Material, xfs: Array, cols: Array = [], shadow: bool = false) -> MultiMeshInstance3D:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var use_cols: bool = (not cols.is_empty()) and cols.size() == xfs.size()
    mm.use_colors = use_cols
    mm.mesh = mesh
    mm.instance_count = xfs.size()
    for i in xfs.size():
        mm.set_instance_transform(i, xfs[i])
        if use_cols:
            mm.set_instance_color(i, cols[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    if not shadow:
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)
    return mmi


func _make_markings() -> void:
    var xfs: Array = []
    for j in Const.N:
        for k in Const.N:
            var c: Vector3 = Const.node_pos(j, k)
            for axis in 2:
                for s in [-1, 1]:
                    var nj: int = j + (s if axis == 0 else 0)
                    var nk: int = k + (s if axis == 1 else 0)
                    if not Const.node_ok(nj, nk):
                        continue
                    var along_c: float = c.x if axis == 0 else c.z
                    var lat_c: float = c.z if axis == 0 else c.x
                    var along: float = along_c + float(s) * Const.SIDE_C
                    for i in 10:
                        var lat: float = lat_c - 4.5 + float(i)
                        var size: Vector3 = Vector3(3.0, 0.02, 0.5) if axis == 0 else Vector3(0.5, 0.02, 3.0)
                        var p: Vector3 = Const.world_pt(axis, along, lat)
                        xfs.append(Transform3D(Basis.from_scale(size), Vector3(p.x, 0.012, p.z)))
                    var lane_c: float = lat_c + Const.lane_lat(axis, -s)
                    var sl: Vector3 = Const.world_pt(axis, along_c + float(s) * Const.STOP_D, lane_c)
                    var ssize: Vector3 = Vector3(0.35, 0.02, 4.4) if axis == 0 else Vector3(4.4, 0.02, 0.35)
                    xfs.append(Transform3D(Basis.from_scale(ssize), Vector3(sl.x, 0.012, sl.z)))
    for j in Const.N:
        for k in Const.N:
            var c2: Vector3 = Const.node_pos(j, k)
            for axis in 2:
                var nj2: int = j + (1 if axis == 0 else 0)
                var nk2: int = k + (1 if axis == 1 else 0)
                if not Const.node_ok(nj2, nk2):
                    continue
                var a0: float = (c2.x if axis == 0 else c2.z) + 14.0
                var a1: float = (c2.x if axis == 0 else c2.z) + Const.PITCH - 14.0
                var lat2: float = c2.z if axis == 0 else c2.x
                var t: float = a0
                while t < a1 - 3.0:
                    var dp: Vector3 = Const.world_pt(axis, t + 1.5, lat2)
                    var dsize: Vector3 = Vector3(3.0, 0.02, 0.18) if axis == 0 else Vector3(0.18, 0.02, 3.0)
                    xfs.append(Transform3D(Basis.from_scale(dsize), Vector3(dp.x, 0.012, dp.z)))
                    t += 8.0
    var plane := PlaneMesh.new()
    plane.size = Vector2(1.0, 1.0)
    _mm(plane, _white, xfs)


# ---------- светофоры, фонари, деревья ----------

func _make_furniture() -> void:
    var poles: Array = []
    var heads: Array = []
    var housings: Array = []
    var lamps: Array = [[[], [], []], [[], [], []]]
    for j in Const.N:
        for k in Const.N:
            var c: Vector3 = Const.node_pos(j, k)
            for sx in [-1, 1]:
                for sz in [-1, 1]:
                    if not Const.node_ok(j + sx, k + sz):
                        continue
                    var pp: Vector3 = c + Vector3(float(sx) * 5.9, 0.0, float(sz) * 5.9)
                    poles.append(Transform3D(Basis.IDENTITY, Vector3(pp.x, Const.CURB + 2.3, pp.z)))
                    _cyl_collider(0.12, 4.6, Vector3(pp.x, Const.CURB + 2.3, pp.z))
                    for axis in 2:
                        var face: Vector3 = Vector3(float(sx), 0.0, 0.0) if axis == 0 else Vector3(0.0, 0.0, float(sz))
                        var leg_ok: bool = Const.node_ok(j + sx, k) if axis == 0 else Const.node_ok(j, k + sz)
                        if not leg_ok:
                            continue
                        var hc: Vector3 = Vector3(pp.x, Const.CURB + 3.4, pp.z) + face * 0.28
                        housings.append(Transform3D(Basis.IDENTITY, hc))
                        for col in 3:
                            var yo: float = 0.32 if col == 2 else (0.0 if col == 1 else -0.32)
                            lamps[axis][col].append(Transform3D(Basis.IDENTITY, hc + face * 0.16 + Vector3(0, yo, 0)))
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.07
    pole_mesh.bottom_radius = 0.09
    pole_mesh.height = 4.6
    pole_mesh.radial_segments = 8
    pole_mesh.rings = 1
    var dark: StandardMaterial3D = WeaponModel.mat(Color(0.08, 0.08, 0.09), 0.5, 0.6)
    var prop_shadow: bool = Settings.shadows >= 3
    _mm(pole_mesh, dark, poles, [], prop_shadow)
    var hm := BoxMesh.new()
    hm.size = Vector3(0.3, 1.1, 0.3)
    _mm(hm, dark, housings, [], prop_shadow)
    var lm := SphereMesh.new()
    lm.radius = 0.11
    lm.height = 0.22
    lm.radial_segments = int(Settings.LAMP_SEG[Settings.graphics])
    lm.rings = maxi(2, int(Settings.LAMP_SEG[Settings.graphics]) / 2)
    for a in 2:
        for col in 3:
            _mm(lm, _lamp_mats[a][col], lamps[a][col], [], prop_shadow)
    # уличные фонари
    var lpoles: Array = []
    var lheads: Array = []
    for j in Const.N:
        for k in Const.N:
            var c2: Vector3 = Const.node_pos(j, k)
            for axis in 2:
                var nj: int = j + (1 if axis == 0 else 0)
                var nk: int = k + (1 if axis == 1 else 0)
                if not Const.node_ok(nj, nk):
                    continue
                var mid: float = (c2.x if axis == 0 else c2.z) + Const.PITCH * 0.5
                var lat_c: float = c2.z if axis == 0 else c2.x
                for side in [-1.0, 1.0]:
                    var lp: Vector3 = Const.world_pt(axis, mid, lat_c + side * 5.7)
                    lpoles.append(Transform3D(Basis.IDENTITY, Vector3(lp.x, Const.CURB + 3.5, lp.z)))
                    _cyl_collider(0.12, 7.0, Vector3(lp.x, Const.CURB + 3.5, lp.z))
                    var hp: Vector3 = Const.world_pt(axis, mid, lat_c + side * 5.0)
                    lheads.append(Transform3D(Basis.IDENTITY, Vector3(hp.x, Const.CURB + 7.05, hp.z)))
    var lpm := CylinderMesh.new()
    lpm.top_radius = 0.06
    lpm.bottom_radius = 0.09
    lpm.height = 7.0
    lpm.radial_segments = 8
    lpm.rings = 1
    _mm(lpm, dark, lpoles, [], prop_shadow)
    var lhm := BoxMesh.new()
    lhm.size = Vector3(0.9, 0.12, 0.3)
    var glow := StandardMaterial3D.new()
    glow.albedo_color = Color(0.9, 0.9, 0.8)
    glow.emission_enabled = true
    glow.emission = Color(1.0, 0.95, 0.8)
    glow.emission_energy_multiplier = 0.4
    _mm(lhm, glow, lheads, [], prop_shadow)


func _make_trees() -> void:
    var spacing: float = [28.0, 21.0, 18.0, 14.0, 12.0][Settings.graphics]
    for j in Const.N:
        for k in Const.N:
            var c: Vector3 = Const.node_pos(j, k)
            for axis in 2:
                var nj: int = j + (1 if axis == 0 else 0)
                var nk: int = k + (1 if axis == 1 else 0)
                if not Const.node_ok(nj, nk):
                    continue
                var a0: float = (c.x if axis == 0 else c.z) + 16.0
                var a1: float = (c.x if axis == 0 else c.z) + Const.PITCH - 16.0
                var lat_c: float = c.z if axis == 0 else c.x
                for side in [-1.0, 1.0]:
                    var t: float = a0 + 3.0
                    while t < a1:
                        if absf(t - ((c.x if axis == 0 else c.z) + Const.PITCH * 0.5)) > 4.0:
                            var p: Vector3 = Const.world_pt(axis, t, lat_c + side * 8.2)
                            _tree_pts.append(Vector3(p.x, Const.CURB, p.z))
                        t += spacing
    var trunks: Array = []
    var crowns: Array = []
    var cols: Array = []
    for tp in _tree_pts:
        var p3: Vector3 = tp
        _cyl_collider(0.22, 3.0, p3 + Vector3(0, 1.5, 0))
        var sc: float = _rng.randf_range(0.85, 1.35)
        trunks.append(Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), p3 + Vector3(0, 1.3 * sc, 0)))
        crowns.append(Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), p3 + Vector3(0, 3.7 * sc, 0)))
        cols.append(Color.from_hsv(_rng.randf_range(0.22, 0.34), _rng.randf_range(0.5, 0.8), _rng.randf_range(0.35, 0.6)))
    var tm := CylinderMesh.new()
    tm.top_radius = 0.12
    tm.bottom_radius = 0.18
    tm.height = 2.6
    tm.radial_segments = int([5, 6, 8, 10, 12][Settings.graphics])
    tm.rings = 1
    _mm(tm, WeaponModel.mat(Color(0.3, 0.2, 0.12), 0.0, 0.9), trunks, [], Settings.shadows >= 3)
    var cm := SphereMesh.new()
    cm.radius = 1.7
    cm.height = 3.2
    cm.radial_segments = int(Settings.LAMP_SEG[Settings.graphics])
    cm.rings = maxi(2, int(Settings.LAMP_SEG[Settings.graphics]) / 2)
    var cmat := StandardMaterial3D.new()
    cmat.vertex_color_use_as_albedo = true
    cmat.roughness = 0.9
    _mm(cm, cmat, crowns, cols, Settings.shadows >= 3)


# ---------- игрок, люди, транспорт, интерфейс ----------

func _make_player() -> void:
    player = Player.new()
    add_child(player)
    var sp: Vector3 = Const.node_pos(3, 3) + Vector3(7.0, 0.4, 7.0)
    player.spawn_pos = sp
    player.global_position = sp
    Game.player = player


func _spawn_people() -> void:
    npc_mgr = NPCManager.new()
    add_child(npc_mgr)
    Game.npc_mgr = npc_mgr
    npc_mgr.target = Settings.npc_count()
    var n: int = npc_mgr.target
    for i in n:
        npc_mgr.spawn_one(false)
        if i % 3 == 0:
            _p(0.78 + 0.08 * float(i) / float(maxi(n, 1)), "Жители города")
            await get_tree().process_frame


func _spawn_traffic() -> void:
    traffic = TrafficManager.new()
    add_child(traffic)
    Game.traffic = traffic
    traffic.target_count = Settings.traffic_count()
    var n: int = traffic.target_count
    for i in n:
        traffic.spawn_one(false)
        if i % 2 == 0:
            _p(0.86 + 0.1 * float(i) / float(maxi(n, 1)), "Транспорт")
            await get_tree().process_frame


func _make_ui() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 10
    add_child(layer)
    hud = Hud.new()
    layer.add_child(hud)
    Game.hud = hud
    hud.open_pause.connect(_open_pause)
    hud.open_items.connect(_open_items)
    var mlayer := CanvasLayer.new()
    mlayer.layer = 20
    add_child(mlayer)
    pause_menu = PauseMenu.new()
    pause_menu.visible = false
    pause_menu.resume_pressed.connect(_resume)
    pause_menu.exit_pressed.connect(_exit)
    mlayer.add_child(pause_menu)
    inv_menu = InventoryMenu.new()
    inv_menu.visible = false
    inv_menu.closed.connect(_resume)
    mlayer.add_child(inv_menu)
    Ctl.action.connect(_on_action)


func _on_action(a: String) -> void:
    if a == "pause":
        if _paused:
            _resume()
        else:
            _open_pause()
    elif a == "items" and not _paused:
        _open_items()


func _open_pause() -> void:
    if _paused:
        return
    _paused = true
    hud.close_wheel()
    get_tree().paused = true
    pause_menu.reset_view()
    pause_menu.visible = true


func _open_items() -> void:
    if _paused:
        return
    _paused = true
    hud.close_wheel()
    get_tree().paused = true
    inv_menu.open()
    inv_menu.visible = true


func _resume() -> void:
    _paused = false
    pause_menu.visible = false
    inv_menu.visible = false
    get_tree().paused = false
    Settings.save_settings()


func _exit() -> void:
    _paused = false
    get_tree().paused = false
    Settings.save_settings()
    exit_requested.emit()


func _process(_delta: float) -> void:
    if _lamp_mats.is_empty():
        return
    for a in 2:
        var st: int = Game.light_state(a)
        if st != _last_light[a]:
            _last_light[a] = st
            for c in 3:
                var m: StandardMaterial3D = _lamp_mats[a][c]
                var on: bool = c == st
                m.emission_energy_multiplier = 3.0 if on else 0.0
                var base: Color = _lamp_cols[c]
                m.albedo_color = base if on else base.darkened(0.85)
