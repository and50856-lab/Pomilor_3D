class_name Vehicle
extends RigidBody3D
# Машина с аркадно-реалистичной физикой: рейкаст-подвеска, модель шины со срывом в занос (дрифт),
# мощностная кривая двигателя, пробитие шин, повреждения, пожар и взрыв.
# Режимы: PARKED (стоит), PLAYER (ведёт игрок), AI_LANE (трафик вдали, кинематика),
# AI_PHYS (трафик рядом с игроком: настоящая физика), AI_FREE (угнана NPC, уезжает).

enum Mode { PARKED, PLAYER, AI_LANE, AI_FREE, AI_PHYS }

var vid: String = "vaz"
var def: Dictionary = {}
var mode: int = Mode.PARKED
var model: Dictionary = {}
var wheel_nodes: Array = []
var spin_nodes: Array = []
var tire_nodes: Array = []
var door_node: Node3D = null
var steer_node: Node3D = null
var paint_mi: MeshInstance3D = null
var glass_mi: MeshInstance3D = null
var lod_mi: MeshInstance3D = null
var seat_local: Vector3 = Vector3.ZERO
var fuel_cap: Vector3 = Vector3.ZERO
var wheel_r: float = 0.35
var length: float = 4.0
var width: float = 1.8
var half_len: float = 2.0
var mounts: Array = []
var susp_len: Array = [0.3, 0.3, 0.3, 0.3]
var drive_share: Array = [0.25, 0.25, 0.25, 0.25]
var susp_h: float = 0.3
var rest_len: float = 0.39
var max_len: float = 0.53
var min_len: float = 0.1
var k_spring: float = 30000.0
var c_damp: float = 3000.0
var drag_k: float = 0.5
var p_eff: float = 40000.0
var f_max: float = 4000.0
var brake_a: float = 9.0

var in_throttle: float = 0.0
var in_steer: float = 0.0
var in_brake: float = 0.0
var in_hand: bool = false
var steer_angle: float = 0.0
var steer_vis: float = 0.0
var speed_ms: float = 0.0

var ai: AIDriver = null
var driver_npc = null
var has_player: bool = false
var door_target: float = 0.0
var still_t: float = 0.0
var horn_cd: float = 0.0
var escape_time: float = 0.0
var free_t: float = 0.0
var free_target: Vector3 = Vector3.ZERO
var stuck_t: float = 0.0
var reverse_t: float = 0.0
var honk_pitch: float = 1.0

# повреждения
var hp: float = 800.0
var max_hp: float = 800.0
var wrecked: bool = false
var burning: bool = false
var burn_t: float = 0.0
var wreck_t: float = 0.0
var post_smoke_t: float = 0.0
var tire_hp: Array = [1.0, 1.0, 1.0, 1.0]
var tire_state: Array = [0, 0, 0, 0]
var tire_dist: Array = [0.0, 0.0, 0.0, 0.0]
var slide: Array = [0.0, 0.0, 0.0, 0.0]

var engine_snd: AudioStreamPlayer3D = null
var _recent: Dictionary = {}
var _spin: float = 0.0
var _ex: Array[RID] = []
var _skid_has: Array = [false, false, false, false]
var _skid_pos: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _wheel_smoke: Array = [null, null, null, null]
var _spark_t: float = 0.0
var _stage: int = 0
var _fx_smoke: CPUParticles3D = null
var _fx_fire: CPUParticles3D = null
var _fx_light: OmniLight3D = null
var _fx_clock: float = 0.0
var _react_cd: float = 0.0
var _holes: Array = []


