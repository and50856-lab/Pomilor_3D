class_name Vehicle
extends RigidBody3D
# Машина: аркадная рейкаст-подвеска. Режимы:
#  PARKED  — стоит (после остановки замораживается, не тратит ресурсы)
#  PLAYER  — ведёт игрок
#  AI_LANE — трафик (кинематически едет по полосе, физики колёс нет)
#  AI_FREE — угнана NPC: едет физически, быстро уезжает

enum Mode { PARKED, PLAYER, AI_LANE, AI_FREE }

var vid: String = "vaz"
var def: Dictionary = {}
var mode: int = Mode.PARKED
var model: Dictionary = {}
var wheel_nodes: Array = []
var spin_nodes: Array = []
var door_node: Node3D = null
var steer_node: Node3D = null
var seat_local: Vector3 = Vector3.ZERO
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

var engine_snd: AudioStreamPlayer3D = null
var hit_zone: Area3D = null
var _recent: Dictionary = {}
var _spin: float = 0.0
var _ex: Array[RID] = []


func setup(id: String, color: Color) -> void:
    vid = id
    def = VehicleDefs.get_def(id)
    mass = def["mass"]
    wheel_r = def["wheel_r"]
    length = def["length"]
    width = def["width"]
    half_len = length * 0.5
    collision_layer = Const.L_VEH
    collision_mask = Const.L_WORLD | Const.L_VEH
    can_sleep = true
    angular_damp = 0.8
    linear_damp = 0.03
    continuous_cd = true
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0.0, -0.12, 0.0)
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
    door_node = model["door"]
    steer_node = model["steer"]
    seat_local = model["seat"]

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
    var s0: float = 0.09
    k_spring = (mass * 9.8 * 0.25) / s0
    c_damp = 2.0 * 0.55 * sqrt(k_spring * mass * 0.25)
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

    hit_zone = Area3D.new()
    hit_zone.collision_layer = 0
    hit_zone.collision_mask = Const.L_CHAR
    hit_zone.monitoring = true
    hit_zone.monitorable = false
    var hz := CollisionShape3D.new()
    var hb := BoxShape3D.new()
    hb.size = Vector3(width + 0.5, 1.4, length + 0.3)
    hz.shape = hb
    hz.position = Vector3(0.0, 0.5, 0.0)
    hit_zone.add_child(hz)
    add_child(hit_zone)

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
    # водителя выгнали/убили: машина больше не ездит по полосе
    ai = null
    if Game.traffic != null:
        Game.traffic.cars.erase(self)
    if mode == Mode.AI_LANE:
        mode = Mode.PARKED
        wake()
        linear_velocity = Vector3.ZERO


func start_escape() -> void:
    # NPC угнал машину и быстро уезжает
    has_player = false
    mode = Mode.AI_FREE
    escape_time = 0.0
    free_t = 0.0
    wake()


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
    var hp: Vector3 = h["position"]
    return hp.y


func exit_position(side: float = -1.0) -> Vector3:
    var off: Vector3 = global_transform.basis.x * side * (width * 0.5 + 0.95)
    var p: Vector3 = global_position + off
    p.y = ground_at(p) + 0.08
    return p


func honk() -> void:
    if horn_cd > 0.0:
        return
    horn_cd = 0.4
    Sfx.play3d("horn", global_position, 3.0, honk_pitch, 90.0)
    if driver_npc != null and is_instance_valid(driver_npc):
        driver_npc.rig.honk()


func shot(pos: Vector3, dir: Vector3, dmg: float) -> void:
    if not freeze:
        apply_impulse(dir * dmg * 0.3, pos - global_position)
    if driver_npc != null and is_instance_valid(driver_npc):
        driver_npc.call("on_vehicle_shot", pos)


func explosion_push(dir: Vector3, f: float) -> void:
    if mode == Mode.AI_LANE:
        detach_ai()
        if driver_npc != null and is_instance_valid(driver_npc):
            driver_npc.call("bail_out", self, true)
    wake()
    apply_central_impulse(dir.normalized() * mass * 9.0 * f)
    apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass * 2.5 * f)


# ---------- физика ----------

