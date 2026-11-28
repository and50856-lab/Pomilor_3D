class_name Humanoid
extends Node3D
# Процедурный человечек с суставами. Лицо смотрит в -Z. Начало координат — ступни.
# Позже можно заменить модель на свою (из Blender), сохранив те же методы управления.

const HIP_Y: float = 0.92

var skin: Color = Color(0.85, 0.65, 0.5)
var shirt: Color = Color(0.2, 0.3, 0.6)
var pants: Color = Color(0.15, 0.15, 0.2)
var hair: Color = Color(0.1, 0.07, 0.05)
var owner_char = null
var with_hitboxes: bool = false

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var shin_l: Node3D
var shin_r: Node3D
var hand_r: Node3D
var weapon_node: Node3D = null
var weapon_id: String = ""
var meshes: Array = []
var active: bool = true
var lod_mi: MeshInstance3D = null
var walk_sign: float = 1.0
var _lod_t: float = 0.0

# входы анимации (выставляет владелец)
var speed: float = 0.0
var run_amt: float = 0.0
var aim: int = 0
var sitting: bool = false:
    set(v):
        sitting = v
        if lod_mi != null:
            lod_mi.visible = not v
var wounded: String = ""
var dead: bool = false
var honk_t: float = 0.0
var pitch_aim: float = 0.0
var hands_up: bool = false
var ads: bool = false

var _cycle: float = 0.0
var _time: float = 0.0
var _act: String = ""
var _act_t: float = 0.0
var _act_dur: float = 1.0


func build() -> void:
    hips = Node3D.new()
    hips.position = Vector3(0.0, HIP_Y, 0.0)
    add_child(hips)
    torso = Node3D.new()
    hips.add_child(torso)
    _box(torso, Vector3(0.40, 0.58, 0.22), Vector3(0, 0.30, 0), shirt)
    _box(torso, Vector3(0.36, 0.14, 0.21), Vector3(0, 0.0, 0), pants)
    head = Node3D.new()
    head.position = Vector3(0, 0.68, 0)
    torso.add_child(head)
    _sphere(head, 0.115, Vector3(0, 0.12, 0), skin)
    _box(head, Vector3(0.23, 0.07, 0.24), Vector3(0, 0.2, 0.01), hair, _fl())
    _box(head, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.1, -0.11), skin.darkened(0.1), _fs())
    var al: Array = _make_arm(-0.26, shirt)
    arm_l = al[0]
    fore_l = al[1]
    var ar: Array = _make_arm(0.26, shirt)
    arm_r = ar[0]
    fore_r = ar[1]
    hand_r = ar[2]
    var ll: Array = _make_leg(-0.10)
    leg_l = ll[0]
    shin_l = ll[1]
    var lr: Array = _make_leg(0.10)
    leg_r = lr[0]
    shin_r = lr[1]
    build_lod()


func _fl() -> float:
    return float(Settings.LOD_LIMBS[Settings.graphics])


func _fs() -> float:
    return float(Settings.LOD_SMALL[Settings.graphics])


func _rig_xform(n: Node3D) -> Transform3D:
    var t: Transform3D = n.transform
    var p: Node = n.get_parent()
    while p != null and p != self:
        t = (p as Node3D).transform * t
        p = p.get_parent()
    return t


# Все части человека склеиваются в один меш (в позе «стоя»). Вдали рисуется он, вблизи — отдельные части.
func build_lod() -> void:
    var verts := PackedVector3Array()
    var norms := PackedVector3Array()
    var cols := PackedColorArray()
    var idx := PackedInt32Array()
    for m in meshes:
        var mi: MeshInstance3D = m
        var arr: Array = mi.mesh.surface_get_arrays(0)
        var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
        var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
        var xf: Transform3D = _rig_xform(mi)
        var col: Color = (mi.material_override as StandardMaterial3D).albedo_color
        var base: int = verts.size()
        for i in v.size():
            verts.append(xf * v[i])
            norms.append((xf.basis * nr[i]).normalized())
            cols.append(col)
        var ix: Variant = arr[Mesh.ARRAY_INDEX]
        if ix is PackedInt32Array and (ix as PackedInt32Array).size() > 0:
            for i in (ix as PackedInt32Array):
                idx.append(i + base)
        else:
            for i in v.size():
                idx.append(base + i)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_COLOR] = cols
    arrays[Mesh.ARRAY_INDEX] = idx
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    lod_mi = MeshInstance3D.new()
    lod_mi.mesh = am
    var mt := StandardMaterial3D.new()
    mt.vertex_color_use_as_albedo = true
    mt.roughness = 0.85
    lod_mi.material_override = mt
    var near: float = float(Settings.LOD_LIMBS[Settings.graphics])
    lod_mi.visibility_range_begin = near
    lod_mi.visibility_range_end = float(Settings.LOD_PEOPLE[Settings.graphics])
    if Settings.shadows < 2:
        lod_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(lod_mi)
    for m in meshes:
        (m as MeshInstance3D).visibility_range_end = near