func setup(id: String, color: Color) -> void:
    vid = id
    def = VehicleDefs.get_def(id)
    mass = def["mass"]
    wheel_r = def["wheel_r"]
    length = def["length"]
    width = def["width"]
    half_len = length * 0.5
    collision_layer = Const.L_VEH
    collision_mask = Const.L_WORLD | Const.L_VEH | Const.L_BODY
    can_sleep = true
    angular_damp = 0.8
    linear_damp = 0.03
    continuous_cd = true
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0.0, float(def["com_y"]), 0.0)
    var pm := PhysicsMaterial.new()
    pm.friction = 0.15
    pm.bounce = 0.0
    physics_material_override = pm
    add_to_group("vehicles")
    _ex.append(get_rid())
    honk_pitch = randf_range(0.9, 1.15)

    model = VehicleModel.build(id, color)
    add_child(model["root"])
    wheel_nodes = model["wheels"]
    spin_nodes = model["spins"]
    tire_nodes = model["tires"]
    door_node = model["door"]
    steer_node = model["steer"]
    seat_local = model["seat"]
    paint_mi = model["paint"]
    glass_mi = model["glass"]
    lod_mi = model["lod"]
    fuel_cap = model["fuel"]

    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = def["body"]
    cs.shape = bs
    cs.position = def["body_c"]
    add_child(cs)
    var cs2 := CollisionShape3D.new()
    var bs2 := BoxShape3D.new()
    bs2.size = def["cab"]
    cs2.shape = bs2
    cs2.position = def["cab_c"]
    add_child(cs2)

    var tr: float = def["track"]
    var wb: float = def["wheelbase"]
    var s0: float = def["s0"]
    k_spring = (mass * 9.8 * 0.25) / s0
    c_damp = 2.0 * float(def["zeta"]) * sqrt(k_spring * mass * 0.25)
    rest_len = susp_h + s0
    max_len = rest_len + 0.14
    min_len = 0.1
    mounts.clear()
    for i in 4:
        var sx: float = -1.0 if (i % 2) == 0 else 1.0
        var sz: float = -1.0 if i < 2 else 1.0
        mounts.append(Vector3(sx * tr * 0.5, susp_h, sz * wb * 0.5))
        susp_len[i] = susp_h
    match String(def["drive"]):
        "fwd":
            drive_share = [0.5, 0.5, 0.0, 0.0]
        "rwd":
            drive_share = [0.0, 0.0, 0.5, 0.5]
        _:
            drive_share = [0.25, 0.25, 0.25, 0.25]

    # мощность и сопротивление воздуха подобраны так, чтобы максимальная скорость совпала с vmax
    var vmax: float = def["vmax"]
    p_eff = float(def["kw"]) * 1000.0 * 0.85
    f_max = def["f_max"]
    var roll: float = 0.015 * mass * 9.8
    drag_k = maxf((p_eff / vmax - roll) / (vmax * vmax), 0.05)
    max_hp = def["hp"]
    hp = max_hp

    engine_snd = Sfx.make_loop_player("engine", self, 55.0)
    engine_snd.volume_db = -8.0


func place(pos: Vector3, yaw: float) -> void:
    global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO


func display_name() -> String:
    return str(def.get("name", vid))


# ---------- режимы ----------

func start_ai_lane() -> void:
    mode = Mode.AI_LANE
    freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
    freeze = true


func set_ai_phys(on: bool) -> void:
    if on:
        if mode != Mode.AI_LANE:
            return
        var fwd: Vector3 = -global_transform.basis.z
        mode = Mode.AI_PHYS
        freeze = false
        sleeping = false
        linear_velocity = fwd * speed_ms
        angular_velocity = Vector3.ZERO
        steer_angle = steer_vis
    else:
        if mode != Mode.AI_PHYS:
            return
        mode = Mode.AI_LANE
        freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
        freeze = true
        if ai != null:
            ai.sync_from_vehicle()


func wake() -> void:
    if freeze:
        freeze = false
    sleeping = false
    still_t = 0.0


func freeze_static() -> void:
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
    freeze = true


func player_enter() -> void:
    has_player = true
    if ai != null:
        ai = null
    if Game.traffic != null:
        Game.traffic.cars.erase(self)
    mode = Mode.PLAYER
    wake()