func _physics_process(delta: float) -> void:
    horn_cd = maxf(0.0, horn_cd - delta)
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
                if still_t > 1.5:
                    freeze_static()
            else:
                still_t = 0.0
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
    var vmax: float = def["vmax"]
    var power: float = def["power"]
    var lat_k: float = def["lat_k"]
    var grip: float = def["grip"]
    var thr: float = in_throttle
    var brk: float = in_brake
    var hand: bool = in_hand
    var steer_t: float = in_steer
    if mode == Mode.PARKED:
        thr = 0.0
        brk = 1.0
        hand = true
        steer_t = 0.0
    var max_steer: float = float(def["steer"]) * lerpf(1.0, 0.25, clampf(absf(v_long) / vmax * 1.6, 0.0, 1.0))
    steer_angle = move_toward(steer_angle, steer_t * max_steer, delta * 2.2)
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.new()
    q.collision_mask = Const.L_WORLD
    q.exclude = _ex
    var m_w: float = mass * 0.25
    var grounded: int = 0
    var dt: float = maxf(delta, 0.0001)
    for i in 4:
        var mount: Vector3 = xf * (mounts[i] as Vector3)
        q.from = mount
        q.to = mount - up * (max_len + wheel_r)
        var hit: Dictionary = space.intersect_ray(q)
        if hit.is_empty():
            susp_len[i] = move_toward(susp_len[i], max_len, delta * 1.5)
            continue
        var hp: Vector3 = hit["position"]
        var nrm: Vector3 = hit["normal"]
        var slen: float = clampf(mount.distance_to(hp) - wheel_r, min_len, max_len)
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
        var mu: float = grip
        var lk: float = lat_k
        if hand and i >= 2:
            mu *= 0.5
            lk *= 0.3
        var lat: float = -v_r * m_w * lk
        var lon: float = 0.0
        var share: float = drive_share[i]
        var bmax: float = m_w * 11.0
        if absf(thr) > 0.02:
            if thr * v_long < -1.5:
                lon = clampf(-v_f * m_w * 20.0, -bmax, bmax)
            else:
                lon = thr * power * share * (1.0 if thr > 0.0 else 0.6)
                if thr < 0.0 and v_long < -14.0:
                    lon = 0.0
        else:
            lon = -v_f * m_w * 0.5
        if brk > 0.01 or (hand and i >= 2):
            lon = clampf(-v_f * m_w * 20.0, -bmax, bmax)
        var tire: Vector3 = w_fwd * lon + w_right * lat
        var max_f: float = f_spring * mu
        var tl: float = tire.length()
        if tl > max_f and tl > 0.001:
            tire = tire * (max_f / tl)
        apply_force(tire, rel)
    var spd2: float = vel.length_squared()
    if spd2 > 0.01:
        apply_central_force(-vel.normalized() * spd2 * (power / (vmax * vmax)) * 0.9)
    if grounded >= 2:
        var av: Vector3 = angular_velocity
        var rp: Vector3 = av - up * av.dot(up)
        apply_torque(-rp * mass * 0.6)
        if up.dot(Vector3.UP) > 0.3:
            apply_torque(up.cross(Vector3.UP) * mass * 2.0)
    elif grounded == 0:
        apply_torque(-angular_velocity * mass * 0.15)


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
    if stuck_t > 1.8 or blocked and absf(speed_ms) < 3.0:
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
    if absf(speed_ms) < 5.0 or hit_zone == null:
        return
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var dirv: Vector3 = -global_transform.basis.z * signf(speed_ms)
    for b in hit_zone.get_overlapping_bodies():
        if not (b is CharacterBody3D):
            continue
        var bid: int = b.get_instance_id()
        if _recent.has(bid) and now - float(_recent[bid]) < 1.2:
            continue
        _recent[bid] = now
        var dmg: float = clampf(absf(speed_ms) * 9.0, 15.0, 180.0)
        if b.has_method("take_hit"):
            b.call("take_hit", "torso", dmg, dirv, self)
        elif b.has_method("take_damage"):
            b.call("take_damage", dmg * 0.5, dirv)
        Sfx.play3d("crash", global_position, -2.0, 1.0, 60.0)


func _sound(_delta: float) -> void:
    if engine_snd == null:
        return
    var want: bool = false
    if has_player:
        want = true
    elif mode == Mode.AI_LANE or mode == Mode.AI_FREE:
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
        engine_snd.volume_db = -9.0 + 4.0 * absf(in_throttle)