func disable_lod() -> void:
    if lod_mi != null:
        lod_mi.visible = false
    for m in meshes:
        (m as MeshInstance3D).visibility_range_end = float(Settings.LOD_PEOPLE[Settings.graphics])


func _reg(mi: MeshInstance3D, far: float = 0.0) -> void:
    mi.visibility_range_end = far if far > 0.0 else float(Settings.LOD_PEOPLE[Settings.graphics])
    if Settings.shadows < 2:
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    meshes.append(mi)


func _box(p: Node3D, size: Vector3, pos: Vector3, c: Color, far: float = 0.0) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = WeaponModel.mat(c, 0.0, 0.8)
    mi.position = pos
    p.add_child(mi)
    _reg(mi, far)


func _sphere(p: Node3D, r: float, pos: Vector3, c: Color, far: float = 0.0) -> void:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = int(Settings.SEG_RADIAL[Settings.graphics]) + 2
    sm.rings = int(Settings.SEG_RINGS[Settings.graphics]) + 2
    mi.mesh = sm
    mi.material_override = WeaponModel.mat(c, 0.0, 0.8)
    mi.position = pos
    p.add_child(mi)
    _reg(mi, far)


func _capsule(p: Node3D, r: float, h: float, pos: Vector3, c: Color, far: float = 0.0) -> void:
    var mi := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = r
    cm.height = h
    cm.radial_segments = int(Settings.SEG_RADIAL[Settings.graphics])
    cm.rings = int(Settings.SEG_RINGS[Settings.graphics])
    mi.mesh = cm
    mi.material_override = WeaponModel.mat(c, 0.0, 0.8)
    mi.position = pos
    p.add_child(mi)
    _reg(mi, far)


func _make_arm(x: float, sleeve: Color) -> Array:
    var up := Node3D.new()
    up.position = Vector3(x, 0.52, 0)
    torso.add_child(up)
    _capsule(up, 0.055, 0.32, Vector3(0, -0.15, 0), sleeve, _fl())
    var fore := Node3D.new()
    fore.position = Vector3(0, -0.30, 0)
    up.add_child(fore)
    _capsule(fore, 0.048, 0.30, Vector3(0, -0.14, 0), skin, _fl())
    var hand := Node3D.new()
    hand.position = Vector3(0, -0.29, 0)
    fore.add_child(hand)
    _sphere(hand, 0.05, Vector3.ZERO, skin, _fs())
    return [up, fore, hand]


func _make_leg(x: float) -> Array:
    var th := Node3D.new()
    th.position = Vector3(x, 0, 0)
    hips.add_child(th)
    _capsule(th, 0.08, 0.46, Vector3(0, -0.22, 0), pants, _fl())
    var sh := Node3D.new()
    sh.position = Vector3(0, -0.45, 0)
    th.add_child(sh)
    _capsule(sh, 0.065, 0.46, Vector3(0, -0.22, 0), pants, _fl())
    _box(sh, Vector3(0.10, 0.07, 0.26), Vector3(0, -0.43, -0.05), Color(0.08, 0.08, 0.09), _fs())
    return [th, sh]


func set_weapon(id: String) -> void:
    if weapon_node != null and is_instance_valid(weapon_node):
        weapon_node.queue_free()
    weapon_node = null
    weapon_id = id
    if id == "":
        aim = 0
        return
    var d: Dictionary = WeaponDefs.get_def(id)
    aim = int(d.get("hold", 0))
    weapon_node = WeaponModel.build(id)
    weapon_node.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    hand_r.add_child(weapon_node)