func player_exit() -> void:
    has_player = false
    in_throttle = 0.0
    in_steer = 0.0
    in_hand = false
    mode = Mode.PARKED
    still_t = 0.0


func detach_ai() -> void:
    ai = null
    if Game.traffic != null:
        Game.traffic.cars.erase(self)
    if mode == Mode.AI_LANE or mode == Mode.AI_PHYS:
        mode = Mode.PARKED
        wake()
        if mode == Mode.PARKED and linear_velocity.length() < 0.01:
            linear_velocity = Vector3.ZERO


func start_escape() -> void:
    has_player = false
    mode = Mode.AI_FREE
    escape_time = 0.0
    free_t = 0.0
    wake()


func panic() -> void:
    if ai != null:
        ai.panic = true
        ai.panic_t = 30.0


func is_flipped() -> bool:
    return global_transform.basis.y.dot(Vector3.UP) < 0.3 and absf(speed_ms) < 3.0


func flip_upright() -> void:
    var p: Vector3 = global_position + Vector3(0, 1.2, 0)
    var yaw: float = global_rotation.y
    global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO


func seat_world() -> Vector3:
    return global_transform * seat_local


func ground_at(p: Vector3) -> float:
    var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 3.0, 0), p - Vector3(0, 6.0, 0), Const.L_WORLD)
    var h: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
    if h.is_empty():
        return p.y
    var hp_: Vector3 = h["position"]
    return hp_.y


func exit_position(side: float = -1.0) -> Vector3:
    var off: Vector3 = global_transform.basis.x * side * (width * 0.5 + 0.95)
    var p: Vector3 = global_position + off
    p.y = ground_at(p) + 0.08
    return p


func _near_camera() -> bool:
    var cam: Camera3D = get_viewport().get_camera_3d()
    return cam != null and cam.global_position.distance_squared_to(global_position) < 6400.0


func honk() -> void:
    if horn_cd > 0.0:
        return
    horn_cd = 0.4
    var vol: float = 2.0
    if has_player and Game.player != null:
        vol = -16.0 if Game.player.car_third else -2.0
    Sfx.play3d("horn", global_position, vol, honk_pitch, 90.0)
    if driver_npc != null and is_instance_valid(driver_npc):
        driver_npc.rig.honk()


# ---------- повреждения ----------

func shot(pos: Vector3, dir: Vector3, dmg: float) -> void:
    if wrecked:
        return
    if not freeze:
        apply_impulse(dir * dmg * 0.3, pos - global_position)
    var lp: Vector3 = to_local(pos)
    if lp.distance_to(fuel_cap) < 0.2:
        ignite(0.35)
        return
    for i in 4:
        var m: Vector3 = mounts[i]
        if absf(lp.x - m.x) < 0.28 and Vector2(lp.y, lp.z - m.z).length() < wheel_r + 0.1 and lp.y < wheel_r * 0.8:
            tire_hit(i, dmg)
            return
    apply_damage(dmg)
    if _react_cd <= 0.0 and driver_npc != null and is_instance_valid(driver_npc):
        _react_cd = 3.0
        driver_npc.call("on_vehicle_shot", pos)


func add_hole(pos: Vector3, normal: Vector3) -> void:
    if _holes.size() >= 10:
        var old = _holes.pop_front()
        if is_instance_valid(old):
            old.queue_free()
    var mi := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = Vector2(0.14, 0.14)
    mi.mesh = pm
    mi.material_override = Effects.hole_material()
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    mi.global_transform = Transform3D(Effects.surface_basis(normal), pos + normal.normalized() * 0.015)
    _holes.append(mi)


func tire_hit(i: int, dmg: float) -> void:
    tire_hp[i] = float(tire_hp[i]) - dmg / 40.0
    if float(tire_hp[i]) <= 0.0 and int(tire_state[i]) == 0:
        tire_state[i] = 1
        tire_dist[i] = 0.0
        Sfx.play3d("pop", global_position, 0.0, randf_range(0.9, 1.1), 60.0)
        _tire_visual(i)
        if driver_npc != null and is_instance_valid(driver_npc):
            driver_npc.call("on_vehicle_shot", global_position)


func _tire_visual(i: int) -> void:
    var spin: Node3D = spin_nodes[i]
    var st: int = int(tire_state[i])
    if st == 1:
        spin.scale = Vector3(1.0, 0.86, 0.86)
    elif st == 2:
        spin.scale = Vector3.ONE
        if i < tire_nodes.size():
            (tire_nodes[i] as MeshInstance3D).visible = false


func apply_damage(d: float) -> void:
    if wrecked:
        return
    hp = maxf(hp - d, 0.0)
    _update_stage()
    if driver_npc != null and is_instance_valid(driver_npc) and _stage >= 1 and mode != Mode.AI_FREE:
        driver_npc.call("bail_out", self, true)


func _update_stage() -> void:
    var r: float = hp / max_hp
    var st: int = 0
    if r < 0.15:
        st = 3
    elif r < 0.35:
        st = 2
    elif r < 0.65:
        st = 1
    if st != _stage:
        _stage = st
        _ensure_fx()
        _apply_stage_fx()
    if st >= 3 and not burning:
        ignite(5.0)


func ignite(t: float) -> void:
    if wrecked:
        return
    if not burning:
        burning = true
        burn_t = t
    else:
        burn_t = minf(burn_t, t)
    _stage = maxi(_stage, 3)
    _ensure_fx()
    _apply_stage_fx()


func _hood() -> Vector3:
    var body: Vector3 = def["body"]
    var bc: Vector3 = def["body_c"]
    return Vector3(0.0, bc.y + body.y * 0.5, -length * 0.25)


func _ensure_fx() -> void:
    if _fx_smoke != null:
        return
    var g: int = Settings.graphics
    var am: int = int(Settings.SMOKE_AMOUNT[g])
    _fx_smoke = Effects.make_smoke(self, _hood(), am, 2.4, Color(0.7, 0.7, 0.72), 0.5, 1.4, 1.8)
    _fx_fire = Effects.make_fire(self, _hood() + Vector3(0, 0.1, 0), maxi(4, am / 2))


func _apply_stage_fx() -> void:
    if _fx_smoke == null:
        return
    match _stage:
        0:
            _fx_smoke.emitting = false
        1:
            _fx_smoke.color = Color(0.78, 0.78, 0.8)
            _fx_smoke.emitting = true
        2:
            _fx_smoke.color = Color(0.35, 0.35, 0.37)
            _fx_smoke.emitting = true
        _:
            _fx_smoke.color = Color(0.1, 0.1, 0.1)
            _fx_smoke.emitting = true
    _fx_fire.emitting = _stage >= 3 or burning


func blast(dir: Vector3, f: float, dmg: float) -> void:
    if mode == Mode.AI_LANE:
        set_ai_phys(true)
    wake()
    apply_central_impulse(dir.normalized() * mass * 5.0 * f)
    apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass * 2.0 * f)
    if not wrecked:
        apply_damage(dmg * f)
        if driver_npc != null and is_instance_valid(driver_npc):
            driver_npc.call("on_vehicle_shot", global_position)