func weapon_muzzle() -> Node3D:
    if weapon_node != null and is_instance_valid(weapon_node):
        return weapon_node.find_child("Muzzle", true, false) as Node3D
    return null


func set_shadow_only(on: bool) -> void:
    var mode: int = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    for m in meshes:
        (m as GeometryInstance3D).cast_shadow = mode
    if weapon_node != null:
        WeaponModel.set_shadow_mode(weapon_node, mode)


func play(act_name: String, dur: float) -> void:
    _act = act_name
    _act_dur = maxf(dur, 0.05)
    _act_t = _act_dur


func honk() -> void:
    honk_t = 0.45


func die(_dir: Vector3) -> void:
    if dead:
        return
    dead = true
    var tw: Tween = create_tween()
    tw.set_parallel(true)
    var tx: float = -PI * 0.5 if randf() < 0.5 else PI * 0.5
    tw.tween_property(self, "rotation:x", tx, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.tween_property(self, "position:y", 0.14, 0.5)
    arm_l.rotation = Vector3(0.4, 0.0, 0.7)
    arm_r.rotation = Vector3(-0.3, 0.0, -0.8)
    fore_l.rotation = Vector3(-0.4, 0, 0)
    fore_r.rotation = Vector3(-0.3, 0, 0)
    leg_l.rotation = Vector3(0.1, 0, 0.15)
    leg_r.rotation = Vector3(-0.1, 0, -0.2)
    shin_l.rotation = Vector3.ZERO
    shin_r.rotation = Vector3(-0.2, 0, 0)
    torso.rotation = Vector3.ZERO
    head.rotation = Vector3(0.0, 0.5, 0.2)
    hips.position.y = HIP_Y


func go_limp() -> void:
    dead = true
    disable_lod()
    arm_l.rotation = Vector3(0.4, 0.0, 0.7)
    arm_r.rotation = Vector3(-0.3, 0.0, -0.8)
    fore_l.rotation = Vector3(-0.4, 0, 0)
    fore_r.rotation = Vector3(-0.3, 0, 0)
    leg_l.rotation = Vector3(0.1, 0, 0.15)
    leg_r.rotation = Vector3(-0.1, 0, -0.2)
    shin_l.rotation = Vector3.ZERO
    shin_r.rotation = Vector3(-0.2, 0, 0)
    torso.rotation = Vector3.ZERO
    head.rotation = Vector3(0.0, 0.5, 0.2)
    hips.position.y = HIP_Y
    hips.rotation = Vector3.ZERO


# Вид от первого лица: голову и руки прячем (руки рисует viewmodel), туловище и ноги видны, если смотреть вниз.
func set_fp_mode(on: bool, show_body: bool = false) -> void:
    head.visible = not on
    arm_l.visible = not on
    arm_r.visible = not on
    var body: bool = (not on) or show_body
    torso.visible = body
    leg_l.visible = body
    leg_r.visible = body


func _rot(n: Node3D, x: float, y: float, z: float, k: float) -> void:
    var r: Vector3 = n.rotation
    n.rotation = Vector3(lerpf(r.x, x, k), lerpf(r.y, y, k), lerpf(r.z, z, k))


func _process(delta: float) -> void:
    if dead:
        return
    _lod_t -= delta
    if _lod_t <= 0.0:
        _lod_t = 0.3 + randf() * 0.2
        var cam: Camera3D = get_viewport().get_camera_3d()
        if cam != null:
            var ad: float = float(Settings.ANIM_DIST[Settings.graphics])
            active = cam.global_position.distance_squared_to(global_position) < ad * ad
    if not active:
        return
    _time += delta
    var k: float = minf(1.0, delta * 12.0)
    _act_t = maxf(0.0, _act_t - delta)
    honk_t = maxf(0.0, honk_t - delta)
    var p: float = 1.0 - _act_t / _act_dur if _act != "" else 0.0
    var ph: float = sin(p * PI) if _act_t > 0.0 else 0.0
    var amp: float = clampf(speed / 5.5, 0.0, 1.0) * (0.6 + 0.4 * run_amt)
    if speed > 0.15:
        _cycle += delta * (4.2 + speed * 1.15) * walk_sign
    var s: float = sin(_cycle)
    var c: float = cos(_cycle)

    # ---- ноги и корпус
    var hip_y: float = HIP_Y + absf(c) * 0.035 * amp
    var lx: float = s * amp * 0.9
    var rx: float = -s * amp * 0.9
    var lshin: float = -maxf(0.0, c) * amp * 1.1
    var rshin: float = -maxf(0.0, -c) * amp * 1.1
    var tors_x: float = -0.12 * run_amt * amp + sin(_time * 1.6) * 0.012
    var tors_y: float = s * amp * 0.12
    var tors_z: float = 0.0
    var hip_z: float = s * 0.03 * amp
    # ---- руки
    var alx: float = -s * amp * 0.7
    var arx: float = s * amp * 0.7
    var alz: float = 0.04
    var arz: float = -0.04
    var flx: float = -0.25 - amp * 0.5 * run_amt
    var frx: float = flx
    var head_x: float = 0.0

    if aim == 1:
        arx = 1.45 + pitch_aim
        frx = -0.1
        arz = -0.05
    elif aim == 2:
        arx = 1.25 + pitch_aim
        frx = -0.6
        arz = -0.15
        alx = 1.35 + pitch_aim
        flx = -0.9
        alz = 0.35
    elif aim == 3:
        arx = 0.5
        frx = -1.2

    if wounded == "torso":
        alx = 0.5
        alz = 0.5
        flx = -1.7
        arx = 0.5
        arz = -0.5
        frx = -1.7
        tors_x = -0.4
        head_x = 0.3
    elif wounded == "leg":
        arx = 0.5
        frx = -0.7
        arz = -0.25
        lx *= 0.3
        lshin = -0.12
        hip_z = s * 0.12
        tors_z = 0.12
        tors_x = -0.12
    elif wounded == "arm":
        arx = 0.6
        arz = -0.7
        frx = -1.5
        alx = 0.2
        flx = -0.4
        tors_x = -0.2

    if aim == 1 or aim == 2:
        if ads:
            arx += 0.14
    if hands_up:
        alx = 2.75 + sin(_time * 9.0) * 0.06
        arx = 2.75 + sin(_time * 9.0 + 1.0) * 0.06
        alz = 0.3
        arz = -0.3
        flx = -0.3
        frx = -0.3
        tors_x = -0.05
    if sitting:
        hip_y = 0.30
        lx = 1.45
        rx = 1.45
        lshin = -1.5
        rshin = -1.5
        hip_z = 0.0
        tors_x = 0.12
        tors_y = 0.0
        alx = 0.9
        arx = 0.9
        flx = -0.8
        frx = -0.8
        alz = 0.1
        arz = -0.1
        if honk_t > 0.0:
            arx = 1.0
            frx = -0.8 + sin((1.0 - honk_t / 0.45) * PI) * 0.4

    # ---- одноразовые действия
    if _act_t > 0.0:
        match _act:
            "punch":
                arx = lerpf(0.5, 1.55, ph)
                frx = lerpf(-1.6, -0.05, ph)
                tors_y = -0.4 * ph
            "punch_l":
                alx = lerpf(0.5, 1.55, ph)
                flx = lerpf(-1.6, -0.05, ph)
                tors_y = 0.4 * ph
            "swing":
                arx = lerpf(2.6, 0.4, p)
                frx = -0.5
                tors_x = -0.25 * ph
            "throw":
                arx = lerpf(0.2, 1.7, ph)
                frx = -0.3
            "hit":
                tors_x = -0.45 * ph
                head_x = 0.35 * ph
            "recoil":
                arx += 0.15 * ph
                tors_x += 0.05 * ph
            "reload":
                arx = 0.9
                frx = -1.2

    hips.position.y = lerpf(hips.position.y, hip_y, k)
    _rot(leg_l, lx, 0.0, 0.0, k)
    _rot(leg_r, rx, 0.0, 0.0, k)
    _rot(shin_l, lshin, 0.0, 0.0, k)
    _rot(shin_r, rshin, 0.0, 0.0, k)
    _rot(torso, tors_x, tors_y, tors_z, k)
    _rot(hips, 0.0, 0.0, hip_z, k)
    _rot(arm_l, alx, 0.0, alz, k)
    _rot(arm_r, arx, 0.0, arz, k)
    _rot(fore_l, flx, 0.0, 0.0, k)
    _rot(fore_r, frx, 0.0, 0.0, k)
    _rot(head, head_x, 0.0, 0.0, k)