func explode_now() -> void:
    if wrecked:
        return
    wrecked = true
    burning = false
    var pos: Vector3 = global_position + Vector3(0, 0.8, 0)
    var drv = driver_npc
    driver_npc = null
    if drv != null and is_instance_valid(drv):
        drv.call("killed_in_car", global_position)
    if has_player and Game.player != null:
        Game.player.call("force_exit_vehicle")
        Game.player.call("take_damage", 70.0, Vector3.UP)
    detach_ai()
    Combat.explode(pos, 8.0, 240.0, null, self, 3.0)
    mode = Mode.PARKED
    wake()
    apply_central_impulse(Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0)) * mass * 5.5)
    apply_torque_impulse(Vector3(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5), randf_range(-1.0, 1.0)) * mass * 3.5)
    if paint_mi != null:
        var m := StandardMaterial3D.new()
        m.albedo_color = Color(0.22, 0.09, 0.045)
        m.roughness = 0.95
        m.metallic = 0.25
        paint_mi.material_override = m
    if glass_mi != null:
        glass_mi.visible = false
    if lod_mi != null:
        var lm := StandardMaterial3D.new()
        lm.albedo_color = Color(0.2, 0.09, 0.05)
        lm.roughness = 0.95
        lod_mi.material_override = lm
    Effects.scorch(Vector3(global_position.x, ground_at(global_position), global_position.z), Vector3.UP, 5.5)
    if engine_snd != null:
        engine_snd.stop()
    _ensure_fx()
    _stage = 3
    _fx_smoke.color = Color(0.12, 0.12, 0.12)
    _fx_smoke.emitting = true
    _fx_fire.emitting = true
    post_smoke_t = 14.0
    wreck_t = 0.0
    var pm := PhysicsMaterial.new()
    pm.friction = 0.8
    pm.bounce = 0.1
    physics_material_override = pm
    linear_damp = 0.4


func _wreck_tick(delta: float) -> void:
    wreck_t += delta
    if wreck_t > 120.0 and not has_player:
        queue_free()
        return
    post_smoke_t -= delta
    if _fx_fire != null and wreck_t > 6.0:
        _fx_fire.emitting = false
        if _fx_light != null:
            _fx_light.light_energy = 0.0
    if _fx_light != null and wreck_t <= 6.0:
        _fx_light.light_energy = 3.0 + sin(wreck_t * 30.0)
    if _fx_smoke != null and post_smoke_t <= 0.0:
        _fx_smoke.emitting = false
    if not freeze:
        if linear_velocity.length() < 0.25 and angular_velocity.length() < 0.3:
            still_t += delta
            if still_t > 2.0:
                freeze_static()
        else:
            still_t = 0.0


func _fx_tick(delta: float) -> void:
    _fx_clock += delta
    if _fx_light != null and burning:
        _fx_light.light_energy = 3.0 + sin(_fx_clock * 30.0) * 1.2


# ---------- физика ----------

func _physics_process(delta: float) -> void:
    horn_cd = maxf(0.0, horn_cd - delta)
    _react_cd -= delta
    if wrecked:
        _wreck_tick(delta)
        return
    if burning:
        burn_t -= delta
        _fx_tick(delta)
        if has_player and Game.player != null:
            Game.player.call("take_damage", 6.0 * delta, Vector3.ZERO)
        if burn_t <= 0.0:
            explode_now()
            return
    match mode:
        Mode.AI_LANE:
            if ai != null:
                ai.update(delta)
            _visuals(delta)
            _runover()
        Mode.PARKED:
            if freeze:
                return
            _drive(delta)
            if linear_velocity.length() < 0.2 and angular_velocity.length() < 0.2:
                still_t += delta
                if still_t > 1.5 and not burning:
                    freeze_static()
            else:
                still_t = 0.0
            _visuals(delta)
        Mode.AI_PHYS:
            if ai != null:
                ai.update(delta)
            _drive(delta)
            _runover()
            _visuals(delta)
        _:
            if mode == Mode.AI_FREE:
                _free_ai(delta)
            _drive(delta)
            _runover()
            _visuals(delta)
    _sound(delta)


func _drive(delta: float) -> void:
    var xf: Transform3D = global_transform
    var up: Vector3 = xf.basis.y
    var fwd: Vector3 = -xf.basis.z
    var vel: Vector3 = linear_velocity
    var v_long: float = vel.dot(fwd)
    speed_ms = v_long
    var sp: float = absf(v_long)
    var vmax: float = def["vmax"]
    var lat_k: float = def["lat_k"]
    var grip: float = def["grip"]
    var grip_r: float = def["grip_r"]
    var thr: float = in_throttle
    var brk: float = in_brake
    var hand: bool = in_hand
    var steer_t: float = in_steer
    if mode == Mode.PARKED:
        thr = 0.0
        brk = 1.0
        hand = true
        steer_t = 0.0
    var max_steer: float = float(def["steer"]) * lerpf(1.0, 0.25, clampf(sp / vmax * 1.6, 0.0, 1.0))
    steer_angle = move_toward(steer_angle, steer_t * max_steer, delta * 2.4)
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.new()
    q.collision_mask = Const.L_WORLD
    q.exclude = _ex
    var m_w: float = mass * 0.25
    var grounded: int = 0
    var dt: float = maxf(delta, 0.0001)
    var near: bool = _near_camera()
    for i in 4:
        var mount: Vector3 = xf * (mounts[i] as Vector3)
        q.from = mount
        q.to = mount - up * (max_len + wheel_r)
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty():
            susp_len[i] = move_toward(susp_len[i], max_len, delta * 1.5)
            slide[i] = 0.0
            if near:
                _wheel_fx(i, Vector3.ZERO, 0.0, 0)
            continue
        var hp_: Vector3 = hit["position"]
        var nrm: Vector3 = hit["normal"]
        var slen: float = clampf(mount.distance_to(hp_) - wheel_r, min_len, max_len)
        var prev: float = susp_len[i]
        susp_len[i] = slen
        var compress: float = rest_len - slen
        var comp_v: float = (prev - slen) / dt
        var f_spring: float = maxf(0.0, compress * k_spring + comp_v * c_damp)
        grounded += 1
        apply_force(nrm * f_spring, mount - global_position)
        var hub: Vector3 = mount - up * slen
        var rel: Vector3 = hub - global_position
        var wv: Vector3 = vel + angular_velocity.cross(rel)
        var st: float = steer_angle if i < 2 else 0.0
        var w_fwd: Vector3 = fwd.rotated(up, -st)
        var w_right: Vector3 = w_fwd.cross(up).normalized()
        var v_f: float = wv.dot(w_fwd)
        var v_r: float = wv.dot(w_right)
        var ts: int = int(tire_state[i])
        var mu: float = grip * (grip_r if i >= 2 else 1.0)
        if ts == 1:
            mu *= 0.6
        elif ts == 2:
            mu *= 0.4
        var lk: float = lat_k
        if hand and i >= 2:
            mu *= 0.45
            lk *= 0.3
        var cap: float = f_spring * mu
        # боковая сила: пик при небольшом угле увода, дальше падает — отсюда занос и дрифт
        var slip: float = atan2(v_r, absf(v_f) + 0.6)
        var lat_pj: float = -sin(1.5 * atan(9.0 * slip)) * cap
        var lat_lin: float = clampf(-v_r * m_w * lk, -cap, cap)
        var lat: float = lerpf(lat_lin, lat_pj, clampf(absf(v_f) / 4.0, 0.0, 1.0))
        if ts > 0:
            var side: float = -1.0 if (i % 2) == 0 else 1.0
            lat += side * m_w * 1.3 * minf(sp / 8.0, 1.0)
        var lon: float = 0.0
        var share: float = drive_share[i]
        var bmax: float = m_w * brake_a
        if brk > 0.01:
            lon = clampf(-v_f * m_w * 20.0, -bmax, bmax)
        elif hand and i >= 2:
            lon = clampf(-v_f * m_w * 20.0, -m_w * 14.0, m_w * 14.0)
        elif absf(thr) > 0.02:
            if thr * v_long < -1.5:
                lon = clampf(-v_f * m_w * 20.0, -bmax, bmax)
            else:
                var f_total: float = minf(f_max, p_eff / maxf(sp, 2.0))
                lon = thr * f_total * share
                if thr < 0.0:
                    lon *= 0.55
                    if v_long < -12.0:
                        lon = 0.0
        else:
            lon = -clampf(v_f, -1.0, 1.0) * m_w * 0.4
        if ts > 0:
            lon -= clampf(v_f, -1.0, 1.0) * m_w * 1.2
            if ts == 1:
                tire_dist[i] = float(tire_dist[i]) + sp * dt
                if float(tire_dist[i]) >= 60.0:
                    tire_state[i] = 2
                    _tire_visual(i)
        # круг трения: тяга/торможение ограничены тем, что осталось от бокового сцепления
        var lon_max: float = sqrt(maxf(cap * cap - lat * lat, 0.0))
        lon = clampf(lon, -lon_max, lon_max)
        apply_force(w_fwd * lon + w_right * lat, rel)
        var sl: float = 0.0
        if sp > 4.0 and cap > 1.0:
            sl = clampf((maxf(absf(lat), absf(lon)) / cap - 0.8) / 0.2, 0.0, 1.0)
            sl = maxf(sl, clampf((absf(slip) - 0.25) / 0.2, 0.0, 1.0))
        slide[i] = sl
        if near:
            _wheel_fx(i, hp_, sl, ts)
    var spd2: float = vel.length_squared()
    if spd2 > 0.01:
        apply_central_force(-vel.normalized() * spd2 * drag_k)
    if grounded >= 2:
        var av: Vector3 = angular_velocity
        var rp: Vector3 = av - up * av.dot(up)
        apply_torque(-rp * mass * 0.6)
        if up.dot(Vector3.UP) > 0.3:
            apply_torque(up.cross(Vector3.UP) * mass * 2.0)
    elif grounded == 0:
        apply_torque(-angular_velocity * mass * 0.15)


# Следы шин, дым из-под колёс, искры от дисков.
func _wheel_fx(i: int, contact: Vector3, sl: float, ts: int) -> void:
    var e: CPUParticles3D = _wheel_smoke[i] as CPUParticles3D
    if sl > 0.35 and contact != Vector3.ZERO:
        if Game.skids != null:
            if bool(_skid_has[i]):
                var last: Vector3 = _skid_pos[i]
                var dd: float = last.distance_to(contact)
                if dd > 3.0:
                    _skid_pos[i] = contact
                elif dd > 0.4:
                    Game.skids.add(last, contact, 0.24)
                    _skid_pos[i] = contact
            else:
                _skid_has[i] = true
                _skid_pos[i] = contact
        if e == null:
            var g: int = Settings.graphics
            var am: int = maxi(2, int(Settings.SMOKE_AMOUNT[g]) / 2)
            var m: Vector3 = mounts[i]
            e = Effects.make_smoke(self, Vector3(m.x, -wheel_r, m.z), am, [0.8, 1.0, 1.4, 1.8, 2.4][g], Color(0.85, 0.85, 0.88), 0.35, 0.95, 0.9)
            _wheel_smoke[i] = e
        e.emitting = true
    else:
        _skid_has[i] = false
        if e != null:
            e.emitting = false
    if ts == 2 and contact != Vector3.ZERO and absf(speed_ms) > 2.0:
        _spark_t -= 0.016
        if _spark_t <= 0.0:
            _spark_t = 0.08
            Effects.sparks(contact, Vector3.UP)


func _free_ai(delta: float) -> void:
    free_t -= delta
    escape_time += delta
    var pl: Node3D = Game.player as Node3D
    if free_t <= 0.0:
        free_t = 2.5
        var best: Vector3 = global_position
        var best_d: float = -1.0
        for i in 5:
            var p: Vector3 = Const.node_pos(randi() % Const.N, randi() % Const.N)
            var dd: float = p.distance_to(pl.global_position) if pl != null else randf()
            if dd > best_d:
                best_d = dd
                best = p
        free_target = best
    var to: Vector3 = free_target - global_position
    to.y = 0.0
    var fwd: Vector3 = -global_transform.basis.z
    fwd.y = 0.0
    fwd = fwd.normalized()
    var ang: float = fwd.signed_angle_to(to.normalized(), Vector3.UP)
    var vmax: float = def["vmax"]
    in_steer = clampf(-ang * 1.6, -1.0, 1.0)
    var target: float = vmax * 0.5 * (0.5 if absf(ang) > 1.0 else 1.0)
    in_throttle = 1.0 if speed_ms < target else 0.0
    in_brake = 0.0
    var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + Vector3(0, 0.6, 0) + fwd * 9.0, Const.L_WORLD | Const.L_VEH)
    q.exclude = _ex
    var blocked: bool = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
    if absf(speed_ms) < 1.0 and in_throttle > 0.0:
        stuck_t += delta
    else:
        stuck_t = maxf(0.0, stuck_t - delta)
    if stuck_t > 1.8 or (blocked and absf(speed_ms) < 3.0):
        reverse_t = 1.4
        stuck_t = 0.0
    if reverse_t > 0.0:
        reverse_t -= delta
        in_throttle = -1.0
        in_steer = -in_steer
    if pl != null and escape_time > 40.0 and pl.global_position.distance_to(global_position) > 130.0:
        if driver_npc != null and is_instance_valid(driver_npc):
            driver_npc.queue_free()
        queue_free()


func _visuals(delta: float) -> void:
    _spin += speed_ms / wheel_r * delta
    var sv: float = steer_vis if mode == Mode.AI_LANE else steer_angle
    for i in 4:
        var w: Node3D = wheel_nodes[i]
        w.position.y = susp_h - float(susp_len[i])
        if i < 2:
            w.rotation.y = -sv
        (spin_nodes[i] as Node3D).rotation.x = -_spin
    if door_node != null:
        door_node.rotation.y = lerpf(door_node.rotation.y, -1.1 * door_target, minf(1.0, delta * 8.0))
    if steer_node != null:
        steer_node.rotation.z = -sv * 2.0


func _runover() -> void:
    if absf(speed_ms) < 1.5:
        return
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var inv: Transform3D = global_transform.affine_inverse()
    var dirv: Vector3 = -global_transform.basis.z * signf(speed_ms)
    var hw: float = width * 0.5 + 0.35
    var hl: float = half_len + 0.3
    for w in Game.walkers():
        if not is_instance_valid(w):
            continue
        var n3: Node3D = w as Node3D
        if n3 == null or n3 == self:
            continue
        var lp: Vector3 = inv * n3.global_position
        if absf(lp.x) > hw or absf(lp.z) > hl or lp.y < -0.6 or lp.y > 2.0:
            continue
        var bid: int = n3.get_instance_id()
        if _recent.has(bid) and now - float(_recent[bid]) < 1.2:
            continue
        _recent[bid] = now
        var dmg: float = clampf(absf(speed_ms) * 9.0, 4.0, 180.0)
        if n3.has_method("take_hit"):
            n3.call("take_hit", "torso", dmg, dirv, self)
        elif n3.has_method("take_damage"):
            n3.call("take_damage", dmg * 0.5, dirv)
        Sfx.play3d("crash", global_position, -2.0, 1.0, 60.0)


func _sound(_delta: float) -> void:
    if engine_snd == null:
        return
    var want: bool = false
    if has_player:
        want = true
    elif mode == Mode.AI_LANE or mode == Mode.AI_FREE or mode == Mode.AI_PHYS:
        var cam: Camera3D = get_viewport().get_camera_3d()
        if cam != null and cam.global_position.distance_to(global_position) < 45.0:
            want = true
    if want and not engine_snd.playing:
        engine_snd.play()
    elif not want and engine_snd.playing:
        engine_snd.stop()
    if engine_snd.playing:
        var vmax: float = def["vmax"]
        var g: float = absf(speed_ms) / (vmax / 5.0)
        engine_snd.pitch_scale = 0.6 + fposmod(g, 1.0) * 0.9 + floorf(g) * 0.1 + absf(in_throttle) * 0.12
        var vol: float = -9.0 + 4.0 * absf(in_throttle)
        if has_player and Game.player != null and Game.player.car_third:
            vol -= 8.0
        engine_snd.volume_db = vol
